# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rack/healthcheck/version"

Gem::Specification.new do |spec|
  spec.name          = "rack-healthcheck"
  spec.version       = Rack::Healthcheck::VERSION
  spec.authors       = ["Leandro Maduro"]
  spec.email         = ["leandromaduro1@gmail.com"]

  spec.summary       = "A healthcheck interface for Sinatra and Rails framework"
  spec.description   = "Rack middleware with configurable service checks for Sinatra and Rails applications."
  spec.homepage      = "https://github.com/skcc321/rack-healthcheck"
  spec.license       = "MIT"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = ">= 3.4.12"
  spec.files = `git ls-files -z`.split("\x0").reject do |file|
    file == "Gemfile.lock" || file.match?(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
