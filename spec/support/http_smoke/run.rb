# frozen_string_literal: true

require "bundler"
require "fileutils"
require "rbconfig"
require "tmpdir"
require_relative "http"
require_relative "processes"

module HTTPSmoke
  module Runner
    ROOT = File.expand_path("../../..", __dir__).freeze
    DUMMY = File.join(ROOT, "spec", "dummy").freeze
    RUBY = RbConfig.ruby
    BUNDLE = [RUBY, "-S", "bundle"].freeze
    HOSTS = %w[rack rails hanami].freeze

    Package = Struct.new(:tmp, :lib, :signals)

    # Build and unpack the gem once; callers must pair this with cleanup_package.
    def self.build_package
      signals = HTTPSmokeProcesses.trap_signals
      tmp = Dir.mktmpdir("rh-http-")
      package = Package.new(tmp, nil, signals)
      Bundler.with_unbundled_env { package.lib = unpack_gem(tmp) }
      HTTPSmokeProcesses.check_interrupted!
      package
    rescue Exception # rubocop:disable Lint/RescueException
      cleanup_package(package || Package.new(tmp, nil, signals))
      raise
    end

    def self.cleanup_package(package)
      return unless package

      FileUtils.remove_entry(package.tmp) if package.tmp && File.exist?(package.tmp)
      HTTPSmokeProcesses.restore_signals(package.signals)
    end

    def self.unpack_gem(tmp)
      package = File.join(tmp, "rack-healthcheck.gem")
      system(RUBY, "-S", "gem", "build", "rack-healthcheck.gemspec", "--output", package, chdir: ROOT, exception: true)
      system(RUBY, "-S", "gem", "unpack", package, "--target", tmp, exception: true)
      File.join(tmp, "rack-healthcheck", "lib")
    end

    def self.with_host(host, tmp, lib, profile: "manual", extra_env: {}, &)
      raise ArgumentError, "unknown host: #{host}" unless HOSTS.include?(host)

      dir = File.join(tmp, host)
      FileUtils.cp_r(File.join(DUMMY, host), dir)
      FileUtils.cp(Dir.glob(File.join(DUMMY, "*.rb")), tmp)
      env = extra_env.merge("HEALTHCHECK_DUMMY_PROFILE" => profile)
      Bundler.with_unbundled_env { with_app(host, dir, lib, extra_env: env, &) }
    end

    def self.with_app(name, dir, lib, extra_env: {}, &)
      env = extra_env.merge(host_env(dir, lib))
      prepare_bundle(dir, env)
      command = [*BUNDLE, "exec", RUBY, "-I", lib, File.join(__dir__, "serve.rb")]
      HTTPSmokeProcesses.check_interrupted!
      HTTPSmokeProcesses.with_host(name, dir, env, command, &)
    end

    def self.prepare_bundle(dir, env)
      HTTPSmokeProcesses.check_interrupted!
      return if system(env, *BUNDLE, "check", chdir: dir, out: File::NULL)

      system(env, *BUNDLE, "install", chdir: dir, exception: true)
    end

    def self.host_env(dir, lib)
      {
        "BUNDLE_GEMFILE" => File.join(dir, "Gemfile"), "BUNDLE_FROZEN" => "true",
        "RAILS_ENV" => "test", "HANAMI_ENV" => "test", "RACK_ENV" => "test", "HEALTHCHECK_SMOKE_LIB" => lib
      }
    end
  end
end
