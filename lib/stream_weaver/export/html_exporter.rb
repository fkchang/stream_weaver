# frozen_string_literal: true

require 'phlex'
require 'base64'
require 'fileutils'
require_relative '../page_shell'

module StreamWeaver
  module Export
    # Raised when the DSL handed to the exporter isn't a canvas-doc fragment
    # (see HtmlExporter.from_dsl).
    class InvalidDslError < StandardError; end

    # Generates self-contained HTML files from StreamWeaver apps.
    #
    # Collects all CDN links (Mermaid, Chart.js, Prism.js, Google Fonts),
    # inlines all CSS (theme + component styles), and renders the body
    # via Phlex to produce a single .html file that works offline
    # (except for CDN scripts which are preserved as external links).
    #
    # @example Export to file
    #   StreamWeaver::Export::HtmlExporter.export(app, path: "output.html")
    #
    # @example Get HTML string
    #   html = StreamWeaver::Export::HtmlExporter.new(app).to_html
    #
    # @example Export a canvas doc / history snapshot (a DSL fragment on disk)
    #   StreamWeaver::Export::HtmlExporter.from_dsl_file(path).export(path: out)
    #
    # The <head>/<body> shell comes from PageShell, so an export lands in the
    # same cascade order as the canvas and the reader rather than re-deriving
    # its own (stream_weaver-mdc).
    class HtmlExporter
      # Known CDN URLs for components that lazy-load scripts
      CDN_MERMAID = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"
      CDN_CHARTJS = "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"
      CDN_PRISMJS_CSS = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.min.css"
      CDN_PRISMJS_JS = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.min.js"
      CDN_PRISMJS_AUTOLOADER = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/plugins/autoloader/prism-autoloader.min.js"
      CDN_ALPINE = "https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"
      CDN_HTMX = "https://unpkg.com/htmx.org@2.0.4"
      CDN_IDIOMORPH = "https://unpkg.com/idiomorph@0.3.0/dist/idiomorph-ext.min.js"
      CDN_GOOGLE_FONTS = "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap"

      # A canvas-doc DSL fragment is a bare list of component calls -- it is
      # instance_eval'd against an App the caller already made. A full
      # standalone app file builds its own App and starts a server, so
      # eval'ing one here either dies deep inside the DSL or boots a web
      # server mid-export; a plain textual check catches it up front with a
      # message that says what the input should have been.
      #
      # Deliberately literal, and it does not know about strings or comments:
      # a doc whose code_block quotes `App.new` is a false positive. That
      # trade is the right way round -- the export refuses with an
      # explanation, versus silently hanging on a booted server.
      FULL_APP_MARKERS = /App\.new|\.run!/

      # @param app [StreamWeaver::App] The app to export
      # @param state [Hash] State to render with (default: empty)
      # @param base_dir [String, nil] Directory that relative asset paths in
      #   the doc resolve against (the source DSL file's dir). Defaults to
      #   the process working directory.
      def initialize(app, state: {}, base_dir: nil)
        @app = app
        @state = state
        @base_dir = base_dir
        @adapter = StreamWeaver::Adapter::AlpineJS.new
      end

      # Build an exporter from a canvas-doc DSL fragment -- the shape a
      # docs/streamweaver_canvas/*.rb file or a history snapshot has: bare
      # component calls, no requires, no App.new/run! wrapper of its own.
      #
      # @param dsl [String] the fragment
      # @param path [String, nil] source file, used for the <title>, for
      #   relative asset resolution, and so a DSL error names the real file
      # @param theme [Symbol, nil] fallback for a doc with no use_theme
      # @param layout [Symbol, nil] fallback for a doc with no use_layout
      # @raise [InvalidDslError] when the fragment looks like a full app file
      def self.from_dsl(dsl, path: nil, theme: nil, layout: nil)
        if dsl.match?(FULL_APP_MARKERS)
          raise InvalidDslError,
                "expected a canvas-doc DSL fragment (bare component calls) but found " \
                "App.new/run! -- export takes the same input as `streamweaver canvas-push`, " \
                "not a standalone app file"
        end

        title = path ? File.basename(path.to_s, '.rb') : 'StreamWeaver Export'
        app = StreamWeaver::App.new(title, theme: theme || :default, layout: layout || :default)
        app.instance_eval(dsl, path.to_s, 1)
        new(app, base_dir: path && File.dirname(File.expand_path(path)))
      end

      # Reads `path` and builds an exporter from it. See .from_dsl.
      def self.from_dsl_file(path, theme: nil, layout: nil)
        from_dsl(File.read(path), path: path, theme: theme, layout: layout)
      end

      # A download-safe "<name>.html" derived from a source DSL path, allowing
      # the same character set DocStore's doc-name allowlist does. DocStore
      # raises on a bad name because a human typed it; here the name comes
      # from a filesystem path the user didn't choose for this purpose, so we
      # sanitize and fall back rather than fail the export.
      def self.export_filename(source_path)
        name = File.basename(source_path.to_s, '.rb')
                   .gsub(/[^A-Za-z0-9._-]+/, '-')
                   .gsub(/\.{2,}/, '.')
                   .sub(/\A[^A-Za-z0-9]+/, '')
        "#{name.empty? ? 'export' : name}.html"
      end

      # Export to a file
      #
      # @param path [String] Output file path
      # @param inline_images [Boolean] Convert image src to base64 data URIs
      # @return [String] The output file path
      def export(path:, inline_images: false)
        html = to_html(inline_images: inline_images)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
        File.write(path, html)
        path
      end

      # Generate self-contained HTML string
      #
      # @param inline_images [Boolean] Convert local image src to base64 data URIs
      # @return [String] Complete HTML document
      def to_html(inline_images: false)
        # Only block-built apps can be rebuilt. A canvas doc is instance_eval'd
        # from a DSL *string* into a bare App, so @block is nil there and
        # rebuilding would re-evaluate nothing, wiping every component
        # (stream_weaver-65z).
        @app.rebuild_with_state(@state) if @app.block

        body_html = render_body
        body_html = inline_images_in_html(body_html) if inline_images

        build_document(
          title: @app.title,
          css_html: css_html,
          cdn_scripts: collect_cdn_scripts,
          cdn_styles: collect_cdn_styles,
          body_html: body_html
        )
      end

      # Class-level convenience method
      #
      # @param app [StreamWeaver::App] The app to export
      # @param path [String] Output file path
      # @param inline_images [Boolean] Convert local images to base64
      # @return [String] The output file path
      def self.export(app, path:, inline_images: false, state: {})
        new(app, state: state).export(path: path, inline_images: inline_images)
      end

      private

      # Render body components to HTML string via Phlex
      def render_body
        StreamWeaver::ComponentRenderer.render_html(@adapter, @app.components, @state)
      end

      # The <head> style block, in the same cascade order the canvas and the
      # reader use (PageShell is the single source of truth): framework layer,
      # then the app's registered theme, then unlayered user CSS last so it
      # outranks everything.
      def css_html
        parts = [StreamWeaver::PageShell.framework_css_html]

        # Registered custom themes are NOT part of master_theme_css -- AppView
        # emits them separately via render_custom_theme_css, and so must we.
        if (theme = custom_theme)
          parts << "<style>#{StreamWeaver::CSS.layer_wrap(theme.to_css)}</style>"
        end

        parts << StreamWeaver::PageShell.user_css_html(inline_stylesheets: @app.inline_stylesheets)
        parts.join("\n")
      end

      def custom_theme
        return nil if @app.theme.nil? || StreamWeaver::App::BUILT_IN_THEMES.include?(@app.theme)

        StreamWeaver.get_theme(@app.theme)
      end

      def body_class
        "sw-theme-#{@app.theme} sw-layout-#{@app.layout}"
      end

      # Collect CDN script URLs based on what components are used
      def collect_cdn_scripts
        scripts = []

        # Alpine.js and HTMX are always needed for the adapter
        scripts << { src: CDN_ALPINE, defer: true }
        scripts << { src: CDN_HTMX }
        scripts << { src: CDN_IDIOMORPH }

        # Mermaid - check if any mermaid components exist
        if components_include?(Components::Mermaid)
          scripts << { src: CDN_MERMAID, type: "module" }
        end

        # Chart.js
        if components_include?(Components::Chart)
          scripts << { src: CDN_CHARTJS }
        end

        # Prism.js for code blocks
        if components_include?(Components::CodeBlock)
          scripts << { src: CDN_PRISMJS_JS }
          scripts << { src: CDN_PRISMJS_AUTOLOADER }
        end

        # Custom scripts from the app
        @app.scripts.each do |src|
          scripts << { src: src }
        end

        scripts
      end

      # Collect CDN stylesheet URLs
      def collect_cdn_styles
        styles = []

        # Google Fonts
        styles << CDN_GOOGLE_FONTS

        # Prism.js theme CSS
        if components_include?(Components::CodeBlock)
          styles << CDN_PRISMJS_CSS
        end

        # Custom stylesheets from the app
        @app.stylesheets.each do |href|
          styles << href
        end

        styles
      end

      # Check if any component (including nested) is an instance of a class
      def components_include?(klass)
        check_components(@app.components, klass)
      end

      def check_components(components, klass)
        components.any? do |c|
          c.is_a?(klass) ||
            (c.respond_to?(:children) && c.children && check_components(c.children, klass))
        end
      end

      # Replace local image paths with base64 data URIs in HTML.
      # Relative paths resolve against the source DSL file's directory, not
      # Dir.pwd -- a doc referencing ./diagram.png means the one next to it,
      # wherever the export happens to be run from.
      def inline_images_in_html(html)
        html.gsub(/src="((?!data:|https?:\/\/)[^"]+)"/) do |match|
          path = File.expand_path($1, @base_dir || Dir.pwd)
          if File.exist?(path)
            mime = case File.extname(path).downcase
                   when '.png' then 'image/png'
                   when '.jpg', '.jpeg' then 'image/jpeg'
                   when '.gif' then 'image/gif'
                   when '.svg' then 'image/svg+xml'
                   when '.webp' then 'image/webp'
                   else 'application/octet-stream'
                   end
            data = Base64.strict_encode64(File.binread(path))
            "src=\"data:#{mime};base64,#{data}\""
          else
            match
          end
        end
      end

      # Build the complete HTML document
      def build_document(title:, css_html:, cdn_scripts:, cdn_styles:, body_html:)
        script_tags = cdn_scripts.map do |s|
          attrs = ["src=\"#{s[:src]}\""]
          attrs << "defer" if s[:defer]
          attrs << "type=\"#{s[:type]}\"" if s[:type]
          "<script #{attrs.join(' ')}></script>"
        end.join("\n    ")

        style_tags = cdn_styles.map do |href|
          "<link rel=\"stylesheet\" href=\"#{href}\">"
        end.join("\n    ")

        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>#{escape_html(title)}</title>
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            #{style_tags}
            #{script_tags}
          #{css_html}
          </head>
          <body class="#{body_class}">
          <!-- #app-container is a DIRECT body child, as the canvas and reader
               render it: theme/sidebar_toc selectors use the ">" combinator
               against body[class*="sw-layout-"] > #app-container. -->
          <div id="app-container">
            #{body_html}
          </div>
          </body>
          </html>
        HTML
      end

      def escape_html(text)
        text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end
    end
  end
end
