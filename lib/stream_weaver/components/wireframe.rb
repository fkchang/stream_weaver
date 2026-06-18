# frozen_string_literal: true

module StreamWeaver
  module Components
    # HTML mockup wrapped in device chrome matching the surface type.
    # Renders the author's HTML fragment inside a visual device frame —
    # browser window, phone bezel, desktop window, or compact floating frame.
    #
    # @example
    #   wireframe(surface: :browser) do
    #     "<h1>Login</h1><button class=\"primary\">Sign in</button>"
    #   end
    class Wireframe < Base
      SURFACES = %w[browser desktop mobile phone tablet popover card widget panel].freeze

      attr_reader :html, :surface

      def initialize(html: "", surface: :browser, **options)
        @html    = html
        @surface = SURFACES.include?(surface.to_s) ? surface.to_s : "browser"
        @options = options
      end

      def render(view, state)
        view.adapter.render_wireframe(view, self, state)
      end
    end
  end
end
