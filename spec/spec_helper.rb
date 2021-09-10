# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simplecov"
require "pry"
require "timecop"

SimpleCov.start do
  add_filter "/spec"
end

require "rack/healthcheck"

RSpec.configure do |config|
  config.example_status_persistence_file_path = "rspec/status.txt"

  config.mock_with :rspec do |mocks|
    # mocks.verify_doubled_constant_names = true
    # mocks.verify_partial_doubles = true
  end
end
