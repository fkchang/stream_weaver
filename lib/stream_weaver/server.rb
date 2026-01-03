# frozen_string_literal: true

require 'sinatra/base'
require 'stringio'
require 'socket'
require 'json'

module StreamWeaver
  # Generated Sinatra application for serving the StreamWeaver app
  class SinatraApp < Sinatra::Base
    enable :sessions
    # Use static secret in development to avoid HMAC errors on restart (must be >=64 chars)
    set :session_secret, ENV.fetch('SESSION_SECRET') {
      if ENV['RACK_ENV'] == 'production'
        raise "SESSION_SECRET environment variable required in production"
      else
        'stream-weaver-development-secret-key-change-in-production-environments-minimum-64-characters'
      end
    }

    # Disable protection in test mode to allow Rack::Test requests
    set :protection, false if ENV['RACK_ENV'] == 'test'

    # Disable Sinatra's startup messages for cleaner output
    set :logging, false
    set :show_exceptions, :after_handler
    set :dump_errors, true
    set :raise_errors, false

    # Create a Sinatra app from a StreamWeaver::App instance
    #
    # @param streamlit_app [StreamWeaver::App] The app definition
    # @return [Class] Sinatra::Base subclass
    def self.create(streamlit_app)
      # Store the streamlit app for access in routes
      set :streamlit_app, streamlit_app

      # Create adapter instance (Alpine.js by default)
      set :adapter, Adapter::AlpineJS.new

      # Helper methods for state synchronization
      helpers do
        # Coerce a form parameter value to the appropriate Ruby type
        def coerce_param_value(value, current_value)
          case
          when value.is_a?(Array) then value
          when value == "on" || value == "true" then true
          when value == "false" then false
          when current_value.is_a?(Array) then Array(value)
          else value
          end
        end

        # Sync form params to state hash
        def sync_params_to_state(state, excluded_keys: [])
          excluded = %w[splat captures] + excluded_keys.map(&:to_s)

          params.each do |key, value|
            next if excluded.include?(key)
            state[key.to_sym] = coerce_param_value(value, state[key.to_sym])
          end
        end

        # Filter state for session storage - remove large/transient keys
        # Session cookies have ~4KB limit, so we can't store file contents, etc.
        def session_safe_state(state)
          transient_keys = [:code_content, :current_file_path, :examples]
          state.reject do |k, _|
            transient_keys.include?(k) || k.to_s.end_with?('_edited_code')
          end
        end

        # Set unchecked checkboxes to false (they don't send params)
        def handle_unchecked_checkboxes(state, components)
          self.class.collect_input_keys(components).each do |key|
            component = self.class.find_component_by_key(components, key)
            if component.is_a?(Components::Checkbox) && !params.key?(key.to_s)
              state[key] = false
            end
          end
        end

        # Render error page for debugging
        def render_error(route_name, error)
          File.open("/tmp/streamweaver_error.log", "a") do |f|
            f.puts "#{Time.now} POST #{route_name} error: #{error.class}: #{error.message}"
            f.puts error.backtrace.first(10).join("\n")
            f.puts "---"
          end
          status 500
          content_type 'text/html'
          <<~HTML
            <div style="color: red; padding: 1rem; border: 1px solid red; margin: 1rem; font-family: monospace;">
              <h3>Error in #{route_name}</h3>
              <p><strong>#{error.class}:</strong> #{Rack::Utils.escape_html(error.message)}</p>
              <pre style="background: #f5f5f5; padding: 0.5rem; overflow-x: auto;">#{Rack::Utils.escape_html(error.backtrace.first(15).join("\n"))}</pre>
            </div>
          HTML
        end
      end

      # Define routes
      get '/' do
        # For agentic mode, always start with fresh state
        # For regular mode, preserve state across requests
        is_agentic = settings.respond_to?(:result_container)
        if is_agentic
          # Completely clear the session to avoid any stale data
          session.clear
          state = {}
          session[:streamlit_state] = session_safe_state(state)
        else
          state = session[:streamlit_state] ||= {}
        end

        # Prevent browser caching for all forms to ensure fresh rendering
        cache_control :no_cache, :no_store, :must_revalidate, max_age: 0
        headers 'Pragma' => 'no-cache'

        streamlit_app = settings.streamlit_app
        adapter = settings.adapter
        session_theme = session[:theme_override]
        streamlit_app.rebuild_with_state(state)
        Views::AppView.new(streamlit_app, state, adapter, is_agentic, session_theme: session_theme).call
      end

      # Update state from form inputs
      post '/update' do
        begin
          state = session[:streamlit_state] ||= {}
          streamlit_app = settings.streamlit_app
          adapter = settings.adapter
          is_agentic = settings.respond_to?(:result_container)

          streamlit_app.rebuild_with_state(state)
          sync_params_to_state(state)
          handle_unchecked_checkboxes(state, streamlit_app.components)
          session[:streamlit_state] = session_safe_state(state)

          streamlit_app.rebuild_with_state(state)
          Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
        rescue => e
          render_error("/update", e)
        end
      end

      # Button actions
      post '/action/:button_id' do
        begin
          state = session[:streamlit_state] ||= {}
          button_id = params[:button_id]
          streamlit_app = settings.streamlit_app
          adapter = settings.adapter
          is_agentic = settings.respond_to?(:result_container)

          streamlit_app.rebuild_with_state(state)
          sync_params_to_state(state, excluded_keys: [:button_id])
          handle_unchecked_checkboxes(state, streamlit_app.components)

          # Find and execute the button action
          button = self.class.find_button_recursive(streamlit_app.components, button_id)
          if button
            button.execute(state)
            session[:streamlit_state] = session_safe_state(state)
          end

          streamlit_app.rebuild_with_state(state)
          Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
        rescue => e
          render_error("/action/#{params[:button_id]}", e)
        end
      end

      # Submit endpoint for agentic mode
      post '/submit' do
        state = session[:streamlit_state] ||= {}
        streamlit_app = settings.streamlit_app

        streamlit_app.rebuild_with_state(state)
        sync_params_to_state(state)
        handle_unchecked_checkboxes(state, streamlit_app.components)
        session[:streamlit_state] = session_safe_state(state)

        # Collect input keys for filtering the result
        input_keys = self.class.collect_input_keys(streamlit_app.components)

        # Filter result to only include keys from input components
        filtered_result = {}
        input_keys.each do |key|
          filtered_result[key] = state[key] if state.key?(key)
        end

        # Signal that result is ready (for run_once!)
        if settings.respond_to?(:result_container)
          settings.result_container[:result] = filtered_result
          settings.result_container[:ready] = true
        end

        # Return confirmation page or auto-close
        auto_close = settings.respond_to?(:auto_close_window) && settings.auto_close_window
        if auto_close
          # Auto-close window with JavaScript
          <<~HTML
            <html>
              <head>
                <title>Submitted</title>
              </head>
              <body>
                <h1>✅ Submitted!</h1>
                <p>Data has been sent to the agent. This window will close automatically...</p>
                <script>
                  // Close window after brief delay to allow user to see confirmation
                  setTimeout(function() {
                    window.close();
                  }, 1000);
                </script>
              </body>
            </html>
          HTML
        else
          # Show confirmation message without auto-close
          "<html><body><h1>✅ Submitted!</h1><p>Data has been sent to the agent. You can close this window.</p></body></html>"
        end
      end

      # Event callback endpoint for on_change/on_blur handlers
      post '/event/:key' do
        begin
          key = params[:key].to_sym
          state = session[:streamlit_state] ||= {}
          streamlit_app = settings.streamlit_app
          adapter = settings.adapter
          is_agentic = settings.respond_to?(:result_container)

          streamlit_app.rebuild_with_state(state)
          sync_params_to_state(state, excluded_keys: [:key])
          handle_unchecked_checkboxes(state, streamlit_app.components)

          # Find the component and execute callbacks
          new_value = state[key]
          component = self.class.find_component_by_key(streamlit_app.components, key)
          if component
            component.execute_on_change(state, new_value) if component.respond_to?(:execute_on_change)
            component.execute_on_blur(state, new_value) if component.respond_to?(:execute_on_blur)
          end

          session[:streamlit_state] = session_safe_state(state)

          streamlit_app.rebuild_with_state(state)
          Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
        rescue => e
          render_error("/event/#{params[:key]}", e)
        end
      end

      # Form submission endpoint for deferred form blocks
      # Receives Rails-style nested params (form_name[field]) and updates state
      post '/form/:form_name' do
        begin
          form_name = params[:form_name].to_sym
          state = session[:streamlit_state] ||= {}
          streamlit_app = settings.streamlit_app
          adapter = settings.adapter
          is_agentic = settings.respond_to?(:result_container)

          # Parse Rails-style nested params: form_name[field] → { field: value }
          form_params = params[form_name.to_s] || {}
          form_values = {}
          form_params.each do |key, value|
            key_sym = key.to_sym
            # Convert checkbox values
            if value == "on" || value == "true"
              form_values[key_sym] = true
            elsif value == "false"
              form_values[key_sym] = false
            else
              form_values[key_sym] = value
            end
          end

          # Auto-update state with form values (the key behavior we designed)
          state[form_name] = form_values
          session[:streamlit_state] = session_safe_state(state)

          # Rebuild to find the form component
          streamlit_app.rebuild_with_state(state)

          # Find and execute submit block if defined
          form_component = self.class.find_form_recursive(streamlit_app.components, form_name)
          form_component&.execute_submit(state, form_values)

          # Re-render with updated state
          streamlit_app.rebuild_with_state(state)
          Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
        rescue => e
          render_error("/form/#{params[:form_name]}", e)
        end
      end

      # Toast dismiss endpoint (called when a toast is closed client-side)
      post '/toast/dismiss/:toast_id' do
        state = session[:streamlit_state] ||= {}
        toast_id = params[:toast_id]

        # Remove the toast from state
        if state[:_toasts].is_a?(Array)
          state[:_toasts].reject! { |t| t[:id] == toast_id }
        end

        session[:streamlit_state] = session_safe_state(state)

        # Return empty response (swap: none means no DOM update needed)
        status 204
        ""
      end

      # Theme switching endpoint (for runtime theme changes)
      post '/theme/:theme_name' do
        theme = params[:theme_name].to_sym

        # Accept built-in themes or custom registered themes
        if StreamWeaver.theme_exists?(theme)
          session[:theme_override] = theme
          status 200
          content_type 'text/plain'
          # Return the new body classes for Alpine.js to update
          "sw-theme-#{theme} sw-layout-#{settings.streamlit_app.layout}"
        else
          status 400
          content_type 'text/plain'
          "Invalid theme: #{theme}. Available themes: #{StreamWeaver.available_themes.join(', ')}"
        end
      end

      # Return the class itself (it's the Rack app)
      self
    end

    # Find a button recursively in the component tree
    #
    # @param components [Array] Array of components
    # @param button_id [String] Button ID to find
    # @return [Components::Button, nil] The button or nil
    def self.find_button_recursive(components, button_id)
      components.each do |component|
        return component if component.is_a?(Components::Button) && component.id == button_id

        if component.respond_to?(:children) && component.children
          found = find_button_recursive(component.children, button_id)
          return found if found
        end

        # Also search modal footer if present
        if component.is_a?(Components::Modal) && component.footer_component&.children
          found = find_button_recursive(component.footer_component.children, button_id)
          return found if found
        end
      end
      nil
    end

    # Find a form component recursively in the component tree
    #
    # @param components [Array] Array of components
    # @param form_name [Symbol] Form name to find
    # @return [Components::Form, nil] The form or nil
    def self.find_form_recursive(components, form_name)
      components.each do |component|
        return component if component.is_a?(Components::Form) && component.name == form_name

        if component.respond_to?(:children) && component.children
          found = find_form_recursive(component.children, form_name)
          return found if found
        end
      end
      nil
    end

    # Collect all input component keys recursively
    #
    # @param components [Array] Array of components
    # @return [Array<Symbol>] Array of state keys
    def self.collect_input_keys(components)
      keys = []
      components.each do |comp|
        keys << comp.key if comp.respond_to?(:key) && comp.key
        keys += collect_input_keys(comp.children) if comp.respond_to?(:children) && comp.children
      end
      keys
    end

    # Find a component by its state key
    #
    # @param components [Array] Array of components
    # @param key [Symbol] State key to find
    # @return [Components::Base, nil] The component or nil
    def self.find_component_by_key(components, key)
      components.each do |comp|
        return comp if comp.respond_to?(:key) && comp.key == key
        if comp.respond_to?(:children) && comp.children
          found = find_component_by_key(comp.children, key)
          return found if found
        end
      end
      nil
    end

    # Find an available port starting from the given port
    #
    # @param start_port [Integer] Starting port number (default 4567)
    # @return [Integer] Available port number
    def self.find_available_port(start_port = 4567)
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

    # Open browser to the given URL (cross-platform)
    #
    # @param url [String] The URL to open
    def self.open_browser(url)
      Thread.new do
        sleep 1  # Wait for server to start
        case RbConfig::CONFIG['host_os']
        when /darwin|mac os/
          system("open", url)
        when /linux|bsd/
          system("xdg-open", url)
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          system("start", url)
        end
      end
    end

    # Custom run! method with auto-browser opening (persistent server)
    #
    # @param options [Hash] Options
    # @option options [Integer] :port Port number (default: auto-detect)
    # @option options [String] :host Host to bind (default: '127.0.0.1')
    # @option options [Boolean] :open_browser Auto-open browser (default: true)
    def self.run!(options = {})
      port = options[:port] || find_available_port
      host = options[:host] || '127.0.0.1'
      auto_open = options.fetch(:open_browser, true)

      set :port, port
      set :bind, host
      set :server, :puma
      set :quiet, true if respond_to?(:quiet)

      url = "http://#{host == '0.0.0.0' ? 'localhost' : host}:#{port}"

      # Custom startup banner
      puts "\n"
      puts "╔═══════════════════════════════════════════════════════════╗"
      puts "║              StreamWeaver App Running                    ║"
      puts "╚═══════════════════════════════════════════════════════════╝"
      puts ""
      puts "  🌐  #{url}"
      puts "  📱  #{settings.streamlit_app.title}"
      puts ""
      puts "  Press Ctrl+C to stop"
      puts ""

      open_browser(url) if auto_open

      # Suppress Sinatra/Puma startup messages
      original_stdout = $stdout
      original_stderr = $stderr
      unless ENV['DEBUG']
        $stdout = StringIO.new
        $stderr = StringIO.new
      end

      # Call Sinatra's original run! with quiet mode
      trap('INT') do
        $stdout = original_stdout
        $stderr = original_stderr
        puts "\n\n👋 Shutting down StreamWeaver..."
        exit
      end

      begin
        super()
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end

    # Run once and return data (agentic mode)
    #
    # @param options [Hash] Options
    # @option options [Symbol] :output Output mode (:stdout or :file, default: :stdout)
    # @option options [String] :output_file File path to write JSON result
    # @option options [Integer] :timeout Timeout in seconds (default: 300)
    # @option options [Boolean] :auto_close_window Auto-close browser window after submit (default: false)
    # @return [Hash] The submitted state
    def self.run_once!(options = {})
      output_mode = options.fetch(:output, :stdout)
      output_file = options[:output_file]
      timeout = options.fetch(:timeout, 300)
      auto_close_window = options.fetch(:auto_close_window, false)

      # Container for result (shared between server and main thread)
      result_container = { result: nil, ready: false }
      set :result_container, result_container
      set :auto_close_window, auto_close_window

      # Find port and configure
      port = options[:port] || find_available_port
      host = options[:host] || '127.0.0.1'
      auto_open = options.fetch(:open_browser, true)

      set :port, port
      set :bind, host
      set :server, :puma
      set :quiet, true if respond_to?(:quiet)

      url = "http://#{host == '0.0.0.0' ? 'localhost' : host}:#{port}"

      # Startup banner
      puts "\n"
      puts "╔═══════════════════════════════════════════════════════════╗"
      puts "║         StreamWeaver App (Agentic Mode)                  ║"
      puts "╚═══════════════════════════════════════════════════════════╝"
      puts ""
      puts "  🌐  #{url}"
      puts "  📱  #{settings.streamlit_app.title}"
      puts "  ⏱️   Waiting for form submission (timeout: #{timeout}s)..."
      puts ""

      open_browser(url) if auto_open

      # Save original stdout/stderr before server thread
      original_stdout = $stdout
      original_stderr = $stderr

      # Setup interrupt handler for clean exit
      interrupted = false
      trap('INT') do
        interrupted = true
        puts "\n\n👋 Shutting down StreamWeaver (agentic mode)..."
      end

      # Start server in background thread
      server_container = { server: nil, error: nil, ready: false }

      # Enable thread exception reporting
      Thread.abort_on_exception = true if ENV['DEBUG']

      server_thread = Thread.new do
        begin
          puts "DEBUG: Starting server thread..." if ENV['DEBUG']

          # Don't suppress output - we need to see errors
          require 'puma'
          puts "DEBUG: Puma loaded" if ENV['DEBUG']

          # Create Puma server directly with thread pool configuration
          # Puma 6.x+ requires threads to be configured in constructor
          puts "DEBUG: Creating Puma::Server..." if ENV['DEBUG']
          puma_server = Puma::Server.new(self, nil, {min_threads: 0, max_threads: 4})
          puts "DEBUG: Puma::Server created" if ENV['DEBUG']

          puma_server.add_tcp_listener(host, port)
          puts "DEBUG: TCP listener added on #{host}:#{port}" if ENV['DEBUG']

          # Store server reference
          server_container[:server] = puma_server
          server_container[:ready] = true
          Thread.current[:server_started] = true
          puts "DEBUG: Server marked as ready" if ENV['DEBUG']

          # Suppress Puma output only after initialization
          unless ENV['DEBUG']
            $stdout = StringIO.new
            $stderr = StringIO.new
          end

          puts "DEBUG: Starting puma_server.run..." if ENV['DEBUG']
          # Run server - this spawns threads but doesn't block
          puma_server.run
          puts "DEBUG: puma_server.run returned, server running: #{puma_server.running}" if ENV['DEBUG']

          # Keep thread alive while server is running
          while puma_server.running
            sleep 0.1
          end
          puts "DEBUG: Server stopped running" if ENV['DEBUG']
        rescue => e
          # Store error for display in main thread
          server_container[:error] = e
          puts "Server thread error: #{e.class}: #{e.message}"
          puts e.backtrace.first(10).join("\n")
        end
      end

      # Wait for server to start and verify it's responding
      sleep 1

      # Check if server thread crashed
      unless server_thread.alive?
        $stdout = original_stdout
        $stderr = original_stderr
        if server_container[:error]
          puts "\n❌ Server failed to start:"
          puts "   #{server_container[:error].class}: #{server_container[:error].message}"
          puts "\n   Backtrace:"
          server_container[:error].backtrace.first(10).each do |line|
            puts "     #{line}"
          end
        else
          puts "\n❌ Server failed to start. Check error messages above."
        end
        exit(1)
      end

      # Try to ping the server to make sure it's responding
      begin
        require 'net/http'
        uri = URI(url)
        response = Net::HTTP.get_response(uri)
        unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
          puts "\n⚠️  Server started but returned unexpected response: #{response.code}"
        end
      rescue => e
        $stdout = original_stdout
        $stderr = original_stderr
        puts "\n❌ Server not responding: #{e.message}"
        puts "   Make sure port #{port} is available and try again."
        if server_container[:server]
          server_container[:server].stop(true) rescue nil
        end
        server_thread.kill if server_thread.alive?
        exit(1)
      end

      # Wait for result, timeout, or interrupt
      start_time = Time.now
      until result_container[:ready] || (Time.now - start_time > timeout) || interrupted
        sleep 0.1
      end

      # Shutdown server gracefully
      if server_container[:server]
        begin
          server_container[:server].stop(true) # true = graceful shutdown
        rescue => e
          # Ignore shutdown errors
        end
      end
      server_thread.kill if server_thread.alive?

      # If interrupted, exit immediately
      if interrupted
        $stdout = original_stdout
        $stderr = original_stderr
        exit(0)
      end

      result = result_container[:result] || {}

      # Ensure stdout is restored before outputting
      $stdout = original_stdout
      $stderr = original_stderr

      # Output result
      if output_mode == :stdout
        puts JSON.generate(result)
      end

      if output_file
        File.write(output_file, JSON.generate(result))
      end

      result
    end
  end
end
