require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Mailgunner < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Mailgunner
        # config = {
        #   :domain,
        #   :api_key
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::EXTERNAL_SERVICE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            mailgun = ::Mailgunner::Client.new(domain: config[:domain], api_key: config[:api_key])
            mailgun.get_domains
          end
        end
      end
    end
  end
end
