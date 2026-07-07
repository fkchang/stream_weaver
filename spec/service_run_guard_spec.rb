# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'tempfile'
require 'timeout'

RSpec.describe "StreamWeaver::Service — loading a file that calls run! unconditionally" do
  include Rack::Test::Methods

  def app
    StreamWeaver::Service
  end

  let(:app_file) do
    f = Tempfile.new(['run_guard_app', '.rb'])
    f.write(<<~RUBY)
      require 'stream_weaver'

      app "Run Guard App" do
        header1 "Run Guard"
      end.run!
    RUBY
    f.close
    f
  end

  before { StreamWeaver::Service.clear_apps }
  after do
    StreamWeaver::Service.clear_apps
    app_file.unlink
  end

  it "loads without booting a second server, warns, and keeps serving" do
    app_id = nil
    warned = nil
    # Timeout is the regression tripwire: without the service_loading guard,
    # run! boots a real blocking Puma server inside this call.
    Timeout.timeout(10) do
      warned = capture_stderr do
        app_id = StreamWeaver::Service.load_app(app_file.path)
      end
    end

    expect(app_id).to match(/\A\h{8}\z/)
    expect(warned).to include("skipping run!")

    get "/apps/#{app_id}"
    expect(last_response).to be_ok
    expect(last_response.body).to include("Run Guard")
  end

  it "clears the service_loading flag even when the file raises" do
    bad = Tempfile.new(['run_guard_bad', '.rb'])
    bad.write("raise 'boom'")
    bad.close

    expect { StreamWeaver::Service.load_app(bad.path) }.to raise_error(RuntimeError, 'boom')
    expect(StreamWeaver.service_loading).to be false
  ensure
    bad.unlink
  end

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
