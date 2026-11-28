# frozen_string_literal: true

require "io/wait"

module StableHTTPProcesses
  def self.with_signals
    handlers = trap_signals
    yield
    check_interrupted!
  ensure
    restore_signals(handlers)
  end

  def self.trap_signals
    @interrupted = false
    # Record interrupts without raising between spawn and PID assignment or
    # during teardown. Server startup and HTTP waits already have deadlines.
    %w[INT TERM].to_h { |signal| [signal, Signal.trap(signal) { @interrupted = true }] }
  end

  def self.restore_signals(handlers)
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
