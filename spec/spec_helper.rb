# frozen_string_literal: true

# Guarantee the ENTIRE suite is browser-free, unconditionally, before any
# other code loads. Individual specs may still scope-and-restore this
# locally (save prev, mutate, `ensure` restore) to exercise the "SW_NO_OPEN
# unset" code path deliberately -- that's safe because they always restore
# to this default, never to a truly-unset state. No spec run should ever
# pop a real browser tab on the developer's desktop; this line is the one
# guarantee that holds even for a spec nobody thought to check.
ENV['SW_NO_OPEN'] = '1'

# Set RACK_ENV to test to disable Sinatra protection middleware
ENV['RACK_ENV'] = 'test'

require "stream_weaver"
require "stream_weaver/university/listener"

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

# Same hazard, same remedy, for StreamWeaver University's two per-user state
# files: the progress ledger (University::Progress) and the recorded worker
# session (University::Runner, written by CLI.write_get_started_worker_json).
# A spec that exercises the premier path and forgets to redirect would
# overwrite the developer's real recorded worker session -- and still be
# green. Specs that need their own tmpdir copy still set these in an around
# block; this is the default that catches the ones nobody thought to check.
SPEC_UNIVERSITY_DIR = File.join(Dir.tmpdir, "streamweaver-spec-university-#{Process.pid}")
ENV['STREAMWEAVER_UNIVERSITY_WORKER']       = File.join(SPEC_UNIVERSITY_DIR, 'worker.json')
ENV['STREAMWEAVER_UNIVERSITY_PROGRESS']     = File.join(SPEC_UNIVERSITY_DIR, 'progress.yml')
ENV['STREAMWEAVER_UNIVERSITY_LISTENER_PID'] = File.join(SPEC_UNIVERSITY_DIR, 'listener.pid')
ENV['STREAMWEAVER_UNIVERSITY_LISTENER_LOG'] = File.join(SPEC_UNIVERSITY_DIR, 'listener.log')

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

  # A stub for a method that does not exist is not a harmless typo here:
  # spec/cli_university_listener_spec.rb kept stubbing a CLI method after
  # it was renamed, and the REAL one then ran during the suite -- opening a
  # genuine iTerm2 window and talking to a live bridge on any machine where
  # those were available. Verified doubles turn that into a failure.
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # `get-started` now starts the University listener as a detached background
  # process, so any spec that exercises either get-started path spawns a real,
  # long-lived ruby on the developer's machine and leaves it there -- silently,
  # while staying green. Stubbed by default for the same reason the docs
  # registry is redirected above: the leak is invisible, so it has to be off
  # unless a spec explicitly asks for the real thing with `:unstubbed_listener_start`
  # (spec/university/listener_daemon_spec.rb and listener_e2e_spec.rb do).
  config.before do |example|
    next if example.metadata[:unstubbed_listener_start]

    allow(StreamWeaver::University::Listener).to receive(:start!).and_return(0)
  end

  config.after(:suite) do
    FileUtils.rm_f(SPEC_DOCS_REGISTRY)
    FileUtils.rm_rf(SPEC_UNIVERSITY_DIR)
  end
end
