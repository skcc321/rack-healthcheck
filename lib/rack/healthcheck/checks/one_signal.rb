# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

module Rack
  module Healthcheck
    module Checks
      class OneSignal < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = OneSignal
        # config = {
        #   app_id: "one signal app id",
        # }
        def initialize(name, config)
          super(name, Rack::Healthcheck::Type::EXTERNAL_SERVICE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            ::OneSignal::App.get(id: config[:app_id])
          end
        end
      end
    end
  end
end
