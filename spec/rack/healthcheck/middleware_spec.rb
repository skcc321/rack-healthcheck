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

    let(:fallback_response) { [404, {}, []] }

    context "when is not a healthcheck request" do
      let(:path) { "/path" }

      it "sends request to app" do
        expect(app).to receive(:call).with(env).once.and_return(fallback_response)

        expect(middleware.call(env)).to be(fallback_response)
      end
    end

    context "when is an invalid request method" do
      let(:path) { "/healthcheck/complete" }
      let(:request_method) { "POST" }

      it "sends request to app" do
        expect(app).to receive(:call).with(env).once.and_return(fallback_response)

        expect(middleware.call(env)).to be(fallback_response)
      end
    end
  end
end
