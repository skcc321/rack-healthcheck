# Stable middleware HTTP smoke tests

From a Git checkout, install the root bundle and run the opt-in suite:

```sh
bundle install
bundle exec rspec spec/fixtures/stable_http/http_examples.rb
```

The suite builds and unpacks the checkout's gem and runs Rack, Rails and
Hanami in separate Puma processes. Each host uses its own frozen bundle;
missing fixture gems are installed from RubyGems without changing the root
bundle. Puma binds an OS-assigned port on `127.0.0.1` and wraps each app in
`Rack::Lint`. The child verifies that the middleware loaded from the unpacked
gem, not the checkout or an installed copy. Processes and temporary files are
cleaned up after each example.

The same HTTP assertions check application traffic, 404 fallthrough, GET
liveness, and the healthy JSON response from one app-owned, manually
configured check. No Redis, Valkey, or other backing service is needed.
The ordinary `bundle exec rspec` run does not boot the fixture apps.
