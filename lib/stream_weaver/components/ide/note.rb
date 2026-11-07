# frozen_string_literal: true

module StreamWeaver
  module Components
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
