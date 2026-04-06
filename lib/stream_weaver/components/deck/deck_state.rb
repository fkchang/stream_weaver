# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'securerandom'

module StreamWeaver
  module Components
    module Deck
      # File-backed state store for design deck selections, notes, and
      # generate-more request queue.
      # Keyed by session ID. Each session gets a JSON file in tmp/deck_state/.
      #
      # Thread-safe via file locking (flock). Multiple Puma threads and
      # background agent threads can safely read/write the same file.
      #
      # State shape:
      #   {
      #     "selections"     => { "slide_id" => "option_label" },
      #     "notes"          => { "slide_id" => { "option_label" => "text" } },
      #     "generate"       => { "status" => "idle", ... },
      #     "generate_queue" => [ { request data } ],
      #     "generated_options" => { "slide_id" => [ { option data } ] }
      #   }
      #
      # @example
      #   state = DeckState.new("abc123")
      #   state.select("arch", "Monolith")
      #   state.set_note("arch", "Monolith", "Simple deployment")
      #   state.selected?("arch", "Monolith") # => true
      #   state.selection("arch")              # => "Monolith"
      #   state.note("arch", "Monolith")       # => "Simple deployment"
      class DeckState
        attr_reader :session_id

        # Base directory for state files (relative to app working dir)
        DEFAULT_STATE_DIR = "tmp/deck_state"

        # @param session_id [String] Unique session identifier
        # @param state_dir [String] Override state directory (for testing)
        def initialize(session_id, state_dir: nil)
          @session_id = session_id
          @state_dir = state_dir || DEFAULT_STATE_DIR
          ensure_state_dir!
        end

        # Generate a new unique session ID
        # @return [String] UUID-style session ID
        def self.generate_session_id
          SecureRandom.uuid
        end

        # Get or create a DeckState for the given session.
        # Generates a new session ID if none provided.
        #
        # @param session_id [String, nil] Existing session ID or nil
        # @param state_dir [String, nil] Override state directory
        # @return [DeckState] The state instance
        def self.for_session(session_id = nil, state_dir: nil)
          session_id ||= generate_session_id
          new(session_id, state_dir: state_dir)
        end

        # Select an option for a slide (radio semantics: one per slide)
        #
        # @param slide_id [String] Slide identifier
        # @param option_label [String] Option label to select
        def select(slide_id, option_label)
          with_lock(:write) do |data|
            data["selections"][slide_id.to_s] = option_label.to_s
            data
          end
        end

        # Get the selected option label for a slide
        #
        # @param slide_id [String] Slide identifier
        # @return [String, nil] Selected option label or nil
        def selection(slide_id)
          read_data["selections"][slide_id.to_s]
        end

        # Check if a specific option is selected for a slide
        #
        # @param slide_id [String] Slide identifier
        # @param option_label [String] Option label to check
        # @return [Boolean]
        def selected?(slide_id, option_label)
          selection(slide_id) == option_label.to_s
        end

        # Get all selections
        # @return [Hash] { slide_id => option_label }
        def selections
          read_data["selections"]
        end

        # Set a note for an option on a slide
        #
        # @param slide_id [String] Slide identifier
        # @param option_label [String] Option label
        # @param text [String] Note text
        def set_note(slide_id, option_label, text)
          with_lock(:write) do |data|
            data["notes"][slide_id.to_s] ||= {}
            data["notes"][slide_id.to_s][option_label.to_s] = text.to_s
            data
          end
        end

        # Get the note for an option on a slide
        #
        # @param slide_id [String] Slide identifier
        # @param option_label [String] Option label
        # @return [String, nil] Note text or nil
        def note(slide_id, option_label)
          notes = read_data["notes"][slide_id.to_s]
          notes&.dig(option_label.to_s)
        end

        # Get all notes
        # @return [Hash] { slide_id => { option_label => text } }
        def notes
          read_data["notes"]
        end

        # Mark this deck as submitted
        def submit!
          with_lock(:write) do |data|
            data["submitted"] = true
            data
          end
        end

        # Check if this deck has been submitted
        # @return [Boolean]
        def submitted?
          read_data["submitted"] == true
        end

        # Set the final notes (overall comments on the summary slide)
        #
        # @param text [String] Final notes text
        def set_final_notes(text)
          with_lock(:write) do |data|
            data["final_notes"] = text.to_s
            data
          end
        end

        # Get the final notes
        # @return [String, nil]
        def final_notes
          read_data["final_notes"]
        end

        # =========================================
        # Model Selector State (T14)
        # =========================================

        # Set the selected AI model for generate-more.
        #
        # @param model_id [String] Model identifier
        def set_model(model_id)
          with_lock(:write) do |data|
            data["selected_model"] = model_id.to_s
            data
          end
        end

        # Get the currently selected model ID.
        # @return [String, nil]
        def selected_model
          read_data["selected_model"]
        end

        # =========================================
        # Generate-More State (T10)
        # =========================================

        # Start a generate request. Transitions to :generating.
        # Returns the request_id for versioning.
        #
        # @param slide_id [String] Slide to generate options for
        # @param count [Integer] Number of options to generate
        # @param prompt [String, nil] User's custom prompt
        # @return [String] The request_id
        def start_generate(slide_id, count, prompt: nil)
          request_id = SecureRandom.hex(8)
          with_lock(:write) do |data|
            data["generate"] = {
              "status" => "generating",
              "slide_id" => slide_id.to_s,
              "requested_count" => count,
              "received_count" => 0,
              "prompt" => prompt,
              "request_id" => request_id,
              "started_at" => Time.now.to_f
            }
            # Queue the request for agent polling
            data["generate_queue"] ||= []
            data["generate_queue"] << {
              "session_id" => @session_id,
              "slide_id" => slide_id.to_s,
              "count" => count,
              "prompt" => prompt,
              "request_id" => request_id,
              "timestamp" => Time.now.to_f
            }
            data
          end
          request_id
        end

        # Cancel a pending generation. Transitions to :idle.
        # Sets a cancellation flag so agents can detect it.
        def cancel_generate
          with_lock(:write) do |data|
            gen = data["generate"] || {}
            if gen["status"] == "generating"
              gen["status"] = "cancelled"
              data["generate"] = gen
              # Remove from queue
              data["generate_queue"] = []
            end
            data
          end
        end

        # Transition a timed-out or cancelled generate to idle.
        def reset_generate
          with_lock(:write) do |data|
            gen = data["generate"] || {}
            gen["status"] = "idle"
            data["generate"] = gen
            data
          end
        end

        # Mark generation as timed out.
        def timeout_generate
          with_lock(:write) do |data|
            gen = data["generate"] || {}
            if gen["status"] == "generating"
              gen["status"] = "timed_out"
              data["generate"] = gen
            end
            data
          end
        end

        # Get the current generate state hash.
        # @return [Hash] Generate state or empty idle state
        def generate_state
          data = read_data
          data["generate"] || { "status" => "idle" }
        end

        # Check if currently generating.
        # @return [Boolean]
        def generating?
          generate_state["status"] == "generating"
        end

        # Get the generate status.
        # @return [Symbol] :idle, :generating, :timed_out, :cancelled
        def generate_status
          (generate_state["status"] || "idle").to_sym
        end

        # Take pending requests from the queue (for agent polling).
        # Returns pending requests and clears the queue atomically.
        #
        # @return [Array<Hash>] Pending requests
        def take_pending_requests!
          requests = []
          with_lock(:write) do |data|
            requests = data["generate_queue"] || []
            data["generate_queue"] = []
            data
          end
          requests
        end

        # Add a generated option to the state (called by agent).
        # Increments received_count and transitions to :idle when all received.
        #
        # @param slide_id [String] Slide the option belongs to
        # @param option_data [Hash] Option data (label, description, etc.)
        # @param request_id [String] Request ID for versioning
        # @return [Hash] Updated generate state
        def add_generated_option(slide_id, option_data, request_id:)
          result_gen = nil
          with_lock(:write) do |data|
            gen = data["generate"] || {}

            # Request versioning: ignore stale pushes
            if gen["request_id"] != request_id
              result_gen = gen
              next data
            end

            # Ignore if cancelled or timed out
            unless gen["status"] == "generating"
              result_gen = gen
              next data
            end

            # Add option to generated_options store
            data["generated_options"] ||= {}
            data["generated_options"][slide_id.to_s] ||= []
            data["generated_options"][slide_id.to_s] << option_data.merge("generated" => true)

            # Update received count
            gen["received_count"] = (gen["received_count"] || 0) + 1

            # If all received, transition to idle
            if gen["received_count"] >= gen["requested_count"]
              gen["status"] = "idle"
            end

            data["generate"] = gen
            result_gen = gen.dup
            data
          end
          result_gen || { "status" => "idle" }
        end

        # Get generated options for a slide.
        # @param slide_id [String] Slide identifier
        # @return [Array<Hash>] Generated options
        def generated_options(slide_id)
          data = read_data
          (data["generated_options"] || {})[slide_id.to_s] || []
        end

        # Get all generated options across all slides.
        # @return [Hash] { slide_id => [options] }
        def all_generated_options
          read_data["generated_options"] || {}
        end

        # Check if a generate request has been cancelled.
        # @return [Boolean]
        def generate_cancelled?
          generate_state["status"] == "cancelled"
        end

        # Read all state data
        # @return [Hash] Full state hash
        def to_h
          read_data
        end

        # Clear all state for this session
        def clear!
          with_lock(:write) do |_data|
            empty_state
          end
        end

        # Delete the state file entirely
        def delete!
          File.delete(state_file_path) if File.exist?(state_file_path)
        end

        # Path to the JSON state file
        # @return [String]
        def state_file_path
          File.join(@state_dir, "#{@session_id}.json")
        end

        # Clean up stale state files older than the given age
        #
        # @param max_age_seconds [Integer] Maximum age in seconds (default: 24 hours)
        # @param state_dir [String] Override state directory
        # @return [Integer] Number of files cleaned up
        def self.cleanup_stale(max_age_seconds: 86400, state_dir: DEFAULT_STATE_DIR)
          return 0 unless Dir.exist?(state_dir)

          count = 0
          cutoff = Time.now - max_age_seconds
          Dir.glob(File.join(state_dir, "*.json")).each do |file|
            if File.mtime(file) < cutoff
              File.delete(file) rescue nil
              count += 1
            end
          end
          count
        end

        private

        def empty_state
          {
            "selections" => {},
            "notes" => {},
            "submitted" => false,
            "final_notes" => "",
            "generate" => { "status" => "idle" },
            "generate_queue" => [],
            "generated_options" => {}
          }
        end

        def ensure_state_dir!
          FileUtils.mkdir_p(@state_dir) unless Dir.exist?(@state_dir)
        end

        # Read state from file. Returns empty state if file doesn't exist.
        def read_data
          with_lock(:read) do |data|
            data
          end
        end

        # Execute a block with file locking.
        # For :write mode, the block receives current data and must return updated data.
        # For :read mode, the block receives current data and returns it.
        def with_lock(mode)
          path = state_file_path
          lock_mode = (mode == :write) ? File::LOCK_EX : File::LOCK_SH

          # Create file if it doesn't exist
          unless File.exist?(path)
            if mode == :write
              File.open(path, File::CREAT | File::WRONLY | File::EXCL) do |f|
                f.flock(File::LOCK_EX)
                f.write(JSON.generate(empty_state))
              end rescue Errno::EEXIST
              # If EEXIST, another thread created it -- that's fine
            else
              return yield(empty_state)
            end
          end

          File.open(path, "r+") do |f|
            f.flock(lock_mode)
            content = f.read
            data = content.empty? ? empty_state : JSON.parse(content)

            result = yield(data)

            if mode == :write
              f.rewind
              f.truncate(0)
              f.write(JSON.generate(result))
              f.flush
            end

            result
          end
        rescue JSON::ParserError
          # Corrupted file -- reset to empty
          if mode == :write
            File.open(path, "w") do |f|
              f.flock(File::LOCK_EX)
              result = yield(empty_state)
              f.write(JSON.generate(result))
              result
            end
          else
            yield(empty_state)
          end
        end
      end
    end
  end
end
