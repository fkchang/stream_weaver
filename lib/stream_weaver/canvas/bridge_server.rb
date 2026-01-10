# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'socket'
require 'fileutils'
require_relative 'protocol'
require_relative 'session'
require_relative 'bridge'

# Load StreamWeaver core for adapter and views
require_relative '../adapter/base'
require_relative '../adapter/alpinejs'

module StreamWeaver
  module Canvas
    # Sinatra-based server that bridges Claude Code (Unix socket) and browsers (WebSocket).
    #
    # Architecture:
    #   Claude Code ◄──Unix Socket──► BridgeServer ◄──WebSocket──► Browser
    #
    # The server:
    #   1. Listens on a Unix socket for messages from Claude Code
    #   2. Serves HTML pages with the StreamWeaver UI
    #   3. Maintains WebSocket connections with browsers
    #   4. Routes messages between Claude and browsers
    #
    class BridgeServer < Sinatra::Base
      SOCKET_PATH = File.expand_path('~/.streamweaver/canvas.sock')
      PID_FILE_PATH = File.expand_path('~/.streamweaver/canvas.pid')
      DEFAULT_PORT = 4568

      class << self
        attr_accessor :bridge, :unix_server, :claude_connections

        def socket_path
          SOCKET_PATH
        end

        def pid_file_path
          PID_FILE_PATH
        end

        def default_port
          DEFAULT_PORT
        end

        def setup!
          @bridge ||= Bridge.new(port: DEFAULT_PORT)
          @claude_connections ||= []
        end
      end

      # Initialize bridge on first request
      before do
        self.class.setup!
      end

      configure do
        set :port, DEFAULT_PORT
        set :bind, '127.0.0.1'
        set :show_exceptions, false
        set :logging, false
      end

      # Health check
      get '/health' do
        content_type :json
        {
          status: 'ok',
          sessions: self.class.bridge.sessions.keys,
          port: DEFAULT_PORT
        }.to_json
      end

      # List all sessions
      get '/sessions' do
        content_type :json
        self.class.bridge.list_sessions.to_json
      end

      # Canvas session page
      get '/canvas/:name' do
        session_name = params[:name]

        # Create or get session
        session = self.class.bridge.create_session(session_name)

        # Render the canvas page
        content_type :html
        render_canvas_page(session_name, session)
      end

      # WebSocket endpoint for browser connections
      # Note: This requires faye-websocket or similar middleware
      # For now, we'll use polling as a fallback
      get '/canvas/:name/poll' do
        session_name = params[:name]
        session = self.class.bridge.get_session(session_name)

        halt 404, { error: 'Session not found' }.to_json unless session

        content_type :json
        { state: session.state }.to_json
      end

      # Receive events from browser (fallback for WebSocket)
      post '/canvas/:name/event' do
        session_name = params[:name]
        session = self.class.bridge.get_session(session_name)

        halt 404, { error: 'Session not found' }.to_json unless session

        # Parse the event
        body = request.body.read
        event = JSON.parse(body, symbolize_names: true) rescue {}

        # Update session state
        if event[:state]
          session.update_state(event[:state])
        end

        # Forward to Claude via Unix socket
        forward_to_claude(session_name, event)

        content_type :json
        { success: true }.to_json
      end

      private

      def render_canvas_page(session_name, session)
        # Create adapter in websocket mode
        adapter = StreamWeaver::Adapter::AlpineJS.new(
          url_prefix: "/canvas/#{session_name}",
          mode: :websocket
        )

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>StreamWeaver Canvas: #{session_name}</title>
            <style>
              #{canvas_styles}
            </style>
            #{adapter.cdn_scripts.join("\n")}
          </head>
          <body class="sw-theme-default">
            <div id="app-container" #{container_attrs(session.state, adapter)}>
              <div class="sw-canvas-waiting">
                <h2>Canvas: #{session_name}</h2>
                <p>Waiting for content from Claude Code...</p>
                <p class="sw-canvas-hint">
                  Push content with:<br>
                  <code>streamweaver canvas-push #{session_name} &lt;&lt;'RUBY'</code>
                </p>
              </div>
            </div>
          </body>
          </html>
        HTML
      end

      def canvas_styles
        <<~CSS
          :root {
            --sw-color-primary: #c2410c;
            --sw-color-text: #111111;
            --sw-color-bg: #f8f8f8;
            --sw-color-bg-card: #ffffff;
            --sw-color-border: #e0e0e0;
            --sw-spacing: 16px;
            --sw-radius: 8px;
          }
          body {
            font-family: 'Source Sans 3', system-ui, sans-serif;
            margin: 0;
            padding: var(--sw-spacing);
            background: var(--sw-color-bg);
            color: var(--sw-color-text);
          }
          #app-container {
            max-width: 800px;
            margin: 0 auto;
            background: var(--sw-color-bg-card);
            border-radius: var(--sw-radius);
            padding: var(--sw-spacing);
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
          }
          h1, h2, h3, h4, h5, h6 { margin: 0 0 var(--sw-spacing) 0; }
          .btn {
            display: inline-block;
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 500;
          }
          .btn-primary {
            background: var(--sw-color-primary);
            color: white;
          }
          .btn-secondary {
            background: #e5e5e5;
            color: var(--sw-color-text);
          }
          .radio-group { display: flex; flex-direction: column; gap: 8px; }
          .radio-option { display: flex; align-items: center; gap: 8px; cursor: pointer; }
          input[type="text"], textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid var(--sw-color-border);
            border-radius: 6px;
            font-size: 16px;
            box-sizing: border-box;
          }
          .sw-canvas-waiting {
            text-align: center;
            padding: 40px;
            color: #666;
          }
          .sw-canvas-hint code {
            background: #f0f0f0;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 14px;
          }
        CSS
      end

      def container_attrs(state, adapter)
        attrs = adapter.container_attributes(state)
        attrs.map { |k, v| "#{k}='#{v.gsub("'", "\\\\'")}'" }.join(' ')
      end

      def forward_to_claude(session_name, event)
        message = Protocol::Messages.event(
          session_name,
          event[:type] || 'event',
          event
        )

        # Send to all connected Claude clients
        self.class.claude_connections.each do |conn|
          begin
            conn.write(Protocol.encode(message))
          rescue => e
            # Connection closed, will be cleaned up
          end
        end
      end

      # Start the Unix socket server in a background thread
      def self.start_unix_socket_server
        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(SOCKET_PATH))

        # Remove stale socket
        File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)

        @unix_server = UNIXServer.new(SOCKET_PATH)

        Thread.new do
          loop do
            begin
              client = @unix_server.accept
              @claude_connections << client
              handle_claude_connection(client)
            rescue => e
              break if @unix_server.nil? || @unix_server.closed?
            end
          end
        end
      end

      def self.handle_claude_connection(client)
        Thread.new do
          buffer = ''

          loop do
            begin
              data = client.read_nonblock(4096)
              buffer += data

              # Parse complete messages
              messages, buffer = Protocol.parse_buffer(buffer)

              messages.each do |msg|
                response = @bridge.handle_claude_message(msg)

                if response
                  client.write(Protocol.encode(response))
                end

                # If push message, broadcast to browser websockets
                if msg[:type] == 'push'
                  broadcast_to_browsers(msg[:name])
                end
              end
            rescue IO::WaitReadable
              IO.select([client], nil, nil, 0.1)
            rescue EOFError, Errno::ECONNRESET
              break
            end
          end

          @claude_connections.delete(client)
          client.close rescue nil
        end
      end

      def self.broadcast_to_browsers(session_name)
        session = @bridge.get_session(session_name)
        return unless session

        # Session broadcasts to its websockets
        # For HTTP polling mode, browsers will get updates on next poll
      end

      # Write PID file
      def self.write_pid_file
        FileUtils.mkdir_p(File.dirname(PID_FILE_PATH))
        File.write(PID_FILE_PATH, "pid=#{Process.pid}\nport=#{DEFAULT_PORT}\n")
      end

      # Cleanup on shutdown
      def self.cleanup
        File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)
        File.delete(PID_FILE_PATH) if File.exist?(PID_FILE_PATH)
        @unix_server&.close
      end

      # Start the full server (Unix socket + HTTP)
      def self.run!
        setup!
        write_pid_file
        start_unix_socket_server

        at_exit { cleanup }

        # Start Sinatra
        super
      end
    end
  end
end
