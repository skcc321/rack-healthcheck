# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"
require "bunny"

describe Rack::Healthcheck::Checks::RabbitMQ do
  let(:rabbit_check) { described_class.new("name", {}) }
  let(:connection) { double(start: true, close: true) }

  describe ".new" do
    it "sets type as MESSAGING" do
      expect(rabbit_check.type).to eq(Rack::Healthcheck::Type::MESSAGING)
    end
  end

  describe "#run" do
    subject(:run_it) { rabbit_check.run }

    before do
      allow(Bunny).to receive(:new).with(any_args).and_return(connection)
    end

    context "when rabbit server is available" do
      it "sets status to true" do
        run_it

        expect(rabbit_check.status).to be_truthy
      end
    end

    context "when rabbit server is down" do
      before do
        allow(connection).to receive(:start).and_raise(Bunny::AuthenticationFailureError)
      end

      it "sets status to false" do
        run_it

        expect(rabbit_check.status).to be_falsy
      end
    end

    it "sets elapsed_time" do
      run_it

      expect(rabbit_check.elapsed_time).to_not be_nil
    end
  end
end
