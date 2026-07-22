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

        begin
          path = StreamWeaver::Canvas::DocStore.save(doc_name, session.dsl)
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
            <style>
              #{SW_STYLES}
            </style>
            <style>#{StreamWeaver::Views::AppView.master_theme_css}</style>
            <style>#{StreamWeaver::Theme.visual_skills_css}</style>
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
        session.stylesheets.map { |css| "<style>#{css}</style>" }.join("\n")
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

      SW_STYLES = <<~CSS
          /* Note: --sw-color and --sw-spacing family tokens are intentionally
             NOT declared at :root here -- they come from AppView.master_theme_css's
             body.sw-theme-{name} block, which is always rendered alongside this
             constant (see render_canvas_page). A :root-level declaration would be
             visible to getComputedStyle(document.documentElement), shadowing the
             body-scoped theme-aware value (and its dark variant) that things like
             sw-mermaid-zoom.js's getThemeVariables() read directly off <html>. */

          /* Base styles */
          *, *::before, *::after { box-sizing: border-box; }
          body {
            font-family: 'Source Sans 3', system-ui, sans-serif;
            font-size: 17px;
            line-height: 1.7;
            margin: 0;
            padding: var(--sw-spacing-md);
            background: var(--sw-color-bg);
            color: var(--sw-color-text);
          }
          #app-container {
            margin: 0 auto;
            background: var(--sw-color-bg-card);
            border-radius: var(--sw-radius-md);
            padding: var(--sw-spacing-lg);
            box-shadow: var(--sw-shadow-sm);
          }
          body.sw-layout-default #app-container { max-width: 900px; }
          body.sw-layout-wide    #app-container { max-width: 1100px; }
          body.sw-layout-full    #app-container { max-width: 1400px; }
          body.sw-layout-fluid   #app-container { max-width: 100%; }
          h1, h2, h3, h4, h5, h6 { margin: 0 0 var(--sw-spacing-md) 0; line-height: 1.3; }
          h1 { font-size: 2rem; }
          h2 { font-size: 1.5rem; }
          h3 { font-size: 1.25rem; }
          p { margin: 0 0 var(--sw-spacing-md) 0; }
          hr { border: none; border-top: 1px solid var(--sw-color-border); margin: var(--sw-spacing-lg) 0; }

          /* Card component */
          .card {
            background: var(--sw-color-bg-card);
            border: 1px solid var(--sw-color-border);
            border-left: var(--sw-card-border-left);
            border-radius: var(--sw-radius-md);
            padding: var(--sw-spacing-lg);
            margin-bottom: var(--sw-spacing-md);
            box-shadow: var(--sw-shadow-sm);
          }
          .card h3 {
            margin-top: 0;
            margin-bottom: var(--sw-spacing-sm);
            color: var(--sw-color-text);
          }
          .card-header {
            padding-bottom: var(--sw-spacing-sm);
            margin-bottom: var(--sw-spacing-md);
            border-bottom: 1px solid var(--sw-color-border);
          }
          .card-header h1, .card-header h2, .card-header h3,
          .card-header h4, .card-header h5, .card-header h6 { margin: 0; }
          .card-body > *:first-child { margin-top: 0; }
          .card-body > *:last-child { margin-bottom: 0; }
          .card-footer {
            padding-top: var(--sw-spacing-sm);
            margin-top: var(--sw-spacing-md);
            border-top: 1px solid var(--sw-color-border);
            display: flex;
            justify-content: flex-end;
            gap: var(--sw-spacing-sm);
          }
          .card-footer button { margin: 0; }

          /* Columns layout */
          .sw-columns {
            display: flex;
            gap: var(--sw-spacing-lg);
            margin-bottom: var(--sw-spacing-md);
          }
          .sw-column { flex: 1; min-width: 0; }
          @media (max-width: 768px) {
            .sw-columns { flex-direction: column; }
          }

          /* Buttons */
          .btn {
            display: inline-block;
            padding: 10px 20px;
            border: none;
            border-radius: var(--sw-radius-md);
            cursor: pointer;
            font-size: 16px;
            font-weight: 500;
            transition: background-color 150ms ease;
          }
          .btn:hover { filter: brightness(0.95); }
          .btn-primary {
            background: var(--sw-color-primary);
            color: white;
          }
          .btn-primary:hover { background: var(--sw-color-primary-hover); }
          .btn-secondary {
            background: #e5e5e5;
            color: var(--sw-color-text);
          }
          .btn-secondary:hover { background: #d5d5d5; }

          /* Form elements */
          .radio-group { display: flex; flex-direction: column; gap: 8px; margin-bottom: var(--sw-spacing-md); }
          .radio-option { display: flex; align-items: center; gap: 8px; cursor: pointer; }
          .checkbox-wrapper { display: flex; align-items: flex-start; gap: 8px; margin-bottom: var(--sw-spacing-sm); }
          .checkbox-wrapper input[type="checkbox"] {
            width: 18px;
            height: 18px;
            margin: 2px 0 0 0;
            cursor: pointer;
          }
          .checkbox-wrapper label { cursor: pointer; flex: 1; }
          input[type="text"], textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid var(--sw-color-border);
            border-radius: var(--sw-radius-md);
            font-size: 16px;
            box-sizing: border-box;
          }
          input[type="text"]:focus, textarea:focus {
            outline: none;
            border-color: var(--sw-color-primary);
            box-shadow: 0 0 0 2px var(--sw-color-primary-light);
          }

          /* Markdown rendering */
          strong, b { font-weight: 600; }
          code {
            background: var(--sw-color-bg-elevated);
            padding: 2px 6px;
            border-radius: var(--sw-radius-sm);
            font-size: 0.9em;
          }

          /* Canvas waiting state */
          .sw-canvas-waiting {
            text-align: center;
            padding: 60px 40px;
            color: #666;
          }
          .sw-canvas-logo {
            color: var(--sw-color-primary);
            margin-bottom: 16px;
          }
          .sw-canvas-waiting h1 {
            font-size: 24px;
            font-weight: 600;
            color: var(--sw-color-text);
            margin-bottom: 24px;
          }
          .sw-canvas-spinner {
            width: 40px;
            height: 40px;
            border: 3px solid #e0e0e0;
            border-top-color: var(--sw-color-primary);
            border-radius: 50%;
            margin: 0 auto 20px;
            animation: sw-spin 1s linear infinite;
          }
          @keyframes sw-spin {
            to { transform: rotate(360deg); }
          }
          @keyframes sw-toast-in {
            from { opacity: 0; transform: translateX(-50%) translateY(-20px); }
            to { opacity: 1; transform: translateX(-50%) translateY(0); }
          }
          .sw-canvas-status {
            font-size: 18px;
            color: #444;
            margin-bottom: 24px;
          }
          .sw-canvas-info { margin-bottom: 32px; }
          .sw-canvas-session code {
            background: #f0f0f0;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 500;
          }
          .sw-canvas-ready {
            font-size: 14px;
            color: #888;
            margin-top: 8px;
          }
          .sw-canvas-tip {
            background: #f8f8f8;
            border-radius: 8px;
            padding: 16px;
            margin-top: 24px;
          }
          .sw-canvas-tip p {
            margin: 0 0 8px 0;
            font-size: 14px;
            color: #666;
          }
          .sw-canvas-tip code {
            display: block;
            background: #fff;
            border: 1px solid #e0e0e0;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 13px;
            color: #333;
          }

          /* Progress bar */
          .sw-progress {
            width: 100%;
            height: 20px;
            background: #e5e7eb;
            border-radius: 10px;
            overflow: hidden;
            position: relative;
            margin-bottom: var(--sw-spacing-md);
          }
          .sw-progress-bar {
            height: 100%;
            background: var(--sw-color-primary);
            border-radius: 10px;
            transition: width 0.3s ease;
          }
          .sw-progress-label {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 12px;
            font-weight: 600;
            color: #333;
          }
          .sw-progress-success .sw-progress-bar { background: #10b981; }
          .sw-progress-warning .sw-progress-bar { background: #f59e0b; }
          .sw-progress-error .sw-progress-bar { background: #ef4444; }
          .sw-progress-animated .sw-progress-bar {
            background-image: linear-gradient(
              45deg, rgba(255,255,255,0.15) 25%, transparent 25%,
              transparent 50%, rgba(255,255,255,0.15) 50%,
              rgba(255,255,255,0.15) 75%, transparent 75%, transparent
            );
            background-size: 1rem 1rem;
            animation: sw-progress-stripes 1s linear infinite;
          }
          @keyframes sw-progress-stripes {
            from { background-position: 1rem 0; }
            to { background-position: 0 0; }
          }

          /* Spinner */
          .sw-spinner-container {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: var(--sw-spacing-sm);
          }
          .sw-spinner {
            border: 2px solid #e0e0e0;
            border-top-color: var(--sw-color-primary);
            border-radius: 50%;
            animation: sw-spin 0.8s linear infinite;
          }
          .sw-spinner-sm { width: 16px; height: 16px; }
          .sw-spinner-md { width: 24px; height: 24px; }
          .sw-spinner-lg { width: 40px; height: 40px; border-width: 3px; }
          .sw-spinner-label {
            font-size: 14px;
            color: var(--sw-color-text-muted);
          }

          /* Status dots */
          .sw-status-dot {
            display: inline-block;
            border-radius: 50%;
            flex-shrink: 0;
          }
          .sw-status-dot-sm { width: 6px; height: 6px; }
          .sw-status-dot-md { width: 10px; height: 10px; }
          .sw-status-dot-lg { width: 14px; height: 14px; }
          .sw-status-dot-red { background: #ef4444; box-shadow: 0 0 6px rgba(239, 68, 68, 0.5); }
          .sw-status-dot-yellow { background: #f59e0b; box-shadow: 0 0 6px rgba(245, 158, 11, 0.5); }
          .sw-status-dot-green { background: #10b981; box-shadow: 0 0 6px rgba(16, 185, 129, 0.5); }
          .sw-status-dot-gray { background: #9ca3af; }
          .sw-status-dot-pulse { animation: sw-pulse 1.5s ease-in-out infinite; }
          @keyframes sw-pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.6; transform: scale(1.1); }
          }

          /* Status dot with label wrapper */
          .sw-status-dot-wrapper {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 4px;
          }
          .sw-status-dot-label {
            font-size: 12px;
            color: var(--sw-color-text-muted);
          }

          /* Activity items */
          .sw-activity-item {
            display: flex;
            gap: 12px;
            padding: 8px 0;
            border-bottom: 1px solid var(--sw-color-border);
          }
          .sw-activity-item:last-child { border-bottom: none; }
          .sw-activity-time {
            font-size: 12px;
            color: var(--sw-color-text-muted);
            min-width: 40px;
          }
          .sw-activity-content { flex: 1; }
          .sw-activity-title { font-weight: 500; }

          /* Alerts */
          .sw-alert {
            padding: var(--sw-spacing-md);
            border-radius: var(--sw-radius-md);
            margin-bottom: var(--sw-spacing-md);
            border-left: 4px solid;
          }
          .sw-alert-info { background: #eff6ff; border-color: #3b82f6; }
          .sw-alert-success { background: #f0fdf4; border-color: #10b981; }
          .sw-alert-warning { background: #fffbeb; border-color: #f59e0b; }
          .sw-alert-error { background: #fef2f2; border-color: #ef4444; }
          .sw-alert-title {
            font-weight: 600;
            margin-bottom: 4px;
          }

          /* Badges */
          .sw-badge {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
          }
          .sw-badge-default { background: #e5e7eb; color: #374151; }
          .sw-badge-info { background: #dbeafe; color: #1d4ed8; }
          .sw-badge-success { background: #d1fae5; color: #047857; }
          .sw-badge-warning { background: #fef3c7; color: #b45309; }
          .sw-badge-danger { background: #fee2e2; color: #b91c1c; }

          /* Collapsible */
          .sw-collapsible { margin-bottom: var(--sw-spacing-md); }
          .sw-collapsible-trigger {
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
            padding: 8px;
            background: var(--sw-color-bg-elevated);
            border-radius: var(--sw-radius-md);
            font-weight: 500;
          }
          .sw-collapsible-trigger:hover { background: #e5e5e5; }
          .sw-collapsible-content {
            padding: var(--sw-spacing-md);
            border: 1px solid var(--sw-color-border);
            border-top: none;
            border-radius: 0 0 var(--sw-radius-md) var(--sw-radius-md);
          }

          /* HStack/VStack */
          .sw-hstack {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
          }
          .sw-hstack-xs { gap: 4px; }
          .sw-hstack-sm { gap: 8px; }
          .sw-hstack-md { gap: 16px; }
          .sw-hstack-lg { gap: 24px; }
          .sw-hstack-xl { gap: 32px; }
          .sw-vstack {
            display: flex;
            flex-direction: column;
          }
          .sw-vstack-none { gap: 0; }
          .sw-vstack-xs { gap: 4px; }
          .sw-vstack-sm { gap: 8px; }
          .sw-vstack-md { gap: 16px; }

          /* Table */
          .sw-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: var(--sw-spacing-md);
          }
          .sw-table th, .sw-table td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid var(--sw-color-border);
          }
          .sw-table th {
            font-weight: 600;
            background: var(--sw-color-bg-elevated);
          }
          .sw-table-striped tr:nth-child(even) td {
            background: var(--sw-color-bg-elevated);
          }
          .sw-table-sortable th {
            cursor: pointer;
          }
          .sw-table-sortable th:hover {
            background: #e0e0e0;
          }

          /* Toast notifications */
          .sw-toast {
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            padding: 12px 40px 12px 16px;
            border-radius: var(--sw-radius-md);
            font-size: 14px;
            font-weight: 500;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            z-index: 10000;
            animation: sw-toast-in 0.3s ease-out;
            max-width: 90%;
          }
          .sw-toast-message { display: inline; }
          .sw-toast-close {
            position: absolute;
            right: 8px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            font-size: 20px;
            cursor: pointer;
            opacity: 0.7;
            padding: 4px 8px;
            line-height: 1;
          }
          .sw-toast-close:hover { opacity: 1; }
          .sw-toast-info {
            background: #dbeafe;
            color: #1e40af;
            border: 1px solid #93c5fd;
          }
          .sw-toast-success {
            background: #d1fae5;
            color: #065f46;
            border: 1px solid #6ee7b7;
          }
          .sw-toast-warning {
            background: #fef3c7;
            color: #92400e;
            border: 1px solid #fcd34d;
          }
          .sw-toast-error {
            background: #fee2e2;
            color: #991b1b;
            border: 1px solid #fca5a5;
          }
        CSS

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
