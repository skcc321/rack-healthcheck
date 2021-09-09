# frozen_string_literal: true

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
          super do
            response = http_get(url)
            if config[:expected_result].is_a?(Regexp)
              config[:expected_result].match(response)
            else
              response == config[:expected_result]
            end || raise("Response body does not match: #{response} <> #{config[:expected_result]}")
          end
        end
      end
    end
  end
end
