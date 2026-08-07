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
      # Both libraries scan the DOM for their own markup, so they have to run
      # after SWRuntime.start() rather than on DOMContentLoaded. Mermaid is
      # pinned to startOnLoad:false for the same reason -- letting it autorun
      # races the first render and finds nothing.
      #
      # Re-renders replace region innerHTML, which resurrects unprocessed
      # nodes, so this re-runs on sw:render. Mermaid rewrites its source node
      # into an <svg>, and running it twice over the same node throws, so
      # already-processed nodes are filtered out by mermaid's own marker
      # attribute.
      ENHANCE_JS = <<~JS.freeze
        (function() {
          function highlight() {
            if (typeof Prism !== "undefined") Prism.highlightAll();
          }
          function diagrams() {
            if (typeof mermaid === "undefined") return;
            var nodes = document.querySelectorAll(".sw-mermaid:not([data-processed])");
            if (!nodes.length) return;
            mermaid.run({ nodes: nodes }).catch(function(e) {
              console.error("[StreamWeaver] mermaid failed:", e);
            });
          }
          function enhance() { highlight(); diagrams(); }
          if (typeof mermaid !== "undefined") {
            mermaid.initialize({
              startOnLoad: false,
              theme: document.documentElement.dataset.swTheme === "dark" ? "dark" : "default"
            });
          }
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
      # theme_css:         path/URL to a CSS file injected as a stylesheet link.
      # google_fonts_url:  full Google Fonts CSS URL; emits preconnect + stylesheet tags.
      # dark_mode_script:  inline JS string placed first in <head> to prevent FOUC.
      def self.render(
        title: "StreamWeaver App",
        app_js: "app.js",
        morphdom_js: nil,
        marked_js: nil,
        prism_js: nil,
        prism_css: nil,
        diff_js: nil,
        mermaid_js: nil,
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

        optional_head = [
          (dark_mode_script && "    <script>#{dark_mode_script}</script>"),
          *google_fonts_tags,
          (theme_css && "    <link rel=\"stylesheet\" href=\"#{theme_css}\">"),
          "    <link rel=\"stylesheet\" href=\"#{prism_css_src}\">"
        ].compact

        optional_section = optional_head.empty? ? "" : "#{optional_head.join("\n")}\n"

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
            <script src="#{diff_src}"></script>
          </head>
          <body class="#{body_theme}">
            <div id="sw-app"></div>
            <script src="#{app_js}"></script>
            <script>#{ENHANCE_JS}</script>
            <script>
              document.addEventListener("DOMContentLoaded", function() {
                SWRuntime.start();
              });
            </script>
          </body>
          </html>
        HTML
      end
    end
  end
end
