[![Release](https://img.shields.io/github/v/release/skcc321/rack-healthcheck)](https://github.com/skcc321/rack-healthcheck/releases)
[![CI](https://github.com/skcc321/rack-healthcheck/actions/workflows/ci.yml/badge.svg)](https://github.com/skcc321/rack-healthcheck/actions/workflows/ci.yml)
[![Test Coverage](https://codecov.io/gh/skcc321/rack-healthcheck/branch/master/graph/badge.svg)](https://codecov.io/gh/skcc321/rack-healthcheck)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.4.12-red)](https://www.ruby-lang.org)
[![License](https://img.shields.io/github/license/skcc321/rack-healthcheck)](LICENSE.txt)

# Rack::Healthcheck

Rack middleware that exposes lightweight health endpoints and detailed dependency checks for Rails, Sinatra, and other Rack applications.

## Requirements

- Ruby 3.4.12 or newer.
- Add and load the client gems for the checks you configure. They are not runtime dependencies of `rack-healthcheck`.

A manual built-in check that raises an error reports `status: false` and normally includes the first line of the error in `details`. The auto Redis check uses fixed failure messages instead.

## Installation

This README describes `master`, which includes the Rack 3 response fixes. Install from GitHub by adding this to your application's `Gemfile`:

```ruby
gem "rack-healthcheck", github: "skcc321/rack-healthcheck", branch: "master"
```

Then install it:

```bash
bundle install
```

Commit `Gemfile.lock` to pin the resolved revision. The tagged release `v0.4.0` predates the Rack 3 response fixes, and the gem on RubyGems.org is not published by this fork.

## Middleware Setup

### Rails

Add the middleware in `config/application.rb`:

```ruby
config.middleware.use Rack::Healthcheck::Middleware
```

If middleware ordering matters in your application, place it explicitly:

```ruby
config.middleware.insert_before 0, Rack::Healthcheck::Middleware
```

### Sinatra and Rack

Add the middleware in `config.ru`:

```ruby
require "rack/healthcheck"

use Rack::Healthcheck::Middleware
```

### Hanami

Require `rack/healthcheck` and mount the middleware in `config/app.rb`:

```ruby
config.middleware.use Rack::Healthcheck::Middleware
```

### Automatic checks (Redis pilot)

Mounting the middleware enables `:auto` by default unless an explicit check array is configured. Adding the gem without mounting the middleware does not expose any route. Auto mode only sees the integrations declared on that mount. It does not use framework hooks, loaded gems, or environment URLs to infer dependencies.

Pass a named, app-owned `redis-client` client or pool, or a zero-argument callable that returns one:

```ruby
require "rack/healthcheck"
require "redis_client" # add redis-client to your application's Gemfile

# Reuse the pool your application already uses.
use Rack::Healthcheck::Middleware, {
  integrations: {
    redis: {
      cache: { client: cache_pool },
      sessions: { client: -> { app_container["sessions_redis"] }, optional: false }
    }
  }
}
```

In Rails or Hanami, pass the same options hash to `config.middleware.use` instead of `use`. For a custom mount, pass the path before the options hash (`use Rack::Healthcheck::Middleware, "/ready", options`). Mount options are boot-time configuration; don't mutate them while serving requests. Use display names that don't contain secrets.

- Only `GET /healthcheck/complete` resolves and probes targets (or the equivalent custom path); the shallow endpoint is unchanged. Unconfigured Redis contributes no row. A named target with no usable client reports `Redis client resolution failed`; an unsuccessful `PING` reports `Redis PING failed`. Neither row exposes a URL or the underlying exception.
- Discovered checks are informational by default. `optional: false` makes the named target required: a failed check makes the detailed endpoint return `503`.
- Each request gets fresh auto check results. Resolution and probes run sequentially on the request thread. The middleware issues one `PING` using `redis-client`'s `call_once`, respects the configured pool checkout and client I/O timeouts, and never closes the client. There is no overall deadline and no timeout imposed on resolver code: keep resolvers fast and configure bounded timeouts on the client or pool.
- Prefer a `RedisClient::Pooled` for a shared client in a concurrent app. An unpooled `RedisClient` is not thread-safe; only use one when the application guarantees exclusive use. The pilot does not support `redis` gem `Redis` objects, cluster adapters, or arbitrary pool wrappers. The existing manual `Checks::Redis` still works with the `redis` gem.

## Configuration

Configure the application metadata and checks during application initialization:

```ruby
Rack::Healthcheck.configure do |config|
  config.app_name = "My Application"
  config.app_version = "1.0.0"
  config.checks = [
    Rack::Healthcheck::Checks::ActiveRecord.new(
      "Primary database",
      { connected_to: { role: :writing } }
    ),
    Rack::Healthcheck::Checks::Redis.new(
      "Cache",
      { url: "redis://localhost:6379" }
    ),
    Rack::Healthcheck::Checks::HTTPRequest.new(
      "Internal API",
      {
        url: "http://localhost:3001/healthcheck",
        service_type: Rack::Healthcheck::Type::INTERNAL_SERVICE,
        expected_result: "LIVE",
        optional: true
      }
    )
  ]
end
```

`app_name` and `app_version` are included in the detailed response. Select checks in this order:

1. Mount `checks: [...]` (including `checks: []`) uses only that array; mount `checks: :auto` explicitly selects auto mode.
2. Otherwise, a global `config.checks = [...]` (including `[]`) uses only that array and bypasses auto.
3. Otherwise, the mount uses auto mode. With no recognized integration configured, `checks` is empty.

The legacy manual API still runs the supplied check instances; it does not make those objects safe to share across concurrent requests.

### Check Options

Every check has a display name. Most checks also accept:

- `optional`: defaults to `false`. An optional check still runs and reports its own result, but its failure does not make `/healthcheck/complete` unhealthy.
- `url`: connection configuration or display metadata, depending on the check. Embedded `user:password@` credentials are filtered from responses.

Common integrations are:

| Check | Client | Configuration |
| --- | --- | --- |
| `ActiveRecord` | `activerecord` | Optional `connected_to` hash for a role or shard; optional `url` metadata |
| `Sequel` | `sequel` and a database adapter | Required connection `url` |
| `MongoDB` | `mongoid` | Optional Mongoid client `name`; optional `url` metadata |
| `RabbitMQ` | `bunny` | Bunny connection options such as `hosts`, `port`, `user`, and `pass` |
| `Redis` | `redis` | Redis connection options such as `url`, `password`, and timeouts |
| `HTTPRequest` | Ruby standard library | Required `url`, `service_type`, and `expected_result` string or regular expression |
| `S3` | `aws-sdk-s3` | Required `bucket`; the check uploads and deletes a probe object |

Valid HTTP request service types are `CACHE`, `EXTERNAL_SERVICE`, `INTERNAL_SERVICE`, `STORAGE`, `MESSAGING`, `DATABASE`, and `FILE`, available as constants under `Rack::Healthcheck::Type`.

## Endpoints

The default mount path exposes two exact routes:

| Route | Methods | Response |
| --- | --- | --- |
| `/healthcheck` | `GET`, `POST`, `DELETE` | HTTP 200 with plain-text `LIVE` or `DEAD` |
| `/healthcheck/complete` | `GET` | HTTP 200 when all required checks pass; otherwise HTTP 503 with JSON details |

`GET /healthcheck` returns the current load-balancer state without running dependency checks. `POST` changes the state to `LIVE`, and `DELETE` changes it to `DEAD`. The state is kept in memory per process, so with a multi-process server (Puma cluster, Unicorn) `POST` and `DELETE` only affect the worker that handled the request. These routes are not authenticated; restrict them at the proxy or network level.

`GET /healthcheck/complete` runs configured checks concurrently and returns application metadata and each result:

```json
{
  "name": "My Application",
  "status": true,
  "version": "1.0.0",
  "checks": [
    {
      "name": "Primary database",
      "type": "DATABASE",
      "status": true,
      "optional": false,
      "time": 0.012
    },
    {
      "name": "Internal API",
      "type": "INTERNAL_SERVICE",
      "status": false,
      "optional": true,
      "time": 0.045,
      "url": "http://localhost:3001/healthcheck",
      "details": "Connection refused"
    }
  ]
}
```

This response is HTTP 200: the database is healthy, and the failed API check is optional. Keep the detailed endpoint internal if it exposes service URLs or error details you don't want to publish.

Unknown routes and unsupported methods are passed to the wrapped Rack application.

### Custom Mount Path

Pass a base path to the middleware to change both routes:

```ruby
# Rails
config.middleware.use Rack::Healthcheck::Middleware, "/status"

# Sinatra or Rack
use Rack::Healthcheck::Middleware, "/status"
```

This exposes `/status` and `/status/complete` on this middleware instance without changing the routes of other instances. Load-balancer state and legacy global configuration are still shared within the process; mount options are local to each instance.

## Development

Install dependencies and run the checks locally:

```bash
bin/setup
bundle exec rspec
bundle exec rubocop -D
bundle exec rake build
```

RSpec generates an HTML coverage report at `coverage/index.html`. GitHub Actions also uploads that directory as the `coverage-report` artifact and sends the machine-readable report to Codecov.

To include the live Redis autodiscovery specs, set `HEALTHCHECK_TEST_REDIS_SOCKET` to the Unix socket path of a disposable local Redis or Valkey server before running `bundle exec rspec`. The live specs are omitted when this variable is unset.

## Acknowledgements

Rack::Healthcheck was originally created by [Leandro Maduro](https://github.com/leandro-maduro) in the [original repository](https://github.com/leandro-maduro/rack-healthcheck). This repository continues that work and retains the original author's copyright notice in the MIT license.

## Contributing

1. [Fork the repository](https://github.com/skcc321/rack-healthcheck/fork).
2. Create a feature branch.
3. Add tests for behavioral changes.
4. Run RSpec and RuboCop.
5. Open a pull request.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
