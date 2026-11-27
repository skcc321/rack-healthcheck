# frozen_string_literal: true

require "spec_helper"
require "rack/lint"
require "rack/mock"
require "redis_client"

if ENV["HEALTHCHECK_TEST_REDIS_SOCKET"]
  describe "Redis autodiscovery with a live server" do
    let(:socket) { ENV.fetch("HEALTHCHECK_TEST_REDIS_SOCKET") }
    let(:pool) { RedisClient.config(path: socket, timeout: 0.2).new_pool(size: 1, timeout: 0.05) }
    let(:down) { RedisClient.config(path: "#{socket}.missing", timeout: 0.2).new_client }

    after do
      pool.close
      down.close
    end

    def mount(targets)
      downstream = ->(_env) { [404, {}, []] }
      app = Rack::Healthcheck::Middleware.new(downstream, checks: :auto, integrations: { redis: targets })
      Rack::MockRequest.new(Rack::Lint.new(app))
    end

    it "pings a live pool and a separate unavailable target without closing the live pool" do
      allow(pool).to receive(:close).and_call_original
      request = mount(cache: { client: pool }, sessions: { client: -> { down } })
      pool.with do |connection|
        expect(connection.call_once("PING")).to eq("PONG")
      end
      response = request.get("/healthcheck/complete")

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).fetch("checks")).to contain_exactly(
        include("name" => "cache", "status" => true),
        include("name" => "sessions", "status" => false, "details" => "Redis PING failed")
      )
      expect(pool.call_once("PING")).to eq("PONG")
      expect(pool).not_to have_received(:close)
    end

    it "reports a required probe failure when its own pool checkout timeout expires" do
      entered = Queue.new
      release = Queue.new
      request = mount(cache: { client: pool, optional: false })
      occupied = Thread.new do
        pool.with do
          entered << true
          release.pop(timeout: 3)
        end
      end
      expect(entered.pop(timeout: 3)).to be(true)

      response = request.get("/healthcheck/complete")
      check = JSON.parse(response.body).fetch("checks").fetch(0)
      expect(response.status).to eq(503)
      expect(check).to include("status" => false, "details" => "Redis PING failed")
      expect(check.fetch("time")).to be_between(0.04, 2)
    ensure
      release << true
      occupied&.join
    end
  end
end
