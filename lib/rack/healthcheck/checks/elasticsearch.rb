# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Elasticsearch < Base
        attr_reader :options

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Elasticsearch
        # config = {
        #   :url,
        #   :optional
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::DATABASE, config[:optional], config[:url])
          @options = config[:options]
        end

        private

        def check
          super do
            client = ::Elasticsearch::Client.new(url: url, log: true, request_timeout: TIMEOUT)
            client.cluster.health
          end
        end
      end
    end
  end
end
