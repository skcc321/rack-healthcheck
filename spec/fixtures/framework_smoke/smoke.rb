# frozen_string_literal: true

require "json"
require "net/http"

module SmokeAssertions
  RESOLUTIONS_HEADER = "x-fixture-redis-resolutions"
  EXPECTED_ROWS = [["cache", true, true].freeze, ["unreachable", false, true].freeze].freeze

  def self.verify(port)
    http = Net::HTTP.new("127.0.0.1", port, nil)
    http.open_timeout = 1
    http.read_timeout = 2
    http.write_timeout = 1
    http.max_retries = 0

    http.start do |connection|
      verify_simple(connection.get("/"), "200", "app")
      verify_simple(connection.get("/missing"), "404")
      verify_simple(connection.get("/healthcheck"), "200", "LIVE")
      verify_complete(connection.get("/healthcheck/complete"))
    end
  end

  def self.verify_simple(response, code, body = nil)
    raise "#{response.uri}: expected #{code}, got #{response.code}" unless response.code == code
    raise "#{response.uri}: unexpected response body" if body && response.body != body
    raise "#{response.uri}: expected zero Redis resolutions" unless response[RESOLUTIONS_HEADER] == "0"
  end

  def self.verify_complete(response)
    body = JSON.parse(response.body)
    rows = body.fetch("checks").map { |row| row.values_at("name", "status", "optional") }.sort
    raise "expected one Redis resolution" unless response[RESOLUTIONS_HEADER] == "1"
    return if [response.code, response.content_type, body["status"], rows] == ["200", "application/json", true, EXPECTED_ROWS]

    raise "unexpected detailed health: #{response.code} #{response.body}"
  end
end
