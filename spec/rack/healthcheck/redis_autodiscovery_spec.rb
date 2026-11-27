# frozen_string_literal: true

require "spec_helper"
require "rack"
require "rack/lint"
require "rack/mock"
require "redis_client"

describe Rack::Healthcheck::Middleware, "Redis autodiscovery" do
  let(:app) { ->(_env) { [404, {}, ["fallback"]] } }
  let(:configuration) { Rack::Healthcheck::Configuration.new }
  let(:client) { RedisClient.config.new_client }

  before do
    allow(Rack::Healthcheck).to receive(:configuration).and_return(configuration)
  end

  def mount(path = nil, **)
    Rack::MockRequest.new(Rack::Lint.new(described_class.new(Rack::Lint.new(app), path, **)))
  end

  def results(response)
    JSON.parse(response.body).fetch("checks")
  end

  it "probes a configured client by default only on the detailed route" do
    expect(client).to receive(:call_once).with("PING").once.and_return("PONG")
    expect(client).not_to receive(:close)
    request = mount(integrations: { redis: { cache: { client: client } } })

    expect(request.get("/unrelated").status).to eq(404)
    expect(request.get("/healthcheck").status).to eq(200)
    expect(request.post("/healthcheck/complete").status).to eq(404)
    response = request.get("/healthcheck/complete")
    expect(response.status).to eq(200)
    expect(results(response)).to contain_exactly(include("name" => "cache", "status" => true, "optional" => true))
  end

  it "does not infer a dependency from a loaded client gem" do
    expect(results(mount.get("/healthcheck/complete"))).to eq([])
  end

  it "bypasses detection for a legacy explicit empty check array" do
    configuration.checks = []
    source = -> { raise "must not run" }
    expect(results(mount(integrations: { redis: { cache: { client: source } } }).get("/healthcheck/complete"))).to eq([])
  end

  it "lets the mount explicitly override the legacy check selection" do
    configuration.checks = []
    options = { integrations: { redis: { cache: { client: nil } } } }

    expect(results(mount(checks: [], **options).get("/healthcheck/complete"))).to eq([])
    expect(results(mount(checks: :auto, **options).get("/healthcheck/complete"))).to contain_exactly(include("name" => "cache"))
  end

  it "distinguishes resolution failures from probe failures without reporting exception text or URLs" do
    allow(client).to receive(:call_once).and_raise("redis://user:password@cache.internal:6379")
    request = mount(integrations: { redis: {
                      missing: { client: -> { raise "secret from resolver" } },
                      wrong: { client: Object.new },
                      unavailable: { client: client, optional: false }
                    } })
    response = request.get("/healthcheck/complete")

    expect(response.status).to eq(503)
    expect(results(response)).to contain_exactly(
      include("name" => "missing", "status" => false, "optional" => true, "details" => "Redis client resolution failed"),
      include("name" => "wrong", "status" => false, "details" => "Redis client resolution failed"),
      include("name" => "unavailable", "status" => false, "optional" => false, "details" => "Redis PING failed")
    )
    expect(response.body).not_to match(/secret|password|cache\.internal|"url"/)
  end

  it "keeps separate mounts on their own named targets" do
    other = RedisClient.config.new_client
    allow(client).to receive(:call_once).and_return("PONG")
    allow(other).to receive(:call_once).and_return("unexpected")
    first = mount("/first", integrations: { redis: { primary: { client: client } } })
    second = mount("/second", integrations: { redis: { secondary: { client: other } } })

    expect(results(first.get("/first/complete"))).to contain_exactly(include("name" => "primary", "status" => true))
    expect(results(second.get("/second/complete"))).to contain_exactly(include("name" => "secondary", "status" => false))
    expect(first.get("/second/complete").status).to eq(404)
  end

  it "resolves on the request thread and isolates overlapping results on the same mount" do
    entered = Queue.new
    release = Queue.new
    allow(client).to receive(:call_once).and_return("PONG")
    source = lambda do
      if Thread.current[:healthy_request]
        entered << true
        release.pop(timeout: 3)
        client
      end
    end
    request = mount(integrations: { redis: { cache: { client: source } } })

    first = Thread.new do
      Thread.current[:healthy_request] = true
      request.get("/healthcheck/complete")
    end
    expect(entered.pop(timeout: 3)).to be(true)
    expect(results(request.get("/healthcheck/complete"))).to contain_exactly(include("name" => "cache", "status" => false))
    release << true
    expect(results(first.value)).to contain_exactly(include("name" => "cache", "status" => true))
    expect(results(request.get("/healthcheck/complete"))).to contain_exactly(include("name" => "cache", "status" => false))
  ensure
    release << true
    first&.join
  end
end
