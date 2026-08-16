# frozen_string_literal: true

# Set RACK_ENV to test to disable Sinatra protection middleware
ENV['RACK_ENV'] = 'test'

require "stream_weaver"

# Canvas::Reader's `before` filter (stream_weaver-rdh) checks request.host
# against 127.0.0.1/localhost -- a real security boundary for /open, which
# evaluates the .rb file it's handed. Rack::Test's own default host is
# "example.org", which every Rack::Test-driven Reader/BridgeServer spec
# would otherwise get 403'd against. Overridden globally here rather than
# passing a host on every request across dozens of spec files.
require 'rack/test'
Rack::Test.send(:remove_const, :DEFAULT_HOST)
Rack::Test::DEFAULT_HOST = '127.0.0.1'

# Single definition of the state key alias for all resource specs
SK = StreamWeaver::Resource::StateKeys

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
