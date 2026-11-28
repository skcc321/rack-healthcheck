# frozen_string_literal: true

require_relative "../profile"

use Rack::Healthcheck::Middleware, DummyProfile.options
run lambda { |env|
  headers = { "content-type" => "text/plain" }
  env["PATH_INFO"] == "/" ? [200, headers, ["app"]] : [404, headers, ["not found"]]
}
