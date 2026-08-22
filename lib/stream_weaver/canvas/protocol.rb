# frozen_string_literal: true

require 'json'

module StreamWeaver
  module Canvas
    # Protocol for Unix socket IPC between Claude Code and Canvas Bridge.
    # Uses newline-delimited JSON.
    module Protocol
      # Encode a message hash to newline-delimited JSON
      # @param message [Hash] Message to encode
      # @return [String] JSON string with trailing newline
      def self.encode(message)
        JSON.generate(message) + "\n"
      end

      # Decode a JSON string to a message hash
      # @param json [String] JSON string
      # @return [Hash, nil] Decoded message with symbol keys, or nil if invalid
      def self.decode(json)
        JSON.parse(json, symbolize_names: true)
      rescue JSON::ParserError
        nil
      end

      # Parse a buffer containing potentially multiple messages
      # @param buffer [String] Buffer with newline-delimited JSON
      # @return [Array<Array<Hash>, String>] [messages, remaining_buffer]
      def self.parse_buffer(buffer)
        lines = buffer.split("\n", -1)
        remaining = lines.pop || ''

        messages = lines.filter_map do |line|
          decode(line) unless line.empty?
        end

        [messages, remaining]
      end

      # Message factory methods
      module Messages
        # Claude → Bridge: Create a new session
        def self.create(name, layout: :fluid, theme: :default)
          { type: 'create', name: name, layout: layout, theme: theme }
        end

        # Claude → Bridge: Push DSL content to session
        # @param source_dir [String, nil] Git root of the pushing side's cwd
        #   (DocStore.git_root(Dir.pwd) computed by the caller), or nil
        #   outside a repo. Not the bridge's own cwd -- see Session#source_dir.
        def self.push(name, dsl, source_dir: nil)
          { type: 'push', name: name, dsl: dsl, source_dir: source_dir }
        end

        # Claude → Bridge: Close a session
        def self.close(name)
          { type: 'close', name: name }
        end

        # Claude → Bridge: Set iTerm pane ID for a session
        def self.set_pane_id(name, pane_id)
          { type: 'set_pane_id', name: name, pane_id: pane_id }
        end

        # Bridge → Claude: Session is ready
        def self.ready(name, url)
          { type: 'ready', name: name, url: url }
        end

        # Bridge → Claude: User interaction event
        def self.event(name, event_type, data)
          { type: 'event', name: name, event: event_type, data: data }
        end
      end
    end
  end
end
