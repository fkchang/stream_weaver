# frozen_string_literal: true

require 'sinatra/base'
require 'securerandom'
require 'json'
require 'socket'
require 'fileutils'

module StreamWeaver
  # Multi-app service that renders StreamWeaver apps without per-app process management.
  # CLI spawns this service if needed, then sends commands to load apps.
  class Service < Sinatra::Base
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
      # @return [String] The app_id
      def load_app(file_path, name: nil)
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

        apps[app_id] = {
          app: streamlit_app,
          path: expanded_path,
          name: app_name,
          loaded_at: Time.now,
          last_accessed: Time.now
        }

        app_id
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
        count
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
            server = TCPServer.new('127.0.0.1', port)
            server.close
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
      name = params[:name]  # Optional custom name

      begin
        app_id = self.class.load_app(file_path, name: name)
        app_entry = self.class.apps[app_id]
        {
          success: true,
          app_id: app_id,
          name: app_entry[:name],
          url: "/apps/#{app_id}"
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

    # List apps with details (JSON API)
    get '/api/apps' do
      content_type :json
      apps_list = self.class.apps.map do |id, entry|
        {
          id: id,
          name: entry[:name],
          path: entry[:path],
          title: entry[:app].title,
          loaded_at: entry[:loaded_at].iso8601,
          last_accessed: entry[:last_accessed].iso8601,
          age_seconds: (Time.now - entry[:loaded_at]).to_i,
          idle_seconds: (Time.now - entry[:last_accessed]).to_i
        }
      end
      { apps: apps_list }.to_json
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
    get '/apps/:app_id' do
      app_id = params[:app_id]
      app_entry = self.class.apps[app_id]
      halt 404, "App not found: #{app_id}" unless app_entry

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
  end

  # Module-level helper for apps to register with the service
  def self.register_service_app(app)
    Service.register_app(app)
  end
end
