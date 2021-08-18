require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Chewy < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Chewy
        # config = {
        #   :index,
        #   :url
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::DATABASE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            config[:index].query("").count
          end
        end
      end
    end
  end
end
