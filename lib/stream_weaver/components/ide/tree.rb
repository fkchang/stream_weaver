# frozen_string_literal: true

module StreamWeaver
  module Components
    # A Projects-style tree for ide_rail_left: a heading with an optional
    # action link, then rows nested by children:. A row with href: is a
    # link; selected: marks the current page, active: the open branch of the
    # tree, disabled: a row that cannot be opened yet (give it a tag: such as
    # "Coming soon").
    #
    # @example
    #   ide_tree(heading: "Projects", action: { label: "New project", icon: :plus, href: "/new" },
    #            rows: [
    #              { label: "stream_weaver", icon: :folder, active: true, children: [
    #                { label: "Landing", icon: :file, href: "/", selected: true },
    #                { label: "Docs", icon: :book, disabled: true, tag: "Coming soon" }
    #              ] }
    #            ])
    class IdeTree < Base
      attr_reader :heading, :action, :rows, :options

      # @param heading [String, nil] uppercase heading over the rows
      # @param action [Hash, nil] { label:, href:, icon: } link at the heading's end
      # @param rows [Array<Hash>] { label:, icon:, href:, active:, selected:, disabled:, tag:, children: }
      # @raise [ArgumentError] when the action has no href:
      def initialize(heading: nil, action: nil, rows: [], **options)
        raise ArgumentError, "ide_tree action: needs an href:" if action && !action[:href]

        @heading = heading
        @action = action
        @rows = flatten(rows, 0)
        @options = options
      end

      def render(view, state)
        view.adapter.render_ide_tree(view, self, state)
      end

      private

      # Depth-first, each row carrying its :depth, and :parent when it has
      # children.
      def flatten(rows, depth)
        rows.flat_map do |row|
          children = row.fetch(:children, [])
          own = row.reject { |key, _| key == :children }.merge(depth: depth, parent: children.any?)
          [own, *flatten(children, depth + 1)]
        end
      end
    end
  end
end
