# frozen_string_literal: true

module StreamWeaver
  module Components
    # A Projects-style tree for ide_rail_left: a heading with an optional
    # action button, then rows nested by children:. A row with href: is a
    # link; selected: marks the current page, active: the open branch of the
    # tree, disabled: a row that cannot be opened yet (give it a tag: such as
    # "Coming soon").
    #
    # @example
    #   ide_tree(heading: "Projects", action: { label: "New project", icon: :plus },
    #            rows: [
    #              { label: "stream_weaver", icon: :folder, active: true, children: [
    #                { label: "Landing", icon: :file, href: "/", selected: true },
    #                { label: "Docs", icon: :book, disabled: true, tag: "Coming soon" }
    #              ] }
    #            ])
    class IdeTree < Base
      attr_reader :heading, :action, :rows, :options

      # @param heading [String, nil] uppercase heading over the rows
      # @param action [Hash, nil] { label:, icon:, href: } button at the heading's end
      # @param rows [Array<Hash>] { label:, icon:, href:, active:, selected:, disabled:, tag:, children: }
      def initialize(heading: nil, action: nil, rows: [], **options)
        @heading = heading
        @action = action
        @rows = flatten(rows, 0)
        @options = options
      end

      def render(view, state)
        view.adapter.render_ide_tree(view, self, state)
      end

      private

      # Depth-first, each row carrying its :depth.
      def flatten(rows, depth)
        rows.flat_map do |row|
          own = row.reject { |key, _| key == :children }.merge(depth: depth)
          [own, *flatten(row.fetch(:children, []), depth + 1)]
        end
      end
    end

    # A note card with a dismiss button; in ide_rail_left it sits at the
    # bottom of the rail. Pass remember: a key to keep it dismissed across
    # visits (browser localStorage, ignored when storage is unavailable).
    #
    # @example
    #   ide_note(dismiss: "Understood", remember: "workspaces") { text "A workspace is a git worktree." }
    class IdeNote < Base
      attr_accessor :children
      attr_reader :icon, :dismiss_label, :remember, :options

      def initialize(icon: :info, dismiss: "Understood", remember: nil, **options)
        @icon = icon
        @dismiss_label = dismiss
        @remember = remember
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_ide_note(view, self, state)
      end
    end
  end
end
