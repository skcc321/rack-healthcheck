# frozen_string_literal: true

require "rack/healthcheck/checks/redis_client"

module Rack
  module Healthcheck
    module Integrations
      module Redis
        def self.detect(context)
          context.fetch(:redis, {}).map do |name, options|
            -> { Checks::RedisClient.new(name.to_s, options) }
          end
        end

        Discovery.register(:redis, self)
      end
    end
  end
end
