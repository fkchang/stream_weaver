# frozen_string_literal: true

require 'socket'
require 'json'
require 'fileutils'
require_relative 'protocol'

module StreamWeaver
  module Canvas
    # Client for communicating with the Canvas Bridge via Unix socket.
    # Used by CLI commands to send messages to the bridge.
    class Client
      class NotRunningError < StandardError; end
      class ConnectionError < StandardError; end

      SOCKET_PATH = File.expand_path('~/.streamweaver/canvas.sock')
      PID_FILE_PATH = File.expand_path('~/.streamweaver/canvas.pid')
      DEFAULT_TIMEOUT = 300 # 5 minutes

      class << self
        def socket_path
          SOCKET_PATH
        end

        def pid_file_path
          PID_FILE_PATH
        end

        # Check if the bridge process is running
        # @return [Boolean]
        def bridge_running?
          return false unless File.exist?(pid_file_path)

          content = File.read(pid_file_path)
          # Parse pid=VALUE format
          pid = content[/pid=(\d+)/, 1]&.to_i || content.strip.to_i
          return false if pid.zero?

          # Check if process exists
          Process.kill(0, pid)
          true
        rescue Errno::ESRCH, Errno::EPERM
          # Process not found or no permission
          cleanup_stale_files
          false
        end

        # Clean up stale PID and socket files
        def cleanup_stale_files
          File.delete(pid_file_path) if File.exist?(pid_file_path)
          File.delete(socket_path) if File.exist?(socket_path)
        end

        # Send a message to the bridge and return the response
        # @param message [Hash] Message to send
        # @param timeout [Integer] Timeout in seconds
        # @return [Hash, nil] Response message or nil
        def send_message(message, timeout: 5)
          raise NotRunningError, "Canvas bridge is not running" unless bridge_running?

          socket = UNIXSocket.new(socket_path)
          socket.write(Protocol.encode(message))

          # Read response with timeout
          if IO.select([socket], nil, nil, timeout)
            buffer = ''
            while (chunk = socket.read_nonblock(4096, exception: false))
              break if chunk == :wait_readable
              buffer += chunk
              break if buffer.include?("\n")
            end

            messages, _ = Protocol.parse_buffer(buffer)
            messages.first
          else
            nil
          end
        rescue Errno::ECONNREFUSED, Errno::ENOENT => e
          raise ConnectionError, "Cannot connect to canvas bridge: #{e.message}"
        ensure
          socket&.close
        end

        # Send a message and wait for a specific event type
        # @param message [Hash] Message to send
        # @param event_type [String] Event type to wait for
        # @param timeout [Integer] Timeout in seconds
        # @return [Hash, nil] Event message or nil
        def send_and_wait(message, event_type:, timeout: DEFAULT_TIMEOUT)
          raise NotRunningError, "Canvas bridge is not running" unless bridge_running?

          socket = UNIXSocket.new(socket_path)
          socket.write(Protocol.encode(message))

          start_time = Time.now
          buffer = ''

          loop do
            remaining = timeout - (Time.now - start_time)
            break if remaining <= 0

            if IO.select([socket], nil, nil, [remaining, 1].min)
              chunk = socket.read_nonblock(4096, exception: false)
              next if chunk == :wait_readable
              buffer += chunk

              messages, buffer = Protocol.parse_buffer(buffer)
              messages.each do |msg|
                return msg if msg[:type] == event_type
              end
            end
          end

          nil
        rescue Errno::ECONNREFUSED, Errno::ENOENT => e
          raise ConnectionError, "Cannot connect to canvas bridge: #{e.message}"
        ensure
          socket&.close
        end

        # Start the bridge process if not running
        # @return [Hash] { pid: Integer, port: Integer }
        def ensure_bridge_running
          return read_bridge_info if bridge_running?

          start_bridge
        end

        # Start the bridge process
        # @return [Hash] { pid: Integer, port: Integer }
        def start_bridge
          require_relative 'bridge_server'

          # Ensure directory exists
          FileUtils.mkdir_p(File.dirname(pid_file_path))

          # Get the lib path
          lib_path = File.expand_path('../..', __dir__)

          # Create startup script
          script = <<~RUBY
            $LOAD_PATH.unshift('#{lib_path}')
            require 'stream_weaver'
            require 'stream_weaver/canvas/bridge_server'
            StreamWeaver::Canvas::BridgeServer.run!
          RUBY

          # Write script to temp file
          script_file = File.join(File.dirname(pid_file_path), 'canvas_start.rb')
          File.write(script_file, script)

          # Log file
          log_file = File.join(File.dirname(pid_file_path), 'canvas.log')

          # Spawn the bridge process
          pid = spawn(
            RbConfig.ruby, script_file,
            out: [log_file, 'a'],
            err: [log_file, 'a'],
            pgroup: true
          )
          Process.detach(pid)

          # Wait for both socket AND HTTP server to be ready
          30.times do
            if File.exist?(socket_path) && File.exist?(pid_file_path)
              info = read_bridge_info
              if info && info[:port]
                # Probe HTTP server to confirm it's actually listening
                begin
                  require 'net/http'
                  uri = URI("http://127.0.0.1:#{info[:port]}/health")
                  response = Net::HTTP.get_response(uri)
                  return info if response.is_a?(Net::HTTPSuccess)
                rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
                  # Server not ready yet
                end
              end
            end
            sleep 0.2
          end

          # Fallback - return what we have
          read_bridge_info || { pid: pid, port: BridgeServer::DEFAULT_PORT }
        end

        # Read bridge info from PID file
        # @return [Hash] { pid: Integer, port: Integer }
        def read_bridge_info
          return nil unless File.exist?(pid_file_path)

          content = File.read(pid_file_path)
          pid = content[/pid=(\d+)/, 1]&.to_i
          port = content[/port=(\d+)/, 1]&.to_i || Bridge::DEFAULT_PORT

          { pid: pid, port: port }
        end

        # Stop the bridge process
        # @return [Boolean] true if stopped
        def stop_bridge
          return false unless bridge_running?

          pid = File.read(pid_file_path).strip.to_i
          Process.kill('TERM', pid)
          sleep 0.5
          cleanup_stale_files
          true
        rescue Errno::ESRCH
          cleanup_stale_files
          true
        end
      end
    end
  end
end
