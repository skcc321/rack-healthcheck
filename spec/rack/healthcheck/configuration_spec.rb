# frozen_string_literal: true

require "spec_helper"

describe Rack::Healthcheck::Configuration do
  subject(:configuration) { described_class.new }

  describe "#checks" do
    it "defaults to an empty array" do
      expect(configuration.checks).to eq([])
    end

    it "returns the configured checks" do
      configuration.checks = [:check]

      expect(configuration.checks).to eq([:check])
    end
  end
end
