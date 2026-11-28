# frozen_string_literal: true

require "hanami"
require_relative "config/app"

Hanami.boot
run Hanami.app
