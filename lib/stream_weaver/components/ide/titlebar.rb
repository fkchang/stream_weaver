# frozen_string_literal: true

module StreamWeaver
  module Components
    # Title bar of an ide_shell: a logo slot (the block), breadcrumb crumbs,
    # a branch label, link buttons and a light/dark toggle.
    #
    # @example
    #   ide_titlebar(crumbs: ["stream_weaver", "landing"], branch: "main",
    #                links: [{ label: "GitHub", href: "https://github.com/...", icon: "★" }]) do
    #     text "SW"
    #   end
    class IdeTitlebar < IdeRegion
      TAG = :header
      BLOCK = "sw-ide-titlebar"

      attr_reader :crumbs, :branch, :links

      # @param crumbs [Array<String>] breadcrumb trail, the last one current
      # @param branch [String, nil] branch label
      # @param links [Array<Hash>] { label:, href:, icon: } link buttons
      # @param theme_toggle [Boolean] render the light/dark toggle
      def initialize(crumbs: [], branch: nil, links: [], theme_toggle: true, **options)
        super(**options)
        @crumbs = Array(crumbs)
        @branch = branch
        @links = Ide.list(links)
        @theme_toggle = theme_toggle
      end

      def theme_toggle?
        @theme_toggle
      end

      def render(view, state)
        view.adapter.render_ide_titlebar(view, self, state)
      end
    end
  end
end
