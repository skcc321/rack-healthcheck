# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"

describe Rack::Healthcheck::Checks::Base do
  let(:name) { "name" }
  let(:type) { Rack::Healthcheck::Type::DATABASE }
  let(:optional) { false }
  let(:url) { "http://some_url" }

  subject(:base_check) { described_class.new(name, type, optional, url) }

  describe ".new" do
    context "when an invalid type is informed" do
      let(:type) { "type" }

      it "raises Rack::Healthcheck::Checks::Base::InvalidType exception" do
        expect { base_check }.to raise_error(Rack::Healthcheck::Checks::Base::InvalidType)
      end
    end
  end

  describe "#to_hash" do
    it "returns only filled attributes" do
      expect(base_check.to_hash.keys).to contain_exactly(:name, :type, :optional, :url)
    end
  end

  describe "#run" do
    let(:failing_check_class) do
      Class.new(described_class) do
        attr_accessor :fail

        def check
          super { raise "boom" if fail }
        end
      end
    end
    let(:check) { failing_check_class.new(name, type, optional, url) }

    it "reports the error message when the check fails" do
      check.fail = true
      check.run

      expect(check.to_hash).to include(status: false, details: "boom")
    end

    it "clears details once the check recovers" do
      check.fail = true
      check.run
      check.fail = false
      check.run

      expect(check.to_hash).to include(status: true)
      expect(check.to_hash).not_to have_key(:details)
    end
  end

  describe "#keep_in_pool?" do
    context "when optional is true" do
      before(:each) do
        base_check.optional = true
      end

      context "when status is true" do
        before do
          allow(base_check).to receive(:status) { true }
        end

        it { expect(base_check.keep_in_pool?).to be_truthy }
      end

      context "when status is false" do
        before do
          allow(base_check).to receive(:status) { false }
        end

        it { expect(base_check.keep_in_pool?).to be_truthy }
      end
    end

    context "when optional is false" do
      before(:each) do
        base_check.optional = false
      end

      context "when status is true" do
        before do
          allow(base_check).to receive(:status) { true }
        end

        it { expect(base_check.keep_in_pool?).to be_truthy }
      end

      context "when status is false" do
        before do
          allow(base_check).to receive(:status) { false }
        end

        it { expect(base_check.keep_in_pool?).to be_falsy }
      end
    end
  end
end
