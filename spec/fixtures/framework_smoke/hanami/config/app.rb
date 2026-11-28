# frozen_string_literal: true

require_relative "../../redis_fixture"

module Smoke
  class App < Hanami::App
    config.middleware.use Rack::Healthcheck::Middleware, RedisFixture.options
  end
end
