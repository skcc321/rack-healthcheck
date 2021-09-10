# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Pusher < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Pusher
        # config = {
        #   :app_id,
        #   :key,
        #   :secret,
        #   :cluster
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::EXTERNAL_SERVICE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            pusher = ::Pusher::Client.new(
              app_id: config[:app_id],
              key: config[:key],
              secret: config[:secret],
              cluster: config[:cluster],
              use_tls: true
            )
            pusher.get("/channels")
          end
        end
      end
    end
  end
end
