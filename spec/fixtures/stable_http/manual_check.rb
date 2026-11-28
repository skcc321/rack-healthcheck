# frozen_string_literal: true

require "rack/healthcheck"

# A deterministic, app-owned check exercising the stable configuration API.
class FixtureCheck
  def run
    @healthy = true
  end

  def keep_in_pool?
    @healthy
  end

  def to_hash
    { name: "manual", status: @healthy, optional: false }
  end
end

Rack::Healthcheck.configure do |config|
  config.app_name = "fixture"
  config.app_version = "1"
  config.checks = [FixtureCheck.new]
end
