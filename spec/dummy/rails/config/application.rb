# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require_relative "../../manual_check"

class RailsSmoke < Rails::Application
  config.root = File.expand_path("..", __dir__)
  config.eager_load = false
  config.secret_key_base = SecureRandom.hex(32)
  config.logger = Logger.new(IO::NULL)
  config.hosts.clear
  config.middleware.use Rack::Healthcheck::Middleware
end
