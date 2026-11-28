# HTTP smoke tests with dummy apps

The apps live in `spec/dummy/{rack,rails,hanami}`; the process and HTTP harness is in
`spec/support/http_smoke`. From a Git checkout, install the root bundle and run the opt-in suite:

```sh
bundle install
bundle exec rspec spec/integration/http_smoke_examples.rb
```

The suite builds and unpacks the checkout's gem and runs Rack, Rails and
Hanami in separate Puma processes. Each host uses its own frozen bundle;
missing dummy-app gems are installed from RubyGems without changing the root
bundle. Puma binds an OS-assigned port on `127.0.0.1` and wraps each app in
`Rack::Lint`. The child verifies that the middleware loaded from the unpacked
gem, not the checkout or an installed copy. The gem is built once per run. Server
processes are stopped after each example and temporary files after the run.

The same HTTP assertions check application traffic, 404 fallthrough, GET
liveness, and the healthy JSON response from one app-owned, manually
configured check (`HEALTHCHECK_DUMMY_PROFILE=manual`, the default).

`spec/integration/redis_discovery_http_examples.rb` boots the same apps with
the `redis` profile (`spec/dummy/redis_fixture.rb`) against a disposable
`redis-server` on a Unix socket with TCP disabled (set `REDIS_SERVER` to use
another binary such as Valkey). It proves liveness and ordinary traffic never
resolve the client, and that `/healthcheck/complete` resolves it once and
reports a live and an unreachable target. Adding another integration means a
new profile in `spec/dummy/profile.rb` and one example file.
The ordinary `bundle exec rspec` run does not boot the dummy apps.
