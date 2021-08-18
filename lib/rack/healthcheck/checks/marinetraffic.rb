require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Marinetraffic < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Marinetraffic
        # config = {
        #   :api_key
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::EXTERNAL_SERVICE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            url = "https://services.marinetraffic.com/api/#{config[:api_name]}/#{config[:api_key]}/protocol:jsono"
            http_get(url)
          end
        end
      end
    end
  end
end
