# frozen_string_literal: true

require 'phlex'
require 'base64'
require 'fileutils'
require 'net/http'
require_relative '../page_shell'

module StreamWeaver
  module Export
    # Raised when the DSL handed to the exporter isn't a canvas-doc fragment
    # (see HtmlExporter.from_dsl).
    class InvalidDslError < StandardError; end

    # Raised when `offline:` can't fetch an asset it needs to inline (see
    # HtmlExporter#mermaid_offline_script_tag).
    class OfflineAssetError < StandardError; end

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
      # The classic/global build (sets globalThis.mermaid), not the ESM one
      # above -- used only by `offline:`, which inlines it as a plain
      # <script> so it's covered by a CSP's 'unsafe-inline', not its
      # (often absent) external-host allowlist. See #mermaid_offline_script_tag.
      CDN_MERMAID_OFFLINE = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"
      CDN_CHARTJS = "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"
      CDN_PRISMJS_CSS = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.min.css"
      CDN_PRISMJS_JS = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.min.js"
      CDN_PRISMJS_AUTOLOADER = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/plugins/autoloader/prism-autoloader.min.js"
      CDN_ALPINE = "https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"
      CDN_GOOGLE_FONTS = "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap"

      # Ground truth for "does this export need Alpine.js" -- see
      # #collect_cdn_scripts.
      ALPINE_DIRECTIVE = /\sx-data=/

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
      # @param offline [Boolean] Fetch and inline mermaid's own library
      #   instead of referencing its CDN, so a diagram renders in a viewer
      #   whose CSP blocks every external host (SharePoint's HTML preview,
      #   etc.) -- see #mermaid_offline_script_tag. Requires network access
      #   at export time; no effect on docs with no mermaid component.
      # @return [String] The output file path
      def export(path:, inline_images: false, offline: false)
        html = to_html(inline_images: inline_images, offline: offline)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
        File.write(path, html)
        path
      end

      # Generate self-contained HTML string
      #
      # @param inline_images [Boolean] Convert local image src to base64 data URIs
      # @param offline [Boolean] see #export
      # @return [String] Complete HTML document
      def to_html(inline_images: false, offline: false)
        # Only block-built apps can be rebuilt. A canvas doc is instance_eval'd
        # from a DSL *string* into a bare App, so @block is nil there and
        # rebuilding would re-evaluate nothing, wiping every component
        # (stream_weaver-65z).
        # ALL_DEFERRED: a static export has no client to run a deferred
        # fragment's auto-fetch, so every deferred block runs inline here or its
        # content is silently lost to a placeholder.
        @app.rebuild_with_state(@state, deferred_target: App::ALL_DEFERRED) if @app.block

        body_html = render_body
        body_html = inline_images_in_html(body_html) if inline_images
        inline_mermaid = offline && components_include?(Components::Mermaid)

        build_document(
          title: @app.title,
          css_html: css_html,
          cdn_scripts: collect_cdn_scripts(body_html, skip_mermaid: inline_mermaid),
          cdn_styles: collect_cdn_styles,
          inline_scripts: inline_mermaid ? [mermaid_offline_script_tag] : [],
          body_html: body_html
        )
      end

      # Class-level convenience method
      #
      # @param app [StreamWeaver::App] The app to export
      # @param path [String] Output file path
      # @param inline_images [Boolean] Convert local images to base64
      # @param offline [Boolean] see #export
      # @return [String] The output file path
      def self.export(app, path:, inline_images: false, offline: false, state: {})
        new(app, state: state).export(path: path, inline_images: inline_images, offline: offline)
      end

      private

      # Render body components to HTML string via Phlex
      def render_body
        StreamWeaver::ComponentRenderer.render_html(@adapter, @app.components, @state)
      end

      # Fetches mermaid's classic global build (sets globalThis.mermaid --
      # not the ESM build CDN_MERMAID points at) and inlines it as a plain
      # <script>. A plain inline script is covered by a CSP's
      # 'unsafe-inline', so it runs even in a viewer whose script-src
      # doesn't allowlist any external host at all (stream_weaver-dnq) --
      # the gap the non-offline fix (stream_weaver-4gs) couldn't close,
      # since that one still referenced mermaid's CDN URL.
      #
      # sw-mermaid-zoom.js's loadMermaid() checks for this global before
      # attempting its own dynamic import, so the rest of the mermaid
      # pipeline (theme vars, zoom/pan, re-init on swap) is unchanged.
      #
      # Does not cover ELK layout (`elk: true` diagrams): ELK ships as a
      # separate CDN module with no equivalent global build to fetch here,
      # so an ELK diagram still needs network access to render even in an
      # offline export. Rare enough (most diagrams use the default layout)
      # that this is a documented limitation, not a blocker for v1.
      #
      # @raise [OfflineAssetError] if the fetch fails -- offline export
      #   still needs network access at *export* time, just not at *view*
      #   time; the message says so rather than surfacing a raw Net::HTTP
      #   or timeout error.
      def mermaid_offline_script_tag
        "<script>#{escape_inline_script(fetch_url(CDN_MERMAID_OFFLINE))}</script>"
      rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, RuntimeError => e
        raise OfflineAssetError,
              "offline export couldn't fetch mermaid's library from #{CDN_MERMAID_OFFLINE} " \
              "(#{e.message}) -- offline export still needs network access once, at export " \
              "time, to embed the library; retry with a connection, or export without --offline"
      end

      # `</script` and `<!--` are the two sequences that can terminate or
      # mis-nest a <script> element's raw text -- the HTML tokenizer closes
      # a script at the first `</script` it sees (case-insensitively, even
      # inside a JS string/template literal/regex), and `<!--` inside a
      # script's raw text starts "script data escaped state", after which
      # the *next* `</script>` doesn't close the element either. Escaped
      # this way both are inert to the tokenizer but unchanged to the JS
      # engine: inside JS, `<\/script` and `<\!--` mean exactly `</script`
      # and `<!--`, and neither is otherwise valid syntax on its own.
      #
      # Scoped to `</` followed specifically by "script" (a lookahead, not
      # consumed) -- NOT every bare `</`. A first draft escaped every `</`
      # and it corrupted real code: mermaid's own minified source contains
      # `/</g` (a regex matching a literal "<"), and blindly inserting a
      # backslash turned it into the invalid regex literal `/<\/g`, a JS
      # syntax error that silently broke the entire inlined script --
      # caught by a live browser check under a CSP that reproduces
      # SharePoint's, not by any spec (none of them parse the output as JS).
      #
      # Correctness here can't rely on mermaid's own minifier already
      # avoiding literal `</script`/`<!--` in its OUTPUT (it does, today) --
      # CDN_MERMAID_OFFLINE is a floating minor-version URL re-fetched on
      # every offline export, so this has to hold regardless of what
      # jsDelivr serves tomorrow.
      def escape_inline_script(js)
        js.gsub(%r{</(?=script)}i, '<\/').gsub('<!--', '<\!--')
      end

      # GET url, following redirects, with a timeout generous enough for
      # mermaid's multi-MB bundle on a slow connection.
      def fetch_url(url, redirects_left: 5)
        raise "too many redirects fetching #{url}" if redirects_left <= 0

        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                         open_timeout: 15, read_timeout: 60) do |http|
          http.get(uri)
        end

        case response
        when Net::HTTPSuccess
          # Net::HTTPResponse#body comes back ASCII-8BIT regardless of the
          # response's actual charset -- force it to UTF-8 (what every
          # asset this fetches in practice is) rather than let a later
          # string interpolation against UTF-8 content (build_document's
          # heredoc) raise Encoding::CompatibilityError deep in an
          # unrelated method.
          body = response.body.dup.force_encoding(Encoding::UTF_8)
          raise "response body is not valid UTF-8" unless body.valid_encoding?

          body
        when Net::HTTPRedirection
          # Location may be relative (RFC 7231) -- resolve against the URL
          # that returned it rather than assuming an absolute URL.
          redirect_uri = URI.join(uri, response['location'])
          raise "redirect to non-https URL: #{redirect_uri}" unless redirect_uri.scheme == 'https'

          fetch_url(redirect_uri.to_s, redirects_left: redirects_left - 1)
        else
          raise "HTTP #{response.code}"
        end
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

      # Collect CDN script URLs based on what's actually in the rendered
      # body.
      #
      # htmx/idiomorph are never included here: a static export has no
      # server to talk to, so they're pure dead weight (and, on a
      # CSP-locked-down viewer such as SharePoint's HTML preview, dead
      # weight that also fails to load at all).
      #
      # Alpine.js is loaded only when the rendered markup actually contains
      # an `x-data=` directive. This is checked against body_html itself
      # rather than an allowlist of component classes: more than a dozen
      # renderers in the adapter (tabs, charts, slide containers, dropdowns,
      # copy buttons, sortable tables, ...) emit Alpine directives, and an
      # allowlist here would silently drift every time one of them changes
      # -- exactly the bug this method used to have, just for Alpine instead
      # of mermaid (stream_weaver-4gs). Mermaid needs no entry in this
      # check: sw-mermaid-zoom.js self-inits without any Alpine directive.
      #
      # @param skip_mermaid [Boolean] true when the caller is inlining
      #   mermaid's library itself (see #mermaid_offline_script_tag) -- the
      #   external CDN reference below would be redundant and, on the CSP
      #   this flag exists to work around, would just be an extra blocked
      #   request.
      def collect_cdn_scripts(body_html, skip_mermaid: false)
        scripts = []

        scripts << { src: CDN_ALPINE, defer: true } if body_html.match?(ALPINE_DIRECTIVE)

        # Mermaid - check if any mermaid components exist
        if components_include?(Components::Mermaid) && !skip_mermaid
          scripts << { src: CDN_MERMAID, type: "module" }
        end

        # Chart.js -- keyed on the whole chart family, not just the one class
        # the generic `chart type:` DSL builds. Every shorthand (bar_chart,
        # pie_chart, sparkline, ...) builds a Components::ChartBase subclass,
        # none of which is a Components::Chart, so gating on Chart alone
        # shipped exports with no library at all; the adapter's
        # `if (typeof Chart !== 'undefined')` x-init guard then swallowed it
        # into an empty box with a silent console (disc-094). Naming the base
        # class means a new chart type is covered the moment it subclasses.
        if components_include?(Components::Chart) || components_include?(Components::ChartBase)
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
      #
      # @param inline_scripts [Array<String>] raw "<script>...</script>"
      #   blocks (offline-fetched assets) emitted after cdn_scripts, so an
      #   inlined replacement -- e.g. mermaid's library -- is present before
      #   any script later in the document expects it.
      def build_document(title:, css_html:, cdn_scripts:, cdn_styles:, body_html:, inline_scripts: [])
        tags = cdn_scripts.map { |s| cdn_script_tag(s) } + inline_scripts
        script_tags = tags.join("\n    ")

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

      def cdn_script_tag(script)
        attrs = ["src=\"#{escape_html(script[:src])}\""]
        attrs << "defer" if script[:defer]
        attrs << "type=\"#{script[:type]}\"" if script[:type]
        "<script #{attrs.join(' ')}></script>"
      end

      def escape_html(text)
        text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end
    end
  end
end
