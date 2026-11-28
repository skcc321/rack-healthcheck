# frozen_string_literal: true

require "puma"
require "puma/server"
require "rack"
require "rack/builder"
require "rack/lint"

app, = Rack::Builder.parse_file("config.ru")
expected_library = File.join(File.realpath(ENV.fetch("HEALTHCHECK_SMOKE_LIB")), "rack/healthcheck.rb")
raise "rack-healthcheck did not load from the built gem" unless $LOADED_FEATURES.include?(expected_library)

# Dummy profiles that count client resolutions must not resolve one at boot.
raise "boot resolved a client" unless DummyProfile.resolutions.to_i.zero?

checked_app = Rack::Lint.new(app)
instrumented_app = lambda do |env|
  status, headers, body = checked_app.call(env)
  count = DummyProfile.resolutions
  [status, count ? headers.merge("x-dummy-resolutions" => count.to_s) : headers, body]
end

server = Puma::Server.new(instrumented_app)
listener = server.add_tcp_listener("127.0.0.1", 0)
thread = server.run
Signal.trap("TERM") { server.stop }
# The parent waits on this pipe; the OS already reserved the ephemeral port.
ready = IO.new(3, "w")
ready.write("#{listener.local_address.ip_port}\n")
ready.close
thread.join
