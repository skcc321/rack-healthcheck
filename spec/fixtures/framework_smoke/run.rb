# frozen_string_literal: true

require "bundler"
require "fileutils"
require "rbconfig"
require "tmpdir"
require_relative "processes"
require_relative "smoke"

module FrameworkSmoke
  HOSTS = %w[rack rails hanami].freeze
  ROOT = File.expand_path("../../..", __dir__).freeze
  RUBY = RbConfig.ruby
  BUNDLE = [RUBY, "-S", "bundle"].freeze

  def self.run
    SmokeProcesses.with_signals do
      Bundler.with_unbundled_env do
        Dir.mktmpdir("rh-smoke-") { |tmp| run_matrix(tmp) }
      end
    end
  end

  def self.run_matrix(tmp)
    lib = unpack_gem(tmp)
    fixtures = copy_fixtures(tmp)
    HOSTS.each { |host| prepare_bundle(File.join(fixtures, host)) }
    SmokeProcesses.check_interrupted!
    SmokeProcesses.with_redis(tmp) do |socket|
      HOSTS.each { |host| run_host(host, fixtures, lib, socket) }
    end
  end

  def self.unpack_gem(tmp)
    package = File.join(tmp, "rack-healthcheck.gem")
    system(RUBY, "-S", "gem", "build", "rack-healthcheck.gemspec", "--output", package, chdir: ROOT, exception: true)
    system(RUBY, "-S", "gem", "unpack", package, "--target", tmp, exception: true)
    File.join(tmp, "rack-healthcheck", "lib")
  end

  def self.copy_fixtures(tmp)
    dest = File.join(tmp, "fixtures")
    Dir.mkdir(dest)
    FileUtils.cp_r(HOSTS.map { |host| File.join(__dir__, host) } + [File.join(__dir__, "redis_fixture.rb")], dest)
    dest
  end

  def self.prepare_bundle(dir)
    SmokeProcesses.check_interrupted!
    env = bundle_env(dir)
    return if system(env, *BUNDLE, "check", chdir: dir, out: File::NULL)

    system(env, *BUNDLE, "install", chdir: dir, exception: true)
  end

  def self.bundle_env(dir)
    { "BUNDLE_GEMFILE" => File.join(dir, "Gemfile"), "BUNDLE_FROZEN" => "true" }
  end

  def self.run_host(host, fixtures, lib, socket)
    SmokeProcesses.check_interrupted!
    dir = File.join(fixtures, host)
    env = bundle_env(dir).merge(
      "RAILS_ENV" => "test", "HANAMI_ENV" => "test", "RACK_ENV" => "test",
      "HEALTHCHECK_TEST_REDIS_SOCKET" => socket, "HEALTHCHECK_SMOKE_LIB" => lib
    )
    command = [*BUNDLE, "exec", RUBY, "-I", lib, File.join(__dir__, "serve.rb")]
    SmokeProcesses.with_host(host, dir, env, command) { |port| SmokeAssertions.verify(port) }
    SmokeProcesses.check_interrupted!
    puts "#{host}: HTTP app traffic, fallback, lazy liveness, live and unavailable Redis passed"
  end
end
