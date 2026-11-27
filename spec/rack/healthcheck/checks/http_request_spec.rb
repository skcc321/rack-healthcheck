# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"

describe Rack::Healthcheck::Checks::HTTPRequest do
  let(:expected_result) { "LIVE" }
  let(:config) do
    {
      url: "http://localhost.com",
      service_type: Rack::Healthcheck::Type::INTERNAL_SERVICE,
      expected_result: expected_result
    }
  end
  let(:http_request_check) { described_class.new("name", config) }

  describe ".new" do
    [nil, "localhost.com", "ftp://localhost.com", "x\nhttp://localhost.com"].each do |invalid_url|
      it "raises InvalidURL for #{invalid_url.inspect}" do
        expect { described_class.new("name", config.merge(url: invalid_url)) }
          .to raise_error(Rack::Healthcheck::Checks::HTTPRequest::InvalidURL)
      end
    end

    it "sets type as INTERNAL_SERVICE" do
      expect(http_request_check.type).to eq(Rack::Healthcheck::Type::INTERNAL_SERVICE)
    end
  end

  describe "#run" do
    subject(:run_it) { http_request_check.run }

    let(:response) { Net::HTTPOK.new("1.1", "200", "OK") }
    let(:body) { "LIVE" }

    before do
      allow(Net::HTTP).to receive(:start).and_return(response)
      allow(response).to receive(:body).and_return(body)
    end

    context "when server is available and returns the expected result" do
      it "sets status to true" do
        run_it

        expect(http_request_check.status).to be_truthy
      end
    end

    context "when the response differs from the expected result" do
      let(:body) { "something" }

      it "sets status to false" do
        run_it

        expect(http_request_check.status).to be_falsy
        expect(http_request_check.details).to include("Response body does not match")
      end
    end

    context "when the expected result is a regular expression" do
      let(:expected_result) { /\ALIVE \d+\z/ }

      it "accepts a matching response" do
        allow(response).to receive(:body).and_return("LIVE 42")
        run_it

        expect(http_request_check.status).to be(true)
      end

      it "rejects a non-matching response" do
        run_it

        expect(http_request_check.status).to be(false)
        expect(http_request_check.details).to include("Response body does not match")
      end
    end

    context "when server is down" do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout, "unavailable")
      end

      it "sets status to false" do
        run_it

        expect(http_request_check.status).to be_falsy
        expect(http_request_check.details).to eq("unavailable")
      end
    end

    it "sets elapsed_time" do
      run_it

      expect(http_request_check.elapsed_time).to be_a(Numeric)
    end
  end
end
