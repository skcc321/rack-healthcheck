# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class MongoDB < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol, Object>] Hash with optional configs
        # @example
        # name = Database
        # config {
        #   optional: false,
        #   url: "mymongodb.com"
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::DATABASE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            Mongoid.client(config[:name]).command(dbStats: 1)
          end
        end
      end
    end
  end
end
