# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"
require "mongoid"

describe Rack::Healthcheck::Checks::MongoDB do
  let(:mongo_check) { described_class.new("name") }

  describe ".new" do
    it "sets type as DATABASE" do
      expect(mongo_check.type).to eq(Rack::Healthcheck::Type::DATABASE)
    end
  end

  describe "#run" do
    subject(:run_it) { mongo_check.run }

    context "when database is up" do
      let(:connection) { double("mongoid::connection", command: "OK") }

      before do
        allow(Mongoid).to receive(:client).with(any_args) { connection }
      end

      it "sets status to true" do
        run_it

        expect(mongo_check.status).to be_truthy
      end
    end

    context "when database is down" do
      before do
        allow(Mongoid).to receive(:client).and_raise(StandardError)
      end

      it "sets status to false" do
        run_it

        expect(mongo_check.status).to be_falsy
      end
    end

    it "sets elapsed_time" do
      run_it

      expect(mongo_check.elapsed_time).to_not be_nil
    end
  end
end
