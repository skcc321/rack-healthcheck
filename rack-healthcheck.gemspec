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
  spec.description   = "A healthcheck interface for Sinatra and Rails framework"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.required_ruby_version = "> 2.7"
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "activerecord", "~> 6.1"
  spec.add_development_dependency "bundler", "~> 2.2", ">= 2.2.27"
  spec.add_development_dependency "bunny", "~> 2.19"
  spec.add_development_dependency "mongoid", "~> 7.3", ">= 7.3.3"
  spec.add_development_dependency "rake", "~> 13.0", ">= 13.0.6"
  spec.add_development_dependency "redis", "~> 4.4"
  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "rubocop", "~> 1.20"
  spec.add_development_dependency "sequel", "~> 5.48"
  spec.add_development_dependency "simplecov", "~> 0.21.2"
end
