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

A built-in check that raises an error reports `status: false` and includes the first line of the error in `details`.

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

`app_name` and `app_version` are included in the detailed response. `checks` should be an array; when omitted, the detailed endpoint returns an empty `checks` array.

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

`GET /healthcheck/complete` runs configured checks concurrently and returns application metadata and each result. Detailed requests in the same process run one at a time, even across mounts, so one request cannot overwrite another's check results. If a detailed request is interrupted, the next one still waits for its running checks to finish. The lightweight `/healthcheck` route does not wait for detailed requests.

Example response:

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

This exposes `/status` and `/status/complete` on this middleware instance without changing the routes of other instances. The load-balancer state and check configuration are still shared within the process.

## Development

Install dependencies and run the checks locally:

```bash
bin/setup
bundle exec rspec
bundle exec rubocop -D
bundle exec rake build
```

RSpec generates an HTML coverage report at `coverage/index.html`. GitHub Actions also uploads that directory as the `coverage-report` artifact and sends the machine-readable report to Codecov.

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
