# frozen_string_literal: true

require 'optparse'
require 'net/http'
require 'json'
require 'uri'

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
      HELP
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
