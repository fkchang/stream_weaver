# frozen_string_literal: true

module StreamWeaver
  module Components
    # Status bar of an ide_shell: left items, then right items pushed to the
    # far end. An item is a String, or { label:, href: } for a link (text
    # only: no icon, and no new-tab behaviour as on title bar links). Block
    # children render after the left items.
    #
    # @example
    #   ide_statusbar(left: ["MIT", { label: "StreamWeaver", href: "https://..." }],
    #                 right: ["Ruby 3.3"])
    class IdeStatusbar < IdeRegion
      TAG = :footer
      BLOCK = "sw-ide-statusbar"

      attr_reader :left, :right

      def initialize(left: [], right: [], **options)
        super(**options)
        @left = Ide.list(left)
        @right = Ide.list(right)
      end

      def render(view, state)
        view.adapter.render_ide_statusbar(view, self, state)
      end
    end
  end
end
