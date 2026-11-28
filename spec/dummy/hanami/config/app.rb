# frozen_string_literal: true

require_relative "../../manual_check"

module Smoke
  class App < Hanami::App
    config.middleware.use Rack::Healthcheck::Middleware
  end
end
