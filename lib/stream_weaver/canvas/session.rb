# frozen_string_literal: true

require_relative 'protocol'

module StreamWeaver
  module Canvas
    # Represents a single canvas session with its state and WebSocket connections.
    class Session
      VALID_LAYOUTS = %i[default wide full fluid].freeze

      attr_reader :name, :state, :websockets, :created_at, :layout, :dsl, :theme, :stylesheets, :source_dir
      attr_accessor :html, :html_version, :pane_id

      # @param name [String] Session name
      # @param layout [Symbol] Layout mode: :default (900px), :wide (1100px), :full (1400px), :fluid (100%)
      # @param theme [Symbol] Theme name (e.g. :default, :doc)
      def initialize(name, layout: :fluid, theme: :default)
        @name = name
        @layout = VALID_LAYOUTS.include?(layout) ? layout : :fluid
        @theme = theme
        @state = {}
        @websockets = []
        @created_at = Time.now
        @html = nil
        @html_version = 0
        @dsl = nil
        @stylesheets = []
        @source_dir = nil
        @pending_toasts = []
        @pane_id = nil
        @mutex = Mutex.new
      end

      # Set the rendered HTML content and increment version
      # @param content [String] HTML content
      def set_html(content)
        @html = content
        @html_version += 1
      end

      # Set the raw DSL for this session. Called by Bridge#handle_push only on
      # successful render. Failed renders preserve the last good DSL so the
      # user can still save it.
      # @param content [String] Raw DSL source
      def set_dsl(content)
        @dsl = content
      end

      # Set the directory the current DSL was pushed from. Called by
      # Bridge#handle_push only on successful render, same as #set_dsl -- a
      # failed push must not desync source_dir from the DSL it's paired with
      # (canvas-doc-location-and-discovery.md).
      # @param dir [String, nil] Absolute git root path, or nil outside a repo
      def set_source_dir(dir)
        @source_dir = dir
      end

      # Replace the inline stylesheets carried by the current DSL (stream_weaver-9uk).
      # Replacing rather than accumulating means a re-push with the same (or no)
      # `use_stylesheet` calls never stacks duplicate <style> tags across pushes.
      # @param list [Array<String>] CSS text, deduped
      def set_stylesheets(list)
        @stylesheets = list.uniq
      end

      # Update session state
      # @param new_state [Hash] State to merge
      def update_state(new_state)
        @state.merge!(new_state)
      end

      # Add a WebSocket connection
      # @param ws [Object] WebSocket connection
      def add_websocket(ws)
        @websockets << ws
      end

      # Remove a WebSocket connection
      # @param ws [Object] WebSocket connection
      def remove_websocket(ws)
        @websockets.delete(ws)
      end

      # Broadcast a message to all connected WebSockets
      # @param message [Hash] Message to send
      def broadcast(message)
        encoded = Protocol.encode(message)
        @websockets.each { |ws| ws.send(encoded) }
      end

      def reset!
        @state.clear
        @html = nil
        @stylesheets = []
        @html_version += 1
        @mutex.synchronize { @pending_toasts.clear }
        broadcast(type: 'reset')
      end

      # Queue a toast for polling clients
      def queue_toast(message:, variant: 'warning', duration: 0)
        toast = { message: message, variant: variant, duration: duration }
        @mutex.synchronize { @pending_toasts << toast }
        # Also broadcast to websocket clients
        broadcast(type: 'toast', **toast)
      end

      # Pop all pending toasts (for polling clients)
      def pop_toasts
        @mutex.synchronize do
          toasts = @pending_toasts.dup
          @pending_toasts.clear
          toasts
        end
      end

      # Return session info as a hash
      # @return [Hash]
      def to_h
        {
          name: @name,
          state: @state,
          websocket_count: @websockets.size,
          created_at: @created_at,
          pane_id: @pane_id,
          theme: @theme,
          layout: @layout
        }
      end
    end
  end
end
