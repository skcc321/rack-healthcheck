# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 3.4.12"

# Specify your gem's dependencies in rack-healthcheck.gemspec
gemspec

group :development do
  gem "bundler", "~> 4.0", ">= 4.0.24"
  gem "rake", "~> 13.4"
  gem "rubocop", "~> 1.92", require: false
end

group :test do
  gem "activerecord", "~> 8.1"
  gem "bunny", "~> 3.6"
  gem "mongoid", "~> 9.1"
  gem "pry", "~> 0.16.1"
  gem "redis", "~> 6.0"
  gem "rspec", "~> 3.13"
  gem "sequel", "~> 5.110"
  gem "simplecov", "~> 1.3"
  gem "timecop", "~> 0.9.11"
end
