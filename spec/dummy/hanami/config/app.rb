# frozen_string_literal: true

require_relative "../../profile"

module Smoke
  class App < Hanami::App
    config.middleware.use Rack::Healthcheck::Middleware, DummyProfile.options
  end
end
