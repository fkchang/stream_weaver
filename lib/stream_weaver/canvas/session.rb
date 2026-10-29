# frozen_string_literal: true

require_relative 'protocol'
require_relative 'notes_panel'

module StreamWeaver
  module Canvas
    # Represents a single canvas session with its state and WebSocket connections.
    class Session
      VALID_LAYOUTS = %i[default wide full fluid].freeze

      attr_reader :name, :state, :websockets, :created_at, :layout, :dsl, :theme, :stylesheets, :source_dir
      PENDING_STATES = %w[queued sent].freeze

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
        @notes = []
        @next_note_id = 0
        @regions = {}
        @pane_id = nil
        @mutex = Mutex.new
        @mutex.synchronize { refresh_side_region }
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

      # Hold a viewer comment as `queued` until the agent takes it. Notes never
      # touch websockets or event sinks; they wait here for drain_notes.
      # @return [Integer] pending note count after the append
      def add_note(note)
        @mutex.synchronize do
          @notes << note.merge(id: (@next_note_id += 1), state: 'queued')
          refresh_side_region
          pending_count
        end
      end

      # Return every pending (queued or sent) note and mark them seen, in one
      # locked step.
      def drain_notes
        @mutex.synchronize do
          taken = @notes.select { |n| PENDING_STATES.include?(n[:state]) }
          taken.each { |n| n[:state] = 'seen' }
          refresh_side_region unless taken.empty?
          taken.map(&:dup)
        end
      end

      # A copy of every note with its state, oldest first.
      def notes_snapshot
        @mutex.synchronize { @notes.map(&:dup) }
      end

      # Named page regions (html + version) that the browser swaps on their
      # own, independent of the main doc. Only the bridge writes them.
      # @return [Hash{String=>Hash}] the regions newer than the page's versions
      def regions_newer_than(versions = {})
        @mutex.synchronize do
          @regions.select { |name, r| r[:version] > versions[name].to_i }
                  .transform_values(&:dup)
        end
      end

      def region(name)
        @mutex.synchronize { @regions[name.to_s]&.dup }
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
      private

      def pending_count
        @notes.count { |n| PENDING_STATES.include?(n[:state]) }
      end

      # Re-render the bridge-owned "side" region from the notes state. Caller
      # holds @mutex. The version only moves when the markup does.
      def refresh_side_region
        html = NotesPanel.render(session_name: @name, notes: @notes)
        current = @regions['side']
        return if current && current[:html] == html

        @regions['side'] = { html: html, version: (current ? current[:version] : 0) + 1 }
      end
    end
  end
end
