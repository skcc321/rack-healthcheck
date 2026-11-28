# frozen_string_literal: true

module Rack
  module Healthcheck
    module Discovery
      @detectors = {}

      class << self
        # Entrypoints register at boot. A detector returns factories, never shared check instances.
        def register(id, detector)
          previous = @detectors.fetch(id, detector)
          raise ArgumentError, "integration already registered: #{id}" unless previous.equal?(detector)

          @detectors[id] = detector
        end

        def run(context)
          @detectors.values.flat_map { |detector| detector.detect(context) }.map do |factory|
            factory.call.tap(&:run)
          end
        end
      end
    end
  end
end

# Dir.glob sorts by default; only entrypoints in the gem directory are loaded.
Dir.glob("integrations/*.rb", base: __dir__).each { |entrypoint| require_relative entrypoint }
