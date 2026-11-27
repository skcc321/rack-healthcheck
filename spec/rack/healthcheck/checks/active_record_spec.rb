# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"
require "active_record"

describe Rack::Healthcheck::Checks::ActiveRecord do
  let(:active_record_check) { described_class.new("name") }
  let(:connection_pool) { double("ARconnectionPool", select_value: "2") }

  describe ".new" do
    it "sets type as DATABASE" do
      expect(active_record_check.type).to eq(Rack::Healthcheck::Type::DATABASE)
    end
  end

  describe "#run" do
    subject(:run_it) { active_record_check.run }

    context "when database is up" do
      before do
        allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection_pool)
      end

      it "sets status to true" do
        run_it

        expect(active_record_check.status).to be_truthy
      end
    end

    context "when database is down" do
      before do
        allow(ActiveRecord::Base).to receive(:with_connection)
          .and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it "sets status to false" do
        run_it

        expect(active_record_check.status).to be_falsy
      end
    end

    context "with a configured role and shard" do
      let(:active_record_check) do
        described_class.new("name", connected_to: { role: :reading, shard: :replica })
      end

      it "runs the probe inside the configured connection context" do
        inside_context = false
        allow(ActiveRecord::Base).to receive(:connected_to).with(role: :reading, shard: :replica) do |&query|
          inside_context = true
          query.call
        ensure
          inside_context = false
        end
        expect(ActiveRecord::Base).to receive(:with_connection) do |&probe|
          expect(inside_context).to be(true)
          probe.call(connection_pool)
        end
        expect(connection_pool).to receive(:select_value).with("SELECT 1 + 1").and_return("2")

        run_it

        expect(active_record_check.status).to be(true)
      end
    end

    it "sets elapsed_time" do
      run_it

      expect(active_record_check.elapsed_time).to_not be_nil
    end
  end
end
