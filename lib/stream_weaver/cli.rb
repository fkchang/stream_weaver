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
              loaded_ago = format_duration(app['age_seconds'])
              idle_ago = format_duration(app['idle_seconds'])
              file_name = File.basename(app['path'])

              puts format("  %-10s %-20s %-30s %10s %10s",
                app['id'][0..9],
                truncate(app['name'], 20),
                truncate(file_name, 30),
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
    def self.showcase
      examples_browser = File.expand_path('../../../examples/advanced/examples_browser.rb', __FILE__)

      if File.exist?(examples_browser)
        run_app([examples_browser])
      else
        puts "Examples browser not found at: #{examples_browser}"
        exit 1
      end
    end

    # Start tutorial (TODO: implement)
    def self.tutorial
      puts "Tutorial not yet implemented"
      # Could load a tutorial app
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
              idle = format_duration(app['idle_seconds'])
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

    # Show help
    def self.help
      puts <<~HELP
        StreamWeaver - Ruby DSL for reactive UIs

        Usage:
          streamweaver <file.rb>              Run an app file
          streamweaver run [options] <file>   Run with options
          streamweaver list                   List all loaded apps
          streamweaver remove <app_id>        Remove a specific app
          streamweaver clear                  Remove all apps
          streamweaver admin                  Open admin dashboard
          streamweaver serve                  Start service in foreground
          streamweaver stop                   Stop the background service
          streamweaver status                 Show service status
          streamweaver showcase               Open examples browser
          streamweaver --help                 Show this help
          streamweaver --version              Show version

        Run Options:
          -n, --name NAME                     Custom name for this app session

        The service auto-starts when you run an app. Each app gets a unique URL,
        allowing multiple apps to run side-by-side.

        Examples:
          streamweaver examples/basic/hello_world.rb
          streamweaver run --name "My Survey" examples/basic/form_demo.rb
          streamweaver list
          streamweaver remove a1b2c3d4
          streamweaver status
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

    # Format seconds as human-readable duration
    def self.format_duration(seconds)
      return "just now" if seconds < 5

      if seconds < 60
        "#{seconds}s ago"
      elsif seconds < 3600
        "#{seconds / 60}m ago"
      elsif seconds < 86400
        "#{seconds / 3600}h ago"
      else
        "#{seconds / 86400}d ago"
      end
    end

    # Truncate string with ellipsis
    def self.truncate(str, max_length)
      return str if str.length <= max_length
      str[0..max_length - 4] + "..."
    end
  end
end
