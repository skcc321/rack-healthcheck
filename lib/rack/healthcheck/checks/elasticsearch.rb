require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class Elasticsearch < Base
        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = Elasticsearch
        # config = {
        #   :url
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::DATABASE, config[:optional], config[:url])
        end

        private

        def check
          super do
            client = ::Elasticsearch::Client.new(url: url, log: true)
            client.cluster.health
          end
        end
      end
    end
  end
end
