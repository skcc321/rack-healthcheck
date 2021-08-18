require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class OhPipe < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = OhPipe
        # config = {
        #   queue_name: "tracking",
        # }
        def initialize(name, config)
          super(name, Rack::Healthcheck::Type::MESSAGING, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          catch_status do
            redis = ::Redis.new(config)
            redis.info
          end
        end
      end
    end
  end
end
