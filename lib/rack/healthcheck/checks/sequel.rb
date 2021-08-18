require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Sequel < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol, Object>] Hash with optional configs
        # @example
        # name = Database
        # config {
        #   optional: false,
        #   url: "mydatabase.com",
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::DATABASE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            ::Sequel.connect(config[:url]) do |db|
              db.get("1 + 1")
            end
          end
        end
      end
    end
  end
end
