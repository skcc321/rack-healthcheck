require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Carrierwave < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Twilio
        # config = {
        #   :uploader,
        #   :file
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::EXTERNAL_SERVICE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            config[:uploader].store!(config[:file])
            config[:uploader].retrieve_from_store!(config[:uploader].filename)
            config[:uploader].file.read
            config[:uploader].file.delete
          end
        end
      end
    end
  end
end
