# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"
require "redis"

describe Rack::Healthcheck::Checks::Redis do
  let(:redis_check) { described_class.new("name", {}) }
  let(:connection) { double(info: true) }

  describe ".new" do
    it "sets type as CACHE" do
      expect(redis_check.type).to eq(Rack::Healthcheck::Type::CACHE)
    end
  end

  describe "#run" do
    subject(:run_it) { redis_check.run }

    before do
      allow(Redis).to receive(:new).with(any_args).and_return(connection)
    end

    context "when redis server is available" do
      it "sets status to true" do
        run_it

        expect(redis_check.status).to be_truthy
      end
    end

    context "when redis server is down" do
      before do
        allow(connection).to receive(:info).and_raise(StandardError)
      end

      it "sets status to false" do
        run_it

        expect(redis_check.status).to be_falsy
      end
    end

    it "sets elapsed_time" do
      run_it

      expect(redis_check.elapsed_time).to_not be_nil
    end
  end
end
