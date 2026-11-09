# frozen_string_literal: true

require_relative '../page_shell'

module StreamWeaver
  module Canvas
    # A DSL body rendered as page content, plus the theme, layout and inline
    # CSS it declared for itself. The live canvas (Bridge#handle_push) and
    # canvas-read (Reader.render_doc) both render a body through here, so
    # the same body resolves to the same page in both (disc-127).
    #
    # Rendering goes through AppContentView, which does not evaluate
    # exclusive-layout render blocks or layout slots (AppView-only), so
    # `layout` reaches only body-class / CSS-selector level layout.
    Fragment = Struct.new(:html, :theme, :layout, :inline_stylesheets, keyword_init: true) do
      # Evaluates `dsl` in an App seeded with `theme` and `layout`: the
      # body's own use_theme / use_layout win, the seeds stand in otherwise.
      # Raises whatever the body raises; each caller decides what a failure
      # looks like.
      #
      # @param adapter [Adapter::AlpineJS] the host's adapter (the canvas is
      #   live, canvas-read is inert)
      # @param path [String, nil] the source file, so a DSL error names it
      # @return [Fragment]
      def self.render(dsl, adapter:, theme: :default, layout: :fluid, path: nil)
        app = StreamWeaver::App.new('Canvas', theme: theme, layout: layout)
        app.instance_eval(dsl, path || '(eval)', 1)
        html = StreamWeaver::Views::AppContentView.new(app, {}, adapter, false,
                                                       delivery: StreamWeaver::Delivery::Served.new).call
        new(html: html, theme: app.theme, layout: app.layout, inline_stylesheets: app.fragment_css)
      end

      # @return [PageShell::Page] what the page around this content needs
      def page
        PageShell.fragment_page(theme: theme, layout: layout, user_css: inline_stylesheets)
      end
    end
  end
end
