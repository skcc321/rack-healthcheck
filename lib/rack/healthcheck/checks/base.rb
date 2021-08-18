module Rack
  module Healthcheck
    module Checks
      class Base
        class InvalidType < RuntimeError; end

        attr_accessor :name, :optional, :url
        attr_reader :type, :status, :elapsed_time, :details

        def initialize(name, type, optional, url)
          unless Rack::Healthcheck::Type::ALL.include?(type)
            raise InvalidType, "Type must be one of these options #{Rack::Healthcheck::Type::ALL.join(', ')}"
          end

          @name = name
          @optional = optional || false
          @url = url
          @type = type
          @details = nil
        end

        def run
          start = Time.now
          check
          @elapsed_time = Time.now - start
        end

        def to_hash
          {
            name: name,
            type: type,
            status: status,
            optional: optional,
            time: elapsed_time,
            url: sanitize(url),
            details: details
          }.reject { |_key, value| value.nil? }
        end

        def keep_in_pool?
          (!optional && status == true) || optional
        end

        private

          def sanitize(url)
            return unless url

            r = /\:\/\/(.*:.*)@/ # ://(usernam:password)@ regexp
            url.gsub(r) { |m| m.gsub($1, "[FILTERED CREDENTIALS]") }
          end

        def check; end

        def catch_status
          yield
          @status = true
        rescue StandardError => error
          @details = error.message.split("\n").first
          @status = false
        end
      end
    end
  end
end
