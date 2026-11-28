# frozen_string_literal: true

require_relative "../support/http_smoke/run"
require_relative "../support/http_smoke/redis_server"

RSpec.describe "Redis discovery over HTTP" do
  before(:context) { @package = HTTPSmoke::Runner.build_package }
  after(:context) { HTTPSmoke::Runner.cleanup_package(@package) }

  # Rows are [name, status, optional]: a live pool and a separate unreachable target.
  let(:expected_rows) { [["cache", true, true], ["unreachable", false, true]] }

  def resolutions(response)
    response["x-dummy-resolutions"]
  end

  HTTPSmoke::Runner::HOSTS.each do |host|
    it "keeps liveness lazy and probes configured Redis targets on #{host}" do
      HTTPSmokeProcesses.with_redis do |socket|
        env = { "HEALTHCHECK_TEST_REDIS_SOCKET" => socket }
        HTTPSmoke::Runner.with_host(host, @package.tmp, @package.lib, profile: "redis", extra_env: env) do |port|
          HTTPSmoke::HTTP.connect(port) do |http|
            [["/", "200", "app"], ["/missing", "404", nil], ["/healthcheck", "200", "LIVE"]].each do |path, code, body|
              response = http.get(path)
              expect([response.code, resolutions(response)]).to eq([code, "0"])
              expect(response.body).to eq(body) if body
            end

            complete = http.get("/healthcheck/complete")
            body = JSON.parse(complete.body)
            rows = body.fetch("checks").map { |row| row.values_at("name", "status", "optional") }.sort
            expect([complete.code, complete.content_type, body["status"], rows, resolutions(complete)])
              .to eq(["200", "application/json", true, expected_rows, "1"])
          end
        end
      end
    end
  end
end
