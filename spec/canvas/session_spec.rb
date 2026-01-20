# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/protocol'
require 'stream_weaver/canvas/session'

RSpec.describe StreamWeaver::Canvas::Session do
  let(:session) { described_class.new('test-session') }

  describe '#initialize' do
    it 'stores the session name' do
      expect(session.name).to eq('test-session')
    end

    it 'starts with empty state' do
      expect(session.state).to eq({})
    end

    it 'starts with no websocket connections' do
      expect(session.websockets).to eq([])
    end
  end

  describe '#update_state' do
    it 'merges new state with existing state' do
      session.update_state(name: 'Alice')
      session.update_state(priority: 'High')

      expect(session.state).to eq({ name: 'Alice', priority: 'High' })
    end

    it 'overwrites existing keys' do
      session.update_state(name: 'Alice')
      session.update_state(name: 'Bob')

      expect(session.state[:name]).to eq('Bob')
    end
  end

  describe '#add_websocket / #remove_websocket' do
    let(:mock_ws) { double('websocket') }

    it 'adds a websocket connection' do
      session.add_websocket(mock_ws)
      expect(session.websockets).to include(mock_ws)
    end

    it 'removes a websocket connection' do
      session.add_websocket(mock_ws)
      session.remove_websocket(mock_ws)
      expect(session.websockets).not_to include(mock_ws)
    end
  end

  describe '#broadcast' do
    let(:ws1) { double('websocket1') }
    let(:ws2) { double('websocket2') }

    before do
      session.add_websocket(ws1)
      session.add_websocket(ws2)
    end

    it 'sends encoded message to all websockets' do
      message = { type: 'update', html: '<h1>Hello</h1>' }
      encoded = StreamWeaver::Canvas::Protocol.encode(message)

      expect(ws1).to receive(:send).with(encoded)
      expect(ws2).to receive(:send).with(encoded)

      session.broadcast(message)
    end
  end

  describe '#to_h' do
    it 'returns session info as a hash' do
      session.update_state(name: 'Test')

      info = session.to_h
      expect(info[:name]).to eq('test-session')
      expect(info[:state]).to eq({ name: 'Test' })
      expect(info[:websocket_count]).to eq(0)
      expect(info[:created_at]).to be_a(Time)
    end
  end
end
