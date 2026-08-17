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

# Canvas::DocRoots (stream_weaver-iugu) reads ~/.streamweaver/docs_roots.log
# and scans ~/work by default. Neither belongs in a test run: DocStore.save
# appends to the registry on every successful write, so an unredirected suite
# would permanently pollute the developer's real registry with tmpdir paths,
# and the scan would make every canvas-read spec depend on whatever happens to
# be checked out under ~/work. Redirected globally here rather than in each
# spec's around block, because the leak is silent -- a spec that forgets is
# still green.
require 'tmpdir'
require 'fileutils'
SPEC_DOCS_REGISTRY = File.join(Dir.tmpdir, "streamweaver-spec-docs-roots-#{Process.pid}.log")
ENV['STREAMWEAVER_DOCS_REGISTRY']   = SPEC_DOCS_REGISTRY
ENV['STREAMWEAVER_DOCS_SCAN_ROOTS'] = ''

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

  config.after(:suite) { FileUtils.rm_f(SPEC_DOCS_REGISTRY) }
end
