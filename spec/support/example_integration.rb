# frozen_string_literal: true

module ExampleIntegration
  class Check < Rack::Healthcheck::Checks::Base
    def initialize(name)
      super(name, Rack::Healthcheck::Type::CACHE, true, nil)
    end

    private

    def check
      super { true }
    end
  end

  def self.detect(context)
    context.fetch(:example, []).map { |name| -> { Check.new(name) } }
  end

  Rack::Healthcheck::Discovery.register(:example, self)
end
