# frozen_string_literal: true

module StreamWeaver
  module Components
    # A wireframe surface block that renders raw HTML as a hand-drawn mockup.
    # Provides scoped --wf-* CSS tokens and helper classes within .sw-wireframe-surface.
    #
    # All styling is intentionally scoped to .sw-wireframe-surface so wireframe
    # aesthetics cannot leak into the surrounding app UI.
    #
    # CSS tokens and helper classes are injected inline by the adapter (same pattern
    # as other canvas components). See AlpineJS#wireframe_css for the full token set.
    #
    # @example
    #   wireframe_block(html: "<h1>Login</h1><button class=\"primary\">Sign in</button>")
    class WireframeBlock < Base
      SURFACES = %w[browser desktop mobile popover panel].freeze

      attr_reader :html, :surface

      # @param html [String] Raw HTML fragment to display inside the wireframe surface
      # @param surface [String] Surface type: browser, desktop, mobile, popover, panel
      def initialize(html: "", surface: "browser", **options)
        @html    = html
        @surface = SURFACES.include?(surface) ? surface : "browser"
        @options = options
      end

      def render(view, state)
        view.adapter.render_wireframe_block(view, self, state)
      end
    end
  end
end
