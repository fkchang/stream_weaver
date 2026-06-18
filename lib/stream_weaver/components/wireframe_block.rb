# frozen_string_literal: true

module StreamWeaver
  module Components
    # A wireframe surface block that renders raw HTML as a hand-drawn mockup.
    # Provides scoped --wf-* CSS tokens and helper classes within .sw-wireframe-surface.
    #
    # All styling is intentionally scoped to .sw-wireframe-surface so wireframe
    # aesthetics cannot leak into the surrounding app UI.
    #
    # @example
    #   wireframe_block(html: "<h1>Login</h1><button class=\"primary\">Sign in</button>")
    class WireframeBlock < Base
      SURFACES = %w[browser desktop mobile popover panel].freeze

      css <<~CSS
        /* =============================================
           StreamWeaver Wireframe Token Foundation
           All rules scoped to .sw-wireframe-surface
           ============================================= */

        /* Light mode tokens */
        .sw-wireframe-surface {
          --wf-ink:         #1a1a2e;
          --wf-muted:       #6b7280;
          --wf-line:        #d1d5db;
          --wf-paper:       #fafafa;
          --wf-card:        #f3f4f6;
          --wf-accent:      #3b82f6;
          --wf-accent-fg:   #ffffff;
          --wf-accent-soft: #dbeafe;
          --wf-warn:        #f59e0b;
          --wf-ok:          #10b981;
          --wf-radius:      4px;

          color: var(--wf-ink);
          background: var(--wf-paper);
          font-family: inherit;
          box-sizing: border-box;
        }

        /* Dark mode tokens */
        html.dark .sw-wireframe-surface {
          --wf-ink:         #f1f5f9;
          --wf-muted:       #94a3b8;
          --wf-line:        #334155;
          --wf-paper:       #0f172a;
          --wf-card:        #1e293b;
          --wf-accent:      #60a5fa;
          --wf-accent-fg:   #0f172a;
          --wf-accent-soft: #1e3a5f;
          --wf-warn:        #fbbf24;
          --wf-ok:          #34d399;
          --wf-radius:      4px;
        }

        /* Helper: bordered/padded container */
        .sw-wireframe-surface .wf-card,
        .sw-wireframe-surface .wf-box {
          border: 1.4px solid var(--wf-line);
          border-radius: var(--wf-radius);
          padding: 12px 16px;
          background: var(--wf-card);
          box-sizing: border-box;
        }

        /* Helper: rounded tag/filter chip */
        .sw-wireframe-surface .wf-pill,
        .sw-wireframe-surface .wf-chip {
          display: inline-flex;
          align-items: center;
          border: 1px solid var(--wf-line);
          border-radius: 999px;
          padding: 2px 10px;
          font-size: 0.75em;
          background: var(--wf-card);
          color: var(--wf-muted);
        }

        /* Accent-filled pill/chip variant */
        .sw-wireframe-surface .wf-pill.accent,
        .sw-wireframe-surface .wf-chip.accent {
          background: var(--wf-accent);
          color: var(--wf-accent-fg);
          border-color: var(--wf-accent);
        }

        /* Helper: muted/secondary text */
        .sw-wireframe-surface .wf-muted {
          color: var(--wf-muted);
        }

        /* Helper: primary action button */
        .sw-wireframe-surface button.primary,
        .sw-wireframe-surface [data-primary] {
          background: var(--wf-accent);
          color: var(--wf-accent-fg);
          border: none;
          border-radius: var(--wf-radius);
          padding: 6px 14px;
          font-weight: 500;
          cursor: pointer;
        }

        .sw-wireframe-surface button.primary:hover,
        .sw-wireframe-surface [data-primary]:hover {
          opacity: 0.88;
        }
      CSS

      attr_reader :html, :surface

      # @param html [String] Raw HTML fragment to display inside the wireframe surface
      # @param surface [String] Surface type: browser, desktop, mobile, popover, panel
      def initialize(html: "", surface: "browser", **options)
        @html    = html
        @surface = SURFACES.include?(surface) ? surface : "browser"
        @options = options
      end

      def render(view, state)
        view.adapter.render_wireframe_block(view, self, state)
      end
    end
  end
end
