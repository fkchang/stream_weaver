# frozen_string_literal: true

module StreamWeaver
  module Components
    # Side-by-side comparison panels with "before" and "after" named regions.
    #
    # Each panel renders its children independently. On narrow viewports
    # (<768px), panels stack vertically.
    #
    # Uses named block DSL: `before { ... }` and `after { ... }` inside
    # the comparison block populate the two panels.
    #
    # @example
    #   comparison(before_label: "Old", after_label: "New") do
    #     before { text "Version 1" }
    #     after { text "Version 2" }
    #   end
    class Comparison < Base
      attr_reader :before_label, :after_label
      attr_accessor :children, :before_children, :after_children

      # @param before_label [String] Label for the "before" panel
      # @param after_label [String] Label for the "after" panel
      # @param options [Hash] Additional options
      def initialize(before_label: "Before", after_label: "After", **options)
        @before_label = before_label
        @after_label = after_label
        @options = options
        @children = []
        @before_children = []
        @after_children = []
      end

      def render(view, state)
        view.adapter.render_comparison(view, self, state)
      end
    end
  end
end
