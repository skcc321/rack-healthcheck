# frozen_string_literal: true

require "rack/healthcheck/action"

module Rack
  module Healthcheck
    class Middleware
      def initialize(app, mount_at = nil)
        @app = app
        @mount_at = mount_at
      end

      def call(env)
        path = env["PATH_INFO"]
        request_method = env["REQUEST_METHOD"]

        mount_at = @mount_at.nil? ? Rack::Healthcheck::Action.mount_at : @mount_at
        action = Rack::Healthcheck::Action.get(path, request_method, mount_at: mount_at)
        action.send(request_method.downcase)
      rescue Rack::Healthcheck::Action::InvalidAction, Rack::Healthcheck::Actions::Base::InvalidRequestMethod
        @app.call(env)
      end
    end
  end
end
