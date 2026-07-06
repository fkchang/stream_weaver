# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/streaming'
require 'securerandom'
require 'json'
require 'socket'
require 'fileutils'
require_relative 'css'

module StreamWeaver
  # Multi-app service that renders StreamWeaver apps without per-app process management.
  # CLI spawns this service if needed, then sends commands to load apps.
  class Service < Sinatra::Base
    helpers Sinatra::Streaming

    enable :sessions
    set :session_secret, ENV.fetch('SESSION_SECRET') {
      'stream-weaver-service-development-secret-key-minimum-64-characters-for-security'
    }

    set :logging, false
    set :show_exceptions, :after_handler
    set :server, :puma

    DEFAULT_PORT = 4567

    class << self
      # { app_id => { app: StreamWeaver::App, path: file_path, loaded_at: Time } }
      attr_accessor :apps

      def apps
        @apps ||= {}
      end

      # =========================================
      # Live Sessions (polling-based update-in-place)
      # =========================================

      def live_sessions
        @live_sessions ||= {}
      end

      # { slug => app_id } registry for human-readable /apps/:slug URLs
      def slug_registry
        @slug_registry ||= {}
      end

      def get_or_create_live_session(name)
        live_sessions[name] ||= {
          content: {},  # { target => { html:, action:, timestamp: } }
          submissions: [],  # Array of form submissions waiting for Claude to read
          created_at: Time.now,
          last_push: nil
        }
      end

      # Store a form submission for Claude to retrieve
      def add_live_submission(name, data)
        session = live_sessions[name]
        return false unless session
        session[:submissions] << {
          data: data,
          timestamp: (Time.now.to_f * 1000).to_i
        }
        true
      end

      # Get pending submissions (Claude polls this)
      def get_live_submissions(name, clear: true)
        session = live_sessions[name]
        return [] unless session
        submissions = session[:submissions].dup
        session[:submissions].clear if clear
        submissions
      end

      def push_to_live_session(name, target:, content:, action: :replace)
        session = live_sessions[name]
        return false unless session

        session[:content][target] = {
          html: content,
          action: action,
          timestamp: (Time.now.to_f * 1000).to_i
        }
        session[:last_push] = Time.now
        true
      end

      def remove_live_session(name)
        live_sessions.delete(name) ? true : false
      end

      def list_live_sessions
        live_sessions.map do |name, session|
          {
            name: name,
            created_at: session[:created_at],
            last_push: session[:last_push]
          }
        end
      end

      # Load an app from a file path and register it
      # Returns the app_id for the newly loaded app
      #
      # Works with existing examples that use the pattern:
      #   App = app "Title" do ... end
      #   App.run! if __FILE__ == $0
      #
      # When loaded from service, __FILE__ != $0 so run! is skipped,
      # and we capture the SinatraApp from StreamWeaver.last_generated_app
      #
      # @param file_path [String] Path to the Ruby file
      # @param name [String, nil] Optional custom name for the app
      # @param source [String, nil] Optional source identifier (e.g., "examples_browser", "tutorial")
      # @return [String] The app_id
      def load_app(file_path, name: nil, source: nil)
        app_id = SecureRandom.hex(4)
        expanded_path = File.expand_path(file_path)

        raise "File not found: #{expanded_path}" unless File.exist?(expanded_path)

        # Clear any previous captured app
        StreamWeaver.last_generated_app = nil

        # Load the file - the global app() helper captures the result
        load expanded_path

        # Get the captured app
        sinatra_app = StreamWeaver.last_generated_app
        raise "No app found. File should use: app \"Title\" do ... end" unless sinatra_app

        # Extract the StreamWeaver::App from the SinatraApp
        streamlit_app = sinatra_app.settings.streamlit_app

        # Derive name from: explicit name > app title > filename
        app_name = name || streamlit_app.title || File.basename(expanded_path, '.rb')
        slug = assign_slug(app_id, app_name, expanded_path)

        apps[app_id] = {
          app: streamlit_app,
          path: expanded_path,
          name: app_name,
          source: source,
          slug: slug,
          loaded_at: Time.now,
          last_accessed: Time.now
        }

        app_id
      end

      # Convert a string into a URL-safe slug: lowercase, non-alphanumerics
      # collapsed to hyphens, leading/trailing hyphens stripped.
      # @param str [String]
      # @return [String]
      def slugify(str)
        str.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
      end

      # Assign (or reuse) a human-readable slug for an app_id, derived from the
      # app's declared name with fallback to the script filename.
      #
      # Re-loading the same file reuses its previous slug. A different file
      # whose derived slug collides with an existing one gets a numeric
      # suffix (-2, -3, ...).
      #
      # @param app_id [String] The app_id being assigned a slug
      # @param app_name [String] The app's declared/derived name
      # @param expanded_path [String] Absolute path to the app's file
      # @return [String] The assigned slug
      def assign_slug(app_id, app_name, expanded_path)
        base = slugify(app_name)
        base = slugify(File.basename(expanded_path, '.rb')) if base.empty?
        base = 'app' if base.empty?

        slug = base
        suffix = 2
        loop do
          holder_id = slug_registry[slug]
          holder_entry = holder_id && apps[holder_id]
          break if holder_entry.nil? || holder_entry[:path] == expanded_path
          slug = "#{base}-#{suffix}"
          suffix += 1
        end

        slug_registry[slug] = app_id
        slug
      end

      # Resolve a hex app_id or a human-readable slug to the canonical app_id
      # @param id_or_slug [String]
      # @return [String, nil] The canonical app_id, or nil if not found
      def resolve_app_id(id_or_slug)
        return id_or_slug if apps.key?(id_or_slug)
        slug_registry[id_or_slug]
      end

      # Remove an app by ID
      # @param app_id [String] The app ID to remove
      # @return [Boolean] true if removed, false if not found
      def remove_app(app_id)
        return false unless apps.key?(app_id)
        apps.delete(app_id)
        true
      end

      # Remove all apps
      # @return [Integer] Number of apps removed
      def clear_apps
        count = apps.size
        @apps = {}
        @slug_registry = {}
        count
      end

      # Remove all apps from a specific source
      # @param source [String] The source identifier
      # @return [Integer] Number of apps removed
      def remove_apps_by_source(source)
        return 0 if source.nil? || source.empty?
        ids_to_remove = apps.select { |_id, entry| entry[:source] == source }.keys
        ids_to_remove.each { |id| apps.delete(id) }
        ids_to_remove.size
      end

      # Find app by source and name (for aliased routes)
      # @param source [String] The source identifier
      # @param name [String] The app name (partial match OK)
      # @return [Array<String, Hash>] [app_id, entry] or [nil, nil]
      def find_app_by_source_and_name(source, name)
        apps.find do |_id, entry|
          entry[:source] == source && entry[:name]&.include?(name)
        end || [nil, nil]
      end

      # Generate aliased route path for an app
      # @param app_id [String] The app ID
      # @return [String, nil] The aliased path or nil if no source
      def aliased_path_for(app_id)
        entry = apps[app_id]
        return nil unless entry && entry[:source]
        # Use custom name if provided, otherwise fall back to filename
        name_part = entry[:name] || File.basename(entry[:path], '.rb')
        # Handle names that might include source prefix (e.g., "tutorial/philosophy")
        name_part = name_part.sub(%r{^#{entry[:source]}/}, '')
        "/#{entry[:source]}/#{name_part}"
      end

      # PID file management
      def pid_file_path
        File.expand_path('~/.streamweaver/server.pid')
      end

      def write_pid_file(port)
        FileUtils.mkdir_p(File.dirname(pid_file_path))
        File.write(pid_file_path, "port=#{port}\npid=#{Process.pid}\n")
      end

      def delete_pid_file
        File.delete(pid_file_path) if File.exist?(pid_file_path)
      end

      def read_pid_file
        return nil unless File.exist?(pid_file_path)
        content = File.read(pid_file_path)
        port = content[/port=(\d+)/, 1]&.to_i
        pid = content[/pid=(\d+)/, 1]&.to_i
        { port: port, pid: pid }
      end

      # Check if a service is already running (named to avoid shadowing Sinatra's running?)
      def service_running?
        info = read_pid_file
        return false unless info && info[:pid]

        # Check if process exists
        Process.kill(0, info[:pid])
        true
      rescue Errno::ESRCH
        # Process not found, clean up stale PID file
        delete_pid_file
        false
      end

      def find_available_port(start_port = DEFAULT_PORT)
        port = start_port
        loop do
          begin
            # Check both 127.0.0.1 and 0.0.0.0 to avoid conflicts where
            # a wildcard listener already holds the port (macOS routes to it)
            s1 = TCPServer.new('127.0.0.1', port)
            s1.close
            s2 = TCPServer.new('0.0.0.0', port)
            s2.close
            return port
          rescue Errno::EADDRINUSE
            port += 1
            raise "No available ports found" if port > start_port + 100
          end
        end
      end

      # Launch service in background using spawn
      def launch_background(port: nil)
        port ||= find_available_port

        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(pid_file_path))

        # Log file for debugging
        log_file = File.join(File.dirname(pid_file_path), 'server.log')

        # Get the lib path for stream_weaver
        lib_path = File.expand_path('../..', __FILE__)

        # Create a simple server script
        server_script = <<~RUBY
          $stdout.sync = true
          $stderr.sync = true
          puts "Starting StreamWeaver service..."

          $LOAD_PATH.unshift('#{lib_path}')
          require 'stream_weaver'

          puts "Setting port to #{port}..."
          StreamWeaver::Service.set :port, #{port}
          StreamWeaver::Service.set :bind, '127.0.0.1'

          # Configure Puma for SSE (more threads to handle long-lived connections)
          StreamWeaver::Service.set :server_settings, {
            :Threads => '5:20'  # Min 5, max 20 threads for SSE support
          }

          # Write PID file
          puts "Writing PID file..."
          File.write('#{pid_file_path}', "port=#{port}\\npid=\#{Process.pid}\\n")

          # Clean up on exit
          at_exit { File.delete('#{pid_file_path}') rescue nil }

          puts "Calling run!..."
          StreamWeaver::Service.run!
        RUBY

        # Write script to temp file
        script_file = File.join(File.dirname(pid_file_path), 'server_start.rb')
        File.write(script_file, server_script)

        # Spawn the server process
        pid = spawn(
          RbConfig.ruby, script_file,
          out: [log_file, 'a'],
          err: [log_file, 'a'],
          pgroup: true  # New process group
        )
        Process.detach(pid)

        # Wait for PID file to be written (server started)
        10.times do
          if File.exist?(pid_file_path)
            sleep 0.5  # Extra time for server to be ready
            return { port: port, pid: pid }
          end
          sleep 0.5
        end

        { port: port, pid: pid }
      end

      def stop
        info = read_pid_file
        return false unless info && info[:pid]

        Process.kill('TERM', info[:pid])
        sleep 1
        delete_pid_file
        true
      rescue Errno::ESRCH
        delete_pid_file
        true
      end
    end

    helpers do
      # Get app-specific state from session
      def app_state(app_id)
        session[:app_states] ||= {}
        session[:app_states][app_id] ||= {}
      end

      def set_app_state(app_id, state)
        session[:app_states] ||= {}
        session[:app_states][app_id] = state
      end

      # Sync form params to state hash (copied from server.rb)
      def sync_params_to_state(state, excluded_keys: [])
        excluded = %w[splat captures app_id button_id] + excluded_keys.map(&:to_s)
        params.each do |key, value|
          next if excluded.include?(key)
          state[key.to_sym] = coerce_param_value(value, state[key.to_sym])
        end
      end

      def coerce_param_value(value, current_value)
        case
        when value.is_a?(Array) then value
        when value == "on" || value == "true" then true
        when value == "false" then false
        when current_value.is_a?(Array) then Array(value)
        else value
        end
      end

      def render_error(message, error = nil)
        status 500
        content_type 'text/html'
        backtrace = error&.backtrace&.first(10)&.join("\n") || ""
        <<~HTML
          <div style="color: red; padding: 1rem; border: 1px solid red; margin: 1rem; font-family: monospace;">
            <h3>Error</h3>
            <p><strong>#{Rack::Utils.escape_html(message)}</strong></p>
            #{"<pre>#{Rack::Utils.escape_html(backtrace)}</pre>" unless backtrace.empty?}
          </div>
        HTML
      end

    end

    # =========================================
    # Service Management Routes
    # =========================================

    # Status endpoint for CLI detection
    get '/api/status' do
      content_type :json
      {
        app: 'streamweaver',
        version: StreamWeaver::VERSION,
        port: settings.port,
        apps: self.class.apps.keys
      }.to_json
    end

    # Load an app from file path
    post '/load-app' do
      content_type :json
      file_path = params[:file_path]
      name = params[:name]    # Optional custom name
      source = params[:source]  # Optional source identifier (e.g., "examples_browser")

      begin
        app_id = self.class.load_app(file_path, name: name, source: source)
        app_entry = self.class.apps[app_id]
        aliased = self.class.aliased_path_for(app_id)
        {
          success: true,
          app_id: app_id,
          slug: app_entry[:slug],
          name: app_entry[:name],
          source: app_entry[:source],
          url: "/apps/#{app_entry[:slug]}",
          canonical_url: "/apps/#{app_id}",
          aliased_url: aliased
        }.to_json
      rescue => e
        status 400
        { success: false, error: e.message }.to_json
      end
    end

    # Remove a specific app
    delete '/apps/:app_id' do
      content_type :json
      app_id = params[:app_id]

      if self.class.remove_app(app_id)
        { success: true, message: "App #{app_id} removed" }.to_json
      else
        status 404
        { success: false, error: "App not found: #{app_id}" }.to_json
      end
    end

    # Also support POST for clients that don't support DELETE
    post '/remove-app' do
      content_type :json
      app_id = params[:app_id]

      if self.class.remove_app(app_id)
        { success: true, message: "App #{app_id} removed" }.to_json
      else
        status 404
        { success: false, error: "App not found: #{app_id}" }.to_json
      end
    end

    # Clear all apps
    post '/clear-apps' do
      content_type :json
      count = self.class.clear_apps
      { success: true, message: "Removed #{count} app(s)" }.to_json
    end

    # Remove all apps from a specific source
    post '/clear-source' do
      content_type :json
      source = params[:source]
      count = self.class.remove_apps_by_source(source)
      { success: true, message: "Removed #{count} app(s) from #{source}", count: count }.to_json
    end

    # List apps with details (JSON API)
    get '/api/apps' do
      content_type :json
      apps_list = self.class.apps.map do |id, entry|
        {
          id: id,
          name: entry[:name],
          path: entry[:path],
          source: entry[:source],
          title: entry[:app].title,
          url: "/apps/#{id}",
          aliased_url: self.class.aliased_path_for(id),
          loaded_at: entry[:loaded_at].iso8601,
          last_accessed: entry[:last_accessed].iso8601,
          age_seconds: (Time.now - entry[:loaded_at]).to_i,
          idle_seconds: (Time.now - entry[:last_accessed]).to_i
        }
      end
      { apps: apps_list }.to_json
    end

    # =========================================
    # Live Sessions (SSE-based update-in-place)
    # =========================================

    # Create or get a live session and serve the live page
    get '/live/:session_name' do
      session_name = params[:session_name]
      theme = (params[:theme] || 'default').to_s
      layout = (params[:layout] || 'default').to_s
      self.class.get_or_create_live_session(session_name)

      # Validate theme
      valid_themes = %w[default dashboard document]
      theme = 'default' unless valid_themes.include?(theme)

      content_type 'text/html'
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>StreamWeaver Live: #{Rack::Utils.escape_html(session_name)}</title>
          #{StreamWeaver::CSS.cdn_scripts_html}
          #{StreamWeaver::CSS.google_fonts_html}
          <style>
            #{StreamWeaver::CSS.full_stylesheet}
            #{StreamWeaver::CSS.animation_css}

            /* Live session header overlay */
            .sw-live-header {
              position: fixed;
              top: 0;
              left: 0;
              right: 0;
              display: flex;
              justify-content: space-between;
              align-items: center;
              padding: 0.5rem 1rem;
              background: rgba(0, 0, 0, 0.85);
              backdrop-filter: blur(8px);
              color: #ffffff;
              font-size: 0.75rem;
              z-index: 9999;
              font-family: var(--sw-font-body);
            }
            .sw-live-status {
              display: flex;
              align-items: center;
              gap: 0.5rem;
            }
            .sw-live-dot {
              width: 8px;
              height: 8px;
              border-radius: 50%;
              background: var(--sw-color-primary);
              animation: sw-pulse 2s infinite;
            }
            @keyframes sw-pulse {
              0%, 100% { opacity: 1; }
              50% { opacity: 0.4; }
            }
            .sw-live-content {
              padding-top: 2.5rem; /* Space for fixed header */
            }
            /* Theme selector in header */
            .sw-live-theme-select {
              background: rgba(255,255,255,0.1);
              border: 1px solid rgba(255,255,255,0.2);
              color: #ffffff;
              padding: 0.25rem 0.5rem;
              border-radius: 4px;
              font-size: 0.75rem;
              cursor: pointer;
            }
            .sw-live-theme-select:hover {
              background: rgba(255,255,255,0.2);
            }
          </style>
        </head>
        <body class="sw-theme-#{Rack::Utils.escape_html(theme)} sw-layout-#{Rack::Utils.escape_html(layout)}">
          <div class="sw-live-header">
            <div class="sw-live-status">
              <span class="sw-live-dot"></span>
              <span>Live: #{Rack::Utils.escape_html(session_name)}</span>
            </div>
            <div style="display: flex; align-items: center; gap: 1rem;">
              <select class="sw-live-theme-select" onchange="switchTheme(this.value)">
                <option value="default" #{theme == 'default' ? 'selected' : ''}>Default</option>
                <option value="dashboard" #{theme == 'dashboard' ? 'selected' : ''}>Dashboard</option>
                <option value="document" #{theme == 'document' ? 'selected' : ''}>Document</option>
              </select>
              <span id="sw-connection-status">Connecting...</span>
            </div>
          </div>
          <div class="sw-live-content">
            <div id="app-container">
              <div id="main">
                <p style="color: var(--sw-color-text-muted);">Waiting for content...</p>
              </div>
            </div>
          </div>

          <script>
            // Theme switching
            function switchTheme(theme) {
              const body = document.body;
              body.className = body.className.replace(/sw-theme-\\w+/, 'sw-theme-' + theme);
              // Update URL without reload
              const url = new URL(window.location);
              url.searchParams.set('theme', theme);
              window.history.replaceState({}, '', url);
            }

            // Polling for updates
            (function() {
              const sessionName = #{session_name.to_json};
              const statusEl = document.getElementById('sw-connection-status');
              let lastTs = 0;

              async function poll() {
                try {
                  const r = await fetch('/live/' + encodeURIComponent(sessionName) + '/poll?since=' + lastTs);
                  const d = await r.json();
                  statusEl.textContent = 'Connected';
                  statusEl.style.color = '#22c55e';
                  d.updates.forEach(u => {
                    const el = document.querySelector(u.target);
                    if (el) {
                      // Add animation class
                      el.classList.remove('sw-fade-in');
                      void el.offsetWidth; // Trigger reflow
                      el.classList.add('sw-fade-in');

                      if (u.action === 'replace') el.innerHTML = u.html;
                      else if (u.action === 'append') el.insertAdjacentHTML('beforeend', u.html);
                      else if (u.action === 'prepend') el.insertAdjacentHTML('afterbegin', u.html);
                      // Tell HTMX to process new content
                      if (typeof htmx !== 'undefined') htmx.process(el);
                    }
                  });
                  lastTs = d.timestamp;
                } catch(e) {
                  statusEl.textContent = 'Reconnecting...';
                  statusEl.style.color = '#eab308';
                }
                setTimeout(poll, 300);
              }
              poll();
            })();
          </script>
        </body>
        </html>
      HTML
    end

    # Polling endpoint for live session updates
    get '/live/:session_name/poll' do
      content_type :json
      session_name = params[:session_name]
      since = params[:since]&.to_i || 0

      session = self.class.get_or_create_live_session(session_name)

      updates = []
      session[:content].each do |target, data|
        updates << { target: target, action: data[:action], html: data[:html] } if data[:timestamp] > since
      end

      { updates: updates, timestamp: (Time.now.to_f * 1000).to_i }.to_json
    end

    # Push content to a live session
    post '/live/:session_name/push' do
      content_type :json
      session_name = params[:session_name]
      target = params[:target] || '#main'
      action = (params[:action] || 'replace').to_sym
      html_content = params[:content] || request.body.read

      # Ensure session exists
      self.class.get_or_create_live_session(session_name)

      if self.class.push_to_live_session(session_name, target: target, content: html_content, action: action)
        { success: true, session: session_name, target: target, action: action }.to_json
      else
        status 404
        { success: false, error: "Session not found: #{session_name}" }.to_json
      end
    end

    # List live sessions
    get '/api/live' do
      content_type :json
      { sessions: self.class.list_live_sessions }.to_json
    end

    # Update from live session (text field changes, etc.)
    post '/live/:session_name/update' do
      # Return 204 No Content - tells HTMX to not swap anything
      status 204
      ''
    end

    # Button action from live session
    post '/live/:session_name/action/:button_id' do
      content_type 'text/html'
      session_name = params[:session_name]
      button_id = params[:button_id]

      # Collect all form data
      excluded = %w[splat captures session_name button_id]
      form_data = { _button: button_id }
      params.each do |key, value|
        next if excluded.include?(key)
        form_data[key.to_sym] = case value
        when "on", "true" then true
        when "false" then false
        else value
        end
      end

      self.class.add_live_submission(session_name, form_data)

      # Return HTML with "thinking" indicator - Claude will push real content when ready
      <<~HTML
        <div id="main" style="display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 200px; gap: 1rem;">
          <div class="sw-spinner" style="width: 40px; height: 40px; border: 3px solid var(--sw-color-border, #e0e0e0); border-top-color: var(--sw-color-primary, #c2410c); border-radius: 50%; animation: sw-spin 0.8s linear infinite;"></div>
          <p style="color: var(--sw-color-text-muted, #666); font-size: 1rem;">Claude is processing your response...</p>
          <style>@keyframes sw-spin { to { transform: rotate(360deg); } }</style>
        </div>
      HTML
    end

    # Submit form data from live session (user interactions)
    post '/live/:session_name/submit' do
      content_type :json
      session_name = params[:session_name]

      # Collect all form data
      excluded = %w[splat captures session_name]
      form_data = {}
      params.each do |key, value|
        next if excluded.include?(key)
        form_data[key.to_sym] = case value
        when "on", "true" then true
        when "false" then false
        else value
        end
      end

      self.class.add_live_submission(session_name, form_data)

      # Return confirmation and push a "submitted" message
      self.class.push_to_live_session(
        session_name,
        target: '#main',
        content: '<p style="color: #22c55e; padding: 1rem;">Submitted! Waiting for response...</p>',
        action: :replace
      )

      { success: true, data: form_data }.to_json
    end

    # Get pending submissions (Claude polls this)
    get '/live/:session_name/submissions' do
      content_type :json
      session_name = params[:session_name]
      clear = params[:clear] != 'false'

      submissions = self.class.get_live_submissions(session_name, clear: clear)
      { submissions: submissions }.to_json
    end

    # Remove a live session
    delete '/live/:session_name' do
      content_type :json
      session_name = params[:session_name]

      if self.class.remove_live_session(session_name)
        { success: true, message: "Session '#{session_name}' removed" }.to_json
      else
        status 404
        { success: false, error: "Session not found: #{session_name}" }.to_json
      end
    end

    # =========================================
    # Admin Dashboard
    # =========================================

    # Admin dashboard - StreamWeaver app managing itself
    get '/admin' do
      admin_app = Admin.create_app
      state = app_state('admin')
      adapter = Adapter::AlpineJS.new(url_prefix: "/admin")

      admin_app.rebuild_with_state(state)
      set_app_state('admin', state)

      Views::AppView.new(admin_app, state, adapter, false).call
    end

    post '/admin/update' do
      admin_app = Admin.create_app
      state = app_state('admin')
      adapter = Adapter::AlpineJS.new(url_prefix: "/admin")

      admin_app.rebuild_with_state(state)
      sync_params_to_state(state)
      set_app_state('admin', state)

      admin_app.rebuild_with_state(state)
      Views::AppContentView.new(admin_app, state, adapter, false).call
    end

    post '/admin/action/:button_id' do
      button_id = params[:button_id]
      admin_app = Admin.create_app
      state = app_state('admin')
      adapter = Adapter::AlpineJS.new(url_prefix: "/admin")

      admin_app.rebuild_with_state(state)
      sync_params_to_state(state)

      button = SinatraApp.find_button_recursive(admin_app.components, button_id)
      button&.execute(state)
      set_app_state('admin', state)

      admin_app.rebuild_with_state(state)
      Views::AppContentView.new(admin_app, state, adapter, false).call
    end

    # Aliased route: /:source/:name -> /apps/:app_id
    # Allows memorable URLs like /examples_browser/hello_world
    get '/:source/:name' do
      source = params[:source]
      name = params[:name]

      # Skip if this looks like a system route
      pass if %w[apps api admin].include?(source)

      app_id, _entry = self.class.find_app_by_source_and_name(source, name)
      halt 404, "App not found: #{source}/#{name}" unless app_id

      redirect "/apps/#{app_id}"
    end

    # List all loaded apps
    get '/' do
      content_type 'text/html'
      apps = self.class.apps

      if apps.empty?
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head><title>StreamWeaver Service</title></head>
          <body style="font-family: system-ui; padding: 2rem;">
            <h1>StreamWeaver Service</h1>
            <p>No apps loaded yet.</p>
            <p>Use: <code>streamweaver run &lt;file.rb&gt;</code></p>
          </body>
          </html>
        HTML
      else
        app_list = apps.map do |id, entry|
          "<li><a href='/apps/#{id}'>#{entry[:app].title}</a> (#{File.basename(entry[:path])})</li>"
        end.join("\n")

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head><title>StreamWeaver Service</title></head>
          <body style="font-family: system-ui; padding: 2rem;">
            <h1>StreamWeaver Service</h1>
            <h2>Loaded Apps</h2>
            <ul>#{app_list}</ul>
          </body>
          </html>
        HTML
      end
    end

    # =========================================
    # App Rendering Routes
    # =========================================

    # Render app main page
    # Accepts either the canonical hex app_id or its human-readable slug
    get '/apps/:app_id' do
      requested_id = params[:app_id]
      app_id = self.class.resolve_app_id(requested_id)
      app_entry = app_id && self.class.apps[app_id]
      halt 404, "App not found: #{requested_id}" unless app_entry

      # Track last access time
      app_entry[:last_accessed] = Time.now

      streamlit_app = app_entry[:app]
      state = app_state(app_id)
      adapter = Adapter::AlpineJS.new(url_prefix: "/apps/#{app_id}")

      streamlit_app.rebuild_with_state(state)
      set_app_state(app_id, state)

      Views::AppView.new(streamlit_app, state, adapter, false).call
    end

    # Update state from form inputs
    post '/apps/:app_id/update' do
      app_id = params[:app_id]
      app_entry = self.class.apps[app_id]
      halt 404, "App not found" unless app_entry

      streamlit_app = app_entry[:app]
      state = app_state(app_id)
      adapter = Adapter::AlpineJS.new(url_prefix: "/apps/#{app_id}")

      streamlit_app.rebuild_with_state(state)
      sync_params_to_state(state)
      set_app_state(app_id, state)

      streamlit_app.rebuild_with_state(state)
      Views::AppContentView.new(streamlit_app, state, adapter, false).call
    end

    # Button actions
    post '/apps/:app_id/action/:button_id' do
      app_id = params[:app_id]
      button_id = params[:button_id]
      app_entry = self.class.apps[app_id]
      halt 404, "App not found" unless app_entry

      streamlit_app = app_entry[:app]
      state = app_state(app_id)
      adapter = Adapter::AlpineJS.new(url_prefix: "/apps/#{app_id}")

      streamlit_app.rebuild_with_state(state)
      sync_params_to_state(state)

      # Find and execute button
      button = SinatraApp.find_button_recursive(streamlit_app.components, button_id)
      button&.execute(state)
      set_app_state(app_id, state)

      streamlit_app.rebuild_with_state(state)
      Views::AppContentView.new(streamlit_app, state, adapter, false).call
    end

    # Event callback endpoint
    post '/apps/:app_id/event/:key' do
      app_id = params[:app_id]
      key = params[:key].to_sym
      app_entry = self.class.apps[app_id]
      halt 404, "App not found" unless app_entry

      streamlit_app = app_entry[:app]
      state = app_state(app_id)
      adapter = Adapter::AlpineJS.new(url_prefix: "/apps/#{app_id}")

      streamlit_app.rebuild_with_state(state)
      sync_params_to_state(state)

      # Execute callbacks
      new_value = state[key]
      component = SinatraApp.find_component_by_key(streamlit_app.components, key)
      if component
        component.execute_on_change(state, new_value) if component.respond_to?(:execute_on_change)
        component.execute_on_blur(state, new_value) if component.respond_to?(:execute_on_blur)
      end

      set_app_state(app_id, state)

      streamlit_app.rebuild_with_state(state)
      Views::AppContentView.new(streamlit_app, state, adapter, false).call
    end

    # Form submission endpoint
    post '/apps/:app_id/form/:form_name' do
      app_id = params[:app_id]
      form_name = params[:form_name].to_sym
      app_entry = self.class.apps[app_id]
      halt 404, "App not found" unless app_entry

      streamlit_app = app_entry[:app]
      state = app_state(app_id)
      adapter = Adapter::AlpineJS.new(url_prefix: "/apps/#{app_id}")

      # Parse form params
      form_params = params[form_name.to_s] || {}
      form_values = {}
      form_params.each do |key, value|
        key_sym = key.to_sym
        form_values[key_sym] = case value
        when "on", "true" then true
        when "false" then false
        else value
        end
      end

      state[form_name] = form_values
      streamlit_app.rebuild_with_state(state)

      # Execute submit block
      form_component = SinatraApp.find_form_recursive(streamlit_app.components, form_name)
      form_component&.execute_submit(state, form_values)

      set_app_state(app_id, state)

      streamlit_app.rebuild_with_state(state)
      Views::AppContentView.new(streamlit_app, state, adapter, false).call
    end

    # Theme switching
    post '/apps/:app_id/theme/:theme_name' do
      app_id = params[:app_id]
      theme = params[:theme_name].to_sym
      app_entry = self.class.apps[app_id]
      halt 404, "App not found" unless app_entry

      if StreamWeaver.theme_exists?(theme)
        session[:theme_overrides] ||= {}
        session[:theme_overrides][app_id] = theme
        status 200
        "sw-theme-#{theme} sw-layout-#{app_entry[:app].layout}"
      else
        status 400
        "Invalid theme"
      end
    end

    # =========================================
    # Custom user-defined HTTP endpoints (App#endpoint DSL) — service mode
    # =========================================
    # Scoped under /apps/:app_id/* so multiple apps' endpoints can't collide with each
    # other. Defined AFTER every fixed /apps/:app_id/... route above, so on a path
    # collision the internal route always wins (Sinatra dispatches to the first route
    # that matches; `endpoint` also warns at registration time about known collisions).
    %i[get post put patch delete].each do |verb|
      send(verb, '/apps/:app_id/*') do
        # Resolve slugs the same way the page route does — endpoints must be
        # reachable at /apps/my-dashboard/api/... as well as the hex id.
        app_id = self.class.resolve_app_id(params[:app_id])
        app_entry = app_id && self.class.apps[app_id]
        pass unless app_entry

        streamlit_app = app_entry[:app]
        path = "/#{params['splat'].first}"
        ep = streamlit_app.find_endpoint(verb, path)
        pass unless ep

        status, headers, body = SinatraApp.normalize_endpoint_result(ep[:block].call(request))
        halt status, headers, body
      end
    end
  end

  # Module-level helper for apps to register with the service
  def self.register_service_app(app)
    Service.register_app(app)
  end
end
