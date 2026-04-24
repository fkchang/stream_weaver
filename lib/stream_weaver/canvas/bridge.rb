# frozen_string_literal: true

require_relative 'protocol'
require_relative 'session'

module StreamWeaver
  module Canvas
    # Bridge between Claude Code (Unix socket) and browsers (WebSocket).
    # Manages sessions and routes messages between the two.
    class Bridge
      DEFAULT_PORT = 4568

      # Result of rendering DSL to HTML
      RenderResult = Struct.new(:html, :error, keyword_init: true)

      attr_reader :sessions, :port

      def initialize(port: DEFAULT_PORT)
        @sessions = {}
        @port = port
      end

      # Create or get an existing session
      # @param name [String] Session name
      # @return [Session]
      def create_session(name, layout: :fluid)
        @sessions[name] ||= Session.new(name, layout: layout)
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
          handle_create(message[:name], layout: (message[:layout] || :fluid).to_sym)
        when 'push'
          handle_push(message[:name], message[:dsl])
        when 'toast'
          handle_toast(message[:name], message[:message], message[:variant], message[:duration])
        when 'close'
          handle_close(message[:name])
        when 'set_pane_id'
          handle_set_pane_id(message[:name], message[:pane_id])
        when 'reset'
          handle_reset(message[:name], message[:all])
        when 'list'
          handle_list
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

      def handle_create(name, layout: :fluid)
        create_session(name, layout: layout)
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
        result = render_dsl(dsl, session_name: name)

        # Store in session for polling clients
        session.set_html(result.html)

        # Broadcast to all websockets (if any connected)
        session.broadcast({ type: 'update', html: result.html })

        # Return error info if rendering failed
        if result.error
          { type: 'push_error', message: result.error }
        else
          { type: 'push_ok' }
        end
      end

      def handle_toast(name, message, variant, duration)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        session.queue_toast(
          message: message,
          variant: variant || 'warning',
          duration: duration || 0
        )

        nil # No response to Claude for toast
      end

      def handle_close(name)
        session = get_session(name)
        pane_id = session&.pane_id
        session&.broadcast(type: 'closed')
        close_session(name)
        { type: 'closed', name: name, pane_id: pane_id }
      end

      def handle_set_pane_id(name, pane_id)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        session.pane_id = pane_id
        { type: 'pane_id_set', name: name }
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

      def handle_reset(name, reset_all = false)
        return reset_all_sessions if reset_all

        session = get_session(name) or return { type: 'error', message: "Session not found: #{name}" }
        session.reset!
        { type: 'reset_ok', name: name }
      end

      def reset_all_sessions
        @sessions.each_value(&:reset!)
        { type: 'reset_ok', count: @sessions.size }
      end

      def handle_list
        { type: 'list', sessions: list_sessions }
      end

      # Render StreamWeaver DSL to HTML
      # @param dsl [String] DSL code
      # @param session_name [String] Session name for routing
      # @return [RenderResult] Result with html and optional error
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
        html = StreamWeaver::Views::AppContentView.new(mini_app, state, adapter, false).call
        RenderResult.new(html: html, error: nil)
      rescue => e
        RenderResult.new(
          html: "<div class='error'>Error: #{e.message}</div>",
          error: e.message
        )
      end
    end
  end
end
