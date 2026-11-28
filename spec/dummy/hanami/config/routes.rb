# frozen_string_literal: true

module Smoke
  class Routes < Hanami::Routes
    get "/", to: ->(_env) { [200, { "content-type" => "text/plain" }, ["app"]] }
  end
end
