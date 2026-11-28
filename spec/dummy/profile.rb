# frozen_string_literal: true

require "rack/healthcheck"

# Selects how the dummy apps configure the middleware. "manual" uses the
# app-owned check from manual_check.rb; "redis" uses :auto discovery against
# the disposable Redis server started by the test harness.
module DummyProfile
  def self.options
    profile = ENV.fetch("HEALTHCHECK_DUMMY_PROFILE", "manual")
    case profile
    when "manual"
      require_relative "manual_check"
      {}
    when "redis"
      require_relative "redis_fixture"
      RedisFixture.options
    else raise "unknown dummy profile: #{profile}"
    end
  end

  # Number of client resolutions so far, or nil when the profile has none.
  def self.resolutions
    RedisFixture.resolutions if defined?(RedisFixture)
  end
end
