require "rack/healthcheck/checks/base"
require "rack/healthcheck/type"

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
          super(name, Rack::Healthcheck::Type::DATABASE, config[:optional], config[:url])
          @config = config
        end

        private

        def check
          super do
            s3 = Aws::S3::Resource.new
            path = "rack-healthcheck/test.txt"
            s3.bucket(config[:bucket]).object(path).upload_file(Tempfile.create)
            s3.bucket(config[:bucket]).object(path).delete
          end
        end
      end
    end
  end
end
