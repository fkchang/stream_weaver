# frozen_string_literal: true

require_relative 'protocol'
require_relative 'session'

module StreamWeaver
  module Canvas
    # Bridge between Claude Code (Unix socket) and browsers (WebSocket).
    # Manages sessions and routes messages between the two.
    class Bridge
      DEFAULT_PORT = 4568

      attr_reader :sessions, :port

      def initialize(port: DEFAULT_PORT)
        @sessions = {}
        @port = port
      end

      # Create or get an existing session
      # @param name [String] Session name
      # @return [Session]
      def create_session(name)
        @sessions[name] ||= Session.new(name)
      end

      # Get a session by name
      # @param name [String] Session name
      # @return [Session, nil]
      def get_session(name)
        @sessions[name]
      end

      # Close and remove a session
      # @param name [String] Session name
      # @return [Boolean] true if session existed
      def close_session(name)
        !!@sessions.delete(name)
      end

      # List all sessions
      # @return [Array<Hash>]
      def list_sessions
        @sessions.values.map(&:to_h)
      end

      # Handle a message from Claude Code (via Unix socket)
      # @param message [Hash] Message from Claude
      # @return [Hash] Response message
      def handle_claude_message(message)
        case message[:type]
        when 'create'
          handle_create(message[:name])
        when 'push'
          handle_push(message[:name], message[:dsl])
        when 'close'
          handle_close(message[:name])
        when 'get_state'
          handle_get_state(message[:name])
        else
          { type: 'error', message: "Unknown message type: #{message[:type]}" }
        end
      end

      # Handle a message from browser (via WebSocket)
      # @param session_name [String] Session name
      # @param message [Hash] Message from browser
      # @return [Hash] Event message to forward to Claude
      def handle_browser_message(session_name, message)
        session = get_session(session_name)
        return nil unless session

        # Update session state from browser
        if message[:state]
          session.update_state(message[:state])
        end

        # Return event for Claude
        {
          type: 'event',
          name: session_name,
          event: message[:type],
          data: {
            button: message[:button],
            state: message[:state]
          }
        }
      end

      private

      def handle_create(name)
        create_session(name)
        {
          type: 'ready',
          name: name,
          url: "http://localhost:#{@port}/canvas/#{name}"
        }
      end

      def handle_push(name, dsl)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        # Render DSL to HTML
        html = render_dsl(dsl, session_name: name)

        # Broadcast to all websockets
        session.broadcast({ type: 'update', html: html })

        nil # No response to Claude for push
      end

      def handle_close(name)
        session = get_session(name)
        if session
          # Notify websockets before closing
          session.broadcast({ type: 'closed' })
        end
        close_session(name)
        { type: 'closed', name: name }
      end

      def handle_get_state(name)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        {
          type: 'state',
          name: name,
          data: session.state
        }
      end

      # Render StreamWeaver DSL to HTML
      # @param dsl [String] DSL code
      # @param session_name [String] Session name for routing
      # @return [String] Rendered HTML
      def render_dsl(dsl, session_name:)
        # Create a mini app to evaluate the DSL
        mini_app = StreamWeaver::App.new("Canvas")
        mini_app.instance_eval(dsl)

        # Create adapter in websocket mode
        adapter = StreamWeaver::Adapter::AlpineJS.new(
          url_prefix: "/canvas/#{session_name}",
          mode: :websocket
        )

        # Render to HTML
        state = {}
        StreamWeaver::Views::AppContentView.new(mini_app, state, adapter, false).call
      rescue => e
        "<div class='error'>Error: #{e.message}</div>"
      end
    end
  end
end
