# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/iterm'

# Regression coverage for a bug found while building `streamweaver get-started`
# (which calls `panel` for its premier iTerm2 path): panel's two browser-open
# fallback branches (iTerm split unavailable/failed) called `open_browser`
# unconditionally, ignoring SW_NO_OPEN entirely -- unlike every other
# browser-open call site in this file. Any headless/CI invocation of
# get-started's premier path (or of `panel` itself, outside a real iTerm2
# session) could pop a real browser tab despite SW_NO_OPEN=1.
#
# Also pins that the canvas URL panel opens/prints always comes straight from
# the live bridge's own response (`Canvas::Client.send_message`'s
# `response[:url]`, itself built from the bridge's real port read out of
# ~/.streamweaver/canvas.pid) -- never a hardcoded default port.
RSpec.describe StreamWeaver::CLI do
  def capture_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end

  # A deliberately distinctive, non-default port -- neither Service::DEFAULT_PORT
  # (4567, the standalone app server) nor Canvas::BridgeServer::DEFAULT_PORT
  # (4700) -- so a test passing only proves the code echoes whatever the live
  # bridge said, not that it happens to match one of the two real defaults.
  let(:live_bridge_url) { 'http://127.0.0.1:59321/canvas/panel-test' }

  before do
    allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running)
    allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return(
      { type: 'ready', name: 'panel-test', url: live_bridge_url }
    )
  end

  describe '.panel (browser-open honors SW_NO_OPEN)' do
    around do |example|
      prev = ENV['SW_NO_OPEN']
      example.run
    ensure
      ENV['SW_NO_OPEN'] = prev
    end

    context 'iTerm2 unavailable entirely' do
      before { allow(StreamWeaver::ITerm).to receive(:available?).and_return(false) }

      it 'does not open a browser when SW_NO_OPEN=1' do
        ENV['SW_NO_OPEN'] = '1'
        expect(described_class).not_to receive(:open_browser)

        capture_io { described_class.panel(['panel-test']) }
      end

      it 'opens the browser at the live bridge URL when SW_NO_OPEN is unset' do
        ENV.delete('SW_NO_OPEN')
        expect(described_class).to receive(:open_browser).with(live_bridge_url)

        capture_io { described_class.panel(['panel-test']) }
      end
    end

    context 'iTerm2 available but the split pane fails' do
      before do
        allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
        allow(StreamWeaver::ITerm).to receive(:split_vertical_with_url).and_return(type: nil, pane_id: nil)
        allow(StreamWeaver::ITerm).to receive(:gem_missing?).and_return(false)
      end

      it 'does not open a browser when SW_NO_OPEN=1' do
        ENV['SW_NO_OPEN'] = '1'
        expect(described_class).not_to receive(:open_browser)

        capture_io { described_class.panel(['panel-test']) }
      end

      it 'opens the browser at the live bridge URL when SW_NO_OPEN is unset' do
        ENV.delete('SW_NO_OPEN')
        expect(described_class).to receive(:open_browser).with(live_bridge_url)

        capture_io { described_class.panel(['panel-test']) }
      end
    end
  end

  describe '.panel (URL always comes from the live bridge response, never a hardcoded port)' do
    it 'prints the exact URL the bridge returned, not a locally-assumed default port' do
      allow(StreamWeaver::ITerm).to receive(:available?).and_return(false)
      allow(StreamWeaver::ITerm).to receive(:gem_missing?).and_return(false)
      allow(described_class).to receive(:open_browser)

      out, _err = capture_io { described_class.panel(['panel-test']) }

      expect(out).to include(live_bridge_url)
      expect(out).not_to include('4567') # Service::DEFAULT_PORT -- a different subsystem entirely
      expect(out).not_to include('4700') # Canvas::BridgeServer::DEFAULT_PORT -- not assumed, only ever echoed if the bridge actually said so
    end
  end
end
