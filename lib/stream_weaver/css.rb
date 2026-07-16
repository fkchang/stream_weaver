# frozen_string_literal: true

module StreamWeaver
  # Shared CSS for StreamWeaver themes and components
  # Used by both AppView (standalone) and live session pages
  module CSS
    # Every framework-emitted style block (master theme, theme presets/
    # overrides, component inject_*_css) is wrapped in this single named
    # layer so any unlayered user stylesheet -- regardless of selector
    # specificity or document order -- always wins the cascade
    # (stream_weaver-oeo). User-authored CSS (App.new stylesheets:, and the
    # `css`/`css_path` class macros a custom Component subclass can declare
    # for itself) is deliberately left unlayered.
    LAYER_NAME = "stream-weaver"

    class << self
      # Wraps framework CSS in the shared @layer so user CSS always wins
      # the cascade regardless of specificity or document order.
      # @param css [String] framework-emitted CSS
      # @return [String] the CSS wrapped in `@layer stream-weaver { ... }`
      def layer_wrap(css)
        return css if css.nil? || css.strip.empty?

        "@layer #{LAYER_NAME} {\n#{css}\n}"
      end
      # Returns the full StreamWeaver CSS (themes + components)
      # @return [String] CSS content
      def full_stylesheet
        @full_stylesheet ||= begin
          # Read from views.rb and extract the CSS heredoc
          views_path = File.expand_path('views.rb', __dir__)
          content = File.read(views_path)
          
          # Extract CSS between the heredoc markers
          # Pattern: raw(safe(<<~CSS)) ... CSS
          if content =~ /raw\(safe\(<<~CSS\)\)(.*?)^\s*CSS$/m
            # Remove the 16-space indentation from the original
            $1.gsub(/^                /, '')
          else
            # Fallback: return minimal CSS
            minimal_css
          end
        end
      end

      # Minimal CSS for fallback
      def minimal_css
        <<~CSS
          :root {
            --sw-transition-fast: 120ms ease-out;
            --sw-transition: 200ms ease-out;
            --sw-color-primary: #c2410c;
            --sw-color-text: #111111;
            --sw-color-bg: #f8f8f8;
            --sw-color-bg-card: #ffffff;
            --sw-color-border: #e0e0e0;
            --sw-spacing-md: 1.25rem;
            --sw-radius-md: 6px;
          }
          
          body {
            font-family: 'Source Sans 3', system-ui, sans-serif;
            background: var(--sw-color-bg);
            color: var(--sw-color-text);
            padding: 1rem;
          }
        CSS
      end

      # Google Fonts link tags
      def google_fonts_html
        <<~HTML
          <link rel="preconnect" href="https://fonts.googleapis.com">
          <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
          <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap">
        HTML
      end

      # CDN scripts for HTMX and Alpine.js
      def cdn_scripts_html
        <<~HTML
          <script src="https://unpkg.com/htmx.org@2.0.4"></script>
          <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
        HTML
      end

      # Content update animation CSS
      def animation_css
        <<~CSS
          /* Content update animations */
          .sw-fade-in {
            animation: sw-fade-in 350ms ease-out;
          }

          @keyframes sw-fade-in {
            from {
              opacity: 0;
              transform: translateY(-12px) scale(0.98);
            }
            to {
              opacity: 1;
              transform: translateY(0) scale(1);
            }
          }
          
          .sw-slide-in {
            animation: sw-slide-in 250ms ease-out;
          }

          @keyframes sw-slide-in {
            from {
              opacity: 0;
              transform: translateX(-8px);
            }
            to {
              opacity: 1;
              transform: translateX(0);
            }
          }

          /* Swap-target busy treatment during in-flight requests (FAC-P1.5).
             Delay-in via transition-delay so fast responses never flicker;
             undimming (class removed) is immediate. */
          #app-container {
            transition: opacity var(--sw-transition-fast, 120ms) ease-out;
          }

          #app-container.htmx-request {
            opacity: 0.85;
            transition-delay: 150ms;
          }

          /* Table styles */
          .sw-table {
            width: 100%;
            border-collapse: collapse;
          }
          .sw-row-striped {
            background: var(--sw-color-bg-muted, #f9fafb);
          }
          .sw-row-hoverable:hover {
            background: var(--sw-color-bg-hover, #f0f0f0) !important;
          }
          .sw-table-bordered td,
          .sw-table-bordered th {
            border: 1px solid var(--sw-color-border, #e0e0e0);
          }
        CSS
      end
    end
  end
end
