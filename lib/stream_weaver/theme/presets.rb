# frozen_string_literal: true

module StreamWeaver
  class Theme
    # Curated theme presets for visual skills components.
    # Each preset is a data-only definition: font pairings + color palette.
    # Presets do NOT contain rendering logic -- they are consumed by
    # Theme#apply_preset which sets CSS custom properties.
    #
    # sw- CSS prefix convention:
    #   All visual skills CSS classes MUST use the sw- prefix.
    #   BEM-style modifiers: sw-component--variant (e.g. sw-card--hero)
    #   State classes: sw-is-active, sw-is-selected
    module Presets
      # Editorial preset: magazine-style with serif display font
      # Instrument Serif + JetBrains Mono, Terracotta + sage palette
      EDITORIAL = {
        name: :editorial,
        label: "Editorial",
        description: "Magazine-style with serif display font",
        fonts: {
          display: "'Instrument Serif', Georgia, serif",
          body: "'Source Sans 3', system-ui, sans-serif",
          mono: "'JetBrains Mono', 'Fira Code', monospace"
        },
        google_fonts: [
          "Instrument+Serif:ital@0;1",
          "JetBrains+Mono:wght@400;500;600",
          "Source+Sans+3:wght@400;500;600;700"
        ],
        colors: {
          light: {
            bg: "#faf8f5",
            surface: "#ffffff",
            surface_elevated: "#f5f3f0",
            border: "#e8e4df",
            text: "#1a1a1a",
            text_dim: "#6b6560",
            accent: "#c2410c",
            node_a: "#c2410c",
            node_b: "#0d9488",
            node_c: "#7c3aed",
            success: "#16a34a",
            warning: "#d97706",
            error: "#dc2626",
            info: "#2563eb"
          },
          dark: {
            bg: "#1a1816",
            surface: "#262220",
            surface_elevated: "#332e2b",
            border: "rgba(255, 255, 255, 0.1)",
            text: "#f5f0eb",
            text_dim: "#a89f97",
            accent: "#f97316",
            node_a: "#f97316",
            node_b: "#2dd4bf",
            node_c: "#a78bfa",
            success: "#22c55e",
            warning: "#fbbf24",
            error: "#f87171",
            info: "#60a5fa"
          }
        }
      }.freeze

      # Technical preset: clean sans-serif for data-heavy content
      # DM Sans + Fira Code, Teal + slate palette
      TECHNICAL = {
        name: :technical,
        label: "Technical",
        description: "Clean sans-serif for data-heavy content",
        fonts: {
          display: "'DM Sans', system-ui, sans-serif",
          body: "'DM Sans', system-ui, sans-serif",
          mono: "'Fira Code', 'JetBrains Mono', monospace"
        },
        google_fonts: [
          "DM+Sans:wght@400;500;600;700",
          "Fira+Code:wght@400;500;600"
        ],
        colors: {
          light: {
            bg: "#f8fafc",
            surface: "#ffffff",
            surface_elevated: "#f1f5f9",
            border: "#e2e8f0",
            text: "#0f172a",
            text_dim: "#64748b",
            accent: "#0d9488",
            node_a: "#0d9488",
            node_b: "#6366f1",
            node_c: "#ec4899",
            success: "#16a34a",
            warning: "#d97706",
            error: "#dc2626",
            info: "#2563eb"
          },
          dark: {
            bg: "#0f172a",
            surface: "#1e293b",
            surface_elevated: "#334155",
            border: "rgba(255, 255, 255, 0.1)",
            text: "#f1f5f9",
            text_dim: "#94a3b8",
            accent: "#2dd4bf",
            node_a: "#2dd4bf",
            node_b: "#818cf8",
            node_c: "#f472b6",
            success: "#22c55e",
            warning: "#fbbf24",
            error: "#f87171",
            info: "#60a5fa"
          }
        }
      }.freeze

      # Warm preset: friendly rounded aesthetic with warm tones
      # Nunito + Source Serif 4 + JetBrains Mono, Amber + warm gray palette
      WARM = {
        name: :warm,
        label: "Warm",
        description: "Friendly rounded aesthetic with warm tones",
        fonts: {
          display: "'Nunito', system-ui, sans-serif",
          body: "'Source Serif 4', Georgia, serif",
          mono: "'JetBrains Mono', 'Fira Code', monospace"
        },
        google_fonts: [
          "Nunito:wght@400;600;700;800",
          "Source+Serif+4:wght@400;500;600",
          "JetBrains+Mono:wght@400;500"
        ],
        colors: {
          light: {
            bg: "#fdf8f3",
            surface: "#ffffff",
            surface_elevated: "#faf3eb",
            border: "#e8ddd0",
            text: "#2d1f10",
            text_dim: "#7a6b5d",
            accent: "#d97706",
            node_a: "#d97706",
            node_b: "#059669",
            node_c: "#9333ea",
            success: "#16a34a",
            warning: "#ea580c",
            error: "#dc2626",
            info: "#2563eb"
          },
          dark: {
            bg: "#1c1714",
            surface: "#2a2420",
            surface_elevated: "#38302a",
            border: "rgba(255, 255, 255, 0.1)",
            text: "#f5ede4",
            text_dim: "#b0a090",
            accent: "#fbbf24",
            node_a: "#fbbf24",
            node_b: "#34d399",
            node_c: "#c084fc",
            success: "#22c55e",
            warning: "#fb923c",
            error: "#f87171",
            info: "#60a5fa"
          }
        }
      }.freeze

      # Minimal preset: ultra-clean Swiss-inspired design
      # Inter + Inter, monochrome with subtle accent
      MINIMAL = {
        name: :minimal,
        label: "Minimal",
        description: "Ultra-clean Swiss-inspired design",
        fonts: {
          display: "'Inter', system-ui, sans-serif",
          body: "'Inter', system-ui, sans-serif",
          mono: "'IBM Plex Mono', 'Menlo', monospace"
        },
        google_fonts: [
          "Inter:wght@400;500;600;700",
          "IBM+Plex+Mono:wght@400;500"
        ],
        colors: {
          light: {
            bg: "#ffffff",
            surface: "#fafafa",
            surface_elevated: "#f5f5f5",
            border: "#e5e5e5",
            text: "#171717",
            text_dim: "#737373",
            accent: "#171717",
            node_a: "#171717",
            node_b: "#525252",
            node_c: "#a3a3a3",
            success: "#16a34a",
            warning: "#d97706",
            error: "#dc2626",
            info: "#2563eb"
          },
          dark: {
            bg: "#0a0a0a",
            surface: "#171717",
            surface_elevated: "#262626",
            border: "rgba(255, 255, 255, 0.1)",
            text: "#fafafa",
            text_dim: "#a3a3a3",
            accent: "#fafafa",
            node_a: "#fafafa",
            node_b: "#d4d4d4",
            node_c: "#737373",
            success: "#22c55e",
            warning: "#fbbf24",
            error: "#f87171",
            info: "#60a5fa"
          }
        }
      }.freeze

      # Terminal preset: retro terminal/hacker aesthetic
      # JetBrains Mono everywhere, green-on-black palette
      TERMINAL = {
        name: :terminal,
        label: "Terminal",
        description: "Retro terminal aesthetic with monospace fonts",
        fonts: {
          display: "'JetBrains Mono', 'Fira Code', monospace",
          body: "'JetBrains Mono', 'Fira Code', monospace",
          mono: "'JetBrains Mono', 'Fira Code', monospace"
        },
        google_fonts: [
          "JetBrains+Mono:wght@400;500;600;700"
        ],
        colors: {
          light: {
            bg: "#f0f4f0",
            surface: "#e8ede8",
            surface_elevated: "#dde3dd",
            border: "#c0ccc0",
            text: "#1a2e1a",
            text_dim: "#4a6a4a",
            accent: "#16a34a",
            node_a: "#16a34a",
            node_b: "#0891b2",
            node_c: "#a855f7",
            success: "#16a34a",
            warning: "#ca8a04",
            error: "#dc2626",
            info: "#0284c7"
          },
          dark: {
            bg: "#0c0c0c",
            surface: "#141414",
            surface_elevated: "#1e1e1e",
            border: "rgba(0, 255, 65, 0.15)",
            text: "#00ff41",
            text_dim: "#00b330",
            accent: "#00ff41",
            node_a: "#00ff41",
            node_b: "#00d4ff",
            node_c: "#d946ef",
            success: "#00ff41",
            warning: "#ffdd00",
            error: "#ff3333",
            info: "#00d4ff"
          }
        }
      }.freeze

      # Sketch preset: hand-drawn wireframe aesthetic
      # Caveat (Google Fonts hand-drawn), rough.js borders via JS, Excalifont-style
      # Special preset — renderer bypasses normal body-level font injection
      # to keep non-wireframe content unaffected (C7).
      SKETCH = {
        name: :sketch,
        label: "Sketch",
        description: "Hand-drawn wireframe aesthetic with rough.js borders and hand-drawn font",
        sketch: true,
        fonts: {
          display: "'Caveat', cursive",
          body: "'Caveat', cursive",
          mono: "monospace"
        },
        google_fonts: ["Caveat:wght@400;500;600;700"],
        colors: {
          light: {
            bg: "#fafafa",
            surface: "#ffffff",
            surface_elevated: "#f5f5f5",
            border: "#d1d5db",
            text: "#1a1a2e",
            text_dim: "#6b7280",
            accent: "#3b82f6",
            node_a: "#3b82f6",
            node_b: "#10b981",
            node_c: "#8b5cf6",
            success: "#16a34a",
            warning: "#d97706",
            error: "#dc2626",
            info: "#2563eb"
          },
          dark: {
            bg: "#1a1a2e",
            surface: "#16213e",
            surface_elevated: "#0f3460",
            border: "#374151",
            text: "#f1f5f9",
            text_dim: "#94a3b8",
            accent: "#60a5fa",
            node_a: "#60a5fa",
            node_b: "#34d399",
            node_c: "#a78bfa",
            success: "#22c55e",
            warning: "#fbbf24",
            error: "#f87171",
            info: "#60a5fa"
          }
        }
      }.freeze

      # Registry of all available presets
      REGISTRY = {
        editorial: EDITORIAL,
        technical: TECHNICAL,
        warm: WARM,
        minimal: MINIMAL,
        terminal: TERMINAL,
        sketch: SKETCH
      }.freeze

      # Get a preset by name
      #
      # @param name [Symbol] Preset name
      # @return [Hash, nil] Preset definition or nil
      def self.get(name)
        REGISTRY[name.to_sym]
      end

      # List all available preset names
      #
      # @return [Array<Symbol>]
      def self.available
        REGISTRY.keys
      end

      # Generate Google Fonts link URL for a preset
      #
      # @param preset [Hash] Preset definition
      # @return [String] Google Fonts CSS URL
      def self.google_fonts_url(preset)
        families = preset[:google_fonts].map { |f| "family=#{f}" }.join("&")
        "https://fonts.googleapis.com/css2?#{families}&display=swap"
      end

      # Generate CSS custom properties for a preset in the given mode
      #
      # @param preset [Hash] Preset definition
      # @param mode [Symbol] :light or :dark
      # @return [Hash] CSS variable name => value pairs (without -- prefix)
      def self.css_variables(preset, mode: :light)
        colors = preset[:colors][mode] || preset[:colors][:light]
        fonts = preset[:fonts]

        vars = {}
        # Font variables
        vars["--sw-font-display"] = fonts[:display]
        vars["--sw-font-body"] = fonts[:body]
        vars["--sw-font-mono"] = fonts[:mono]

        # Color variables -- visual skills semantic tokens
        vars["--sw-bg"] = colors[:bg]
        vars["--sw-surface"] = colors[:surface]
        vars["--sw-surface-elevated"] = colors[:surface_elevated]
        vars["--sw-border"] = colors[:border]
        vars["--sw-text"] = colors[:text]
        vars["--sw-text-dim"] = colors[:text_dim]
        vars["--sw-accent"] = colors[:accent]

        # Node colors for diagrams
        vars["--sw-node-a"] = colors[:node_a]
        vars["--sw-node-b"] = colors[:node_b]
        vars["--sw-node-c"] = colors[:node_c]

        # Status colors
        vars["--sw-success"] = colors[:success]
        vars["--sw-warning"] = colors[:warning]
        vars["--sw-error"] = colors[:error]
        vars["--sw-info"] = colors[:info]

        vars
      end

      # Generate a complete CSS block for a preset that applies to :root (light)
      # and html.dark (dark mode). Also sets font-family on body elements.
      #
      # @param preset_name [Symbol] Preset name
      # @return [String] CSS string with custom properties for both modes
      def self.generate_preset_css(preset_name)
        preset = get(preset_name)
        return "" unless preset

        light_vars = css_variables(preset, mode: :light)
        dark_vars = css_variables(preset, mode: :dark)

        light_block = light_vars.map { |k, v| "  #{k}: #{v};" }.join("\n")
        dark_block = dark_vars.map { |k, v| "  #{k}: #{v};" }.join("\n")

        fonts = preset[:fonts]

        <<~CSS
          /* Theme preset: #{preset[:label]} -- #{preset[:description]} */
          :root {
          #{light_block}
          }
          html.dark {
          #{dark_block}
          }
          /* Apply preset fonts to body */
          body {
            font-family: #{fonts[:body]};
          }
          h1, h2, h3, h4, h5, h6 {
            font-family: #{fonts[:display]};
          }
          code, pre, .sw-code-block {
            font-family: #{fonts[:mono]};
          }
        CSS
      end

      # Generate CSS @keyframes and utility classes for animations.
      # All classes use sw- prefix.
      #
      # @return [String] CSS with animation keyframes and utility classes
      def self.animations_css
        <<~CSS
          /* ===========================================
             StreamWeaver Animations (T15)
             sw- prefixed animation utilities.
             =========================================== */

          /* Keyframes */
          @keyframes sw-fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
          }

          @keyframes sw-slideUp {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
          }

          @keyframes sw-fadeScale {
            from { opacity: 0; transform: scale(0.92); }
            to { opacity: 1; transform: scale(1); }
          }

          @keyframes sw-shimmer {
            0% { background-position: -200% 0; }
            100% { background-position: 200% 0; }
          }

          @keyframes sw-slideDown {
            from { opacity: 0; transform: translateY(-20px); }
            to { opacity: 1; transform: translateY(0); }
          }

          /* Animation utility classes */
          .sw-animate-fadeIn {
            animation: sw-fadeIn 0.4s ease-out both;
          }

          .sw-animate-slideUp {
            animation: sw-slideUp 0.5s ease-out both;
          }

          .sw-animate-fadeScale {
            animation: sw-fadeScale 0.4s ease-out both;
          }

          .sw-animate-shimmer {
            background: linear-gradient(
              90deg,
              var(--sw-surface-elevated) 25%,
              var(--sw-border) 50%,
              var(--sw-surface-elevated) 75%
            );
            background-size: 200% 100%;
            animation: sw-shimmer 1.5s ease-in-out infinite;
          }

          .sw-animate-slideDown {
            animation: sw-slideDown 0.5s ease-out both;
          }

          /* Stagger delay helpers: apply to children for sequential reveal.
             Usage: parent.sw-stagger > child elements get increasing delays.
             Uses CSS custom property --sw-stagger-delay (default 80ms). */
          .sw-stagger > :nth-child(1) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 0); }
          .sw-stagger > :nth-child(2) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 1); }
          .sw-stagger > :nth-child(3) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 2); }
          .sw-stagger > :nth-child(4) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 3); }
          .sw-stagger > :nth-child(5) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 4); }
          .sw-stagger > :nth-child(6) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 5); }
          .sw-stagger > :nth-child(7) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 6); }
          .sw-stagger > :nth-child(8) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 7); }
          .sw-stagger > :nth-child(9) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 8); }
          .sw-stagger > :nth-child(10) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 9); }
          .sw-stagger > :nth-child(11) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 10); }
          .sw-stagger > :nth-child(12) { animation-delay: calc(var(--sw-stagger-delay, 80ms) * 11); }

          /* Slide swap transitions */
          .sw-slide-transition {
            transition: opacity 0.3s ease-out, transform 0.3s ease-out;
          }

          .sw-slide-enter {
            opacity: 0;
            transform: translateX(20px);
          }

          .sw-slide-enter-active {
            opacity: 1;
            transform: translateX(0);
          }

          .sw-slide-exit {
            opacity: 1;
            transform: translateX(0);
          }

          .sw-slide-exit-active {
            opacity: 0;
            transform: translateX(-20px);
          }

          /* Reduce motion preference: disable all animations */
          @media (prefers-reduced-motion: reduce) {
            .sw-animate-fadeIn,
            .sw-animate-slideUp,
            .sw-animate-fadeScale,
            .sw-animate-shimmer,
            .sw-animate-slideDown {
              animation: none !important;
            }
            .sw-slide-transition {
              transition: none !important;
            }
          }
        CSS
      end
    end
  end
end
