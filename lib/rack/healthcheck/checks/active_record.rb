require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class ActiveRecord < Base
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
        end

        private

        def check
          catch_status do
            if config.key?(:connected_to)
              ActiveRecord::Base.connected_to(config[:connected_to]) do
                ::ApplicationRecord.connection.select_value('SELECT 1') == 1
              end
            else
              ::ApplicationRecord.connection.select_value('SELECT 1') == 1
            end
          end
        end
      end
    end
  end
end
