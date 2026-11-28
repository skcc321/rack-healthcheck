# frozen_string_literal: true

require_relative "../support/http_smoke/run"

RSpec.describe "Middleware over HTTP" do
  # Build and unpack the gem once for all hosts.
  before(:context) do
    @package = HTTPSmoke::Runner.build_package
    @workspace = @package.tmp
    @library = @package.lib
  end

  after(:context) { HTTPSmoke::Runner.cleanup_package(@package) }

  HTTPSmoke::Runner::HOSTS.each do |host|
    it "serves application traffic and explicit health checks on #{host}" do
      HTTPSmoke::Runner.with_host(host, @workspace, @library) do |port|
        HTTPSmoke::HTTP.connect(port) do |http|
          expect(HTTPSmoke::HTTP.response(http.get("/"))).to eq(["200", "text/plain", "app"])
          missing = http.get("/missing")
          expect(missing.code).to eq("404")
          expect(missing.body).to eq("not found") if host == "rack" # the app's own fallback
          expect(HTTPSmoke::HTTP.response(http.get("/healthcheck"))).to eq(["200", "text/plain", "LIVE"])

          complete = http.get("/healthcheck/complete")
          expect([complete.code, complete.content_type]).to eq(["200", "application/json"])
          expect(JSON.parse(complete.body)).to eq(
            "name" => "fixture", "version" => "1", "status" => true,
            "checks" => [{ "name" => "manual", "status" => true, "optional" => false }]
          )
        end
      end
    end
  end
end
