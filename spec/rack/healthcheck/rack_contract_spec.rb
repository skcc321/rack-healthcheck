# frozen_string_literal: true

require "spec_helper"
require "rack/lint"
require "rack/mock"

describe "Rack response contract" do
  let(:app) { ->(_env) { [404, { "content-type" => "text/plain" }, ["Not found"]] } }
  let(:middleware) { Rack::Healthcheck::Middleware.new(app) }
  let(:request) { Rack::MockRequest.new(Rack::Lint.new(middleware)) }

  describe "/healthcheck" do
    let(:load_balancer) { Rack::Healthcheck::Actions::LoadBalancer }

    around do |example|
      original_status = load_balancer.status
      example.run
    ensure
      load_balancer.status = original_status
    end

    %w[GET POST DELETE].each do |method|
      it "returns a valid Rack response to #{method}" do
        load_balancer.status = method == "POST" ? load_balancer::DEAD : load_balancer::LIVE
        response = request.request(method, "/healthcheck")

        expect(response.status).to eq(200)
        expect(response["content-type"]).to eq("text/plain")
        expect(response.body).to eq(method == "DELETE" ? "DEAD" : "LIVE")
      end
    end
  end

  describe "/healthcheck/complete" do
    let(:configuration) { Rack::Healthcheck::Configuration.new }

    def failing_check(optional:)
      options = { url: "https://example.test/health", service_type: "INTERNAL_SERVICE", expected_result: "LIVE", optional: optional }
      Rack::Healthcheck::Checks::HTTPRequest.new("service", options).tap do |check|
        allow(check).to receive(:http_get).and_raise(IOError, "unavailable")
      end
    end

    before do
      allow(Rack::Healthcheck).to receive(:configuration).and_return(configuration)
    end

    it "returns a valid Rack response with an empty list when no checks are configured" do
      configuration.checks = nil
      response = request.get("/healthcheck/complete")

      expect(response.status).to eq(200)
      expect(response["content-type"]).to eq("application/json")
      expect(JSON.parse(response.body)).to include("status" => true, "checks" => [])
    end

    it "returns a valid Rack response when a required check fails" do
      configuration.checks = [failing_check(optional: false)]

      response = request.get("/healthcheck/complete")

      expect(response.status).to eq(503)
      expect(response["content-type"]).to eq("application/json")
      expect(JSON.parse(response.body)).to include("status" => false)
    end

    it "reports a failing optional check without marking the endpoint unhealthy" do
      configuration.checks = [failing_check(optional: true)]

      response = request.get("/healthcheck/complete")
      body = JSON.parse(response.body)

      expect(response.status).to eq(200)
      expect(body).to include("status" => true)
      expect(body.fetch("checks")).to contain_exactly(a_hash_including("name" => "service", "status" => false, "optional" => true))
    end
  end
end
