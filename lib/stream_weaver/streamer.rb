# frozen_string_literal: true

require 'json'

module StreamWeaver
  # Thread-safe SSE connection manager with Turbo Stream-like actions.
  # Manages browser SSE connections and broadcasts targeted DOM updates.
  #
  # @example Internal usage (from app stream block)
  #   streamer.replace("#metric-rps", "<div>3500</div>")
  #
  # @example External usage (via POST /stream/push)
  #   curl -X POST localhost:4567/stream/push -d 'target=#metric-rps&html=<div>3500</div>'
  class Streamer
    include Pushable

    ACTIONS = %i[replace append prepend remove add_class remove_class].freeze

    def initialize
      @connections = []
      @mutex = Mutex.new
      @shutting_down = false
    end

    def shutdown!
      @shutting_down = true
    end

    def shutting_down?
      @shutting_down
    end

    def add_connection(conn)
      @mutex.synchronize { @connections << conn }
    end

    def remove_connection(conn)
      @mutex.synchronize { @connections.delete(conn) }
    end

    def connection_count
      @mutex.synchronize { @connections.size }
    end

    private

    def push_update(action:, target:, html: nil, value: nil)
      payload = { action: action, target: target }
      payload[:html] = html if html
      payload[:value] = value if value
      data = payload.to_json
      @mutex.synchronize do
        dead = []
        @connections.each do |conn|
          conn << "data: #{data}\n\n"
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET, Puma::ConnectionError
          dead << conn
        end
        @connections -= dead
      end
    end
  end
end
