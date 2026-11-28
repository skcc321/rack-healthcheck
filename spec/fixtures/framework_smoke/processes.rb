# frozen_string_literal: true

require "io/wait"
require "socket"

module SmokeProcesses
  def self.with_signals
    @interrupted = false
    # Record interrupts without raising between spawn and PID assignment or
    # during teardown. Server startup and HTTP waits already have deadlines.
    handlers = %w[INT TERM].to_h { |signal| [signal, Signal.trap(signal) { @interrupted = true }] }
    yield
    check_interrupted!
  ensure
    handlers&.each { |signal, handler| Signal.trap(signal, handler) }
  end

  def self.check_interrupted!
    raise Interrupt if @interrupted
  end

  def self.with_host(host, dir, env, command)
    log = File.join(dir, "puma.log")
    IO.pipe do |reader, writer|
      pid = Process.spawn(env, *command, 3 => writer, chdir: dir, out: log, err: %i[child out])
      writer.close
      yield read_port(reader, host)
    ensure
      stop(pid) if pid
    end
  rescue StandardError
    warn File.read(log) if File.file?(log)
    raise
  end

  def self.read_port(reader, host)
    # The child writes the whole record atomically in a single pipe write.
    raw = reader.read_nonblock(6, exception: false) if reader.wait_readable(10)
    check_interrupted!
    port = Integer(raw, exception: false) if raw.is_a?(String) && raw.match?(/\A[1-9][0-9]{0,4}\n\z/)
    return port if port&.between?(1, 65_535)

    raise "#{host}: Puma did not send a port"
  end

  def self.with_redis(tmp)
    socket = File.join(tmp, "redis.sock")
    log = File.join(tmp, "redis.log")
    server = ENV.fetch("REDIS_SERVER", "redis-server")
    pid = Process.spawn(server, "--port", "0", "--unixsocket", socket, "--unixsocketperm", "700",
                        "--save", "", "--appendonly", "no", "--daemonize", "no", chdir: tmp, out: log, err: %i[child out])
    wait_for_socket(socket)
    yield socket
  rescue StandardError
    warn File.read(log) if File.file?(log)
    raise
  ensure
    stop(pid) if pid
  end

  def self.wait_for_socket(socket)
    deadline = clock + 5
    loop do
      check_interrupted!
      UNIXSocket.open(socket) { return }
    rescue Errno::ENOENT, Errno::ECONNREFUSED
      raise "Redis socket not ready: #{socket} (use a short TMPDIR)" if clock >= deadline

      sleep 0.02
    end
  end

  def self.stop(pid)
    Process.kill("TERM", pid)
    deadline = clock + 3
    until Process.waitpid(pid, Process::WNOHANG)
      if clock >= deadline
        Process.kill("KILL", pid)
        Process.wait(pid)
        break
      end
      sleep 0.02
    end
  end

  def self.clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
