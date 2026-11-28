# frozen_string_literal: true

require "puma"
require "puma/server"
require "rack"
require "rack/builder"
require "rack/lint"

app, = Rack::Builder.parse_file("config.ru")
expected_library = File.join(File.realpath(ENV.fetch("HEALTHCHECK_SMOKE_LIB")), "rack/healthcheck.rb")
raise "rack-healthcheck did not load from the built gem" unless $LOADED_FEATURES.include?(expected_library)

server = Puma::Server.new(Rack::Lint.new(app))
listener = server.add_tcp_listener("127.0.0.1", 0)
thread = server.run
Signal.trap("TERM") { server.stop }
# The parent waits on this pipe; the OS already reserved the ephemeral port.
ready = IO.new(3, "w")
ready.write("#{listener.local_address.ip_port}\n")
ready.close
thread.join
