# frozen_string_literal: true

require "rack/healthcheck/action"

module Rack
  module Healthcheck
    class Middleware
      # Rack stacks can forward middleware options as a positional hash.
      def initialize(app, mount_at = nil, options = {})
        if mount_at.is_a?(Hash)
          options = mount_at
          mount_at = nil
        end
        @app = app
        @mount_at = mount_at
        @check_mode = options[:checks]
        @integrations = options.fetch(:integrations, {})
      end

      def call(env)
        path = env["PATH_INFO"]
        request_method = env["REQUEST_METHOD"]

        mount_at = @mount_at.nil? ? Rack::Healthcheck::Action.mount_at : @mount_at
        action = Rack::Healthcheck::Action.get(path, request_method, mount_at: mount_at)
        return action.get(**check_options) if action.is_a?(Actions::Complete)

        action.send(request_method.downcase)
      rescue Rack::Healthcheck::Action::InvalidAction, Rack::Healthcheck::Actions::Base::InvalidRequestMethod
        @app.call(env)
      end

      private

      def check_options
        mode = @check_mode
        mode = :auto if mode.nil? && !Rack::Healthcheck.configuration.checks_configured?
        return { integrations: @integrations } if mode == :auto
        return {} if mode.nil?

        { checks: mode }
      end
    end
  end
end
