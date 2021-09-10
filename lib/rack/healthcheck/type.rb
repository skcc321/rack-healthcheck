# frozen_string_literal: true

module Rack
  module Healthcheck
    class Type
      ALL = [
        CACHE             = "CACHE",
        EXTERNAL_SERVICE  = "EXTERNAL_SERVICE",
        INTERNAL_SERVICE  = "INTERNAL_SERVICE",
        STORAGE           = "STORAGE",
        MESSAGING         = "MESSAGING",
        DATABASE          = "DATABASE",
        FILE              = "FILE"
      ].freeze
    end
  end
end
