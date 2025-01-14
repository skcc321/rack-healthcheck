# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class RabbitMQ < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,Object>] Hash with configs
        # @example
        # name = RabbitMQ
        # config = {
        #   hosts: [localhost],
        #   port: 5672,
        #   user: guest,
        #   pass: guest,
        #   optional: true
        # }
        def initialize(name, config)
          super(name, Rack::Healthcheck::Type::MESSAGING, config[:optional], config[:hosts])
          @config = config
        end

        private

        def check
          super do
            connection = Bunny.new(config)
            connection.start
            connection.close
          end
        end
      end
    end
  end
end
