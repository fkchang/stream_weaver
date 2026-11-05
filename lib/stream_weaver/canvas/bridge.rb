# frozen_string_literal: true

require_relative 'protocol'
require_relative 'session'
require_relative 'event_log'

module StreamWeaver
  module Canvas
    # Bridge between Claude Code (Unix socket) and browsers (WebSocket).
    # Manages sessions and routes messages between the two.
    class Bridge
      DEFAULT_PORT = 4568

      # Result of rendering DSL to HTML
      RenderResult = Struct.new(:html, :error, :stylesheets, keyword_init: true)

      attr_reader :sessions, :port

      def initialize(port: DEFAULT_PORT)
        @sessions = {}
        @port = port
      end

      # Create or get an existing session
      # @param name [String] Session name
      # @return [Session]
      def create_session(name, layout: :fluid, theme: :default, via: 'api')
        @sessions[name] ||= Session.new(name, layout: layout, theme: theme).tap do
          EventLog.record(:session_create, session_name: name, via: via)
        end
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
        session = @sessions.delete(name)
        session&.close!
        !!session
      end

      # List all sessions
      # @return [Array<Hash>]
      def list_sessions
        @sessions.values.map(&:to_h)
      end

      # Handle a message from Claude Code (via Unix socket)
      # @param message [Hash] Message from Claude
      # @return [Hash] Response message
      # @param alive [#call] liveness of the requesting connection; only the
      #   blocking wait_submit command consults it
      def handle_claude_message(message, alive = -> { true })
        case message[:type]
        when 'create'
          handle_create(message[:name], layout: (message[:layout] || :fluid).to_sym, theme: (message[:theme] || :default).to_sym)
        when 'push'
          handle_push(message[:name], message[:dsl], message[:source_dir])
        when 'toast'
          handle_toast(message[:name], message[:message], message[:variant], message[:duration])
        when 'close'
          handle_close(message[:name], cause: message[:cause], caller_info: message[:caller])
        when 'get_dsl'
          handle_get_dsl(message[:name])
        when 'drain_notes'
          handle_drain_notes(message[:name])
        when 'wait_submit'
          handle_wait_submit(message[:name], alive, message[:timeout])
        when 'notes_reply'
          handle_notes_reply(message[:name], message[:summary])
        when 'annotate'
          handle_annotate(message[:name], message[:on])
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

      def handle_create(name, layout: :fluid, theme: :default)
        create_session(name, layout: layout, theme: theme, via: 'cli_create')
        {
          type: 'ready',
          name: name,
          url: "http://localhost:#{@port}/canvas/#{name}"
        }
      end

      def handle_push(name, dsl, source_dir = nil)
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
          # Persist raw DSL, its inline stylesheets, and the directory it was
          # pushed from only on successful render so a later failed push
          # doesn't clobber the user's last-good content, re-skin
          # (stream_weaver-9uk), or desync source_dir from the DSL it's
          # paired with (canvas-doc-location-and-discovery.md).
          session.set_dsl(dsl)
          session.set_stylesheets(result.stylesheets)
          session.set_source_dir(source_dir)
          session.doc_pushed!
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

      def handle_close(name, cause: nil, caller_info: nil)
        session = get_session(name)
        pane_id = session&.pane_id
        EventLog.record(:session_close, session_name: name, pane_id: pane_id, cause: cause,
                        caller_info: caller_info, existed: !session.nil?)
        session&.broadcast(type: 'closed')
        close_session(name)
        { type: 'closed', name: name, pane_id: pane_id }
      end

      # canvas-snapshot's DSL/body source (stream_weaver-ps84): returns the
      # session's current in-memory dsl plus the theme/layout it was created
      # with, since the bridge only sets those at Session.new and neither
      # can drift afterward (Session has no theme=/layout= setter).
      def handle_get_dsl(name)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        { type: 'dsl', name: name, dsl: session.dsl, theme: session.theme, layout: session.layout }
      end

      # Drain viewer comments (canvas-notes). A name drains that session; no
      # name drains every session that has notes. Each session's read-and-clear
      # is one locked step, so concurrent drains never share a note.
      def handle_drain_notes(name)
        if name
          session = get_session(name)
          return { type: 'error', message: "Session not found: #{name}" } unless session

          return { type: 'notes', notes: { name => session.drain_notes } }
        end

        notes = @sessions.values.to_h { |s| [s.name, s.drain_notes] }.reject { |_, v| v.empty? }
        { type: 'notes', notes: notes }
      end

      # Blocks the calling connection thread until a batch is sent. Replies
      # 'submitted' with the batch, 'closed' if the canvas closed, or nothing
      # when the waiting client went away.
      def handle_wait_submit(name, alive, timeout)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        result = session.wait_for_submit(alive: alive, timeout: timeout)
        return nil if result.nil?
        return { type: 'closed', name: name } if result[:closed]

        { type: 'submitted', name: name, notes: result[:notes], ended: result[:ended] }
      end

      def handle_notes_reply(name, summary)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        { type: 'notes_replied', name: name, done: session.reply(summary) }
      end

      def handle_annotate(name, on)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        session.annotate = on == true
        { type: 'annotating', name: name, on: session.annotate? }
      end

      def handle_set_pane_id(name, pane_id)
        session = get_session(name)
        return { type: 'error', message: "Session not found: #{name}" } unless session

        previous = session.pane_id
        unless previous == pane_id
          EventLog.record(previous ? :pane_duplicate : :pane_create,
                          session_name: name, pane_id: pane_id, previous_pane_id: previous)
        end
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
        RenderResult.new(html: html, error: nil, stylesheets: mini_app.inline_stylesheets)
      rescue => e
        RenderResult.new(
          html: "<div class='error'>Error: #{e.message}</div>",
          error: e.message,
          stylesheets: []
        )
      end
    end
  end
end
