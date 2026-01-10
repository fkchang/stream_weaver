# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/protocol'
require 'stream_weaver/canvas/session'
require 'stream_weaver/canvas/bridge'

RSpec.describe StreamWeaver::Canvas::Bridge do
  let(:bridge) { described_class.new }

  describe '#initialize' do
    it 'starts with no sessions' do
      expect(bridge.sessions).to eq({})
    end
  end

  describe '#create_session' do
    it 'creates a new session with the given name' do
      session = bridge.create_session('survey')

      expect(session).to be_a(StreamWeaver::Canvas::Session)
      expect(session.name).to eq('survey')
    end

    it 'stores the session for later retrieval' do
      bridge.create_session('survey')

      expect(bridge.sessions).to have_key('survey')
    end

    it 'returns existing session if name already exists' do
      session1 = bridge.create_session('survey')
      session2 = bridge.create_session('survey')

      expect(session1).to equal(session2)
    end
  end

  describe '#get_session' do
    it 'returns the session by name' do
      bridge.create_session('survey')
      session = bridge.get_session('survey')

      expect(session.name).to eq('survey')
    end

    it 'returns nil for unknown session' do
      expect(bridge.get_session('unknown')).to be_nil
    end
  end

  describe '#close_session' do
    it 'removes the session' do
      bridge.create_session('survey')
      bridge.close_session('survey')

      expect(bridge.sessions).not_to have_key('survey')
    end

    it 'returns true if session existed' do
      bridge.create_session('survey')
      expect(bridge.close_session('survey')).to be true
    end

    it 'returns false if session did not exist' do
      expect(bridge.close_session('unknown')).to be false
    end
  end

  describe '#list_sessions' do
    it 'returns info for all sessions' do
      bridge.create_session('survey')
      bridge.create_session('wizard')

      list = bridge.list_sessions
      expect(list.map { |s| s[:name] }).to contain_exactly('survey', 'wizard')
    end
  end

  describe '#handle_claude_message' do
    context 'with create message' do
      it 'creates a session and returns ready message' do
        message = { type: 'create', name: 'survey' }
        response = bridge.handle_claude_message(message)

        expect(response[:type]).to eq('ready')
        expect(response[:name]).to eq('survey')
        expect(response[:url]).to match(%r{/canvas/survey})
      end
    end

    context 'with push message' do
      let(:mock_ws) { double('websocket', send: nil) }

      before do
        session = bridge.create_session('survey')
        session.add_websocket(mock_ws)
      end

      it 'broadcasts update to session websockets' do
        message = { type: 'push', name: 'survey', dsl: "header1 'Hello'" }

        expect(mock_ws).to receive(:send).with(anything)

        bridge.handle_claude_message(message)
      end
    end

    context 'with close message' do
      it 'closes the session and returns closed message' do
        bridge.create_session('survey')
        message = { type: 'close', name: 'survey' }
        response = bridge.handle_claude_message(message)

        expect(response[:type]).to eq('closed')
        expect(response[:name]).to eq('survey')
        expect(bridge.sessions).not_to have_key('survey')
      end
    end

    context 'with get_state message' do
      it 'returns state message with current session state' do
        session = bridge.create_session('survey')
        session.update_state(choice: 'A')

        message = { type: 'get_state', name: 'survey' }
        response = bridge.handle_claude_message(message)

        expect(response[:type]).to eq('state')
        expect(response[:name]).to eq('survey')
        expect(response[:data]).to eq({ choice: 'A' })
      end
    end

    context 'with unknown message type' do
      it 'returns error message' do
        message = { type: 'unknown', name: 'survey' }
        response = bridge.handle_claude_message(message)

        expect(response[:type]).to eq('error')
        expect(response[:message]).to include('Unknown')
      end
    end
  end

  describe '#handle_browser_message' do
    it 'updates session state from browser data' do
      session = bridge.create_session('survey')
      message = { type: 'action', button: 'submit', state: { choice: 'B' } }

      bridge.handle_browser_message('survey', message)

      expect(session.state[:choice]).to eq('B')
    end

    it 'returns event message to forward to Claude' do
      bridge.create_session('survey')
      message = { type: 'action', button: 'submit', state: { choice: 'B' } }

      result = bridge.handle_browser_message('survey', message)

      expect(result[:type]).to eq('event')
      expect(result[:name]).to eq('survey')
      expect(result[:event]).to eq('action')
      expect(result[:data][:button]).to eq('submit')
      expect(result[:data][:state]).to eq({ choice: 'B' })
    end
  end
end
