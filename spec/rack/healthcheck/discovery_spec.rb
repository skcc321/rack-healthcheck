# frozen_string_literal: true

require "spec_helper"
require "rack"
require "rack/lint"
require "rack/mock"
require_relative "../../support/example_integration"

describe Rack::Healthcheck::Discovery do
  it "runs a separately registered test integration without any integration-specific core changes" do
    described_class.register(:example, ExampleIntegration)
    expect { described_class.register(:example, Module.new) }.to raise_error(ArgumentError, "integration already registered: example")
    allow(Rack::Healthcheck).to receive(:configuration).and_return(Rack::Healthcheck::Configuration.new)
    stack = Rack::Builder.new do
      use Rack::Healthcheck::Middleware, { integrations: { example: ["test-only"] } }
      run ->(_env) { [404, {}, []] }
    end
    request = Rack::MockRequest.new(Rack::Lint.new(stack.to_app))
    response = request.get("/healthcheck/complete")

    expect(JSON.parse(response.body).fetch("checks")).to contain_exactly(include("name" => "test-only", "status" => true))
  end
end
