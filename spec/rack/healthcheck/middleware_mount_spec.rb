# frozen_string_literal: true

require "spec_helper"

describe Rack::Healthcheck::Middleware, "mount paths" do
  let(:app) { ->(_env) { [404, {}, ["fallback"]] } }
  let(:custom_middleware) { described_class.new(app, "/custom") }

  around do |example|
    original_path = Rack::Healthcheck::Action.mount_at
    Rack::Healthcheck::Action.mount_at = "healthcheck"
    example.run
  ensure
    Rack::Healthcheck::Action.mount_at = original_path
  end

  def request_body(middleware, path)
    middleware.call("PATH_INFO" => path, "REQUEST_METHOD" => "GET").last.join
  end

  it "keeps the load-balancer route on the middleware that defines it" do
    first = custom_middleware
    second = described_class.new(app, "/another")

    expect(request_body(first, "/custom")).to match(/\A(?:LIVE|DEAD)\z/)
    expect(request_body(first, "/another")).to eq("fallback")
    expect(request_body(second, "/another")).to match(/\A(?:LIVE|DEAD)\z/)
  end

  it "lets a changed default move only the middleware without an explicit mount" do
    default = described_class.new(app)
    custom = custom_middleware
    Rack::Healthcheck::Action.mount_at = "/configured"

    expect(request_body(default, "/configured")).to match(/\A(?:LIVE|DEAD)\z/)
    expect(request_body(default, "/healthcheck")).to eq("fallback")
    expect(request_body(custom, "/custom")).to match(/\A(?:LIVE|DEAD)\z/)
    expect(request_body(custom, "/configured")).to eq("fallback")
  end

  it "keeps the default detailed route after a custom mount is created" do
    allow(Rack::Healthcheck).to receive(:configuration).and_return(Rack::Healthcheck::Configuration.new)
    custom = custom_middleware
    default = described_class.new(app)

    expect(JSON.parse(request_body(default, "/healthcheck/complete"))).to include("status" => true)
    expect(request_body(default, "/custom/complete")).to eq("fallback")
    expect(JSON.parse(request_body(custom, "/custom/complete"))).to include("status" => true)
  end
end
