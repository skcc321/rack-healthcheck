# frozen_string_literal: true

require "rack/healthcheck"
require "redis_client"

module RedisFixture
  class << self
    attr_reader :pool, :resolutions

    def options
      socket = ENV.fetch("HEALTHCHECK_TEST_REDIS_SOCKET")
      @resolutions = 0
      @pool = client_config(socket).new_pool(size: 1, timeout: 0.2)
      unreachable = client_config("#{socket}.down").new_client
      at_exit do
        pool.close
        unreachable.close
      end

      { integrations: { redis: { cache: { client: method(:resolve) }, unreachable: { client: unreachable } } } }
    end

    private

    def client_config(socket)
      RedisClient.config(path: socket, timeout: 0.2, reconnect_attempts: 0)
    end

    def resolve
      @resolutions += 1
      pool
    end
  end
end
