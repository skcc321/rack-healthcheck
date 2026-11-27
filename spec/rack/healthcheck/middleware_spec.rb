# frozen_string_literal: true

require "spec_helper"

describe Rack::Healthcheck::Middleware do
  let(:app) { double }
  let(:env) do
    {
      "PATH_INFO" => path,
      "REQUEST_METHOD" => request_method
    }
  end

  subject(:middleware) { described_class.new(app) }

  describe "#call" do
    let(:path) { "/healthcheck" }
    let(:request_method) { "GET" }

    context "when the detailed endpoint is requested" do
      let(:path) { "/healthcheck/complete" }
      let(:checks) { [] }

      before do
        configuration = Rack::Healthcheck::Configuration.new
        configuration.checks = checks
        allow(Rack::Healthcheck).to receive(:configuration).and_return(configuration)
      end

      it "returns a Rack success response" do
        status, headers, body = middleware.call(env)

        expect([status, headers, JSON.parse(body.join)["status"]]).to eql([200, { "content-type" => "application/json" }, true])
      end

      context "when a required check fails" do
        let(:checks) do
          options = { url: "https://example.test/health", service_type: "INTERNAL_SERVICE", expected_result: "LIVE" }
          check = Rack::Healthcheck::Checks::HTTPRequest.new("service", options)
          allow(check).to receive(:http_get).and_raise(IOError, "unavailable")
          [check]
        end

        it "returns a Rack service unavailable response" do
          status, headers, body = middleware.call(env)

          expect([status, headers, JSON.parse(body.join)["status"]]).to eql([503, { "content-type" => "application/json" }, false])
        end
      end
    end

    context "when is not a healthcheck request" do
      let(:path) { "/path" }

      it "sends request to app" do
        allow(Rack::Healthcheck::Action).to receive(:get).and_raise(Rack::Healthcheck::Action::InvalidAction)
        expect(app).to receive(:call).once

        middleware.call(env)
      end
    end

    context "when is an invalid request method" do
      let(:request_method) { "PATH" }

      it "sends request to app" do
        allow(Rack::Healthcheck::Action).to receive(:get).and_raise(Rack::Healthcheck::Actions::Base::InvalidRequestMethod)
        expect(app).to receive(:call).once

        middleware.call(env)
      end
    end

    context "when is a healthcheck request" do
      let(:action) { Rack::Healthcheck::Actions::LoadBalancer.new(path, request_method) }
      it "performs the checks" do
        allow(Rack::Healthcheck::Action).to receive(:get).and_return(action)

        expect(action).to receive(:get).once
        middleware.call(env)
      end
    end
  end
end
