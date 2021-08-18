require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Twilio < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Twilio
        # config = {
        #   :account_sid,
        #   :auth_token
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::EXTERNAL_SERVICE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            client = ::Twilio::REST::Client.new config[:account_sid], config[:auth_token]
            client.messages.list(limit: 1)
          end
        end
      end
    end
  end
end
