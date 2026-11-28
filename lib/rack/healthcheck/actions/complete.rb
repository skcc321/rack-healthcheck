# frozen_string_literal: true

require "json"
require "rack/healthcheck/actions/base"
require "rack/healthcheck/discovery"
require "rack/healthcheck/checks/active_record"
require "rack/healthcheck/checks/sequel"
require "rack/healthcheck/checks/mongo_db"
require "rack/healthcheck/checks/rabbit_mq"
require "rack/healthcheck/checks/redis"
require "rack/healthcheck/checks/http_request"
require "rack/healthcheck/checks/one_signal"
require "rack/healthcheck/checks/pusher"
require "rack/healthcheck/checks/twilio"
require "rack/healthcheck/checks/mailgunner"
require "rack/healthcheck/checks/oh_pipe"
require "rack/healthcheck/checks/geocoder"
require "rack/healthcheck/checks/elasticsearch"
require "rack/healthcheck/checks/s3"
require "rack/healthcheck/checks/flightaware"
require "rack/healthcheck/checks/marinetraffic"

module Rack
  module Healthcheck
    module Actions
      class Complete < Base
        REQUEST_LOCK = Mutex.new
        private_constant :REQUEST_LOCK

        def get(checks: Rack::Healthcheck.configuration.checks, integrations: nil)
          # Discovery builds request-local checks, so it does not need the manual check lock.
          return response(Discovery.run(integrations)) if integrations

          # Manual checks share mutable state. Keep the lock through serialization.
          REQUEST_LOCK.synchronize do
            perform(checks)
            response(checks)
          end
        end

        private

        def response(checks)
          body = result(checks)
          status = body[:status] ? 200 : 503
          [status, { "content-type" => "application/json" }, [body.to_json]]
        end

        def result(checks)
          results = []
          status = true
          checks.each do |check|
            status = status == true && check.keep_in_pool?
            results << check.to_hash
          end

          {
            name: Rack::Healthcheck.configuration.app_name,
            status: status,
            version: Rack::Healthcheck.configuration.app_version,
            checks: results
          }
        end

        def perform(checks)
          # Do not let an asynchronous timeout interrupt worker registration or cleanup.
          Thread.handle_interrupt(Object => :never) { perform_checks(checks) }
        end

        def perform_checks(checks)
          started = 0
          finished = Queue.new
          threads = checks.map do |check|
            thread = Thread.new do
              check.run
            ensure
              finished << true
            end
            started += 1
            thread
          end

          Thread.handle_interrupt(Object => :immediate) { threads.each(&:join) }
        ensure
          # Wait for outstanding checks without re-raising their errors during cleanup.
          started.times { finished.pop }
        end
      end
    end
  end
end
