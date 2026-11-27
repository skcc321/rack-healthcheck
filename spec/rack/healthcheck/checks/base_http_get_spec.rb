# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"

describe Rack::Healthcheck::Checks::Base, "#http_get" do
  subject(:check) { described_class.new("name", Rack::Healthcheck::Type::INTERNAL_SERVICE, false, nil) }

  def response(klass, code, location: nil, body: nil)
    klass.new("1.1", code, "").tap do |res|
      res["location"] = location if location
      allow(res).to receive(:body).and_return(body)
    end
  end

  it "follows a relative redirect against the current url" do
    visited = []
    allow(Net::HTTP).to receive(:start) do |host, _port, _options, &_block|
      visited << host
      visited.size == 1 ? response(Net::HTTPFound, "302", location: "/health/v2") : response(Net::HTTPOK, "200", body: "LIVE")
    end

    expect(check.send(:http_get, "http://service.local/health")).to eq("LIVE")
    expect(visited).to eq(%w[service.local service.local])
  end

  it "follows an absolute redirect" do
    calls = 0
    allow(Net::HTTP).to receive(:start) do
      calls += 1
      calls == 1 ? response(Net::HTTPFound, "302", location: "http://other.local/x") : response(Net::HTTPOK, "200", body: "LIVE")
    end

    expect(check.send(:http_get, "http://service.local/health")).to eq("LIVE")
  end
end
