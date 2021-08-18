require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"
require "uri"
require "net/http"

module Rack
  module Healthcheck
    module Checks
      class HTTPRequest < Base
        class InvalidURL < RuntimeError; end

        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol, Object>] Hash with configs
        # @example
        # name = Ceph or Another system
        # config = {
        #   url: localhost,
        #   service_type: "INTERNAL_SERVICE",
        #   expected_result: "LIVE",
        #   optional: true
        # }
        # @see Rack::Healthcheck::Type
        def initialize(name, config)
          raise InvalidURL, "Expected :url to be a http or https endpoint" if config[:url].match(%r{^(http://|https://)}).nil?

          super(name, config[:service_type], config[:optional], config[:url])
          @config = config
        end

        private

        def check
          catch_status do
            uri = URI(url)
            response = Net::HTTP.get_response(uri)
            response.body.delete("\n") == config[:expected_result] ||
              raise("Response body does not match expected: #{response.body} <> #{config[:expected_result]}")
          end
        end
      end
    end
  end
end
