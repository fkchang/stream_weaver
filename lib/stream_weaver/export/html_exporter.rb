# frozen_string_literal: true

require 'phlex'
require 'base64'
require 'net/http'
require 'uri'

module StreamWeaver
  module Export
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

      # @param app [StreamWeaver::App] The app to export
      # @param state [Hash] State to render with (default: empty)
      def initialize(app, state: {})
        @app = app
        @state = state
        @adapter = StreamWeaver::Adapter::AlpineJS.new
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
        # Rebuild components with state
        @app.rebuild_with_state(@state)

        body_html = render_body
        body_html = inline_images_in_html(body_html) if inline_images
        css = inline_css
        cdn_scripts = collect_cdn_scripts
        cdn_styles = collect_cdn_styles

        build_document(
          title: @app.title,
          css: css,
          cdn_scripts: cdn_scripts,
          cdn_styles: cdn_styles,
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

      # Collect all CSS that should be inlined
      def inline_css
        css_parts = []

        # Visual skills foundation CSS (custom properties)
        css_parts << StreamWeaver::Theme.visual_skills_css

        # Theme-specific CSS if a custom theme is registered
        if @app.theme && @app.theme != :default
          theme = StreamWeaver.get_theme(@app.theme)
          css_parts << theme.to_css if theme
        end

        # App-level stylesheets are kept as links (they might be CDN)
        # The component-level CSS is injected inline by the adapter during render_body

        css_parts.compact.join("\n\n")
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

      # Replace local image paths with base64 data URIs in HTML
      def inline_images_in_html(html)
        html.gsub(/src="((?!data:|https?:\/\/)[^"]+)"/) do |match|
          path = $1
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
      def build_document(title:, css:, cdn_scripts:, cdn_styles:, body_html:)
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
            <style>
          #{css}
            </style>
          </head>
          <body>
            #{body_html}
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
