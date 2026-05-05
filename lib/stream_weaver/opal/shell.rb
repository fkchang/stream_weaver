# frozen_string_literal: true

module StreamWeaver
  module Opal
    class OpalShell
      MORPHDOM_CDN = "https://unpkg.com/morphdom@2.7.4/dist/morphdom.min.js"
      MARKED_CDN   = "https://cdn.jsdelivr.net/npm/marked/lib/marked.umd.js"

      # title and app_js are build-time developer-supplied values — not user input. No escaping applied.
      # morphdom_js:       local file path to use instead of CDN.
      # marked_js:         local file path to use instead of CDN.
      # theme_css:         path/URL to a CSS file injected as a stylesheet link.
      # google_fonts_url:  full Google Fonts CSS URL; emits preconnect + stylesheet tags.
      # dark_mode_script:  inline JS string placed first in <head> to prevent FOUC.
      def self.render(
        title: "StreamWeaver App",
        app_js: "app.js",
        morphdom_js: nil,
        marked_js: nil,
        theme_css: nil,
        google_fonts_url: nil,
        dark_mode_script: nil
      )
        morphdom_src = morphdom_js || MORPHDOM_CDN
        marked_src   = marked_js   || MARKED_CDN

        google_fonts_tags = google_fonts_url && [
          '    <link rel="preconnect" href="https://fonts.googleapis.com">',
          '    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
          "    <link rel=\"stylesheet\" href=\"#{google_fonts_url}\">"
        ]

        optional_head = [
          (dark_mode_script && "    <script>#{dark_mode_script}</script>"),
          *google_fonts_tags,
          (theme_css && "    <link rel=\"stylesheet\" href=\"#{theme_css}\">")
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
          </head>
          <body>
            <div id="sw-app"></div>
            <script src="#{app_js}"></script>
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
