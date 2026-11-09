# frozen_string_literal: true

require_relative 'protocol'
require_relative 'notes_panel'
require_relative '../page_shell'

module StreamWeaver
  module Canvas
    # Represents a single canvas session with its state and WebSocket connections.
    class Session
      VALID_LAYOUTS = %i[default wide full fluid].freeze

      attr_reader :name, :state, :websockets, :created_at, :layout, :dsl, :theme, :stylesheets, :source_dir
      PENDING_STATES = %w[queued sent].freeze
      SUMMARY_MAX = 500

      attr_accessor :html, :html_version, :pane_id

      # @param name [String] Session name
      # @param layout [Symbol] Layout mode: :default (900px), :wide (1100px), :full (1400px), :fluid (100%)
      # @param theme [Symbol] Theme name (e.g. :default, :doc)
      def initialize(name, layout: :fluid, theme: :default)
        @name = name
        @layout = VALID_LAYOUTS.include?(layout) ? layout : :fluid
        @theme = theme
        @page_theme = nil
        @page_layout = nil
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
        @waiters = 0
        @ended_unread = false
        @review_ended = false
        @closed = false
        @doc_updated = false
        @summary = nil
        @round = 0
        @round_summaries = {}
        @annotate = false
        @cv = ConditionVariable.new
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

      # A successful push: its content, the theme, layout and inline CSS it
      # resolved to, its DSL and the directory it came from, written in one
      # locked step so a poll (#snapshot) never pairs one push's HTML with
      # another's version or page. Bridge#handle_push calls it only after
      # the body rendered, so a failed push keeps everything the page had.
      # @param fragment [Fragment]
      def publish(fragment, dsl:, source_dir:)
        @mutex.synchronize do
          @page_theme = fragment.theme
          @page_layout = fragment.layout
          @stylesheets = fragment.inline_stylesheets.uniq
          @dsl = dsl
          @source_dir = source_dir
          @html = fragment.html
          @html_version += 1
        end
      end

      # The theme and layout on the page now: the last good push's
      # use_theme / use_layout, else the ones the session was created with
      # (#theme, #layout, which a push's render falls back to).
      def current_theme
        @page_theme || @theme
      end

      def current_layout
        @page_layout || @layout
      end

      # What the page needs for the current push: the same recipe as
      # canvas-read's Reader.page_for (PageShell.fragment_page), so the live
      # canvas and canvas-read agree for the same body (disc-127).
      # @return [StreamWeaver::PageShell::Page]
      def page
        snapshot[:page]
      end

      # The content, its version and its page, read in one locked step.
      # @param since [Integer, nil] the version a poller already has: the
      #   page is resolved and included only when this one is newer
      # @return [Hash] { html:, version:, page: } (page omitted when not newer)
      def snapshot(since: nil)
        html, version, theme, layout, user_css =
          @mutex.synchronize { [@html, @html_version, current_theme, current_layout, @stylesheets] }
        return { html: html, version: version } if since && version <= since

        { html: html, version: version,
          page: StreamWeaver::PageShell.fragment_page(theme: theme, layout: layout, user_css: user_css) }
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
        @mutex.synchronize do
          @html = nil
          @stylesheets = []
          @page_theme = nil
          @page_layout = nil
          @html_version += 1
          @pending_toasts.clear
        end
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
          # A comment after Send & End starts a fresh review: clear the ended
          # banner AND an unread end flag, or the next wait would stop the agent
          # with the new batch.
          @review_ended = false
          @ended_unread = false
          refresh_side_region
          pending_count
        end
      end

      # Change the text of a note that has not been sent yet.
      # @return [Boolean] false when the note is unknown or no longer queued
      def update_note(id, text)
        @mutex.synchronize do
          note = @notes.find { |n| n[:id] == id && n[:state] == 'queued' }
          next false unless note

          note[:text] = text
          refresh_side_region
          true
        end
      end

      # Remove a note that has not been sent yet.
      # @return [Boolean] false when the note is unknown or no longer queued
      def remove_note(id)
        @mutex.synchronize do
          removed = @notes.reject! { |n| n[:id] == id && n[:state] == 'queued' }
          refresh_side_region if removed
          !removed.nil?
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

      # Send to Agent / Send & End: move EVERY queued note to sent in one locked
      # step and wake any waiting agent. A batch nobody waits for stays sent
      # until a wait or a pull takes it, so a Send with no waiter loses nothing.
      # @return [Hash] { sent: Integer, ended: Boolean }
      def send_queued(end_review: false)
        @mutex.synchronize do
          queued = @notes.select { |n| n[:state] == 'queued' }
          # Each Send starts a round; the comments sent together share its number.
          # Earlier summaries stay: only reply writes them, one per round it closes.
          @round += 1 unless queued.empty?
          queued.each { |n| n.merge!(state: 'sent', round: @round) }
          @doc_updated = false unless queued.empty?
          if end_review
            @ended_unread = true
            @review_ended = true
          end
          refresh_side_region
          @cv.broadcast
          { sent: queued.size, ended: end_review }
        end
      end

      # Block until a batch has been sent (or the review ended), hand it over
      # exactly once and mark it seen. A wait started after Send returns at
      # once with the unread batch. While this runs the panel says the agent is
      # waiting; `alive` is polled so a killed wait clears quickly.
      # @param alive [#call] false once the waiting client is gone
      # @return [Hash, nil] { notes:, ended: }, { closed: true }, or nil on
      #   timeout or a vanished client
      def wait_for_submit(alive: -> { true }, timeout: nil, poll: 0.25)
        deadline = timeout && (Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout)
        @mutex.synchronize { @waiters += 1; refresh_side_region }
        begin
          loop do
            batch = @mutex.synchronize do
              take_batch || (@closed ? { closed: true } : (@cv.wait(@mutex, poll) && nil))
            end
            return batch if batch
            return nil unless alive.call
            return nil if deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          end
        ensure
          @mutex.synchronize { @waiters -= 1; refresh_side_region }
        end
      end

      # The main doc was re-pushed. Comments the agent has read move to
      # Working, and if a batch is in flight the panel says the doc changed.
      # Region markup is untouched by the push itself; only this state is.
      def doc_pushed!
        @mutex.synchronize do
          in_flight = @notes.select { |n| %w[sent seen working].include?(n[:state]) }
          next if in_flight.empty?

          in_flight.each { |n| n[:state] = 'working' if n[:state] == 'seen' }
          @doc_updated = true
          refresh_side_region
        end
      end

      # The agent's one-line answer to the batch: shown (escaped) in the panel,
      # and every in-flight comment becomes Done.
      # @return [Integer] how many comments were marked done
      def reply(summary)
        @mutex.synchronize do
          done = @notes.select { |n| %w[sent seen working].include?(n[:state]) }
          done.each { |n| n[:state] = 'done' }
          @summary = summary.to_s.gsub(/\s+/, ' ').strip[0, SUMMARY_MAX]
          done.filter_map { |n| n[:round] }.uniq.each { |r| @round_summaries[r] = @summary }
          refresh_side_region
          done.size
        end
      end

      # Annotate mode (a click comments instead of pressing) is held here so a
      # reload or a second tab shows the same state.
      def annotate?
        @mutex.synchronize { @annotate }
      end

      def annotate=(on)
        @mutex.synchronize do
          @annotate = on ? true : false
          refresh_side_region
        end
      end

      def close!
        @mutex.synchronize { @closed = true; @cv.broadcast }
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
          theme: current_theme,
          layout: current_layout
        }
      end
      private

      # Caller holds @mutex. Sent notes (and a pending end-of-review) are
      # handed to exactly one taker; they become seen.
      def take_batch
        sent = @notes.select { |n| n[:state] == 'sent' }
        return nil if sent.empty? && !@ended_unread

        sent.each { |n| n[:state] = 'seen' }
        ended = @ended_unread
        @ended_unread = false
        refresh_side_region
        { notes: sent.map(&:dup), ended: ended }
      end

      def pending_count
        @notes.count { |n| PENDING_STATES.include?(n[:state]) }
      end

      # Re-render the bridge-owned "side" region from the notes state. Caller
      # holds @mutex. The version only moves when the markup does.
      def refresh_side_region
        html = NotesPanel.render(session_name: @name, notes: @notes, agent_waiting: @waiters.positive?, review_ended: @review_ended,
                                 doc_updated: @doc_updated, summary: @summary, annotate: @annotate,
                                 round_summaries: @round_summaries)
        current = @regions['side']
        return if current && current[:html] == html

        @regions['side'] = { html: html, version: (current ? current[:version] : 0) + 1 }
      end
    end
  end
end
