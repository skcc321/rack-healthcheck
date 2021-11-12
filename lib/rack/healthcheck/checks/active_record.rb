# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class ActiveRecord < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol, Object>] Hash with optional configs
        # @example
        # name = Database
        # config {
        #   optional: false,
        #   url: "mydatabase.com",
        #   connected_to: { role: :primary }
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::DATABASE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            if config.key?(:connected_to)
              ::ActiveRecord::Base.connected_to(**config[:connected_to]) do
                ::ActiveRecord::Base.connection.select_value("SELECT 1 + 1")
              end
            else
              ::ActiveRecord::Base.connection.select_value("SELECT 1 + 1")
            end
          end
        end
      end
    end
  end
end
