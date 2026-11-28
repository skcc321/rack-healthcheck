# frozen_string_literal: true

require "json"
require "net/http"

module HTTPSmoke
  module HTTP
    def self.connect(port, &)
      http = Net::HTTP.new("127.0.0.1", port, nil)
      http.open_timeout = 1
      http.read_timeout = 2
      http.write_timeout = 1
      http.max_retries = 0
      http.start(&)
    end

    def self.response(response)
      [response.code, response.content_type, response.body]
    end
  end
end
