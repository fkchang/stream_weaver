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
        run_app(args.first)
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
        if command&.end_with?('.rb')
          run_app(command)
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
    def self.run_app(file_path)
      unless file_path
        puts "Usage: streamweaver run <file.rb>"
        exit 1
      end

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        exit 1
      end

      ensure_service_running

      # POST to service to load the app
      uri = URI("http://localhost:#{service_port}/load-app")
      response = Net::HTTP.post_form(uri, { file_path: File.expand_path(file_path) })

      result = JSON.parse(response.body)

      if result['success']
        url = "http://localhost:#{service_port}#{result['url']}"
        puts "Loaded: #{File.basename(file_path)}"
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

    # Show examples browser (showcase)
    def self.showcase
      examples_browser = File.expand_path('../../../examples/advanced/examples_browser.rb', __FILE__)

      if File.exist?(examples_browser)
        run_app(examples_browser)
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

        # Try to get app list
        begin
          uri = URI("http://localhost:#{info[:port]}/api/status")
          response = Net::HTTP.get_response(uri)
          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            apps = data['apps'] || []
            puts "  Loaded apps: #{apps.length}"
            apps.each { |id| puts "    - #{id}" }
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
          streamweaver <file.rb>        Run an app file
          streamweaver run <file.rb>    Run an app file (explicit)
          streamweaver serve            Start service in foreground
          streamweaver stop             Stop the background service
          streamweaver status           Show service status
          streamweaver showcase         Open examples browser
          streamweaver tutorial         Start interactive tutorial
          streamweaver --help           Show this help
          streamweaver --version        Show version

        The service auto-starts when you run an app. Each app gets a unique URL,
        allowing multiple apps to run side-by-side.

        Examples:
          streamweaver examples/basic/hello_world.rb
          streamweaver showcase
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
  end
end
