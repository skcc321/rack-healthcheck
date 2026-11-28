# frozen_string_literal: true

RailsSmoke.routes.draw do
  get "/", to: ->(_env) { [200, { "content-type" => "text/plain" }, ["app"]] }
end
