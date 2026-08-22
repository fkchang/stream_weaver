# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/streaming'
require 'stringio'
require 'socket'
require 'json'
require 'fileutils'
require 'digest'
require_relative 'session_store'
require_relative 'dev_fallback_overlay'

module StreamWeaver
  # Generated Sinatra application for serving the StreamWeaver app
  class SinatraApp < Sinatra::Base
    # ── Session store configuration ──────────────────────────────────────────
    # SW_SESSION_STORE=file (default) — one file per session, no 4KB limit
    # SW_SESSION_STORE=cookie         — cookie-based, 4KB limit, warns when near limit
    SW_SESSION_STORE_NAME = (ENV['SW_SESSION_STORE'] || 'file').freeze
    SW_SESSION_FILTER     = StreamWeaver::SessionStore.build(SW_SESSION_STORE_NAME)

    SW_SESSION_SECRET = ENV.fetch('SESSION_SECRET') {
      if ENV['RACK_ENV'] == 'production'
        raise "SESSION_SECRET environment variable required in production"
      else
        'stream-weaver-development-secret-key-change-in-production-environments-minimum-64-characters'
      end
    }

    case SW_SESSION_STORE_NAME
    when 'file'
      SW_SESSION_DIR = ENV.fetch('SW_SESSION_DIR') {
        ::File.join(Dir.home, '.config', 'stream_weaver', 'sessions')
      }
      FileUtils.mkdir_p(SW_SESSION_DIR)
      # Clean up session files older than 7 days on startup
      cutoff = Time.now - (7 * 86_400)
      Dir.glob("#{SW_SESSION_DIR}/session_*").each { |f| ::File.delete(f) if ::File.mtime(f) < cutoff rescue nil }
      use StreamWeaver::FileSession, path: SW_SESSION_DIR, expire_after: 86_400, same_site: :lax
      $stderr.puts "[SW] Sessions: file (#{SW_SESSION_DIR})"
    else
      enable :sessions
      set :session_secret, SW_SESSION_SECRET
      set :sessions, same_site: :lax
      $stderr.puts "[SW] Sessions: cookie (4KB limit — set SW_SESSION_STORE=file to remove limit)"
    end

    # Disable protection in test mode to allow Rack::Test requests
    set :protection, false if ENV['RACK_ENV'] == 'test'

    # Disable Sinatra's startup messages for cleaner output
    set :logging, false
    set :show_exceptions, :after_handler
    set :dump_errors, true
    set :raise_errors, false
    # Allow any Host header — StreamWeaver is a local dev tool, and reverse
    # proxies like puma-dev send .test domains to loopback
    set :host_authorization, { permitted_hosts: [] }

    # Debug middleware - logs before Sinatra/session processing
    if ENV['SW_DEBUG']
      use(Class.new {
        def initialize(app) @app = app end
        def call(env)
          $stderr.puts "[SW:rack] >>> #{env['REQUEST_METHOD']} #{env['PATH_INFO']} (thread: #{Thread.current.object_id})"
          $stderr.puts "[SW:rack]     cookie size: #{env['HTTP_COOKIE']&.bytesize || 0}B"
          $stderr.flush
          status, headers, body = @app.call(env)
          $stderr.puts "[SW:rack] <<< #{env['REQUEST_METHOD']} #{env['PATH_INFO']} -> #{status}"
          $stderr.flush
          [status, headers, body]
        end
      })
    end


    # Create a Sinatra app from a StreamWeaver::App instance
    #
    # @param streamlit_app [StreamWeaver::App] The app definition
    # @return [Class] Sinatra::Base subclass
    def self.create(streamlit_app)
      helpers Sinatra::Streaming

      # Store the streamlit app for access in routes
      set :streamlit_app, streamlit_app

      # Create adapter instance (Alpine.js by default)
      set :adapter, Adapter::AlpineJS.new

      # Initialize streamer for SSE push (always available for POST /stream/push)
      set :streamer, Streamer.new

      # Helper methods for state synchronization
      helpers do
        # dev-loud-failure-overlay: follows this file's existing RACK_ENV
        # convention (line ~22's `== 'production'`, line ~48's `== 'test'`)
        # rather than Sinatra's settings.environment/development? -- that
        # settings value is fixed once at class-load time (spec_helper sets
        # RACK_ENV=test before requiring stream_weaver), so it can't be
        # toggled per-request/per-example the way a plain ENV read can.
        # Anything that isn't explicitly production or test counts as dev.
        def sw_dev_mode?
          !%w[production test].include?(ENV['RACK_ENV'])
        end

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
          excluded = App::ROUTE_OWNED_PARAMS + excluded_keys.map(&:to_s)

          params.each do |key, value|
            next if excluded.include?(key)
            state[key.to_sym] = coerce_param_value(value, state[key.to_sym])
          end
        end

        # Filter state before saving to session.
        # Cookie store enforces 4KB limit and warns; file store passes through unchanged.
        def session_safe_state(state)
          app_transient = settings.streamlit_app.transient_keys
          scope_names = settings.streamlit_app.scope_names
          SW_SESSION_FILTER.filter(state, app_transient: app_transient, scope_names: scope_names)
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

        # Inject deck state into the render state so adapter can read it.
        # Called before rebuild_with_state for routes that render content.
        def inject_deck_state!(state)
          if session[:deck_session_id]
            state[:_deck_state] = Components::Deck::DeckState.new(session[:deck_session_id])
          end
        end

        # A full GET's URL -- never the session -- decides a `url: true` tabs
        # group's index (see App#tab_index_source). Renders answering a POST leave
        # those groups on the state they were given.
        def render_app(state, is_htmx: false)
          adapter = settings.adapter
          streamlit_app = settings.streamlit_app
          is_agentic = settings.respond_to?(:result_container)
          session_theme = session[:theme_override]
          streamlit_app.with_render_lock do
            inject_deck_state!(state)
            generation = session[:sw_action_generation] ||= SecureRandom.hex(12)
            streamlit_app.rebuild_with_state(state, generation: generation,
              state_version: (session[:sw_state_version] || 0),
              url_params: (params if request.get?))
            session[:sw_action_manifest] = streamlit_app.render_state.action_tokens.to_a

            # Scrub transient keys that leaked into the session
            unless streamlit_app.transient_keys.empty?
              state.reject! { |k, _| streamlit_app.transient_keys.include?(k) }
            end
            session[:streamlit_state] = session_safe_state(state)

            if is_htmx
              Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
            else
              Views::AppView.new(streamlit_app, state, adapter, is_agentic, session_theme: session_theme).call
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

      # Request logging when DEBUG is set
      before do
        if ENV['SW_DEBUG']
          state = session[:streamlit_state]
          state_size = state ? state.to_s.bytesize : 0
          cookie_size = request.env['HTTP_COOKIE']&.bytesize || 0
          $stderr.puts "[SW] #{request.request_method} #{request.path_info} | cookie=#{cookie_size}B state=#{state_size}B keys=#{state&.keys&.join(',')}"
        end
      end

      after do
        if ENV['SW_DEBUG']
          state = session[:streamlit_state]
          state_size = state ? state.to_s.bytesize : 0
          $stderr.puts "[SW] #{request.request_method} #{request.path_info} -> #{response.status} | state_after=#{state_size}B"
        end
      end

      # Suppress browser's automatic /favicon.ico request (the real favicon
      # is served via <link rel="icon"> in the HTML head)
      get '/favicon.ico' do
        status 204
        ""
      end

      # Serve local files registered via css_path/js_path class macros, or via
      # App#local_asset / auto-detected stylesheets: entries (stream_weaver-1lo).
      # Only files whose absolute path was explicitly registered are served
      # (no traversal -- the key is a hash of that path, never derived from
      # the request), and registration itself already validated the path was
      # under the app's script dir / assets_dirs: (see App#local_asset).
      get '/sw-asset/:key/:filename' do
        abs_path = StreamWeaver::ComponentAssets.resolve_file(params[:key])
        halt 404 unless abs_path && File.exist?(abs_path)
        halt 404 unless File.basename(abs_path) == params[:filename]
        etag Digest::MD5.hexdigest("#{File.mtime(abs_path).to_i}-#{File.size(abs_path)}")
        content_type StreamWeaver::App::LOCAL_ASSET_MIME_TYPES[File.extname(abs_path).delete('.').downcase] || "application/octet-stream"
        File.binread(abs_path)
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
        elsif self.class.reset_state_pending?
          session.clear
          state = {}
          session[:streamlit_state] = state
        else
          state = session[:streamlit_state] ||= {}
        end

        # Seed state from URL routing (e.g., `page :home, '/'` registers a parser for '/')
        if settings.streamlit_app.routable?
          if (route_state = settings.streamlit_app.state_for_path('/'))
            route_state.each { |k, v| state[k] = v }
          end
        end

        sync_params_to_state(state)
        session[:streamlit_state] = session_safe_state(state)

        # Prevent browser caching for all forms to ensure fresh rendering
        cache_control :no_cache, :no_store, :must_revalidate, max_age: 0
        headers 'Pragma' => 'no-cache'

        render_app(state)
      end

      # Update state from form inputs
      post '/update' do
        begin
          state = session[:streamlit_state] ||= {}
          InteractionRunner.new(
            app: settings.streamlit_app, state: state, params: params,
            interaction: :update, adapter: settings.adapter,
            agentic: settings.respond_to?(:result_container),
            prepare_state: method(:inject_deck_state!),
            persist: ->(value) { session[:streamlit_state] = session_safe_state(value) },
            response_headers: ->(values) { headers values },
            state_version: (session[:sw_state_version] || 0),
            persist_state_version: ->(version) { session[:sw_state_version] = version }
          ).call
        rescue => e
          render_error("/update", e)
        end
      end

      # Button actions
      post '/action/:button_id' do
        begin
          state = session[:streamlit_state] ||= {}
          InteractionRunner.new(
            app: settings.streamlit_app, state: state, params: params,
            interaction: :action, target: params[:button_id], adapter: settings.adapter,
            agentic: settings.respond_to?(:result_container),
            prepare_state: method(:inject_deck_state!),
            persist: ->(value) { session[:streamlit_state] = session_safe_state(value) },
            action_manifest: Set.new(session[:sw_action_manifest] || []),
            generation: (session[:sw_action_generation] ||= SecureRandom.hex(12)),
            persist_manifest: ->(tokens) { session[:sw_action_manifest] = tokens.to_a },
            result_container: (settings.result_container if settings.respond_to?(:result_container)),
            auto_close: settings.respond_to?(:auto_close_window) && settings.auto_close_window,
            response_headers: ->(values) { headers values },
            state_version: (session[:sw_state_version] || 0),
            persist_state_version: ->(version) { session[:sw_state_version] = version }
          ).call
        rescue StaleActionDefinition => e
          status 409
          headers 'HX-Retarget' => '#app-container'
          content = render_app(state, is_htmx: true)
          # dev-loud-failure-overlay: production keeps the silent self-heal
          # above completely unchanged; dev additionally prepends a visible,
          # dismissible overlay naming the stale target + likely cause
          # (StreamWeaver's analog of Hotwire's "content missing"). See
          # docs/for_llms.md, "Dev loud, prod self-heal".
          if sw_dev_mode?
            StreamWeaver::DevFallbackOverlay.render(action: e.action, fragment: e.fragment, cause: e.cause) + content
          else
            content
          end
        rescue => e
          render_error("/action/#{params[:button_id]}", e)
        end
      end

      # Submit endpoint for agentic mode
      post '/submit' do
        state = session[:streamlit_state] ||= {}
        streamlit_app = settings.streamlit_app

        input_keys = streamlit_app.with_render_lock do
          streamlit_app.rebuild_with_state(state)
          sync_params_to_state(state)
          handle_unchecked_checkboxes(state, streamlit_app.components)
          session[:streamlit_state] = session_safe_state(state)

          # Collect input keys for filtering the result
          self.class.collect_input_keys(streamlit_app.components)
        end

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
          state = session[:streamlit_state] ||= {}
          InteractionRunner.new(
            app: settings.streamlit_app, state: state, params: params,
            interaction: :event, target: params[:key], adapter: settings.adapter,
            agentic: settings.respond_to?(:result_container),
            persist: ->(value) { session[:streamlit_state] = session_safe_state(value) },
            response_headers: ->(values) { headers values },
            state_version: (session[:sw_state_version] || 0),
            persist_state_version: ->(version) { session[:sw_state_version] = version }
          ).call
        rescue => e
          render_error("/event/#{params[:key]}", e)
        end
      end

      # Form submission endpoint for deferred form blocks
      # Receives Rails-style nested params (form_name[field]) and updates state
      post '/form/:form_name' do
        begin
          state = session[:streamlit_state] ||= {}
          InteractionRunner.new(
            app: settings.streamlit_app, state: state, params: params,
            interaction: :form, target: params[:form_name], adapter: settings.adapter,
            agentic: settings.respond_to?(:result_container),
            persist: ->(value) { session[:streamlit_state] = session_safe_state(value) },
            response_headers: ->(values) { headers values },
            state_version: (session[:sw_state_version] || 0),
            persist_state_version: ->(version) { session[:sw_state_version] = version }
          ).call
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

      # =========================================
      # Deck State endpoints (T8)
      # =========================================

      # Select an option for a slide (radio semantics)
      post '/deck/select' do
        begin
          payload = if request.content_type&.include?('application/json')
            JSON.parse(request.body.read, symbolize_names: true)
          else
            { slide_id: params[:slide_id], option_label: params[:option_label] }
          end

          slide_id = payload[:slide_id]
          option_label = payload[:option_label]

          unless slide_id && option_label
            halt 400, { 'Content-Type' => 'application/json' },
                 JSON.generate(error: "Missing slide_id or option_label")
          end

          # Get or create deck session
          session[:deck_session_id] ||= Components::Deck::DeckState.generate_session_id
          deck_state = Components::Deck::DeckState.new(session[:deck_session_id])
          deck_state.select(slide_id, option_label)

          content_type :json
          JSON.generate(success: true, slide_id: slide_id, option_label: option_label)
        rescue => e
          render_error("/deck/select", e)
        end
      end

      # Save a note for an option
      post '/deck/note' do
        begin
          payload = if request.content_type&.include?('application/json')
            JSON.parse(request.body.read, symbolize_names: true)
          else
            { slide_id: params[:slide_id], option_label: params[:option_label], text: params[:text] }
          end

          slide_id = payload[:slide_id]
          option_label = payload[:option_label]
          text = payload[:text] || ""

          unless slide_id && option_label
            halt 400, { 'Content-Type' => 'application/json' },
                 JSON.generate(error: "Missing slide_id or option_label")
          end

          session[:deck_session_id] ||= Components::Deck::DeckState.generate_session_id
          deck_state = Components::Deck::DeckState.new(session[:deck_session_id])
          deck_state.set_note(slide_id, option_label, text)

          content_type :json
          JSON.generate(success: true, slide_id: slide_id, option_label: option_label)
        rescue => e
          render_error("/deck/note", e)
        end
      end

      # Read the full deck state (for debugging / agent access)
      get '/deck/state' do
        session[:deck_session_id] ||= Components::Deck::DeckState.generate_session_id
        deck_state = Components::Deck::DeckState.new(session[:deck_session_id])

        content_type :json
        JSON.generate(deck_state.to_h)
      end

      # Re-render app content with current deck state.
      # Accepts ?slide=N to remember which slide the user is on.
      get '/deck/refresh' do
        state = session[:streamlit_state] ||= {}
        state[:_deck_current_slide] = params[:slide].to_i if params[:slide]
        inject_deck_state!(state)
        streamlit_app = settings.streamlit_app
        adapter = settings.adapter
        is_agentic = settings.respond_to?(:result_container)
        streamlit_app.with_render_lock do
          streamlit_app.rebuild_with_state(state)
          Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
        end
      end

      # Save final notes on the summary slide (T9)
      post '/deck/final_notes' do
        begin
          payload = if request.content_type&.include?('application/json')
            JSON.parse(request.body.read, symbolize_names: true)
          else
            { text: params[:text] }
          end

          session[:deck_session_id] ||= Components::Deck::DeckState.generate_session_id
          deck_state = Components::Deck::DeckState.new(session[:deck_session_id])
          deck_state.set_final_notes(payload[:text] || "")

          content_type :json
          JSON.generate(success: true)
        rescue => e
          render_error("/deck/final_notes", e)
        end
      end

      # Submit the deck -- marks as submitted and sets _result for run_once! (T9)
      post '/deck/submit' do
        begin
          session[:deck_session_id] ||= Components::Deck::DeckState.generate_session_id
          deck_state = Components::Deck::DeckState.new(session[:deck_session_id])
          deck_state.submit!

          state = session[:streamlit_state] ||= {}
          state[:_result] = {
            deck_selections: deck_state.selections,
            deck_notes: deck_state.notes,
            deck_final_notes: deck_state.final_notes
          }
          session[:streamlit_state] = session_safe_state(state)

          # Signal completion for agentic mode (run_once!)
          is_agentic = settings.respond_to?(:result_container)
          if is_agentic && settings.respond_to?(:result_container)
            settings.result_container[:result] = state[:_result]
            settings.result_container[:ready] = true
          end

          content_type :json
          JSON.generate(success: true, submitted: true)
        rescue => e
          render_error("/deck/submit", e)
        end
      end

      # =========================================
      # Model Selector endpoint (T14)
      # =========================================

      # Set the selected AI model for generate-more.
      post '/deck/set_model' do
        begin
          payload = if request.content_type&.include?('application/json')
            JSON.parse(request.body.read, symbolize_names: true)
          else
            { model_id: params[:model_id] }
          end

          model_id = payload[:model_id]
          halt 400, JSON.generate(error: "model_id required") unless model_id

          deck_state = get_or_create_deck_state
          deck_state.set_model(model_id.to_s)

          content_type :json
          JSON.generate(success: true, model_id: model_id.to_s)
        rescue => e
          render_error("/deck/set_model", e)
        end
      end

      # =========================================
      # Generate-More endpoints (T10)
      # =========================================

      # User requests more options for a slide.
      # Queues a generate request and transitions to :generating.
      post '/deck/generate' do
        begin
          payload = if request.content_type&.include?('application/json')
            JSON.parse(request.body.read, symbolize_names: true)
          else
            { slide_id: params[:slide_id], count: params[:count], prompt: params[:prompt] }
          end

          slide_id = payload[:slide_id]
          count = (payload[:count] || 2).to_i
          prompt = payload[:prompt]

          unless slide_id
            halt 400, { 'Content-Type' => 'application/json' },
                 JSON.generate(error: "Missing slide_id")
          end

          count = [[count, 1].max, 5].min # Clamp 1-5

          session[:deck_session_id] ||= Components::Deck::DeckState.generate_session_id
          deck_state = Components::Deck::DeckState.new(session[:deck_session_id])
          request_id = deck_state.start_generate(slide_id, count, prompt: prompt)

          # Trigger SSE re-render so skeletons appear
          if settings.respond_to?(:streamer) && settings.streamer
            state = session[:streamlit_state] ||= {}
            inject_deck_state!(state)
            streamlit_app = settings.streamlit_app
            adapter = settings.adapter
            is_agentic = settings.respond_to?(:result_container)
            html = streamlit_app.with_render_lock do
              streamlit_app.rebuild_with_state(state)
              Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
            end
            settings.streamer.replace("#main", html)
          end

          status 202
          content_type :json
          JSON.generate(
            status: "generating",
            request_id: request_id,
            slide_id: slide_id,
            count: count
          )
        rescue => e
          render_error("/deck/generate", e)
        end
      end

      # Agent polls for pending generate requests.
      # Returns and removes all queued requests for the given session.
      get '/deck/pending' do
        begin
          session_id = params[:session_id]
          unless session_id
            halt 400, { 'Content-Type' => 'application/json' },
                 JSON.generate(error: "Missing session_id")
          end

          deck_state = Components::Deck::DeckState.new(session_id)
          requests = deck_state.take_pending_requests!

          content_type :json
          JSON.generate(requests: requests)
        rescue => e
          render_error("/deck/pending", e)
        end
      end

      # Agent pushes a generated option into state.
      # Increments received_count, transitions to :idle when all received.
      # Triggers SSE re-render.
      post '/deck/add_option' do
        begin
          payload = if request.content_type&.include?('application/json')
            JSON.parse(request.body.read, symbolize_names: true)
          else
            halt 400, { 'Content-Type' => 'application/json' },
                 JSON.generate(error: "Request body must be JSON")
          end

          session_id = payload[:session_id]
          slide_id = payload[:slide_id]
          request_id = payload[:request_id]
          option_data = payload[:option] || {}

          unless session_id && slide_id && request_id
            halt 400, { 'Content-Type' => 'application/json' },
                 JSON.generate(error: "Missing session_id, slide_id, or request_id")
          end

          deck_state = Components::Deck::DeckState.new(session_id)

          # Convert symbol keys to strings for storage
          option_hash = {}
          option_data.each { |k, v| option_hash[k.to_s] = v }

          gen_state = deck_state.add_generated_option(slide_id, option_hash, request_id: request_id)

          # Trigger SSE re-render so new option appears
          if settings.respond_to?(:streamer) && settings.streamer
            # We can't easily re-render for a different session from the agent endpoint.
            # Instead, use replace on #main to trigger a page refresh via SSE.
            # The connected browser will pick up new state on next render.
            # Push a refresh-trigger event.
            settings.streamer.replace(
              "#sw-generate-area",
              "<div id='sw-generate-area' data-refresh='#{Time.now.to_f}'></div>"
            )
          end

          content_type :json
          JSON.generate(
            success: true,
            slide_id: slide_id,
            received_count: gen_state["received_count"],
            status: gen_state["status"]
          )
        rescue => e
          render_error("/deck/add_option", e)
        end
      end

      # User cancels a pending generation.
      post '/deck/cancel_generate' do
        begin
          session[:deck_session_id] ||= Components::Deck::DeckState.generate_session_id
          deck_state = Components::Deck::DeckState.new(session[:deck_session_id])
          deck_state.cancel_generate
          # Immediately transition cancelled -> idle
          deck_state.reset_generate

          # Trigger SSE re-render
          if settings.respond_to?(:streamer) && settings.streamer
            state = session[:streamlit_state] ||= {}
            inject_deck_state!(state)
            streamlit_app = settings.streamlit_app
            adapter = settings.adapter
            is_agentic = settings.respond_to?(:result_container)
            html = streamlit_app.with_render_lock do
              streamlit_app.rebuild_with_state(state)
              Views::AppContentView.new(streamlit_app, state, adapter, is_agentic).call
            end
            settings.streamer.replace("#main", html)
          end

          content_type :json
          JSON.generate(success: true, status: "idle")
        rescue => e
          render_error("/deck/cancel_generate", e)
        end
      end

      # SSE endpoint - browser subscribes for real-time push updates.
      # Uses Sinatra stream (without :keep_open) for Puma compatibility.
      # The block keeps the connection alive with a heartbeat loop;
      # the Streamer broadcasts to the `out` object from other threads.
      get '/stream' do
        content_type 'text/event-stream'
        cache_control :no_cache
        headers 'Connection' => 'keep-alive',
                'X-Accel-Buffering' => 'no'

        stream do |out|
          streamer = settings.streamer
          streamer.add_connection(out)
          $stderr.puts "[SW] SSE connected (#{streamer.connection_count} total)" if ENV['SW_DEBUG']
          out << "data: #{JSON.generate(type: "connected")}\n\n"
          # Keep connection alive - Puma needs the block to stay open.
          # Check shutdown flag so Ctrl+C can terminate cleanly.
          until streamer.shutting_down?
            sleep 1
            out << ": heartbeat\n\n"
          end
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          # Client disconnected
          $stderr.puts "[SW] SSE disconnected (client gone)" if ENV['SW_DEBUG']
        ensure
          streamer.remove_connection(out)
          $stderr.puts "[SW] SSE removed (#{streamer.connection_count} remaining)" if ENV['SW_DEBUG']
        end
      end

      # Push endpoint - any external process can POST targeted DOM updates
      post '/stream/push' do
        payload = if request.content_type&.include?('application/json')
          JSON.parse(request.body.read, symbolize_names: true)
        else
          params
        end

        target = payload[:target] || '#main'
        action = (payload[:action] || 'replace').to_sym
        html   = payload[:html] || payload[:content] || ''

        unless Streamer::ACTIONS.include?(action)
          halt 400, { 'Content-Type' => 'application/json' },
               JSON.generate(error: "Invalid action: #{action}")
        end

        settings.streamer.public_send(action, target, html)
        content_type :json
        JSON.generate(success: true, target: target, action: action)
      end

      # ── StreamWeaver Debug Routes (/sw/*) ─────────────────────────────────
      # /sw/session          — dump current session state as JSON
      # /sw/session/size     — per-key byte breakdown + overflow flag
      # /sw/reset            — clear session and redirect to /
      # /sw/sessions/cleanup — delete file sessions older than 7 days

      get '/sw/session' do
        content_type :json
        state = session[:streamlit_state] || {}
        JSON.pretty_generate(state.transform_keys(&:to_s))
      end

      get '/sw/session/size' do
        content_type :json
        state = session[:streamlit_state] || {}
        serialized = JSON.dump(state)
        by_key = state.map { |k, v| { key: k.to_s, bytes: JSON.dump(v).bytesize } }
                      .sort_by { |x| -x[:bytes] }
        result = {
          store:       SW_SESSION_STORE_NAME,
          total_bytes: serialized.bytesize,
          keys:        by_key
        }
        if SW_SESSION_STORE_NAME == 'cookie'
          result[:limit_bytes] = 4096
          result[:over_limit]  = serialized.bytesize > 4096
        end
        JSON.pretty_generate(result)
      end

      get '/sw/reset' do
        session.clear
        redirect '/'
      end

      get '/sw/sessions/cleanup' do
        content_type :json
        unless SW_SESSION_STORE_NAME == 'file'
          halt 400, JSON.generate({ error: 'cleanup only applies to file session store' })
        end
        dir = defined?(SW_SESSION_DIR) ? SW_SESSION_DIR : ''
        unless ::File.directory?(dir)
          halt 400, JSON.generate({ error: "session dir not found: #{dir}" })
        end
        cutoff  = Time.now - (7 * 86_400)
        deleted = Dir.glob("#{dir}/session_*").count do |f|
          ::File.mtime(f) < cutoff && ::File.delete(f) rescue false
        end
        remaining = Dir.glob("#{dir}/session_*").count
        JSON.generate({ deleted: deleted, remaining: remaining, dir: dir })
      end

      # =========================================
      # Custom user-defined HTTP endpoints (App#endpoint DSL)
      # =========================================
      # These are defined AFTER every StreamWeaver-internal route above, so on a path
      # collision the internal route always wins (Sinatra dispatches to the first route
      # that matches, and `endpoint` warns at registration time about known collisions).
      # GET custom endpoints are checked inside the '/*' catch-all below (Sinatra only
      # dispatches one GET '/*' route, which URL-routing's fallback also needs); the other
      # verbs get their own catch-all here since no other route claims them.
      %i[post put patch delete].each do |verb|
        send(verb, '/*') do
          streamlit_app = settings.streamlit_app
          path = "/#{params['splat'].first}"
          ep = streamlit_app.find_endpoint(verb, path)
          pass unless ep
          status, headers, body = SinatraApp.normalize_endpoint_result(ep[:block].call(request))
          halt status, headers, body
        end
      end

      # URL routing: catch-all GET for deep-linked paths
      get '/*' do
        streamlit_app = settings.streamlit_app
        path = "/#{params['splat'].first}"

        if (ep = streamlit_app.find_endpoint(:get, path))
          status, headers, body = SinatraApp.normalize_endpoint_result(ep[:block].call(request))
          halt status, headers, body
        end

        pass unless streamlit_app.routable?

        route_state = streamlit_app.state_for_path(path)
        pass unless route_state

        state = session[:streamlit_state] ||= {}
        route_state.each { |k, v| state[k] = v }
        sync_params_to_state(state)
        session[:streamlit_state] = session_safe_state(state)

        cache_control :no_cache, :no_store, :must_revalidate, max_age: 0
        headers 'Pragma' => 'no-cache'

        render_app(state, is_htmx: request.env.key?('HTTP_HX_REQUEST'))
      end

      # URL routing: push URL on POST responses when route key changes
      after do
        next unless request.post? && settings.streamlit_app.routable?
        state = session[:streamlit_state] || {}
        new_path = settings.streamlit_app.path_for_state(state)
        headers['HX-Push-Url'] = new_path if new_path
      end

      # Return the class itself (it's the Rack app)
      self
    end

    # Convert an App#endpoint block's return value into a Rack triplet.
    # Shared by SinatraApp (standalone mode) and Service (multi-app mode).
    #
    # @param result [Object] whatever the endpoint block returned
    # @return [Array(Integer, Hash, Array<String>)] a Rack-compatible [status, headers, body]
    def self.normalize_endpoint_result(result)
      case result
      when Array
        result
      when Hash
        [200, { 'Content-Type' => 'application/json' }, [JSON.generate(result)]]
      when String
        [200, { 'Content-Type' => 'text/html' }, [result]]
      else
        [200, { 'Content-Type' => 'text/plain' }, [result.to_s]]
      end
    end

    # Find a button (or menu item -- same click-dispatch contract: #id + #execute)
    # recursively in the component tree
    #
    # @param components [Array] Array of components
    # @param button_id [String] Button ID to find
    # @return [Components::Button, Components::MenuItem, nil] The button/menu item or nil
    def self.find_button_recursive(components, button_id)
      components.each do |component|
        if (component.is_a?(Components::Button) || component.is_a?(Components::MenuItem)) &&
           component.id == button_id
          return component
        end

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

    # Resolve host and port from options, env vars, or defaults
    def self.resolve_host_and_port(options)
      port = options[:port] || ENV['STREAMWEAVER_PORT']&.to_i || ENV['PORT']&.to_i || find_available_port
      host = options[:host] || ENV['STREAMWEAVER_HOST'] || '127.0.0.1'
      [host, port]
    end

    # Configure Sinatra server settings for host, port, and host authorization
    def self.configure_server!(host, port)
      set :port, port
      set :bind, host
      set :server, :puma
      set :quiet, true if respond_to?(:quiet)
      # host_authorization is set at class level (permits all hosts)
    end

    def self.loopback_host?(host)
      %w[127.0.0.1 localhost ::1].include?(host)
    end

    # One-shot state reset: returns true once, then false thereafter
    def self.reset_state_pending?
      return false unless @reset_state_pending
      @reset_state_pending = false
      true
    end

    def self.display_url(host, port)
      display_host = (host == '0.0.0.0' || host == '::') ? 'localhost' : host
      "http://#{display_host}:#{port}"
    end

    # Start the internal stream thread if the app has a stream block.
    # Start timer thread if the app has periodic timers.
    # Assumes rebuild_with_state has already been called to evaluate the DSL.
    def self.start_stream_thread
      stream_block = settings.streamlit_app.stream_block
      timers = settings.streamlit_app.timers

      # Capture real stderr before it gets suppressed
      real_stderr = $stderr

      if stream_block
        Thread.new do
          # Wait for at least one SSE subscriber before pushing
          sleep 0.1 until settings.streamer.connection_count > 0

          retries = 0
          begin
            stream_block.call(settings.streamer)
          rescue => e
            retries += 1
            real_stderr.puts "[StreamWeaver] Stream thread error (attempt #{retries}): #{e.class}: #{e.message}"
            real_stderr.puts e.backtrace.first(5).join("\n")
            sleep [2 ** retries, 30].min
            retry
          end
        end
      end

      if timers.any?
        Thread.new do
          # Wait for at least one SSE subscriber before firing timers
          sleep 0.1 until settings.streamer.connection_count > 0

          loop do
            now = Time.now.to_f
            timers.each do |timer|
              next if timer[:last_run] && (now - timer[:last_run]) < timer[:interval]
              timer[:last_run] = now
              begin
                timer[:block].call(settings.streamer)
              rescue => e
                real_stderr.puts "[StreamWeaver] Timer error: #{e.class}: #{e.message}"
                real_stderr.puts e.backtrace.first(5).join("\n")
              end
            end
            sleep 1
          end
        end
      end
    end

    # Custom run! method with auto-browser opening (persistent server)
    #
    # @param options [Hash] Options
    # @option options [Integer] :port Port number (default: auto-detect, or STREAMWEAVER_PORT env var)
    # @option options [String] :host Host to bind (default: '127.0.0.1', or STREAMWEAVER_HOST env var)
    # @option options [Boolean] :open_browser Auto-open browser (default: true, but false when PORT env var is set)
    def self.run!(options = {})
      if StreamWeaver.service_loading
        warn "StreamWeaver: skipping run! — this file is being loaded into a running " \
             "service (streamweaver serve), which serves it directly; starting a second " \
             "server here would take the service down."
        return self
      end

      host, port = resolve_host_and_port(options)
      auto_open = options.fetch(:open_browser, !ENV['PORT'] && !ENV['SW_NO_OPEN'])
      @reset_state_pending = ARGV.delete('--reset') ? true : false

      configure_server!(host, port)
      # Force-kill after 1s on shutdown - SSE connections never complete gracefully
      # SSE connections hold threads indefinitely, so we need a generous pool
      set :server_settings, { force_shutdown_after: 1, Threads: '0:16' }

      url = display_url(host, port)

      # Evaluate the DSL block to detect stream configuration
      settings.streamlit_app.rebuild_with_state({})

      # Portfile: write so feed scripts can discover this app by name
      Portfile.clean_stale!
      Portfile.write(settings.streamlit_app.title, url: url, pid: Process.pid)
      at_exit { Portfile.delete(settings.streamlit_app.title) }

      # Custom startup banner
      sanitized = Portfile.sanitize(settings.streamlit_app.title)
      puts "\n"
      puts "╔═══════════════════════════════════════════════════════════╗"
      puts "║              StreamWeaver App Running                    ║"
      puts "╚═══════════════════════════════════════════════════════════╝"
      puts ""
      puts "  🌐  #{url}"
      puts "  📱  #{settings.streamlit_app.title}"
      puts "  📁  ~/.streamweaver/apps/#{sanitized}.port"
      if settings.streamlit_app.stream_block
        puts "  📡  SSE streaming enabled (GET /stream, POST /stream/push)"
      end
      if settings.streamlit_app.has_timers?
        puts "  ⏱️   #{settings.streamlit_app.timers.size} periodic timer(s) registered"
      end
      if @reset_state_pending
        puts "  🔄  State will be cleared on first page load (--reset)"
      end
      puts ""
      puts "  Press Ctrl+C to stop (may take a few seconds to drain SSE connections)"
      puts ""

      open_browser(url) if auto_open

      # Start internal stream thread if app defined a stream block
      start_stream_thread

      # Suppress Sinatra/Puma startup messages
      original_stdout = $stdout
      original_stderr = $stderr
      unless ENV['DEBUG'] || ENV['SW_DEBUG']
        $stdout = StringIO.new
        $stderr = StringIO.new
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

      host, port = resolve_host_and_port(options)
      auto_open = options.fetch(:open_browser, !ENV['SW_NO_OPEN'])

      configure_server!(host, port)

      url = display_url(host, port)

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
