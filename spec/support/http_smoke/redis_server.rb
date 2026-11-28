# frozen_string_literal: true

require "socket"
require "tmpdir"
require_relative "processes"

# A disposable Redis server on a Unix socket with TCP disabled.
module HTTPSmokeProcesses
  def self.with_redis
    # Unix socket paths are short; keep the server directory directly under /tmp.
    Dir.mktmpdir("rh-redis-", "/tmp") do |tmp|
      socket = File.join(tmp, "redis.sock")
      log = File.join(tmp, "redis.log")
      server = ENV.fetch("REDIS_SERVER", "redis-server")
      pid = Process.spawn(server, "--port", "0", "--unixsocket", socket, "--unixsocketperm", "700",
                          "--save", "", "--appendonly", "no", "--daemonize", "no", chdir: tmp, out: log, err: %i[child out])
      begin
        wait_for_socket(socket)
        yield socket
      rescue StandardError
        warn File.read(log) if File.file?(log)
        raise
      ensure
        stop(pid)
      end
    end
  end

  def self.wait_for_socket(socket)
    deadline = clock + 5
    loop do
      check_interrupted!
      UNIXSocket.open(socket) { return }
    rescue Errno::ENOENT, Errno::ECONNREFUSED
      raise "Redis socket not ready: #{socket}" if clock >= deadline

      sleep 0.02
    end
  end
end
