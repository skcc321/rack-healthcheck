# Autodiscovery specification (v1.0)

Status: proposed. This document is the plan that the v1.0 discovery pull
requests build on. Each of them should be reviewable against it, and changing
the plan means changing this file first.

## Why

Today every dependency check is listed by hand, in global configuration, and
the application must construct each check object itself. Most applications
already own a configured Redis, Memcached or Mongo client; asking them to wire
a second object per client for the health endpoint is busywork that gets
forgotten.

v1.0 lets the middleware reuse the clients an application already owns, on
the same terms for bare Rack, Rails and Hanami, without changing what
`master` ships today.

## Branches and release model

- `master` is the stable line. It keeps the manual configuration API and
  carries only repository, CI, test-infrastructure and security changes that
  do not alter behaviour. Releases of the old mechanism come from it.
- `v1.0` is the release train for discovery. Discovery pull requests target
  `v1.0`, never `master`.
- Discovery pull requests stack: each one is based on its direct
  predecessor until that is merged, then on `v1.0`.
- Changes to `master` reach `v1.0` through a plain merge commit (no rebase of
  published branches). Shared test infrastructure therefore lives in `master`
  once and is extended, not duplicated, on `v1.0`.

## Goals

1. Mounting the middleware is the only switch. Adding the gem exposes nothing.
2. The same behaviour on any Rack host. No Railtie, Hanami plugin or framework
   branch in the gem.
3. No new runtime dependency. Client libraries belong to the application.
4. Discovery cannot make an application slower to start or less available.
5. Nothing leaks: no credentials, URLs or raw exceptions in responses.
6. Adding an integration is a small, local change that does not edit core.

## Non-goals

- Scanning installed gems, environment variables or framework internals to
  guess dependencies. A loaded gem or an ambient service URL is not a
  declaration.
- Closing, wrapping or reconfiguring an application-owned client.
- Changing the existing routes, status codes or the shallow endpoint.
- Worker or queue liveness. Connectivity checks only.
- A generic dependency-injection abstraction.

## Behaviour contract

Every integration must satisfy all of this; the shared contract spec
(`spec/support/discovery_contract.rb`) enforces it per adapter.

### Selection order

1. Mount `checks: [...]`, including `[]`, uses only that array.
   `checks: :auto` selects auto mode explicitly.
2. Otherwise a global `config.checks = [...]`, including `[]`, uses only that
   array and bypasses auto.
3. Otherwise the mount uses auto mode. With nothing declared the result is an
   empty check list, so an untouched mount behaves exactly as before.

### Declaration

Targets are declared on the mount, by name, as an app-owned client, pool or a
zero-argument callable that returns one:

```ruby
use Rack::Healthcheck::Middleware, {
  integrations: { redis: { cache: { client: cache_pool } } }
}
```

Declarations are boot-time configuration and are local to the mount instance.
Display names must not contain secrets.

### Timing

- Nothing is resolved or probed at boot, and nothing happens on the shallow
  `GET /healthcheck`.
- Only `GET /healthcheck/complete` resolves the client and probes.
- Resolution and probing run per request on the request thread, with fresh
  check objects. Results are never shared across requests or mounts.
- Probes must be bounded by the client's own timeouts, which the application
  configures. The middleware imposes no timeout on resolver code. An
  integration whose client cannot guarantee a bounded probe is not shipped
  until the design handles that case (see Dalli below).

### Results

- Discovered checks are informational by default. `optional: false` on a
  target makes failure return `503`.
- Failure rows use fixed messages (for example `Redis client resolution
  failed`, `Redis PING failed`). They never contain URLs, credentials or the
  underlying exception.
- A probe must be read-only. No writes, enqueues, publishes or reads of
  application data.

## Integration contract

An integration is one file in `lib/rack/healthcheck/integrations/` plus its
check class in `lib/rack/healthcheck/checks/`:

```ruby
module Integrations
  module Example
    # context is the mount's `integrations:` hash; return factories, not instances
    def self.detect(context)
      context.fetch(:example, {}).map { |name, options| -> { Checks::Example.new(name.to_s, options) } }
    end

    Discovery.register(:example, self)
  end
end
```

- `Discovery` loads only the gem's shipped `integrations/*.rb`, in sorted
  order, and rejects a second registration of the same id.
- The core must not name any integration. A test-only integration
  (`spec/support/example_integration.rb`) proves a new one needs no core edit.
- The client library is never required by the gem. The check detects the
  client by constant at probe time and degrades to a failed row if absent.

## Testing strategy

Tests are layered so a reader can tell what each layer proves. A pull request
adds the rows that apply to it, and does not repeat a lower layer's proof.

1. **Unit** (`spec/rack/healthcheck/...`): check classes against stubbed
   clients, including failure paths and message fixing.
2. **Shared contract** (`spec/support/discovery_contract.rb`): the same
   examples run for every adapter: declared vs undeclared, loaded but not
   configured, selection order, manual override bypassing the resolver,
   resolve only on detailed GET, client never closed, mount isolation,
   overlapping requests.
3. **Live service** (`*_live_spec.rb`): a disposable local server (Unix
   socket or loopback, no external network) with healthy, stopped and, where
   supported, bad-credential cases. These are skipped unless the server
   environment variable is set, and always run in CI.
4. **Real HTTP smoke** (`spec/integration/`): the packed gem inside dummy Rack,
   Rails and Hanami apps (`spec/dummy/`) under Puma and `Rack::Lint`, driven by
   the shared harness (`spec/support/http_smoke/`). Each integration adds a
   profile in `spec/dummy/profile.rb` and one example file. The harness
   proves the built gem works, not the checkout.
5. **Boot tripwire**: the harness fails the host if a client is resolved
   during boot or on liveness. Assertions are about I/O, never about wall-clock
   thresholds, which would be flaky in CI.

Every integration pull request must keep `bundle exec rspec`, `rubocop -D`
and `bundle-audit` clean, and the hosted CI green on the supported Ruby
matrix.

## Boot cost evidence

Measured on the Redis pilot with fresh Puma processes (60 per mode and
framework, warm file cache): mounting the middleware added a median 37, 24 and
27 ms (Rack, Rails, Hanami) over not loading the gem; `:auto` against
`checks: []` added -0.04, -0.35 and +0.71 ms, within noise. Startup and
liveness made no resolver or Redis calls; the first `/complete` did. The
decision is to keep discovery lazy and to guard it with the I/O tripwire above.

## Roadmap

Each step is a separate pull request, can ship on its own, and adds no runtime
dependency.

1. **Redis** (`redis-client`): first slice, also proves the core, the shared
   contract and the harness.
2. **Dalli**: blocked on a bounded probe. Dalli 5.4.0 does not guarantee a
   native deadline for its version command on an open connection (one run
   returned after 0.92 s against a 0.5 s limit). The contract is not relaxed:
   either upstream provides the deadline or the PR defines an explicitly
   documented bounded alternative first.
3. **Mongo** (`mongo`, standalone client, no Mongoid requirement): ping through
   an app-owned `Mongo::Client`.
4. **OpenSearch**, then named cloud resources starting with SQS
   (`GetQueueAttributes` only), then other candidates ranked by Rails
   relevance, new service coverage, probe cost and RubyGems reach. Redis-backed
   Sidekiq reuses the Redis integration rather than adding a second check.

Open questions, to be resolved in the PR that needs them: how a pool wrapper
other than `RedisClient::Pooled` is recognised; whether a future opt-in
should add a bounded overall deadline across sequential checks.
