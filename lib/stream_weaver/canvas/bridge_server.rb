# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'socket'
require 'fileutils'
require_relative 'protocol'
require_relative 'session'
require_relative 'bridge'
require_relative 'doc_store'

# Load StreamWeaver core for adapter and views
require_relative '../adapter/base'
require_relative '../adapter/alpinejs'
require_relative '../views'
require_relative '../page_shell'

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
      DEFAULT_PORT = 4700

      class << self
        attr_accessor :bridge, :unix_server, :claude_connections, :port

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
          @port ||= DEFAULT_PORT
          @bridge ||= Bridge.new(port: @port)
          @claude_connections ||= []
        end

        # Find an available port starting from DEFAULT_PORT
        def find_available_port(start_port = DEFAULT_PORT)
          port = start_port
          loop do
            begin
              server = TCPServer.new('127.0.0.1', port)
              server.close
              return port
            rescue Errno::EADDRINUSE
              port += 1
              raise "No available ports found for canvas bridge" if port > start_port + 100
            end
          end
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
          port: self.class.port || DEFAULT_PORT
        }.to_json
      end

      post '/shutdown' do
        content_type :json
        Thread.new { sleep 0.1; exit(0) }
        { status: 'shutting_down' }.to_json
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

      # Poll endpoint for browsers without WebSocket
      # Returns HTML content and version for incremental updates
      get '/canvas/:name/poll' do
        session_name = params[:name]
        session = self.class.bridge.get_session(session_name)

        halt 404, { error: 'Session not found' }.to_json unless session

        content_type :json
        {
          state: session.state,
          html: session.html,
          version: session.html_version,
          toasts: session.pop_toasts
        }.to_json
      end

      # Save the session's last-good DSL as a persistent canvas doc (Tier 2).
      # Body: {"name": "<doc-name>"}; ".rb" is added/normalized by DocStore.
      post '/canvas/:name/save-doc' do
        content_type :json
        session_name = params[:name]
        session = self.class.bridge.get_session(session_name)

        halt 404, { ok: false, error: "Session not found: #{session_name}" }.to_json unless session
        halt 422, { ok: false, error: "No DSL stored for session #{session_name}" }.to_json if session.dsl.nil?

        body = JSON.parse(request.body.read, symbolize_names: true) rescue {}
        doc_name = body[:name]

        # Carry the live session's theme/layout into the saved text -- canvas-read
        # re-renders the file with no session to inherit from (stream_weaver-csf).
        dsl = StreamWeaver::Canvas::DocStore.dsl_with_metadata(
          session.dsl, theme: session.theme, layout: session.layout
        )

        begin
          path = StreamWeaver::Canvas::DocStore.save(doc_name, dsl)
          { ok: true, path: path }.to_json
        rescue ArgumentError => e
          halt 422, { ok: false, error: e.message }.to_json
        rescue StandardError => e
          halt 500, { ok: false, error: e.message }.to_json
        end
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

        # If session already has HTML, show it; otherwise show waiting message
        initial_content = if session.html
          session.html
        else
          <<~WAITING
            <div class="sw-canvas-waiting">
              <div class="sw-canvas-logo">
                <svg viewBox="0 0 24 24" width="48" height="48">
                  <path fill="currentColor" d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                </svg>
              </div>
              <h1>StreamWeaver Canvas</h1>
              <div class="sw-canvas-spinner"></div>
              <p class="sw-canvas-status">Waiting for Claude Code...</p>
              <div class="sw-canvas-info">
                <p class="sw-canvas-session">Session: <code>#{session_name}</code></p>
                <p class="sw-canvas-ready">Ready to receive content</p>
              </div>
              <div class="sw-canvas-tip">
                <p>Push content with:</p>
                <code>streamweaver canvas-push #{session_name} &lt;&lt;'RUBY'</code>
              </div>
            </div>
          WAITING
        end

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>StreamWeaver Canvas: #{session_name}</title>
            #{StreamWeaver::PageShell.framework_css_html}
            #{inline_stylesheets_html(session)}
            <script>#{StreamWeaver::Theme::AutoMode.inline_script}</script>
            #{adapter.cdn_scripts.join("\n")}
            <!-- Chart.js for charts -->
            <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
            <!-- Highlight.js for syntax highlighting -->
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github.min.css">
            <script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>
            <!-- Mermaid zoom/pan engine — always present so canvas-push with mermaid works on first push -->
            <script>#{File.read(File.join(__dir__, '..', 'assets', 'js', 'sw-mermaid-zoom.js'))}</script>
            <!-- Kick off CDN fetch immediately so mermaid is ready before first push arrives -->
            <script>if (window.swMermaidPreload) window.swMermaidPreload();</script>
          </head>
          <body class="sw-theme-#{session.theme} sw-layout-#{session.layout}">
            <div id="app-container" #{container_attrs(session.state, adapter)}>
              #{initial_content}
            </div>
            #{save_doc_widget(session_name)}
            <script>
              #{polling_script(session_name, session.html_version)}
            </script>
          </body>
          </html>
        HTML
      end

      # CSS carried by the pushed DSL's `use_stylesheet` calls (stream_weaver-9uk)
      # -- canvas has no route to serve a referenced asset file across
      # processes, so the bridge inlines the raw content it was handed
      # instead. `session.stylesheets` is already deduped/replaced per push
      # (Session#set_stylesheets), so no further digest bookkeeping is
      # needed here to avoid stacking duplicate tags across re-pushes.
      def inline_stylesheets_html(session)
        StreamWeaver::PageShell.user_css_html(inline_stylesheets: session.stylesheets)
      end

      # Floating "Save as doc" button + Alpine.js modal that POSTs the
      # session's last-good DSL to /canvas/:name/save-doc, promoting it from
      # ephemeral history to docs/streamweaver_canvas/<name>.rb.
      def save_doc_widget(session_name)
        <<~HTML
          <style>
            [x-cloak] { display: none !important; }
            .sw-save-doc-btn {
              position: fixed; bottom: 1rem; right: 1rem; z-index: 50;
              background: var(--sw-color-primary, #1f6feb); color: #fff;
              border: none; border-radius: 999px; padding: 0.55rem 1rem;
              font-size: 0.85rem; font-weight: 600; cursor: pointer;
              box-shadow: 0 6px 16px rgba(28,25,23,0.18);
              opacity: 0.85; transition: opacity 120ms ease, transform 120ms ease;
            }
            .sw-save-doc-btn:hover { opacity: 1; transform: translateY(-1px); }
            .sw-save-doc-modal {
              position: fixed; inset: 0; z-index: 60;
              background: rgba(15, 17, 23, 0.45);
              display: flex; align-items: center; justify-content: center;
            }
            .sw-save-doc-dialog {
              background: #fff; border-radius: 8px; padding: 1.5rem;
              width: min(440px, 90vw); box-shadow: 0 20px 50px rgba(0,0,0,0.25);
              font-family: 'Source Sans 3', system-ui, sans-serif;
            }
            .sw-save-doc-dialog h3 { margin: 0 0 0.5rem 0; font-size: 1.1rem; }
            .sw-save-doc-dialog p.hint {
              margin: 0 0 1rem 0; color: #6b7280; font-size: 0.85rem;
            }
            .sw-save-doc-dialog input[type=text] {
              width: 100%; padding: 0.55rem 0.75rem;
              border: 1px solid #d1d5db; border-radius: 5px;
              font-size: 0.95rem; font-family: ui-monospace, monospace;
              box-sizing: border-box;
            }
            .sw-save-doc-dialog input[type=text]:focus {
              outline: 2px solid var(--sw-color-primary, #1f6feb); outline-offset: -1px;
              border-color: transparent;
            }
            .sw-save-doc-error {
              margin-top: 0.75rem; padding: 0.5rem 0.75rem;
              background: #fee2e2; color: #991b1b; border-radius: 4px;
              font-size: 0.85rem;
            }
            .sw-save-doc-success {
              margin-top: 0.75rem; padding: 0.5rem 0.75rem;
              background: #dcfce7; color: #166534; border-radius: 4px;
              font-size: 0.85rem; word-break: break-all;
            }
            .sw-save-doc-actions {
              display: flex; justify-content: flex-end; gap: 0.5rem;
              margin-top: 1rem;
            }
            .sw-save-doc-actions button {
              padding: 0.45rem 1rem; border-radius: 5px;
              font-size: 0.9rem; cursor: pointer; border: 1px solid transparent;
            }
            .sw-save-doc-actions button:disabled { opacity: 0.5; cursor: not-allowed; }
            .sw-save-doc-cancel { background: #f3f4f6; color: #374151; border-color: #d1d5db; }
            .sw-save-doc-cancel:hover:not(:disabled) { background: #e5e7eb; }
            .sw-save-doc-save {
              background: var(--sw-color-primary, #1f6feb); color: #fff;
            }
            .sw-save-doc-save:hover:not(:disabled) { filter: brightness(1.05); }
          </style>
          <div x-data="{
            open: false,
            name: '',
            saving: false,
            savedPath: null,
            error: null,
            defaultName() {
              const d = new Date();
              const pad = n => String(n).padStart(2, '0');
              const ymd = d.getFullYear() + pad(d.getMonth()+1) + pad(d.getDate());
              const hm = pad(d.getHours()) + pad(d.getMinutes());
              return '#{session_name}-' + ymd + '-' + hm;
            },
            openDialog() {
              this.error = null; this.savedPath = null;
              this.name = this.defaultName();
              this.open = true;
              this.$nextTick(() => this.$refs.input && this.$refs.input.select());
            },
            async save() {
              if (this.saving) return;
              this.saving = true; this.error = null;
              try {
                const res = await fetch('/canvas/#{session_name}/save-doc', {
                  method: 'POST',
                  headers: {'Content-Type': 'application/json'},
                  body: JSON.stringify({name: this.name})
                });
                const data = await res.json();
                if (res.ok && data.ok) {
                  this.savedPath = data.path;
                  setTimeout(() => { this.open = false; }, 1800);
                } else {
                  this.error = data.error || ('HTTP ' + res.status);
                }
              } catch (e) {
                this.error = e.message;
              } finally {
                this.saving = false;
              }
            }
          }" @keydown.escape.window="open = false">
            <button class="sw-save-doc-btn" @click="openDialog()" title="Save this canvas as a persistent doc">
              💾 Save as doc
            </button>
            <div x-show="open" x-cloak class="sw-save-doc-modal" @click.self="open = false">
              <div class="sw-save-doc-dialog" @click.stop>
                <h3>Save canvas as doc</h3>
                <p class="hint">Writes to <code>docs/streamweaver_canvas/&lt;name&gt;.rb</code> (or <code>~/.streamweaver/canvas/</code> outside a git repo).</p>
                <input type="text" x-model="name" x-ref="input"
                       @keydown.enter.prevent="save()"
                       :disabled="saving"
                       placeholder="my-canvas-doc">
                <div x-show="error" x-text="error" class="sw-save-doc-error"></div>
                <div x-show="savedPath" class="sw-save-doc-success">
                  ✓ Saved to <code x-text="savedPath"></code>
                </div>
                <div class="sw-save-doc-actions">
                  <button class="sw-save-doc-cancel" @click="open = false" :disabled="saving">Cancel</button>
                  <button class="sw-save-doc-save" @click="save()" :disabled="saving">
                    <span x-show="!saving">Save</span>
                    <span x-show="saving">Saving...</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        HTML
      end

      def polling_script(session_name, current_version)
        <<~JS
          (function() {
            let currentVersion = #{current_version};
            let sessionClosed = false;
            const pollUrl = '/canvas/#{session_name}/poll';
            const container = document.getElementById('app-container');
            const closedHtml = '<div style="text-align:center;padding:60px;color:#374151;"><div style="font-size:3rem;margin-bottom:16px;">✓</div><h2 style="margin:0 0 12px">Session Complete</h2><p style="color:#666;margin:0">This StreamWeaver canvas session has closed.</p></div>';

            // Shared state for coordinating poll updates with showFeedback.
            // When showFeedback shows a spinner, it records the version at that
            // time. The poll will only replace the spinner with content from a
            // NEWER version, preventing stale feedback from clobbering new content.
            window._swContentVersion = currentVersion;
            window._swFeedbackActive = false;

            // --- Optional debug overlay: add ?debug to the URL to enable ---
            if (location.search.includes('debug')) {
              const _dbg = document.createElement('div');
              _dbg.id = 'sw-debug';
              _dbg.style.cssText = 'position:fixed;top:0;left:0;right:0;background:rgba(0,0,0,0.85);color:#0f0;font:10px/1.3 monospace;padding:2px 6px;z-index:99999;max-height:60px;overflow-y:auto;pointer-events:none;';
              document.body.appendChild(_dbg);
              const _dl = [];
              window._dbgLog = function(msg) {
                const t = new Date().toLocaleTimeString('en-US',{hour12:false});
                _dl.push(t + ' ' + msg);
                if (_dl.length > 30) _dl.shift();
                _dbg.innerHTML = _dl.join('<br>');
                _dbg.scrollTop = 99999;
              };
              window._dbgLog('init v=' + currentVersion);
            } else {
              window._dbgLog = function(){};
            }

            function showToast(toast) {
              // Remove any existing toast
              const existing = document.querySelector('.sw-toast');
              if (existing) existing.remove();

              const el = document.createElement('div');
              el.className = 'sw-toast sw-toast-' + (toast.variant || 'warning');
              el.innerHTML = '<span class="sw-toast-message">' + escapeHtml(toast.message) + '</span>' +
                             '<button class="sw-toast-close" onclick="this.parentElement.remove()">&times;</button>';
              document.body.appendChild(el);

              // Auto-dismiss if duration > 0
              if (toast.duration > 0) {
                setTimeout(() => el.remove(), toast.duration);
              }
            }

            function escapeHtml(text) {
              const div = document.createElement('div');
              div.textContent = text;
              return div.innerHTML;
            }

            async function poll() {
              try {
                const resp = await fetch(pollUrl);
                if (!resp.ok) {
                  if (resp.status === 404 && !sessionClosed) {
                    sessionClosed = true;
                    container.innerHTML = closedHtml;
                  }
                  return;
                }

                const data = await resp.json();

                // Show any pending toasts
                if (data.toasts && data.toasts.length > 0) {
                  data.toasts.forEach(toast => showToast(toast));
                }

                // Update if version changed and there's HTML
                if (data.version > currentVersion && data.html) {
                  window._dbgLog('POLL v' + currentVersion + '->' + data.version + ' feedback=' + window._swFeedbackActive);
                  currentVersion = data.version;
                  window._swContentVersion = data.version;
                  window._swFeedbackActive = false;
                  container.innerHTML = data.html;

                  // Remove toast when new content arrives (unless persistent)
                  const existingToast = document.querySelector('.sw-toast');
                  if (existingToast) existingToast.remove();

                  // Re-initialize Alpine.js on the new content
                  if (window.Alpine) {
                    Alpine.initTree(container);
                  }

                  // Initialize mermaid diagrams (swMermaidInit is idempotent via data-sw-mermaid-done guard)
                  if (window.swMermaidInit) window.swMermaidInit();

                  // Apply syntax highlighting and initialize charts after DOM update
                  setTimeout(() => {
                    // Apply syntax highlighting to code blocks
                    if (window.hljs) {
                      container.querySelectorAll('pre code:not(.hljs)').forEach((block) => {
                        hljs.highlightElement(block);
                      });
                    }

                    // Initialize Chart.js charts
                    if (window.Chart) {
                      container.querySelectorAll('canvas[data-chart-config]:not([data-chart-init])').forEach((canvas) => {
                        try {
                          const config = JSON.parse(canvas.dataset.chartConfig);
                          new Chart(canvas, config);
                          canvas.dataset.chartInit = 'true';
                        } catch (e) {
                          console.error('Chart init error:', e);
                        }
                      });
                    }
                  }, 10);
                }
              } catch (e) {
                console.error('Poll error:', e);
              }
            }

            // Poll every 500ms
            setInterval(poll, 500);

            // Also poll immediately
            poll();
          })();
        JS
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

        connections = self.class.claude_connections || []

        # Send to all connected Claude clients
        connections.each do |conn|
          conn.write(Protocol.encode(message))
        rescue => e
          warn "canvas: dropped event for #{session_name}: #{e.message}"
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
        File.write(PID_FILE_PATH, "pid=#{Process.pid}\nport=#{@port || DEFAULT_PORT}\n")
      end

      # Cleanup on shutdown
      def self.cleanup
        File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)
        File.delete(PID_FILE_PATH) if File.exist?(PID_FILE_PATH)
        @unix_server&.close
      end

      # Start the full server (Unix socket + HTTP)
      def self.run!
        # Find available port before setup
        @port = find_available_port
        set :port, @port

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
