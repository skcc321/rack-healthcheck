# Rack, Rails and Hanami smoke tests

From the repository root, with the project's bundle installed, run the opt-in
RSpec example on a Unix-like system with Redis or Valkey installed:

```sh
bundle exec rspec spec/fixtures/framework_smoke/http_examples.rb
# Or choose a different server binary:
REDIS_SERVER=valkey-server bundle exec rspec spec/fixtures/framework_smoke/http_examples.rb
```

The runner builds and unpacks the checkout's gem, starts a private Redis
server on a temporary Unix socket (no TCP or persistence), and boots each
app's `config.ru` in its own Puma process and locked bundle in a temporary
directory. Puma listens on an OS-assigned loopback port. Missing gems are
installed from RubyGems using the fixture's Gemfile, not the main project's
Gemfile. Use a short `TMPDIR` if your platform's Unix socket path limit is
exceeded.

Real HTTP requests through `Rack::Lint` verify normal app traffic, 404
fallthrough, lightweight health without client resolution, and detailed checks
for a live Redis pool and an unavailable optional Redis client. The fixture
owns the clients and closes them on exit. The runner reaps its Puma and Redis
processes and removes its temporary directory even when a check fails.

These are separate from `bundle exec rspec`. To include the suite's live
Redis specs, set `HEALTHCHECK_TEST_REDIS_SOCKET` to an existing disposable
server's Unix socket before running RSpec.
