# frozen_string_literal: true

require "bundler"
require "fileutils"
require "rbconfig"
require "tmpdir"
require_relative "http"
require_relative "processes"

module StableHTTP
  module Runner
    ROOT = File.expand_path("../../..", __dir__).freeze
    RUBY = RbConfig.ruby
    BUNDLE = [RUBY, "-S", "bundle"].freeze
    HOSTS = %w[rack rails hanami].freeze

    def self.with_package
      StableHTTPProcesses.with_signals do
        Bundler.with_unbundled_env do
          Dir.mktmpdir("rh-http-") { |tmp| yield tmp, unpack_gem(tmp) }
        end
      end
    end

    def self.unpack_gem(tmp)
      package = File.join(tmp, "rack-healthcheck.gem")
      system(RUBY, "-S", "gem", "build", "rack-healthcheck.gemspec", "--output", package, chdir: ROOT, exception: true)
      system(RUBY, "-S", "gem", "unpack", package, "--target", tmp, exception: true)
      File.join(tmp, "rack-healthcheck", "lib")
    end

    def self.with_host(host, tmp, lib, &)
      raise ArgumentError, "unknown host: #{host}" unless HOSTS.include?(host)

      dir = File.join(tmp, host)
      FileUtils.cp_r(File.join(__dir__, host), dir)
      FileUtils.cp(File.join(__dir__, "manual_check.rb"), tmp)
      with_app(host, dir, lib, &)
    end

    def self.with_app(name, dir, lib, extra_env: {}, &)
      env = extra_env.merge(host_env(dir, lib))
      prepare_bundle(dir, env)
      command = [*BUNDLE, "exec", RUBY, "-I", lib, File.join(__dir__, "serve.rb")]
      StableHTTPProcesses.check_interrupted!
      StableHTTPProcesses.with_host(name, dir, env, command, &)
    end

    def self.prepare_bundle(dir, env)
      StableHTTPProcesses.check_interrupted!
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
