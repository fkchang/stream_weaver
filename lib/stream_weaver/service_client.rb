# frozen_string_literal: true

require 'net/http'
require 'json'
require 'rbconfig'

module StreamWeaver
  # Client module for interacting with the StreamWeaver service.
  # Include this in tools that load apps via the service API.
  #
  # @example
  #   class MyTool
  #     include StreamWeaver::ServiceClient
  #
  #     def run_example(file_path)
  #       result = load_app_via_service(file_path, source: "my_tool")
  #       open_in_browser(result[:url]) if result[:ok]
  #     end
  #   end
  module ServiceClient
    # Get the service port from PID file or default
    #
    # @return [Integer] The port number
    def service_port
      info = Service.read_pid_file
      info ? info[:port] : Service::DEFAULT_PORT
    end

    # Open a URL in the default browser (OS-aware)
    #
    # @param url [String] The URL to open
    def open_in_browser(url)
      case RbConfig::CONFIG['host_os']
      when /darwin|mac os/
        system('open', url)
      when /linux|bsd/
        system('xdg-open', url)
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        system('start', url)
      end
    end

    # Load an app via the service API
    #
    # @param file_path [String] Path to the Ruby file defining the app
    # @param source [String] Source identifier for tracking (e.g., "tutorial", "examples_browser")
    # @param name [String, nil] Optional display name
    # @return [Hash] Result with :ok, :app_id, :url, :aliased_url, or :error
    def load_app_via_service(file_path, source:, name: nil)
      expanded_path = File.expand_path(file_path)

      uri = URI("http://localhost:#{service_port}/load-app")
      params = { file_path: expanded_path, source: source }
      params[:name] = name if name

      response = Net::HTTP.post_form(uri, params)
      result = JSON.parse(response.body)

      if result['success']
        {
          ok: true,
          app_id: result['app_id'],
          name: result['name'],
          url: "http://localhost:#{service_port}#{result['url']}",
          aliased_url: result['aliased_url'] ? "http://localhost:#{service_port}#{result['aliased_url']}" : nil
        }
      else
        { ok: false, error: result['error'] }
      end
    rescue Errno::ECONNREFUSED
      { ok: false, error: "Service not running" }
    rescue => e
      { ok: false, error: e.message }
    end

    # Remove an app from the service
    #
    # @param app_id [String] The app ID to remove
    # @return [Hash] Result with :ok key for consistency
    def remove_app_via_service(app_id)
      uri = URI("http://localhost:#{service_port}/remove-app")
      response = Net::HTTP.post_form(uri, { app_id: app_id })
      result = JSON.parse(response.body)
      { ok: result['success'] }
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout
      { ok: false }
    end

    # Clear all apps from a specific source
    #
    # @param source [String] The source identifier to clear
    def clear_source_via_service(source)
      uri = URI("http://localhost:#{service_port}/clear-source")
      Net::HTTP.post_form(uri, { source: source })
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout
      # Service might be down, that's ok during cleanup
    end
  end
end
