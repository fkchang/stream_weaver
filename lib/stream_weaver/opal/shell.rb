# frozen_string_literal: true

module StreamWeaver
  module Opal
    class OpalShell
      MORPHDOM_CDN = "https://unpkg.com/morphdom@2.7.4/dist/morphdom.min.js"
      MARKED_CDN   = "https://cdn.jsdelivr.net/npm/marked/lib/marked.umd.js"
      PRISM_CDN     = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.min.js"
      PRISM_CSS_CDN = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.min.css"
      MERMAID_CDN   = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"
      DIFF_CDN      = "https://cdn.jsdelivr.net/npm/diff@5.2.0/dist/diff.min.js"

      # Typesets diagrams and highlights code once the runtime has painted.
      #
      # Prism scans the DOM for its own markup, so it has to run after
      # SWRuntime.start() rather than on DOMContentLoaded.
      #
      # Diagrams are handled by sw-mermaid-zoom.js (swMermaidInit), not
      # mermaid.run() directly: Adapter::Static#render_mermaid (shared by
      # both adapters, stream_weaver-mermaid-extension) writes the mermaid
      # source into a data attribute rather than element text, and only
      # sw-mermaid-zoom.js reads that shape. It owns mermaid.initialize(),
      # theme variables, and its own data-sw-mermaid-done idempotency guard,
      # so nothing else here needs to re-init mermaid or track processed
      # nodes. If a build omits it (see OpalBuilder#copy_browser_assets --
      # currently unconditional, so this is a defensive check, not an
      # expected path), diagrams render as empty boxes rather than raising.
      ENHANCE_JS = <<~JS.freeze
        (function() {
          function highlight() {
            if (typeof Prism !== "undefined") Prism.highlightAll();
          }
          function diagrams() {
            if (typeof swMermaidInit === "function") swMermaidInit();
          }
          function enhance() { highlight(); diagrams(); }
          document.addEventListener("sw:render", enhance);
          window.swEnhance = enhance;
        })();
      JS

      # title and app_js are build-time developer-supplied values — not user input. No escaping applied.
      # morphdom_js:       local file path to use instead of CDN.
      # marked_js:         local file path to use instead of CDN.
      # prism_js/prism_css: local Prism bundle + theme, else CDN.
      # mermaid_js:        local Mermaid bundle, else CDN.
      # diff_js:           local jsdiff bundle, else CDN. Powers DiffBlock in
      #                    the browser, where diff(1) does not exist.
      # mermaid_zoom_js:   local path to sw-mermaid-zoom.js. No CDN fallback --
      #                    it is StreamWeaver's own code, not a third-party
      #                    library. Omitting it leaves diagrams unrendered
      #                    (see ENHANCE_JS's comment).
      # theme_css:         path/URL to a CSS file injected as a stylesheet link.
      # google_fonts_url:  full Google Fonts CSS URL; emits preconnect + stylesheet tags.
      # dark_mode_script:  inline JS string placed first in <head> to prevent FOUC.
      # body_html:         pre-rendered markup for #sw-app. Supplying it makes the
      #                    page a finished document rather than an empty shell the
      #                    runtime fills in.
      # inline_css:        CSS text written into a <style> in <head>. A statically
      #                    rendered document cannot let the adapter append per-
      #                    component styles at runtime, so they come through here.
      # app_js:            set to nil for a static render -- with no runtime to
      #                    boot, the page only needs the enhancers (Prism/Mermaid)
      #                    to run once over markup that is already present.
      def self.render(
        title: "StreamWeaver App",
        app_js: "app.js",
        body_html: nil,
        inline_css: nil,
        morphdom_js: nil,
        marked_js: nil,
        prism_js: nil,
        prism_css: nil,
        diff_js: nil,
        mermaid_js: nil,
        mermaid_zoom_js: nil,
        theme_css: nil,
        google_fonts_url: nil,
        dark_mode_script: nil,
        body_theme: "sw-theme-default"
      )
        morphdom_src = morphdom_js || MORPHDOM_CDN
        marked_src   = marked_js   || MARKED_CDN
        prism_src    = prism_js    || PRISM_CDN
        prism_css_src = prism_css  || PRISM_CSS_CDN
        mermaid_src  = mermaid_js  || MERMAID_CDN
        diff_src     = diff_js     || DIFF_CDN

        google_fonts_tags = google_fonts_url && [
          '    <link rel="preconnect" href="https://fonts.googleapis.com">',
          '    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
          "    <link rel=\"stylesheet\" href=\"#{google_fonts_url}\">"
        ]

        has_inline_css = !(inline_css.nil? || inline_css.to_s.strip.empty?)

        optional_head = [
          (dark_mode_script && "    <script>#{dark_mode_script}</script>"),
          *google_fonts_tags,
          (theme_css && "    <link rel=\"stylesheet\" href=\"#{theme_css}\">"),
          "    <link rel=\"stylesheet\" href=\"#{prism_css_src}\">",
          (has_inline_css ? "    <style>\n#{inline_css}\n    </style>" : nil)
        ].compact

        optional_section = optional_head.empty? ? "" : "#{optional_head.join("\n")}\n"

        # With app_js the page boots the runtime, which fires sw:render and lets
        # ENHANCE_JS decorate what it painted. Without it nothing will ever fire
        # that event, so the enhancers are invoked directly against the markup
        # that shipped in the HTML.
        app_script = app_js ? "  <script src=\"#{app_js}\"></script>\n" : ""
        boot_call  = app_js ? "SWRuntime.start();" : "if (typeof swEnhance === \"function\") swEnhance();"

        # After mermaid_src, not before: swMermaidInit's globalThis.mermaid
        # fast path (sw-mermaid-zoom.js) needs mermaid already loaded.
        mermaid_zoom_tag = mermaid_zoom_js ? "    <script src=\"#{mermaid_zoom_js}\"></script>\n" : ""

        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{title}</title>
          #{optional_section}    <script src="#{marked_src}"></script>
            <script src="#{morphdom_src}"></script>
            <script src="#{prism_src}"></script>
            <script src="#{mermaid_src}"></script>
          #{mermaid_zoom_tag}    <script src="#{diff_src}"></script>
          </head>
          <body class="#{body_theme}">
            <div id="sw-app">#{body_html}</div>
          #{app_script}  <script>#{ENHANCE_JS}</script>
            <script>
              document.addEventListener("DOMContentLoaded", function() {
                #{boot_call}
              });
            </script>
          </body>
          </html>
        HTML
      end
    end
  end
end
