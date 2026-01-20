# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/protocol'
require 'stream_weaver/canvas/session'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/client'

# Test the canvas-related CLI commands
# These are integration-style tests for the CLI command routing
RSpec.describe 'Canvas CLI commands' do
  describe 'command routing in CLI.run' do
    # We test that the CLI routes to the right methods
    # Actual behavior tested via the methods themselves

    it 'routes "canvas" command to canvas_session method' do
      expect(StreamWeaver::CLI).to receive(:canvas_session).with(['test'])
      StreamWeaver::CLI.run(['canvas', 'test'])
    end

    it 'routes "canvas-push" command to canvas_push method' do
      expect(StreamWeaver::CLI).to receive(:canvas_push).with(['test'])
      StreamWeaver::CLI.run(['canvas-push', 'test'])
    end

    it 'routes "canvas-wait" command to canvas_wait method' do
      expect(StreamWeaver::CLI).to receive(:canvas_wait).with(['test'])
      StreamWeaver::CLI.run(['canvas-wait', 'test'])
    end

    it 'routes "canvas-close" command to canvas_close method' do
      expect(StreamWeaver::CLI).to receive(:canvas_close).with(['test'])
      StreamWeaver::CLI.run(['canvas-close', 'test'])
    end

    it 'routes "canvas-list" command to canvas_list method' do
      expect(StreamWeaver::CLI).to receive(:canvas_list)
      StreamWeaver::CLI.run(['canvas-list'])
    end

    it 'routes "canvas-stop" command to canvas_stop method' do
      expect(StreamWeaver::CLI).to receive(:canvas_stop)
      StreamWeaver::CLI.run(['canvas-stop'])
    end
  end
end

RSpec.describe StreamWeaver::Canvas::Client do
  describe '.socket_path' do
    it 'returns the canvas socket path' do
      path = described_class.socket_path
      expect(path).to eq(File.expand_path('~/.streamweaver/canvas.sock'))
    end
  end

  describe '.pid_file_path' do
    it 'returns the canvas PID file path' do
      path = described_class.pid_file_path
      expect(path).to eq(File.expand_path('~/.streamweaver/canvas.pid'))
    end
  end

  describe '.bridge_running?' do
    context 'when PID file does not exist' do
      before do
        allow(File).to receive(:exist?).with(described_class.pid_file_path).and_return(false)
      end

      it 'returns false' do
        expect(described_class.bridge_running?).to be false
      end
    end
  end

  describe '.send_message' do
    let(:socket_path) { described_class.socket_path }

    context 'when bridge is not running' do
      before do
        allow(described_class).to receive(:bridge_running?).and_return(false)
      end

      it 'raises an error' do
        expect {
          described_class.send_message({ type: 'create', name: 'test' })
        }.to raise_error(StreamWeaver::Canvas::Client::NotRunningError)
      end
    end
  end
end
