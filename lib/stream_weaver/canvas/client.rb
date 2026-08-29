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
        # STREAMWEAVER_CANVAS_SOCKET / _PID redirect the whole bridge --
        # socket, pid file, and (because the bridge is spawned with the
        # environment it inherits) the server half too. This exists so a
        # test, or a deliberately separate instance, can run its own bridge
        # without stopping the one the developer has open in a browser and
        # taking every live canvas session with it.
        def socket_path
          ENV['STREAMWEAVER_CANVAS_SOCKET'] || SOCKET_PATH
        end

        def pid_file_path
          ENV['STREAMWEAVER_CANVAS_PID'] || PID_FILE_PATH
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

        # Hold ONE connection open and yield every event for `name` until the
        # bridge closes it or the block breaks. This is what a long-lived
        # listener wants: `send_and_wait` takes a single event and closes the
        # socket, so a loop built on it is deaf for the whole gap between
        # handling one click and reopening -- which is exactly when the
        # re-push is happening and the user is most likely to click again.
        #
        # Events are filtered by session name because the bridge forwards
        # every session's events to every connected client
        # (docs/bug-2026-08-24-canvas-bridge-broadcasts-no-session-filtering.md).
        #
        # @param name [String, nil] session to filter on; nil yields all
        # @yield [Hash] each event message
        def each_event(name = nil)
          raise NotRunningError, "Canvas bridge is not running" unless bridge_running?

          socket = UNIXSocket.new(socket_path)
          buffer = ''

          loop do
            # readpartial blocks until there are bytes and raises at EOF --
            # no poll interval to burn, and no third spelling of "closed".
            # A peer reset is the same event as a clean close as far as this
            # loop is concerned: the bridge is gone, so return and let the
            # caller decide whether to reconnect.
            buffer += socket.readpartial(4096)

            messages, buffer = Protocol.parse_buffer(buffer)
            messages.each do |msg|
              next unless msg[:type] == 'event'
              next if name && msg[:name] != name

              yield msg
            end
          rescue EOFError, Errno::ECONNRESET
            break
          end
        rescue Errno::ECONNREFUSED, Errno::ENOENT => e
          raise ConnectionError, "Cannot connect to canvas bridge: #{e.message}"
        ensure
          socket&.close
        end

        # Start the bridge process if not running
        # @return [Hash] { pid: Integer, port: Integer }
        def ensure_bridge_running
          if bridge_running?
            info = read_bridge_info
            # Verify HTTP server is actually responding
            if info && info[:port] && http_healthy?(info[:port])
              return info
            end
            # Bridge process exists but HTTP not responding - restart
            cleanup_stale_files
          end

          start_bridge
        end

        # Check if HTTP server is responding on given port
        def http_healthy?(port)
          require 'net/http'
          uri = URI("http://127.0.0.1:#{port}/health")
          response = Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
            http.get(uri.path)
          end
          response.is_a?(Net::HTTPSuccess)
        rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::OpenTimeout, Net::ReadTimeout
          false
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

          info = read_bridge_info
          if info && info[:port]
            require 'net/http'
            begin
              Net::HTTP.start('127.0.0.1', info[:port], open_timeout: 2, read_timeout: 2) do |http|
                http.post('/shutdown', '')
              end
              sleep 0.5
            rescue StandardError
              # HTTP shutdown failed — fall back to SIGTERM
              pid = info[:pid] || File.read(pid_file_path)[/pid=(\d+)/, 1]&.to_i
              Process.kill('TERM', pid) if pid
              sleep 0.5
            end
          end

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
