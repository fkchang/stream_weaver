# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'stream_weaver/canvas/protocol'
require 'stream_weaver/canvas/session'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/bridge_server'

RSpec.describe StreamWeaver::Canvas::BridgeServer do
  describe '.socket_path' do
    it 'returns the Unix socket path' do
      expect(described_class.socket_path).to eq(
        File.expand_path('~/.streamweaver/canvas.sock')
      )
    end
  end

  describe '.pid_file_path' do
    it 'returns the PID file path' do
      expect(described_class.pid_file_path).to eq(
        File.expand_path('~/.streamweaver/canvas.pid')
      )
    end
  end

  describe '.default_port' do
    it 'returns 4568' do
      expect(described_class.default_port).to eq(4568)
    end
  end

  describe 'routes' do
    # Use Rack::Test for route testing
    include Rack::Test::Methods

    def app
      StreamWeaver::Canvas::BridgeServer
    end

    before(:all) do
      StreamWeaver::Canvas::BridgeServer.setup!
    end

    describe 'GET /canvas/:name' do
      it 'returns 200 for existing session' do
        # Create a session first
        StreamWeaver::Canvas::BridgeServer.bridge.create_session('test-session')

        get '/canvas/test-session'

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('app-container')
      end

      it 'creates session if not exists' do
        get '/canvas/new-session'

        expect(last_response.status).to eq(200)
        expect(StreamWeaver::Canvas::BridgeServer.bridge.get_session('new-session')).not_to be_nil
      end
    end

    describe 'GET /health' do
      it 'returns health status' do
        get '/health'

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['status']).to eq('ok')
      end
    end

    after(:each) do
      # Clean up sessions
      if StreamWeaver::Canvas::BridgeServer.bridge
        StreamWeaver::Canvas::BridgeServer.bridge.sessions.keys.each do |name|
          StreamWeaver::Canvas::BridgeServer.bridge.close_session(name)
        end
      end
    end
  end
end
