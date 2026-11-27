# frozen_string_literal: true

require "spec_helper"
require "rack/healthcheck/type"

describe Rack::Healthcheck::Checks::S3 do
  let(:s3_check) { described_class.new("name", bucket: "bucket") }
  let(:objects) { [] }
  let(:bucket) { double }

  before do
    stub_const("Aws::S3::Resource", Class.new)
    allow(Aws::S3::Resource).to receive(:new).and_return(double(bucket: bucket))
    allow(bucket).to receive(:object) do |key|
      double(upload_file: true, delete: true).tap { |object| objects << [key, object] }
    end
  end

  describe "#run" do
    it "uploads and deletes the probe object" do
      s3_check.run

      expect(s3_check.status).to be(true)
      expect(objects.size).to eq(1)
      expect(objects.first.last).to have_received(:upload_file)
      expect(objects.first.last).to have_received(:delete)
    end

    it "uses a different key on every run so concurrent probes do not collide" do
      2.times { s3_check.run }

      expect(objects.map(&:first).uniq.size).to eq(2)
    end

    it "does not leave temporary files open" do
      files = []
      allow(bucket).to receive(:object) do
        double(delete: true).tap { |o| allow(o).to receive(:upload_file) { |file| files << file } }
      end

      s3_check.run

      expect(files.size).to eq(1)
      expect(files.first).to be_closed
      expect(File.exist?(files.first.path)).to be(false)
    end

    it "sets status to false when the upload fails" do
      allow(bucket).to receive(:object).and_raise(StandardError, "denied")

      s3_check.run

      expect(s3_check.status).to be(false)
      expect(s3_check.details).to eq("denied")
    end
  end
end
