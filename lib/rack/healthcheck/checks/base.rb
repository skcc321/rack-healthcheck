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
            url: sanitized_url,
            details: details
          }.reject { |_key, value| value.nil? }
        end

        def keep_in_pool?
          (!optional && status == true) || optional
        end

        private

          def sanitized_url
            return unless url

            r = /\:\/\/(.*:.*)@/ # ://(usernam:password)@ regexp
            url.gsub(r) { |m| m.gsub($1, "[FILTERED CREDENTIALS]") }
          end

          def check
            yield
            @status = true
          rescue StandardError => error
            @details = error.message.split("\n").first
            @status = false
          end

          def http_get(uri_str, limit = 3)
            raise ArgumentError, "too many HTTP redirects" if limit == 0

            response = Net::HTTP.get_response(URI(uri_str))

            case response
            when Net::HTTPSuccess, Net::HTTPOK then
              response.body
            when Net::HTTPRedirection then
              location = response["location"]
              # warn "redirected to #{location}"
              http_get(location, limit - 1)
            else
              response.value
            end
          end
      end
    end
  end
end
