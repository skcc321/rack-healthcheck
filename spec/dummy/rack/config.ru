# frozen_string_literal: true

require_relative "../manual_check"

use Rack::Healthcheck::Middleware
run lambda { |env|
  headers = { "content-type" => "text/plain" }
  env["PATH_INFO"] == "/" ? [200, headers, ["app"]] : [404, headers, ["not found"]]
}
