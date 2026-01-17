# frozen_string_literal: true

require_relative 'protocol'

module StreamWeaver
  module Canvas
    # Represents a single canvas session with its state and WebSocket connections.
    class Session
      attr_reader :name, :state, :websockets, :created_at
      attr_accessor :html, :html_version

      # @param name [String] Session name
      def initialize(name)
        @name = name
        @state = {}
        @websockets = []
        @created_at = Time.now
        @html = nil
        @html_version = 0
      end

      # Set the rendered HTML content and increment version
      # @param content [String] HTML content
      def set_html(content)
        @html = content
        @html_version += 1
      end

      # Update session state
      # @param new_state [Hash] State to merge
      def update_state(new_state)
        @state.merge!(new_state)
      end

      # Add a WebSocket connection
      # @param ws [Object] WebSocket connection
      def add_websocket(ws)
        @websockets << ws
      end

      # Remove a WebSocket connection
      # @param ws [Object] WebSocket connection
      def remove_websocket(ws)
        @websockets.delete(ws)
      end

      # Broadcast a message to all connected WebSockets
      # @param message [Hash] Message to send
      def broadcast(message)
        encoded = Protocol.encode(message)
        @websockets.each { |ws| ws.send(encoded) }
      end

      # Return session info as a hash
      # @return [Hash]
      def to_h
        {
          name: @name,
          state: @state,
          websocket_count: @websockets.size,
          created_at: @created_at
        }
      end
    end
  end
end
