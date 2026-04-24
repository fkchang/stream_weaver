# frozen_string_literal: true

require 'optparse'
require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

module StreamWeaver
  # Command-line interface for StreamWeaver service
  class CLI
    DEFAULT_PORT = Service::DEFAULT_PORT

    def self.run(args)
      return help if args.empty?

      command = args.shift

      case command
      when 'serve'
        serve(args)
      when 'run'
        run_app(args)
      when 'list'
        list_apps
      when 'remove'
        remove_app(args.first)
      when 'clear'
        clear_apps
      when 'admin'
        admin
      when 'showcase'
        showcase
      when 'tutorial'
        tutorial
      when 'stop'
        stop_service
      when 'status'
        status
      when 'llm'
        llm_docs
      when 'eval'
        eval_dsl(args)
      when 'prompt'
        prompt_ui(args)
      when 'live'
        live_session(args)
      when 'push'
        push_content(args)
      when 'live-list'
        list_live_sessions
      when 'live-close'
        close_live_session(args.first)
      when 'wait'
        wait_for_submission(args)
      when 'template'
        run_template(args)
      # Canvas commands (two-way IPC with Claude Code)
      when 'canvas'
        canvas_session(args)
      when 'canvas-push'
        canvas_push(args)
      when 'canvas-wait'
        canvas_wait(args)
      when 'canvas-close'
        canvas_close(args)
      when 'canvas-toast'
        canvas_toast(args)
      when 'canvas-list'
        canvas_list
      when 'canvas-reset'
        canvas_reset(args)
      when 'canvas-stop'
        canvas_stop
      # High-level canvas helpers
      when 'pick'
        canvas_pick(args)
      when 'confirm'
        canvas_confirm(args)
      when 'panel'
        panel(args)
      when 'install-skill'
        install_skill(args)
      when 'setup'
        setup
      when '--help', '-h', 'help'
        help
      when '--version', '-v'
        puts "StreamWeaver #{StreamWeaver::VERSION}"
      else
        # Bare file path: streamweaver examples/basic/hello_world.rb
        # Or with options: streamweaver --name "My App" file.rb
        if command&.start_with?('-') || command&.end_with?('.rb')
          run_app([command] + args)
        else
          puts "Unknown command: #{command}"
          help
          exit 1
        end
      end
    end

    # Start service in foreground (for development)
    def self.serve(args)
      port = DEFAULT_PORT

      OptionParser.new do |opts|
        opts.on('-p', '--port PORT', Integer, "Port (default: #{DEFAULT_PORT})") { |p| port = p }
      end.parse!(args)

      puts "Starting StreamWeaver service on port #{port}..."
      Service.set :port, port
      Service.set :bind, '127.0.0.1'
      Service.run!
    end

    # Run an app file
    def self.run_app(args)
      name = nil
      file_path = nil

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: streamweaver run [options] <file.rb>"
        opts.on('-n', '--name NAME', 'Custom name for this app session') { |n| name = n }
      end

      begin
        remaining = parser.parse(args)
        file_path = remaining.first
      rescue OptionParser::InvalidOption => e
        # Might be a bare file path
        file_path = args.find { |a| a.end_with?('.rb') }
      end

      unless file_path
        puts "Usage: streamweaver run [--name NAME] <file.rb>"
        exit 1
      end

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        exit 1
      end

      ensure_service_running

      # POST to service to load the app
      uri = URI("http://localhost:#{service_port}/load-app")
      params = { file_path: File.expand_path(file_path) }
      params[:name] = name if name

      response = Net::HTTP.post_form(uri, params)
      result = JSON.parse(response.body)

      if result['success']
        url = "http://localhost:#{service_port}#{result['url']}"
        puts "Loaded: #{result['name']} (#{File.basename(file_path)})"
        puts "URL: #{url}"
        open_browser(url)
      else
        puts "Error: #{result['error']}"
        exit 1
      end
    rescue Errno::ECONNREFUSED
      puts "Error: Could not connect to StreamWeaver service"
      exit 1
    end

    # List all loaded apps with details
    def self.list_apps
      unless Service.service_running?
        puts "StreamWeaver service is not running"
        exit 1
      end

      begin
        uri = URI("http://localhost:#{service_port}/api/apps")
        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          apps = data['apps'] || []

          if apps.empty?
            puts "No apps loaded"
          else
            puts "Loaded apps (#{apps.length}):\n\n"
            puts format("  %-10s %-20s %-30s %10s %10s", "ID", "NAME", "FILE", "LOADED", "IDLE")
            puts "  " + "-" * 84

            apps.each do |app|
              loaded_ago = Utils.format_duration(app['age_seconds'])
              idle_ago = Utils.format_duration(app['idle_seconds'])
              file_name = File.basename(app['path'])

              puts format("  %-10s %-20s %-30s %10s %10s",
                app['id'][0..9],
                Utils.truncate(app['name'], 20),
                Utils.truncate(file_name, 30),
                loaded_ago,
                idle_ago
              )
            end
          end
        else
          puts "Error getting app list"
          exit 1
        end
      rescue Errno::ECONNREFUSED
        puts "Error: Could not connect to StreamWeaver service"
        exit 1
      end
    end

    # Remove a specific app
    def self.remove_app(app_id)
      unless app_id
        puts "Usage: streamweaver remove <app_id>"
        puts "Use 'streamweaver list' to see app IDs"
        exit 1
      end

      unless Service.service_running?
        puts "StreamWeaver service is not running"
        exit 1
      end

      begin
        uri = URI("http://localhost:#{service_port}/remove-app")
        response = Net::HTTP.post_form(uri, { app_id: app_id })
        result = JSON.parse(response.body)

        if result['success']
          puts result['message']
        else
          puts "Error: #{result['error']}"
          exit 1
        end
      rescue Errno::ECONNREFUSED
        puts "Error: Could not connect to StreamWeaver service"
        exit 1
      end
    end

    # Clear all apps
    def self.clear_apps
      unless Service.service_running?
        puts "StreamWeaver service is not running"
        exit 1
      end

      begin
        uri = URI("http://localhost:#{service_port}/clear-apps")
        response = Net::HTTP.post_form(uri, {})
        result = JSON.parse(response.body)

        if result['success']
          puts result['message']
        else
          puts "Error: #{result['error']}"
          exit 1
        end
      rescue Errno::ECONNREFUSED
        puts "Error: Could not connect to StreamWeaver service"
        exit 1
      end
    end

    # Open admin dashboard
    def self.admin
      ensure_service_running
      url = "http://localhost:#{service_port}/admin"
      puts "Opening admin dashboard..."
      puts "URL: #{url}"
      open_browser(url)
    end

    # Show examples browser (showcase)
    # Runs the browser standalone (not in service) so it can use at_exit for cleanup
    def self.showcase
      examples_browser = File.expand_path('../../../examples/advanced/examples_browser.rb', __FILE__)

      unless File.exist?(examples_browser)
        puts "Examples browser not found at: #{examples_browser}"
        exit 1
      end

      # Ensure service is running for the examples
      ensure_service_running

      puts "Starting Examples Browser..."
      puts "Examples will load into service at http://localhost:#{service_port}"
      puts "Press Ctrl+C to quit and cleanup\n\n"

      # Run browser standalone (exec replaces process, so Ctrl+C triggers at_exit)
      exec(RbConfig.ruby, examples_browser)
    end

    # Show interactive tutorial
    # Runs the tutorial standalone (not in service) so it can use at_exit for cleanup
    def self.tutorial
      tutorial_app = File.expand_path('../../../examples/advanced/tutorial.rb', __FILE__)

      unless File.exist?(tutorial_app)
        puts "Tutorial not found at: #{tutorial_app}"
        exit 1
      end

      # Ensure service is running for the playgrounds
      ensure_service_running

      puts "Starting StreamWeaver Tutorial..."
      puts "Playgrounds will load into service at http://localhost:#{service_port}"
      puts "Press Ctrl+C to quit and cleanup\n\n"

      # Run tutorial standalone (exec replaces process, so Ctrl+C triggers at_exit)
      exec(RbConfig.ruby, tutorial_app)
    end

    # Stop the service
    def self.stop_service
      if Service.service_running?
        Service.stop
        puts "StreamWeaver service stopped"
      else
        puts "No StreamWeaver service is running"
      end
    end

    # Show service status
    def self.status
      if Service.service_running?
        info = Service.read_pid_file
        puts "StreamWeaver service is running"
        puts "  PID: #{info[:pid]}"
        puts "  Port: #{info[:port]}"
        puts "  URL: http://localhost:#{info[:port]}"

        # Try to get detailed app list
        begin
          uri = URI("http://localhost:#{info[:port]}/api/apps")
          response = Net::HTTP.get_response(uri)
          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            apps = data['apps'] || []
            puts "  Loaded apps: #{apps.length}"
            apps.each do |app|
              idle = Utils.format_duration(app['idle_seconds'])
              puts "    - #{app['id'][0..7]}  #{app['name']}  (idle #{idle})"
            end
          end
        rescue
          # Ignore errors getting status
        end
      else
        puts "StreamWeaver service is not running"
        puts "  Start with: streamweaver serve"
        puts "  Or run an app: streamweaver <file.rb>"
      end
    end

    def self.llm_docs
      llms_path = File.expand_path('../../../llms.txt', __FILE__)
      if File.exist?(llms_path)
        puts File.read(llms_path)
      else
        $stderr.puts "Error: llms.txt not found at #{llms_path}"
        exit 1
      end
    end

    # Evaluate StreamWeaver DSL from stdin and return JSON result
    # Usage: streamweaver eval <<'RUBY'
    #   app "Question" do
    #     radio_group :choice, ["A", "B", "C"]
    #   end.run_once!
    # RUBY
    def self.eval_dsl(args)
      title = "StreamWeaver Prompt"
      auto_close = false

      OptionParser.new do |opts|
        opts.banner = "Usage: streamweaver eval [options] < script.rb"
        opts.on('-t', '--title TITLE', 'Window title') { |t| title = t }
        opts.on('-c', '--auto-close', 'Close browser after submit') { auto_close = true }
      end.parse!(args)

      # Read DSL from stdin
      if $stdin.tty?
        $stderr.puts "Usage: streamweaver eval <<'RUBY'"
        $stderr.puts "  app \"Title\" do"
        $stderr.puts "    text_field :name"
        $stderr.puts "  end.run_once!"
        $stderr.puts "RUBY"
        exit 1
      end

      dsl_code = $stdin.read.strip

      # Check if code already has run_once! or run!
      unless dsl_code.include?('run_once!') || dsl_code.include?('.run!')
        # Wrap in app block with run_once! if not present
        if dsl_code.include?('app ')
          # Has app block but no run - add run_once!
          dsl_code = dsl_code.sub(/end\s*\z/, "end.run_once!#{auto_close ? '(auto_close_window: true)' : ''}")
        else
          # No app block - wrap everything
          auto_close_opt = auto_close ? 'auto_close_window: true' : ''
          dsl_code = <<~RUBY
            app "#{title}" do
              #{dsl_code}
            end.run_once!(#{auto_close_opt})
          RUBY
        end
      end

      # Create temp file
      require 'tempfile'
      temp_file = Tempfile.new(['streamweaver_eval', '.rb'])
      temp_file.write("require 'stream_weaver'\n\n#{dsl_code}")
      temp_file.close

      begin
        # Execute and capture output (run_once! outputs JSON to stdout)
        result = `#{RbConfig.ruby} #{temp_file.path}`
        puts result
        focus_terminal if auto_close || dsl_code.include?('auto_close')
      ensure
        temp_file.unlink
      end
    end

    # Quick prompt UI from command-line flags
    # Usage: streamweaver prompt "Title" --radio "choice:A,B,C" --text "notes:Any notes?"
    def self.prompt_ui(args)
      title = args.shift || "Prompt"
      components = []
      auto_close = true  # Default to auto-close for better UX
      description = nil

      i = 0
      while i < args.length
        arg = args[i]
        case arg
        when '--radio'
          i += 1
          key, options = parse_component_arg(args[i])
          components << "radio_group :#{key}, #{options.inspect}"
        when '--select'
          i += 1
          key, options = parse_component_arg(args[i])
          components << "select :#{key}, #{options.inspect}"
        when '--text'
          i += 1
          key, placeholder = parse_component_arg(args[i])
          placeholder_opt = placeholder ? ", placeholder: #{placeholder.first.inspect}" : ""
          components << "text_field :#{key}#{placeholder_opt}"
        when '--textarea'
          i += 1
          key, placeholder = parse_component_arg(args[i])
          placeholder_opt = placeholder ? ", placeholder: #{placeholder.first.inspect}" : ""
          components << "text_area :#{key}#{placeholder_opt}"
        when '--checkbox'
          i += 1
          key, label = parse_component_arg(args[i])
          label_str = label&.first || key.to_s.capitalize
          components << "checkbox :#{key}, #{label_str.inspect}"
        when '--confirm'
          i += 1
          key, label = parse_component_arg(args[i])
          label_str = label&.first || "Confirm"
          components << "checkbox :#{key}, #{label_str.inspect}"
        when '--md', '--description'
          i += 1
          description = args[i]
        when '--keep-open'
          auto_close = false
        end
        i += 1
      end

      if components.empty?
        $stderr.puts "Usage: streamweaver prompt \"Title\" --radio \"key:opt1,opt2\" --text \"key:placeholder\""
        $stderr.puts ""
        $stderr.puts "Options:"
        $stderr.puts "  --radio KEY:OPT1,OPT2,...    Radio button group"
        $stderr.puts "  --select KEY:OPT1,OPT2,...   Dropdown select"
        $stderr.puts "  --text KEY:PLACEHOLDER       Text input"
        $stderr.puts "  --textarea KEY:PLACEHOLDER   Multi-line text"
        $stderr.puts "  --checkbox KEY:LABEL         Checkbox"
        $stderr.puts "  --confirm KEY:LABEL          Confirmation checkbox"
        $stderr.puts "  --md TEXT                    Markdown description"
        $stderr.puts "  --keep-open                  Keep browser open after submit"
        exit 1
      end

      # Build DSL
      auto_close_opt = auto_close ? 'auto_close_window: true' : ''
      md_line = description ? "md #{description.inspect}\n  " : ""
      dsl = <<~RUBY
        require 'stream_weaver'

        app "#{title}" do
          #{md_line}#{components.join("\n  ")}
        end.run_once!(#{auto_close_opt})
      RUBY

      # Create temp file and execute
      require 'tempfile'
      temp_file = Tempfile.new(['streamweaver_prompt', '.rb'])
      temp_file.write(dsl)
      temp_file.close

      begin
        result = `#{RbConfig.ruby} #{temp_file.path}`
        puts result
        focus_terminal if auto_close
      ensure
        temp_file.unlink
      end
    end

    # Parse "key:value1,value2" into [key, [value1, value2]]
    def self.parse_component_arg(arg)
      return [arg, nil] unless arg&.include?(':')
      key, rest = arg.split(':', 2)
      values = rest.include?(',') ? rest.split(',').map(&:strip) : [rest]
      [key, values]
    end

    # Show help
    def self.help
      puts <<~HELP
        StreamWeaver - Ruby DSL for reactive UIs

        Usage:
          streamweaver <file.rb>              Run an app file
          streamweaver run [options] <file>   Run with options
          streamweaver eval                   Evaluate DSL from stdin, return JSON
          streamweaver prompt "Title" [opts]  Quick UI from flags, return JSON
          streamweaver list                   List all loaded apps
          streamweaver remove <app_id>        Remove a specific app
          streamweaver clear                  Remove all apps
          streamweaver admin                  Open admin dashboard
          streamweaver tutorial               Interactive tutorial
          streamweaver showcase               Browse all examples
          streamweaver serve                  Start service in foreground
          streamweaver stop                   Stop the background service
          streamweaver status                 Show service status
          streamweaver llm                    Output LLM documentation
          streamweaver --help                 Show this help
          streamweaver --version              Show version

        Run Options:
          -n, --name NAME                     Custom name for this app session

        Prompt Options (for Claude Code integration):
          --radio KEY:OPT1,OPT2,...           Radio button group
          --select KEY:OPT1,OPT2,...          Dropdown select
          --text KEY:PLACEHOLDER              Text input
          --textarea KEY:PLACEHOLDER          Multi-line text
          --checkbox KEY:LABEL                Checkbox
          -c, --auto-close                    Close browser after submit

        Examples:
          # Run an app
          streamweaver examples/basic/hello_world.rb

          # Quick prompt (for Claude Code)
          streamweaver prompt "Pick approach" --radio "choice:Refactor,Adapter,Patch"

          # Eval DSL from stdin
          streamweaver eval <<'RUBY'
            app "Survey" do
              text_field :name
              select :priority, ["Low", "Medium", "High"]
            end.run_once!
          RUBY

        Live Sessions (update-in-place via SSE):
          streamweaver live <name>              Open a persistent live session
          streamweaver push <name> [options]    Push content to a live session
          streamweaver live-list                List all live sessions
          streamweaver live-close <name>        Close a live session

        Push Options:
          --target SELECTOR                     CSS selector (default: #main)
          --action ACTION                       replace, append, prepend (default: replace)
          --file FILE                           Read content from file
          --html HTML                           HTML content directly
          (or pipe content via stdin)

        Live Session Examples:
          # Open a persistent session
          streamweaver live adventure

          # Push content to it
          echo "<h1>Hello!</h1>" | streamweaver push adventure
          streamweaver push adventure --html "<p>New paragraph</p>" --action append
          streamweaver push adventure --file scene.html --target "#story"

        Canvas (Two-way IPC with Claude Code):
          streamweaver canvas <name>              Create/connect to canvas session
          streamweaver canvas-push <name>         Push DSL content (from stdin)
          streamweaver canvas-wait <name>         Wait for user interaction
          streamweaver canvas-toast <name> <msg>  Show toast overlay (doesn't replace content)
          streamweaver canvas-close <name>        Close a canvas session
          streamweaver canvas-reset <name>        Reset session state (keep connections)
          streamweaver canvas-reset --all         Reset all sessions
          streamweaver canvas-list                List canvas sessions
          streamweaver canvas-stop                Stop the canvas bridge

        Canvas Examples:
          # Create session and open browser
          streamweaver canvas survey

          # Push UI content
          streamweaver canvas-push survey <<'RUBY'
            header1 "Quick Survey"
            radio_group :choice, ["A", "B", "C"]
            button "Submit"
          RUBY

          # Wait for user input (returns JSON)
          streamweaver canvas-wait survey
          # => {"choice":"B"}

        Panel (iTerm2 Split + Canvas):
          streamweaver panel [name]               Split iTerm2, open canvas in right pane
          streamweaver panel [name] --fresh       Close existing session first, then open
          streamweaver setup                      Configure Claude Code (permissions + skill)
          streamweaver install-skill [--global]   Install Claude Code skill only

        Panel Example (iTerm2):
          # Split terminal, open canvas on right
          streamweaver panel notes

          # Push content from Claude Code
          streamweaver canvas-push notes <<'RUBY'
            header1 "Meeting Notes"
            md "## Discussion Points\\n- Item 1\\n- Item 2"
          RUBY
      HELP
    end

    # =========================================
    # Live Session Commands
    # =========================================

    # Open a live session in browser
    def self.live_session(args)
      session_name = args.first

      unless session_name
        $stderr.puts "Usage: streamweaver live <session-name>"
        exit 1
      end

      ensure_service_running
      port = service_port

      # Create session via API (will be created on first connection anyway)
      url = "http://localhost:#{port}/live/#{URI.encode_www_form_component(session_name)}"

      puts "Opening live session: #{session_name}"
      puts "URL: #{url}"
      puts ""
      puts "Push content with:"
      puts "  echo '<h1>Hello</h1>' | streamweaver push #{session_name}"
      puts "  streamweaver push #{session_name} --html '<p>Content</p>'"
      puts ""

      open_browser(url)
    end

    # Push content to a live session
    def self.push_content(args)
      session_name = nil
      target = '#main'
      action = 'replace'
      content = nil
      is_dsl = false

      stdin_dsl = false

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: streamweaver push <session-name> [options]"
        opts.on('-t', '--target SELECTOR', 'CSS selector (default: #main)') { |t| target = t }
        opts.on('-a', '--action ACTION', 'replace, append, prepend (default: replace)') { |a| action = a }
        opts.on('-f', '--file FILE', 'Read content from file') { |f| content = File.read(f) }
        opts.on('-h', '--html HTML', 'HTML content directly') { |h| content = h }
        opts.on('-d', '--dsl DSL', 'StreamWeaver DSL to render') { |d| content = d; is_dsl = true }
        opts.on('--dsl-file FILE', 'StreamWeaver DSL from file') { |f| content = File.read(f); is_dsl = true }
        opts.on('--stdin-dsl', 'Read DSL from stdin') { stdin_dsl = true; is_dsl = true }
      end

      remaining = parser.parse(args)
      session_name = remaining.first

      unless session_name
        $stderr.puts "Usage: streamweaver push <session-name> [options]"
        $stderr.puts ""
        $stderr.puts "Options:"
        $stderr.puts "  -t, --target SELECTOR   CSS selector (default: #main)"
        $stderr.puts "  -a, --action ACTION     replace, append, prepend (default: replace)"
        $stderr.puts "  -f, --file FILE         Read content from file"
        $stderr.puts "  -h, --html HTML         HTML content directly"
        $stderr.puts "  -d, --dsl DSL           StreamWeaver DSL to render"
        $stderr.puts "  --dsl-file FILE         StreamWeaver DSL from file"
        $stderr.puts "  --stdin-dsl             Read DSL from stdin"
        $stderr.puts ""
        $stderr.puts "Examples:"
        $stderr.puts "  echo '<h1>Hello</h1>' | streamweaver push my-session"
        $stderr.puts "  streamweaver push my-session --dsl 'header1 \"Title\"; text \"Hello\"'"
        $stderr.puts "  cat scene.rb | streamweaver push my-session --stdin-dsl"
        exit 1
      end

      # Read from stdin if no content provided or if --stdin-dsl
      if content.nil? || stdin_dsl
        if $stdin.tty? && content.nil?
          $stderr.puts "Error: No content provided. Use --html, --dsl, --file, --stdin-dsl, or pipe via stdin."
          exit 1
        end
        content = $stdin.read if content.nil? || stdin_dsl
      end

      # Render DSL to HTML if needed
      if is_dsl
        content = render_dsl_to_html(content, session_name: session_name)
      end

      # Ensure service is running
      unless Service.service_running?
        $stderr.puts "Error: StreamWeaver service not running. Start with: streamweaver live #{session_name}"
        exit 1
      end

      port = service_port

      # POST to the push endpoint
      uri = URI("http://localhost:#{port}/live/#{URI.encode_www_form_component(session_name)}/push")
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(
        'target' => target,
        'action' => action,
        'content' => content
      )

      begin
        response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 10) { |http| http.request(req) }

        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          puts "Pushed to #{result['session']} #{result['target']} (#{result['action']})"
        else
          $stderr.puts "Error: #{response.body}"
          exit 1
        end
      rescue => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end
    end

    # List all live sessions
    def self.list_live_sessions
      unless Service.service_running?
        puts "StreamWeaver service is not running"
        return
      end

      port = service_port
      uri = URI("http://localhost:#{port}/api/live")

      begin
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          sessions = data['sessions'] || []

          if sessions.empty?
            puts "No live sessions"
          else
            puts "Live Sessions:"
            sessions.each do |s|
              age = Utils.format_duration((Time.now - Time.parse(s['created_at'])).to_i) rescue 'unknown'
              last_push = s['last_push'] ? Utils.format_duration((Time.now - Time.parse(s['last_push'])).to_i) + ' ago' : 'never'
              puts "  #{s['name']} - created #{age} ago, last push: #{last_push}"
            end
          end
        else
          puts "Error: #{response.body}"
        end
      rescue => e
        puts "Error: #{e.message}"
      end
    end

    # Close a live session
    def self.close_live_session(session_name)
      unless session_name
        $stderr.puts "Usage: streamweaver live-close <session-name>"
        exit 1
      end

      unless Service.service_running?
        puts "StreamWeaver service is not running"
        return
      end

      port = service_port
      uri = URI("http://localhost:#{port}/live/#{URI.encode_www_form_component(session_name)}")
      req = Net::HTTP::Delete.new(uri)

      begin
        response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
        result = JSON.parse(response.body)

        if result['success']
          puts result['message']
        else
          puts "Error: #{result['error']}"
        end
      rescue => e
        puts "Error: #{e.message}"
      end
    end

    # Wait for a submission from a live session
    def self.wait_for_submission(args)
      session_name = args.first
      timeout = 300  # 5 minute default timeout

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: streamweaver wait <session-name> [options]"
        opts.on('-t', '--timeout SECONDS', Integer, 'Timeout in seconds (default: 300)') { |t| timeout = t }
      end

      remaining = parser.parse(args)
      session_name = remaining.first

      unless session_name
        $stderr.puts "Usage: streamweaver wait <session-name> [--timeout SECONDS]"
        exit 1
      end

      unless Service.service_running?
        $stderr.puts "Error: StreamWeaver service not running"
        exit 1
      end

      port = service_port
      start_time = Time.now

      # Poll for submissions
      loop do
        if Time.now - start_time > timeout
          $stderr.puts "Timeout waiting for submission"
          exit 1
        end

        uri = URI("http://localhost:#{port}/live/#{URI.encode_www_form_component(session_name)}/submissions")

        begin
          response = Net::HTTP.get_response(uri)
          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            submissions = data['submissions'] || []

            if submissions.any?
              # Return the first submission as JSON
              puts JSON.generate(submissions.first['data'])
              return
            end
          end
        rescue => e
          $stderr.puts "Poll error: #{e.message}"
        end

        sleep 0.5  # Poll every 500ms
      end
    end

    # Run a pre-built template with JSON configuration
    # Usage: streamweaver template wizard SESSION '{"title":"Setup","steps":[...]}'
    def self.run_template(args)
      template_name = args.shift
      session_name = args.shift
      json_data = args.shift

      unless template_name && session_name
        $stderr.puts "Usage: streamweaver template <template-name> <session-name> '<json-config>'"
        $stderr.puts ""
        $stderr.puts "Available templates:"
        $stderr.puts "  wizard  - Multi-step form wizard"
        $stderr.puts ""
        $stderr.puts "Example:"
        $stderr.puts '  streamweaver template wizard test \'{"title":"Setup","steps":[{"title":"Info","fields":[{"type":"text","key":"name","label":"Name"}]}]}\''
        exit 1
      end

      unless Service.service_running?
        ensure_service_running
      end

      # Parse JSON config
      config = if json_data
        JSON.parse(json_data)
      else
        # Read from stdin if no JSON provided
        JSON.parse($stdin.read)
      end

      # Load and run the template
      case template_name
      when 'wizard'
        require_relative 'templates/wizard'
        result = Templates::Wizard.run(session: session_name, config: config)
        puts JSON.generate(result)
      when 'choices'
        require_relative 'templates/choices'
        result = Templates::Choices.run(session: session_name, config: config)
        puts JSON.generate(result)
      when 'confirm'
        require_relative 'templates/confirm'
        result = Templates::Confirm.run(session: session_name, config: config)
        puts JSON.generate(result)
      when 'info'
        require_relative 'templates/info'
        result = Templates::Info.run(session: session_name, config: config)
        puts JSON.generate(result)
      when 'table'
        require_relative 'templates/table'
        result = Templates::Table.run(session: session_name, config: config)
        puts JSON.generate(result)
      when 'code'
        require_relative 'templates/code'
        result = Templates::Code.run(session: session_name, config: config)
        puts JSON.generate(result)
      when 'diff'
        require_relative 'templates/diff'
        result = Templates::Diff.run(session: session_name, config: config)
        puts JSON.generate(result)
      else
        $stderr.puts "Unknown template: #{template_name}"
        $stderr.puts "Available: wizard, choices, confirm, info, table, code, diff"
        exit 1
      end
    rescue JSON::ParserError => e
      $stderr.puts "Invalid JSON: #{e.message}"
      exit 1
    rescue => e
      $stderr.puts "Template error: #{e.message}"
      $stderr.puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
      exit 1
    end

    private

    def self.ensure_service_running
      return if Service.service_running?

      puts "Starting StreamWeaver service..."
      result = Service.launch_background
      puts "Service started on port #{result[:port]}"

      # Wait for service to be ready (up to 10 seconds)
      10.times do
        begin
          uri = URI("http://localhost:#{result[:port]}/api/status")
          response = Net::HTTP.get_response(uri)
          return if response.is_a?(Net::HTTPSuccess)
        rescue Errno::ECONNREFUSED
          # Not ready yet
        end
        sleep 1
      end

      puts "Warning: Service may not be ready yet"
    end

    def self.service_port
      info = Service.read_pid_file
      info ? info[:port] : DEFAULT_PORT
    end

    def self.open_browser(url)
      case RbConfig::CONFIG['host_os']
      when /darwin|mac os/
        system('open', url)
      when /linux|bsd/
        system('xdg-open', url)
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        system('start', url)
      end
    end

    # Render StreamWeaver DSL to HTML
    # @param dsl_code [String] StreamWeaver DSL code (e.g., "header1 'Title'; text 'Hello'")
    # @param session_name [String] Live session name for URL routing
    # @return [String] Rendered HTML
    def self.render_dsl_to_html(dsl_code, session_name: nil)
      require 'json'

      # Create a mini app to evaluate the DSL
      mini_app = StreamWeaver::App.new("Live Push")

      # Evaluate the DSL in the context of the app
      mini_app.instance_eval(dsl_code)

      # Create adapter with URL prefix for live session submit
      url_prefix = session_name ? "/live/#{session_name}" : "/live"
      adapter = StreamWeaver::Adapter::AlpineJS.new(url_prefix: url_prefix)

      # Render components to HTML using a Phlex view with adapter
      # Wrap in x-data container for Alpine.js binding (required for hx-include="[x-model]")
      state = {}
      view = Class.new(Phlex::HTML) do
        attr_reader :adapter

        define_method(:initialize) do |components, st, adp|
          @components = components
          @state = st
          @adapter = adp
        end

        define_method(:view_template) do
          # Wrap in div with x-data for Alpine.js form binding
          div(id: "main", "x-data": JSON.generate(@state)) do
            @components.each { |c| c.render(self, @state) }
          end
        end
      end

      view.new(mini_app.components, state, adapter).call
    end

    # =========================================
    # Canvas Commands (Two-way IPC)
    # =========================================

    # Create or connect to a canvas session
    def self.canvas_session(args)
      session_name = args.first

      unless session_name
        $stderr.puts "Usage: streamweaver canvas <session-name>"
        exit 1
      end

      require_relative 'canvas/client'

      # Ensure bridge is running
      info = Canvas::Client.ensure_bridge_running
      port = info[:port] || Canvas::Bridge::DEFAULT_PORT

      # Create session
      response = Canvas::Client.send_message(
        Canvas::Protocol::Messages.create(session_name)
      )

      if response && response[:type] == 'ready'
        puts "Canvas session: #{session_name}"
        puts "URL: #{response[:url]}"
        puts ""
        puts "Push content with:"
        puts "  streamweaver canvas-push #{session_name} <<'RUBY'"
        puts "    header1 'Hello'"
        puts "    radio_group :choice, ['A', 'B', 'C']"
        puts "    button 'Submit'"
        puts "  RUBY"
        puts ""
        puts "Wait for user input:"
        puts "  streamweaver canvas-wait #{session_name}"

        open_browser(response[:url])
      else
        $stderr.puts "Error creating canvas session"
        exit 1
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      $stderr.puts "Try: streamweaver canvas #{session_name}"
      exit 1
    end

    # Push DSL content to a canvas session
    def self.canvas_push(args)
      session_name = args.first

      unless session_name
        $stderr.puts "Usage: streamweaver canvas-push <session-name> < dsl.rb"
        exit 1
      end

      # Read DSL from stdin
      if $stdin.tty?
        $stderr.puts "Usage: streamweaver canvas-push #{session_name} <<'RUBY'"
        $stderr.puts "  header1 'Title'"
        $stderr.puts "  text_field :name"
        $stderr.puts "RUBY"
        exit 1
      end

      dsl = $stdin.read.strip

      require_relative 'canvas/client'

      response = Canvas::Client.send_message(
        Canvas::Protocol::Messages.push(session_name, dsl)
      )

      # Check for DSL errors reported back from the bridge
      if response && response[:type] == 'push_error'
        $stderr.puts "DSL Error: #{response[:message]}"
        $stderr.puts "Pushed with error to #{session_name}"
        exit 1
      elsif response && response[:type] == 'error'
        $stderr.puts "Error: #{response[:message]}"
        exit 1
      else
        puts "Pushed to #{session_name}"
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    rescue Canvas::Client::ConnectionError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # Show a toast notification on a canvas session (doesn't replace main content)
    def self.canvas_toast(args)
      message = nil
      variant = 'warning'
      duration = 0  # 0 = persistent until dismissed or next push

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: streamweaver canvas-toast <session-name> <message> [options]"
        opts.on('-v', '--variant VARIANT', 'Toast variant: info, success, warning, error (default: warning)') { |v| variant = v }
        opts.on('-d', '--duration MS', Integer, 'Auto-dismiss after milliseconds (default: 0 = persistent)') { |d| duration = d }
      end

      remaining = parser.parse(args)
      session_name = remaining.shift
      message = remaining.join(' ')

      unless session_name && !message.empty?
        $stderr.puts "Usage: streamweaver canvas-toast <session-name> <message> [--variant warning] [--duration 5000]"
        $stderr.puts "Example: streamweaver canvas-toast myapp 'Check terminal for permissions' --variant warning"
        exit 1
      end

      require_relative 'canvas/client'

      response = Canvas::Client.send_message({
        type: 'toast',
        name: session_name,
        message: message,
        variant: variant,
        duration: duration
      })

      puts "Toast sent to #{session_name}"
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    rescue Canvas::Client::ConnectionError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # Wait for user interaction on a canvas session
    def self.canvas_wait(args)
      session_name = args.first
      timeout = 300 # 5 minute default
      event_filter = 'action' # Default to waiting for button clicks only

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: streamweaver canvas-wait <session-name> [options]"
        opts.on('-t', '--timeout SECONDS', Integer, 'Timeout in seconds (default: 300)') { |t| timeout = t }
        opts.on('-e', '--event TYPE', 'Event type to wait for (default: action)') { |e| event_filter = e }
        opts.on('-a', '--any', 'Wait for any event (not just action)') { event_filter = nil }
      end

      remaining = parser.parse(args)
      session_name = remaining.first

      unless session_name
        $stderr.puts "Usage: streamweaver canvas-wait <session-name> [--timeout SECONDS]"
        exit 1
      end

      require_relative 'canvas/client'

      # Wait for an event, optionally filtering by event type
      start_time = Time.now
      loop do
        remaining_time = timeout - (Time.now - start_time).to_i
        if remaining_time <= 0
          $stderr.puts "Timeout waiting for user interaction"
          exit 1
        end

        result = Canvas::Client.send_and_wait(
          { type: 'subscribe', name: session_name },
          event_type: 'event',
          timeout: [remaining_time, 5].min # Check every 5 seconds max
        )

        if result
          # Check if event matches filter
          event_data = result[:data] || {}
          if event_filter.nil? || event_data[:type] == event_filter
            # Output the event data as JSON
            puts JSON.generate(event_data)
            return
          end
          # Event didn't match filter, keep waiting
        end
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # Close a canvas session
    def self.canvas_close(args)
      session_name = args.first

      unless session_name
        $stderr.puts "Usage: streamweaver canvas-close <session-name>"
        exit 1
      end

      require_relative 'canvas/client'

      response = Canvas::Client.send_message(
        Canvas::Protocol::Messages.close(session_name)
      )

      if response&.dig(:type) == 'closed'
        puts "Closed canvas session: #{session_name}"
        puts "Closed browser pane" if ITerm.close_pane(response[:pane_id])
      else
        $stderr.puts "Session not found: #{session_name}"
        exit 1
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # List all canvas sessions
    def self.canvas_list
      require_relative 'canvas/client'

      unless Canvas::Client.bridge_running?
        puts "Canvas bridge is not running"
        return
      end

      response = Canvas::Client.send_message({ type: 'list' })

      if response && response[:sessions]
        sessions = response[:sessions]
        if sessions.empty?
          puts "No canvas sessions"
        else
          puts "Canvas sessions:"
          sessions.each do |s|
            puts "  #{s[:name]} - #{s[:websocket_count]} connections"
          end
        end
      else
        puts "No canvas sessions"
      end
    rescue Canvas::Client::NotRunningError
      puts "Canvas bridge is not running"
    end

    # Stop the canvas bridge
    def self.canvas_stop
      require_relative 'canvas/client'

      if Canvas::Client.stop_bridge
        puts "Canvas bridge stopped"
      else
        puts "Canvas bridge is not running"
      end
    end

    def self.canvas_reset(args)
      reset_all = args.include?('--all') || args.include?('-a')
      session_name = args.reject { |a| a.start_with?('-') }.first

      unless session_name || reset_all
        $stderr.puts "Usage: streamweaver canvas-reset <session-name>"
        $stderr.puts "       streamweaver canvas-reset --all"
        exit 1
      end

      require_relative 'canvas/client'

      unless Canvas::Client.bridge_running?
        $stderr.puts "Canvas bridge is not running"
        exit 1
      end

      response = Canvas::Client.send_message({
        type: 'reset', name: session_name, all: reset_all
      })

      case response&.dig(:type)
      when 'reset_ok'
        message = reset_all ? "Reset all canvas sessions (#{response[:count]} sessions)" : "Reset canvas session: #{session_name}"
        puts message
      when 'error'
        $stderr.puts "Error: #{response[:message]}"
        exit 1
      else
        $stderr.puts "Failed to reset session"
        exit 1
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # =========================================
    # High-level Canvas Helpers
    # =========================================

    # Quick pick from a list of choices
    # Usage: streamweaver pick "Title" "Choice1" "Choice2" "Choice3"
    def self.canvas_pick(args)
      if args.length < 2
        $stderr.puts "Usage: streamweaver pick \"Title\" \"Choice1\" \"Choice2\" ..."
        exit 1
      end

      title = args.shift
      choices = args

      require_relative 'canvas/client'
      require_relative 'canvas/helpers'

      # Generate session name
      session_name = "pick_#{Time.now.to_i}"

      # Ensure bridge is running
      Canvas::Client.ensure_bridge_running

      # Create session
      response = Canvas::Client.send_message(
        Canvas::Protocol::Messages.create(session_name)
      )

      if response && response[:type] == 'ready'
        # Open browser
        open_browser(response[:url])

        # Push the pick UI
        dsl = Canvas::Helpers.pick_dsl(title, choices)
        Canvas::Client.send_message(
          Canvas::Protocol::Messages.push(session_name, dsl)
        )

        # Wait for response
        result = Canvas::Client.send_and_wait(
          { type: 'subscribe', name: session_name },
          event_type: 'event',
          timeout: 300
        )

        # Close session
        Canvas::Client.send_message(
          Canvas::Protocol::Messages.close(session_name)
        )

        if result && result[:data]
          choice = Canvas::Helpers.parse_pick_result(result[:data])
          puts JSON.generate({ choice: choice })
        else
          $stderr.puts "Timeout or cancelled"
          exit 1
        end
      else
        $stderr.puts "Failed to create canvas session"
        exit 1
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # Quick confirmation dialog
    # Usage: streamweaver confirm "Are you sure?"
    def self.canvas_confirm(args)
      message = args.first
      yes_label = "Confirm"
      no_label = "Cancel"

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: streamweaver confirm \"Message\" [options]"
        opts.on('--yes LABEL', 'Yes button label') { |l| yes_label = l }
        opts.on('--no LABEL', 'No button label') { |l| no_label = l }
      end

      remaining = parser.parse(args)
      message = remaining.first

      unless message
        $stderr.puts "Usage: streamweaver confirm \"Are you sure?\" [--yes LABEL] [--no LABEL]"
        exit 1
      end

      require_relative 'canvas/client'
      require_relative 'canvas/helpers'

      # Generate session name
      session_name = "confirm_#{Time.now.to_i}"

      # Ensure bridge is running
      Canvas::Client.ensure_bridge_running

      # Create session
      response = Canvas::Client.send_message(
        Canvas::Protocol::Messages.create(session_name)
      )

      if response && response[:type] == 'ready'
        # Open browser
        open_browser(response[:url])

        # Push the confirm UI
        dsl = Canvas::Helpers.confirm_dsl(message, yes_label: yes_label, no_label: no_label)
        Canvas::Client.send_message(
          Canvas::Protocol::Messages.push(session_name, dsl)
        )

        # Wait for response
        result = Canvas::Client.send_and_wait(
          { type: 'subscribe', name: session_name },
          event_type: 'event',
          timeout: 300
        )

        # Close session
        Canvas::Client.send_message(
          Canvas::Protocol::Messages.close(session_name)
        )

        if result && result[:data]
          confirmed = Canvas::Helpers.parse_confirm_result(result[:data])
          puts JSON.generate({ confirmed: confirmed })
        else
          $stderr.puts "Timeout or cancelled"
          exit 1
        end
      else
        $stderr.puts "Failed to create canvas session"
        exit 1
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # =========================================
    # Panel Command - iTerm2 split with canvas
    # =========================================

    # Open a canvas panel in a split iTerm2 pane
    # Usage: streamweaver panel [session-name] [--fresh]
    #
    # Panel never opens an external browser - the point is to have the browser
    # inline in a split pane. If iTerm2 Web Browser profile isn't available,
    # we just print the URL for the user to open manually.
    def self.panel(args)
      require_relative 'iterm'
      require_relative 'canvas/client'

      debug = ENV['DEBUG_PANEL']
      fresh = args.include?('--fresh') || args.include?('-f')
      args = args.reject { |a| a.start_with?('-') }

      session_name = args.first || "panel-#{SecureRandom.hex(4)}"
      $stderr.puts "[DEBUG] session_name: #{session_name}, fresh: #{fresh}" if debug

      # Ensure bridge is running
      $stderr.puts "[DEBUG] Calling ensure_bridge_running..." if debug
      bridge_info = Canvas::Client.ensure_bridge_running
      $stderr.puts "[DEBUG] Bridge info: #{bridge_info.inspect}" if debug

      if fresh
        $stderr.puts "[DEBUG] Closing existing session for fresh start..." if debug
        Canvas::Client.send_message(Canvas::Protocol::Messages.close(session_name))
      end

      # Create session
      $stderr.puts "[DEBUG] Creating session..." if debug
      response = Canvas::Client.send_message(
        Canvas::Protocol::Messages.create(session_name)
      )
      $stderr.puts "[DEBUG] Response: #{response.inspect}" if debug

      if response && response[:type] == 'ready'
        url = response[:url]
        $stderr.puts "[DEBUG] URL from response: #{url.inspect}" if debug

        # Verify URL is accessible
        if debug
          require 'net/http'
          begin
            test_response = Net::HTTP.get_response(URI(url))
            $stderr.puts "[DEBUG] URL test: HTTP #{test_response.code}"
          rescue => e
            $stderr.puts "[DEBUG] URL test FAILED: #{e.message}"
          end
        end

        # Try iTerm2 split with browser profile (never open external browser)
        if ITerm.available?
          $stderr.puts "[DEBUG] Calling ITerm.split_vertical_with_url..." if debug
          iterm_result = ITerm.split_vertical_with_url(url, open_browser: false)
          $stderr.puts "[DEBUG] iTerm result: #{iterm_result.inspect}" if debug

          # Store pane_id in the canvas session for later cleanup
          if iterm_result[:pane_id]
            Canvas::Client.send_message(
              Canvas::Protocol::Messages.set_pane_id(session_name, iterm_result[:pane_id])
            )
          end

          case iterm_result[:type]
          when :browser
            puts "Canvas '#{session_name}' ready"
            puts "Browser opened in split pane"
          when :terminal
            puts "Canvas '#{session_name}' ready"
            puts "Split pane created - open #{url} in a browser"
          else
            puts "Canvas '#{session_name}' ready at #{url}"
          end
          puts ""
          puts "URL (if browser didn't open): #{url}"
        else
          puts "Canvas '#{session_name}' ready at #{url}"
          puts "(iTerm2 not detected - open URL manually for side-by-side workflow)"
        end

        puts ""
        puts "Push content with:"
        puts "  streamweaver canvas-push #{session_name} <<'RUBY'"
        puts "    header1 'Hello'"
        puts "    md 'Your content here'"
        puts "  RUBY"
      else
        $stderr.puts "Error: Failed to create canvas session"
        exit 1
      end
    rescue Canvas::Client::NotRunningError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    # =========================================
    # Skill Installation
    # =========================================

    SKILL_CONTENT = <<~'MARKDOWN'
      # StreamWeaver Panel Skill

      Use StreamWeaver panels to present information visually, not just collect input.

      ## When to Use Panels

      - **Presenting results**: Tables, formatted reports, summaries
      - **Status displays**: Progress dashboards, build status
      - **Rich choices**: When terminal options are too limiting
      - **Documentation**: Help text, guides with formatting
      - **Visual content**: Diagrams, charts

      ## How to Use

      1. Open a panel: `streamweaver panel [session-name]`
      2. Push content: `streamweaver canvas-push <session> <<< 'your DSL'`
      3. Wait for interaction: `streamweaver canvas-wait <session>`

      ## Example: Present a Report

      ```bash
      streamweaver panel report
      streamweaver canvas-push report <<'RUBY'
        header1 "Analysis Complete"
        md "## Summary"
        md "- 47 files analyzed"
        md "- 3 issues found"
        table headers: ["File", "Issue", "Severity"], rows: [
          ["api.rb", "N+1 query", "warning"],
          ["auth.rb", "Missing validation", "error"],
          ["user.rb", "Deprecated method", "info"]
        ]
        button "Acknowledged"
      RUBY
      result=$(streamweaver canvas-wait report)
      ```

      ## Example: Quick Selection

      ```bash
      streamweaver panel picker
      streamweaver canvas-push picker <<'RUBY'
        header2 "Select Database"
        radio_group :choice, ["PostgreSQL", "SQLite", "MySQL"]
        button "Continue"
      RUBY
      result=$(streamweaver canvas-wait picker)
      # result contains JSON with the selection
      ```

      ## Key Insight

      Panels aren't just for forms - use them whenever visual presentation
      helps the user understand information better than terminal text.

      ## DSL Quick Reference

      ```ruby
      # Text
      text "Plain text"
      md "**Markdown** with *formatting*"
      header1 "Title"  # through header6

      # Forms
      text_field :name, placeholder: "Name"
      select :option, ["A", "B", "C"]
      checkbox :agree, "I agree"
      radio_group :choice, ["Option 1", "Option 2"]

      # Layout
      card { text "In a card" }
      columns widths: ['50%', '50%'] do
        column { text "Left" }
        column { text "Right" }
      end

      # Data
      table headers: ["Col1", "Col2"], rows: [["a", "b"]]
      bar_chart data: { a: 10, b: 20 }

      # Actions
      button "Click me"
      ```
    MARKDOWN

    # Install the StreamWeaver panel skill for Claude Code
    # Usage: streamweaver install-skill [--global]
    def self.install_skill(args)
      global = args.include?('--global') || args.include?('-g')

      if global
        skill_dir = File.expand_path('~/.claude/skills')
      else
        skill_dir = File.join(Dir.pwd, '.claude', 'skills')
      end

      FileUtils.mkdir_p(skill_dir)

      # Panel skill (inline content, written as a flat .md file)
      panel_path = File.join(skill_dir, 'streamweaver-panel.md')
      File.write(panel_path, SKILL_CONTENT)

      # Visual companion skill (lives in gem, installed as symlink so gem updates propagate)
      gem_skill_src = File.expand_path(
        File.join(File.dirname(__FILE__), 'skills', 'streamweaver-visual-companion', 'SKILL.md')
      )
      companion_dir = File.join(skill_dir, 'streamweaver-visual-companion')
      companion_path = File.join(companion_dir, 'SKILL.md')
      FileUtils.mkdir_p(companion_dir)
      FileUtils.ln_sf(gem_skill_src, companion_path)

      location = global ? "global (~/.claude/skills/)" : "project (.claude/skills/)"
      puts "StreamWeaver skills installed to #{location}"
      puts "  streamweaver-panel.md          (panel workflow reference)"
      puts "  streamweaver-visual-companion/ (brainstorming companion, symlinked from gem)"
      puts ""
      puts "Claude Code will now know how to use StreamWeaver panels and the visual companion."
    end

    # One-command setup for Claude Code integration
    # Adds bash permissions and installs the panel skill globally
    def self.setup
      settings_path = File.expand_path('~/.claude/settings.json')

      # Step 1: Add bash permissions to settings.json
      settings = if File.exist?(settings_path)
        JSON.parse(File.read(settings_path))
      else
        {}
      end

      # Ensure permissions structure exists
      settings['permissions'] ||= {}
      settings['permissions']['allow'] ||= []

      # Add streamweaver permission if not present
      permission = 'Bash(streamweaver *)'
      unless settings['permissions']['allow'].include?(permission)
        settings['permissions']['allow'] << permission
      end

      # Write settings
      FileUtils.mkdir_p(File.dirname(settings_path))
      File.write(settings_path, JSON.pretty_generate(settings))
      puts "Added bash permission: #{permission}"
      puts "  Path: #{settings_path}"

      # Step 2: Install skills globally
      install_skill(['--global'])

      puts ""
      puts "StreamWeaver setup complete!"
      puts ""
      puts "Skills installed (~/.claude/skills/):"
      puts "  panel             → streamweaver-panel.md"
      puts "  visual-companion  → symlink → gem (auto-updates with gem)"
      puts ""
      puts "Run: streamweaver panel <name>  to start a visual companion session."
    end

    # Bring terminal back to front after browser auto-closes
    def self.focus_terminal
      case RbConfig::CONFIG['host_os']
      when /darwin|mac os/
        # Try iTerm2 first, fall back to Terminal.app
        script = <<~APPLESCRIPT
          tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
          end tell
          if frontApp contains "iTerm" then
            tell application "iTerm2" to activate
          else if frontApp contains "Terminal" then
            tell application "Terminal" to activate
          else
            -- Try to activate iTerm2 if installed, otherwise Terminal
            try
              tell application "iTerm2" to activate
            on error
              tell application "Terminal" to activate
            end try
          end if
        APPLESCRIPT
        system('osascript', '-e', script)
      end
      # Linux/Windows: terminal typically stays focused or user can alt-tab
    end

  end
end
