# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class RedisClient < Base
        def initialize(name, options)
          super(name, Type::CACHE, options.fetch(:optional, true), nil)
          @source = options[:client]
        end

        private

        def check
          client = resolve_client
          return fail_with("Redis client resolution failed") unless client

          @status = client.call_once("PING") == "PONG"
          @details = @status ? nil : "Redis PING failed"
        rescue StandardError
          fail_with("Redis PING failed")
        end

        def resolve_client
          return @source if redis_client?(@source)
          return unless @source.respond_to?(:call)

          client = @source.call
          client if redis_client?(client)
        rescue StandardError
          nil
        end

        def redis_client?(value)
          defined?(::RedisClient) && (value.is_a?(::RedisClient) || value.is_a?(::RedisClient::Pooled))
        end

        def fail_with(details)
          @status = false
          @details = details
        end
      end
    end
  end
end
