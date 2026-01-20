# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/protocol'

RSpec.describe StreamWeaver::Canvas::Protocol do
  describe '.encode' do
    it 'encodes a message to newline-delimited JSON' do
      message = { type: 'create', name: 'survey' }
      encoded = described_class.encode(message)

      expect(encoded).to eq("{\"type\":\"create\",\"name\":\"survey\"}\n")
    end
  end

  describe '.decode' do
    it 'decodes a JSON string to a message hash with symbol keys' do
      json = '{"type":"ready","name":"survey","url":"http://localhost:4568/canvas/survey"}'
      message = described_class.decode(json)

      expect(message).to eq({
        type: 'ready',
        name: 'survey',
        url: 'http://localhost:4568/canvas/survey'
      })
    end

    it 'handles malformed JSON by returning nil' do
      expect(described_class.decode('not json')).to be_nil
    end
  end

  describe '.parse_buffer' do
    it 'extracts complete messages from a buffer' do
      buffer = "{\"type\":\"create\"}\n{\"type\":\"push\"}\n"
      messages, remaining = described_class.parse_buffer(buffer)

      expect(messages).to eq([
        { type: 'create' },
        { type: 'push' }
      ])
      expect(remaining).to eq('')
    end

    it 'returns incomplete data as remaining buffer' do
      buffer = "{\"type\":\"create\"}\n{\"type\":\"pu"
      messages, remaining = described_class.parse_buffer(buffer)

      expect(messages).to eq([{ type: 'create' }])
      expect(remaining).to eq("{\"type\":\"pu")
    end

    it 'handles empty buffer' do
      messages, remaining = described_class.parse_buffer('')

      expect(messages).to eq([])
      expect(remaining).to eq('')
    end
  end

  describe 'message types' do
    describe StreamWeaver::Canvas::Protocol::Messages do
      it 'creates a create message' do
        msg = described_class.create('survey')
        expect(msg).to eq({ type: 'create', name: 'survey' })
      end

      it 'creates a push message with DSL' do
        msg = described_class.push('survey', "header1 'Hello'")
        expect(msg).to eq({ type: 'push', name: 'survey', dsl: "header1 'Hello'" })
      end

      it 'creates a close message' do
        msg = described_class.close('survey')
        expect(msg).to eq({ type: 'close', name: 'survey' })
      end

      it 'creates a ready message' do
        msg = described_class.ready('survey', 'http://localhost:4568/canvas/survey')
        expect(msg).to eq({ type: 'ready', name: 'survey', url: 'http://localhost:4568/canvas/survey' })
      end

      it 'creates an event message' do
        msg = described_class.event('survey', 'submit', { choice: 'A' })
        expect(msg).to eq({ type: 'event', name: 'survey', event: 'submit', data: { choice: 'A' } })
      end
    end
  end
end
