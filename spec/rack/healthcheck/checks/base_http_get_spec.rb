# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"

describe Rack::Healthcheck::Checks::Base, "#http_get" do
  subject(:check) { described_class.new("name", Rack::Healthcheck::Type::INTERNAL_SERVICE, false, nil) }

  let(:visited) { [] }

  def response(klass, code, location: nil, body: nil)
    klass.new("1.1", code, "").tap do |res|
      res["location"] = location if location
      allow(res).to receive(:body).and_return(body)
    end
  end

  def stub_http(*responses)
    allow(Net::HTTP).to receive(:start) do |host, _port, _options, &block|
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request) do |request|
        visited << [host, request.path]
        responses.shift
      end
      block.call(http)
    end
  end

  it "follows a relative redirect against the current url" do
    stub_http(response(Net::HTTPFound, "302", location: "v2?deep=1"), response(Net::HTTPOK, "200", body: "LIVE"))

    expect(check.send(:http_get, "http://service.local/health/v1")).to eq("LIVE")
    expect(visited).to eq([["service.local", "/health/v1"], ["service.local", "/health/v2?deep=1"]])
  end

  it "follows an absolute redirect" do
    stub_http(response(Net::HTTPFound, "302", location: "http://other.local/x"), response(Net::HTTPOK, "200", body: "LIVE"))

    expect(check.send(:http_get, "http://service.local/health")).to eq("LIVE")
    expect(visited).to eq([["service.local", "/health"], ["other.local", "/x"]])
  end

  it "stops before requesting another hop once the limit is exhausted" do
    redirect = response(Net::HTTPFound, "302", location: "/health")
    stub_http(redirect, redirect, redirect, response(Net::HTTPOK, "200", body: "LIVE"))

    expect { check.send(:http_get, "http://service.local/health") }.to raise_error(ArgumentError, "too many HTTP redirects")
    expect(visited).to eq([["service.local", "/health"]] * 3)
  end
end
