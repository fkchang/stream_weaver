# frozen_string_literal: true

module StreamWeaver
  module Components
    # Centralized keyboard shortcut registry.
    # Non-visual component -- emits a <script> block that registers keyboard handlers
    # with context awareness (suppress in text inputs, textareas, code editors).
    #
    # "mod" maps to Meta (Cmd) on Mac, Control elsewhere -- handled in JS.
    #
    # sw- CSS classes: none (non-visual)
    #
    # @example Basic usage
    #   keyboard_shortcuts do |kb|
    #     kb.on "mod+s", context: :global do |state|
    #       # save action
    #     end
    #     kb.on "ArrowRight", context: :navigation do |state|
    #       # next slide
    #     end
    #   end
    class KeyboardShortcuts < Base
      attr_reader :bindings

      # Suppression selectors -- keyboard shortcuts are ignored when
      # the active element matches any of these.
      SUPPRESSION_SELECTORS = %w[
        input[type=text]
        input[type=search]
        input[type=email]
        input[type=url]
        input[type=number]
        input:not([type])
        textarea
        [contenteditable=true]
        .sw-mermaid--zoom
        .sw-code-scroll
      ].freeze

      # @param options [Hash] Additional options
      def initialize(**options)
        @bindings = []
        super(**options)
      end

      # Register a keyboard shortcut binding.
      #
      # @param key_combo [String] Key combination (e.g. "mod+s", "ArrowRight", "1..9")
      # @param context [Symbol] Context for suppression (:global, :navigation, :selection)
      # @param js_action [String, nil] JavaScript code to execute (alternative to block)
      # @param block [Proc, nil] Server-side callback (stored but not executed client-side)
      def on(key_combo, context: :global, js_action: nil, &block)
        @bindings << {
          key: key_combo,
          context: context,
          js_action: js_action,
          callback: block
        }
      end

      def render(view, state)
        view.adapter.render_keyboard_shortcuts(view, self, state)
      end

      # Generate the JS registration calls for all bindings.
      # Each binding becomes a call to swKeyboard.register(...)
      #
      # @return [String] JavaScript code
      def to_js
        lines = @bindings.map do |binding|
          key = binding[:key]
          context = binding[:context]
          action = binding[:js_action] || "console.log('shortcut: #{key}')"

          if key.include?("..")
            # Range shortcut (e.g. "1..9")
            range_start, range_end = key.split("..").map(&:to_i)
            (range_start..range_end).map do |n|
              "swKeyboard.register('#{n}', '#{context}', function(e) { #{action.gsub('KEY', n.to_s)} });"
            end.join("\n")
          else
            "swKeyboard.register('#{key}', '#{context}', function(e) { #{action} });"
          end
        end
        lines.join("\n")
      end

      # CSS class list (empty -- non-visual component)
      def css_classes
        ""
      end
    end
  end
end
