# frozen_string_literal: true

require "rack"
require "rack/lint"
require "rack/mock"

# The including adapter supplies real client instances with the network operation
# stubbed: healthy_client succeeds, down_client raises with probe_error.
RSpec.shared_examples "a declared discovery adapter" do |integration| # rubocop:disable Metrics/BlockLength
  let(:configuration) { Rack::Healthcheck::Configuration.new }
  let(:fallback) { ->(_env) { [404, {}, ["fallback"]] } }
  let(:probe_error) { "probe://user:probe-secret@private.example" }

  before do
    allow(Rack::Healthcheck).to receive(:configuration).and_return(configuration)
  end

  def mount(path = nil, **)
    app = Rack::Healthcheck::Middleware.new(Rack::Lint.new(fallback), path, **)
    Rack::MockRequest.new(Rack::Lint.new(app))
  end

  def results(response)
    JSON.parse(response.body).fetch("checks")
  end

  it "has no checks when the adapter's client library is loaded but no target is declared" do
    response = mount.get("/healthcheck/complete")

    expect(response.status).to eq(200)
    expect(results(response)).to be_empty
  end

  it "honors an explicit empty mount even without a legacy selection" do
    resolutions = 0
    source = lambda do
      resolutions += 1
      healthy_client
    end
    options = { integrations: { integration => { cache: { client: source } } } }

    expect(results(mount(checks: [], **options).get("/healthcheck/complete"))).to be_empty
    expect(resolutions).to be_zero
  end

  it "lets an explicit auto mount override an empty legacy selection" do
    configuration.checks = []
    source = -> { healthy_client }
    options = { integrations: { integration => { cache: { client: source } } } }

    expect(results(mount(**options).get("/healthcheck/complete"))).to be_empty

    response = mount(checks: :auto, **options).get("/healthcheck/complete")
    expect(results(response)).to contain_exactly(include("name" => "cache", "status" => true))
  end

  it "runs a manual mount check instead of discovering configured targets" do
    manual = Class.new(Rack::Healthcheck::Checks::Base) do
      def check
        super { true }
      end
    end.new("manual", Rack::Healthcheck::Type::CACHE, false, nil)
    source = -> { raise "explicit checks must bypass the resolver" }
    request = mount(checks: [manual], integrations: { integration => { cache: { client: source } } })

    response = request.get("/healthcheck/complete")
    expect(response.status).to eq(200)
    expect(results(response)).to contain_exactly(include("name" => "manual", "status" => true))
  end

  it "resolves only on detailed GET and leaves the app-owned client open" do
    client = healthy_client
    expect(client).not_to receive(:close)
    resolutions = 0
    source = lambda do
      resolutions += 1
      client
    end
    targets = { cache: { client: source } }
    request = mount(integrations: { integration => targets })

    expect(resolutions).to be_zero
    expect(request.get("/unrelated").body).to eq("fallback")
    expect(request.get("/healthcheck").status).to eq(200)
    expect(request.post("/healthcheck/complete").status).to eq(404)
    expect(resolutions).to be_zero

    response = request.get("/healthcheck/complete")
    expect(response.status).to eq(200)
    expect(results(response)).to contain_exactly(include("name" => "cache", "status" => true, "optional" => true))
    expect(resolutions).to eq(1)
  end

  [true, false].each do |optional|
    it "reports configured probe and resolver failures without leaking credentials (optional: #{optional})" do
      targets = { cache: { client: down_client, optional: optional }, missing: { client: -> { raise "resolver-secret" } } }
      response = mount(integrations: { integration => targets }).get("/healthcheck/complete")
      body = JSON.parse(response.body)

      expect(response.status).to eq(optional ? 200 : 503)
      expect(body.fetch("status")).to eq(optional)
      expect(results(response)).to contain_exactly(
        include("name" => "cache", "status" => false, "optional" => optional),
        include("name" => "missing", "status" => false, "optional" => true)
      )
      expect(response.body).not_to match(/probe-secret|resolver-secret|private\.example|"url"/)
    end
  end

  it "keeps each mount on its own named target" do
    first = mount("/first", integrations: { integration => { primary: { client: healthy_client } } })
    second = mount("/second", integrations: { integration => { secondary: { client: down_client } } })

    expect(results(first.get("/first/complete"))).to contain_exactly(include("name" => "primary", "status" => true))
    expect(results(second.get("/second/complete"))).to contain_exactly(include("name" => "secondary", "status" => false))
    expect(first.get("/second/complete").status).to eq(404)
  end

  it "resolves on the request thread and isolates overlapping requests to the same mount" do
    entered = Queue.new
    release = Queue.new
    healthy = healthy_client
    down = down_client
    source = lambda do
      next down unless Thread.current[:discovery_contract_first_request]

      entered << true
      release.pop(timeout: 3) ? healthy : raise("first request timed out")
    end
    request = mount(integrations: { integration => { cache: { client: source, optional: false } } })
    first = Thread.new do
      Thread.current[:discovery_contract_first_request] = true
      request.get("/healthcheck/complete")
    end
    expect(entered.pop(timeout: 3)).to be(true)

    second = request.get("/healthcheck/complete")
    expect(second.status).to eq(503)
    expect(results(second)).to contain_exactly(include("name" => "cache", "status" => false))
    release << true
    healthy_response = (first.join(3) || raise("first request did not finish")).value
    expect(healthy_response.status).to eq(200)
    expect(results(healthy_response)).to contain_exactly(include("name" => "cache", "status" => true))
  ensure
    release << true
    first&.kill unless first&.join(3)
  end
end
