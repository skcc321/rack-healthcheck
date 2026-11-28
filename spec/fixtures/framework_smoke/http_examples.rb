# frozen_string_literal: true

require_relative "run"

RSpec.describe "Framework HTTP smoke tests" do
  it "serves app traffic and probes Redis from the packaged middleware on Rack, Rails and Hanami" do
    FrameworkSmoke.run
  end
end
