# frozen_string_literal: true

require "rack/healthcheck/actions/load_balancer"
require "rack/healthcheck/actions/complete"

module Rack
  module Healthcheck
    class Action
      class InvalidAction < RuntimeError; end

      @mount_at = "healthcheck"

      class << self
        attr_accessor :mount_at

        def get(path, request_method, mount_at: self.mount_at)
          action = available_actions(mount_at: mount_at)[path]
          raise InvalidAction, "Unknown action" unless action

          action.send(:new, path, request_method)
        end

        def available_actions(mount_at: self.mount_at)
          route = mount_at.gsub(%r{^/}, "")
          {
            "/#{route}" => Rack::Healthcheck::Actions::LoadBalancer,
            "/#{route}/complete" => Rack::Healthcheck::Actions::Complete
          }
        end
      end

      private_class_method :new
    end
  end
end
