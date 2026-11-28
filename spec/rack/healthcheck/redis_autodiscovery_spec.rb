# frozen_string_literal: true

require "spec_helper"
require "redis_client"
require_relative "../../support/discovery_contract"

RSpec.describe Rack::Healthcheck::Middleware, "Redis autodiscovery" do
  let(:healthy_client) do
    RedisClient.config.new_client.tap do |client|
      allow(client).to receive(:call_once).with("PING").and_return("PONG")
    end
  end

  let(:down_client) do
    RedisClient.config.new_client.tap do |client|
      allow(client).to receive(:call_once).with("PING").and_raise(RedisClient::ConnectionError, probe_error)
    end
  end

  include_examples "a declared discovery adapter", :redis

  it "issues exactly one native PING for a configured Redis client" do
    request = mount(integrations: { redis: { cache: { client: healthy_client } } })
    expect(request.get("/healthcheck/complete").status).to eq(200)
    expect(healthy_client).to have_received(:call_once).with("PING").once
  end

  it "distinguishes a rejected client from a Redis PING failure" do
    request = mount(integrations: { redis: { wrong: { client: Object.new }, unavailable: { client: down_client } } })
    response = request.get("/healthcheck/complete")

    expect(results(response)).to contain_exactly(
      include("name" => "wrong", "status" => false, "details" => "Redis client resolution failed"),
      include("name" => "unavailable", "status" => false, "details" => "Redis PING failed")
    )
  end
end
