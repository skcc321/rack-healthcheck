# frozen_string_literal: true

require "spec_helper"
require "rack/lint"
require "rack/mock"

describe "Concurrent requests to the detailed healthcheck" do
  let(:configuration) { Rack::Healthcheck::Configuration.new }
  let(:first_result) { { name: "primary", status: false, details: { message: "unavailable" }, time: 0.25 } }
  let(:second_result) { { name: "primary", status: true, details: { message: "recovered" }, time: 0.125 } }
  let(:primary_finished) { Queue.new }
  let(:secondary_started) { Queue.new }
  let(:release) { Queue.new }
  let(:probe_class) do
    Struct.new(:probe, :completed) do
      def run
        @result ||= {}
        @result.replace(probe.call)
        if @result.key?(:details)
          @details ||= {}
          @result[:details] = @details.replace(@result.fetch(:details))
        end
        completed&.push(@result.dup)
      end

      def keep_in_pool?
        @result.fetch(:status)
      end

      def to_hash
        @result
      end
    end
  end

  before do
    allow(Rack::Healthcheck).to receive(:configuration).and_return(configuration)
  end

  def queue_with(*items)
    Queue.new.tap { |queue| items.each { |item| queue << item } }
  end

  def request_complete
    fallback = ->(_env) { [404, {}, []] }
    app = Rack::Lint.new(Rack::Healthcheck::Middleware.new(fallback))
    Thread.new do
      Thread.current.report_on_exception = false
      Rack::MockRequest.new(app).get("/healthcheck/complete")
    end
  end

  def response_from(thread)
    expect(thread.join(5)).not_to be_nil
    response = thread.value
    [response.status, JSON.parse(response.body)]
  end

  def blocking_probe
    blocking_runs = queue_with(true, false)
    probe_class.new(lambda {
      if blocking_runs.pop
        secondary_started << true
        raise "test gate timed out" unless release.pop(timeout: 5)
      end
      { name: "secondary", status: true }
    })
  end

  it "keeps each request's probe status, details, and duration in its own response" do
    results = queue_with(first_result, second_result)
    primary = probe_class.new(-> { results.pop }, primary_finished)
    configuration.checks = [primary, blocking_probe]

    first = request_complete
    expect(primary_finished.pop(timeout: 5)).to eq(first_result)
    expect(secondary_started.pop(timeout: 5)).to be(true)
    second = request_complete
    # Give the second request a chance to finish while the first is still blocked.
    second.join(0.25)
    release << true

    first_status, first_body = response_from(first)
    second_status, second_body = response_from(second)
    expect([first_status, first_body.fetch("status"), first_body.fetch("checks").first])
      .to eq([503, false, JSON.parse(first_result.to_json)])
    expect([second_status, second_body.fetch("status"), second_body.fetch("checks").first])
      .to eq([200, true, JSON.parse(second_result.to_json)])
  ensure
    release << true
    [first, second].compact.each { |thread| thread.join(5) || thread.kill.join }
  end

  it "includes later check output without consulting its pool predicate after a failure" do
    failing = double(run: nil, keep_in_pool?: false, to_hash: { name: "required", status: false })
    later = double(run: nil, to_hash: { name: "later", status: true })
    expect(later).not_to receive(:keep_in_pool?)
    configuration.checks = [failing, later]

    status, body = response_from(request_complete)

    expect(status).to eq(503)
    expect(body.fetch("checks").map { |check| check.fetch("name") }).to eq(%w[required later])
  end

  def failing_probe(error)
    double.tap do |probe|
      allow(probe).to receive(:run) do
        Thread.current.report_on_exception = false
        yield
        raise error
      end
    end
  end

  def await_gate(gate)
    raise "test gate timed out" unless gate.pop(timeout: 5)
  end

  it "drains all workers before propagating the original error" do
    cleanup_started = Queue.new
    release_cleanup = Queue.new
    failing = failing_probe(IOError.new("first worker failed")) do
      await_gate(cleanup_started)
      await_gate(secondary_started)
    end
    cleanup = failing_probe(NotImplementedError.new("cleanup worker failed")) do
      cleanup_started << true
      await_gate(release_cleanup)
    end
    configuration.checks = [failing, cleanup, blocking_probe]

    request = request_complete
    expect(request.join(0.25)).to be_nil
    release_cleanup << true
    expect(request.join(0.25)).to be_nil
    release << true
    expect { request.value }.to raise_error(IOError, "first worker failed")
  ensure
    release_cleanup << true
    release << true
    begin
      request&.join(5)
    rescue IOError, NotImplementedError
      # A worker error is asserted above, after opening the gates.
    end
  end

  it "does not leave running checks behind when the request times out during cleanup" do
    failing = failing_probe(IOError.new("worker failed")) { await_gate(secondary_started) }
    configuration.checks = [failing, blocking_probe]

    request = request_complete
    expect(request.join(0.25)).to be_nil
    request.raise(Timeout::Error, "request timed out")
    expect(request.join(0.25)).to be_nil
    release << true
    expect { request.value }.to raise_error(Timeout::Error, "request timed out")
  ensure
    release << true
    begin
      request&.join(5)
    rescue Timeout::Error, IOError
      # The request error is asserted above, after opening the gate.
    end
  end
end
