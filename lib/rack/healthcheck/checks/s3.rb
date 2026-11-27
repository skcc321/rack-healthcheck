# frozen_string_literal: true

require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"
require "securerandom"
require "tempfile"

module Rack
  module Healthcheck
    module Checks
      class S3 < Base
        attr_reader :config

        # @param name [String]
        # @param config [Hash<Symbol,String>] Hash with configs
        # @param optional [Boolean] Flag used to inform if this service is optional
        # @example
        # name = s3
        # config = {
        #   :bucket
        # }
        def initialize(name, config = {})
          super(name, Rack::Healthcheck::Type::STORAGE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            object = Aws::S3::Resource.new.bucket(config[:bucket]).object("rack-healthcheck/#{SecureRandom.uuid}.txt")
            Tempfile.create("rack-healthcheck") { |file| object.upload_file(file) }
            object.delete
          end
        end
      end
    end
  end
end
