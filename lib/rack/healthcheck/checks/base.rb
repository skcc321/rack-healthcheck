# frozen_string_literal: true

module Rack
  module Healthcheck
    module Checks
      class Base
        TIMEOUT = 5

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

          r = %r{://(.*:.*)@} # ://(usernam:password)@ regexp
          url.gsub(r) { |m| m.gsub(Regexp.last_match(1), "[FILTERED CREDENTIALS]") }
        end

        def check
          yield
          @status = true
        rescue StandardError => e
          @details = e.message.split("\n").first
          @status = false
        end

        def http_get(url, limit = 3)
          raise ArgumentError, "too many HTTP redirects" if limit.zero?

          uri = URI.parse(url)
          request = Net::HTTP::Get.new(uri)

          options = {
            use_ssl: uri.scheme == "https",
            open_timeout: TIMEOUT,
            read_timeout: TIMEOUT
          }

          # setting both OpenTimeout and ReadTimeout
          response = Net::HTTP.start(uri.host, uri.port, options) do |http|
            http.request(request)
          end

          case response
          when Net::HTTPSuccess, Net::HTTPOK
            response.body
          when Net::HTTPRedirection, Net::HTTPMovedPermanently
            http_get(response["location"], limit - 1)
          else
            response.value
          end
        end
      end
    end
  end
end
