# frozen_string_literal: true

module StreamWeaver
  module Opal
    class OpalShell
      MORPHDOM_CDN = "https://unpkg.com/morphdom@2.7.4/dist/morphdom.min.js"

      # title and app_js are build-time developer-supplied values — not user input. No escaping applied.
      def self.render(title: "StreamWeaver App", app_js: "app.js")
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{title}</title>
            <script src="#{MORPHDOM_CDN}"></script>
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
