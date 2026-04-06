# frozen_string_literal: true

require 'json'
require_relative 'theme/presets'
require_relative 'theme/auto_mode'

module StreamWeaver
  # Custom theme registration and management.
  #
  # == Visual Skills CSS Foundation (T2)
  #
  # This module provides the CSS custom property vocabulary used by ALL
  # visual skills components (T3-T15). The convention is:
  #
  # === sw- CSS Prefix Convention
  #
  # All visual skills CSS classes MUST use the +sw-+ prefix to avoid
  # collisions with user CSS and third-party libraries.
  #
  #   BEM naming:   sw-component--variant   (e.g. sw-card--hero)
  #   State:        sw-is-active, sw-is-selected
  #   Utility:      sw-text-dim, sw-bg-surface
  #
  # === CSS Custom Properties
  #
  # Semantic tokens (set per light/dark mode):
  #   --sw-bg              Page background
  #   --sw-surface         Card / panel surface
  #   --sw-surface-elevated  Elevated surface (dropdowns, popovers)
  #   --sw-border          Default border color
  #   --sw-text            Primary text color
  #   --sw-text-dim        Secondary / muted text
  #   --sw-accent          Primary accent color
  #   --sw-node-a/b/c      Diagram node palette
  #   --sw-success/warning/error/info  Status colors
  #
  # These are _additional_ to the existing --sw-color-* tokens.
  # Components should prefer the short --sw-* names; the --sw-color-*
  # variants remain for backward compatibility.
  #
  # @example Register a custom theme
  #   StreamWeaver.register_theme :corporate, {
  #     font_family: "'Inter', system-ui, sans-serif",
  #     color_primary: "#0066cc",
  #     spacing_md: "1rem"
  #   }, base: :dashboard
  #
  # @example Use in an app
  #   app "Corporate App", theme: :corporate do
  #     text "Hello, styled world!"
  #   end
  class Theme
    # Variable schema: maps Ruby keys to CSS variables with type info
    # Types: :string, :size, :number, :color
    VARIABLE_SCHEMA = {
      # Typography
      font_display: { css: "--sw-font-display", type: :string },
      font_body: { css: "--sw-font-body", type: :string },
      font_family: { css: "--sw-font-family", type: :string },
      font_size_base: { css: "--sw-font-size-base", type: :size },
      font_size_sm: { css: "--sw-font-size-sm", type: :size },
      font_size_lg: { css: "--sw-font-size-lg", type: :size },
      font_size_xl: { css: "--sw-font-size-xl", type: :size },
      line_height: { css: "--sw-line-height", type: :number },

      # Colors - Primary
      color_primary: { css: "--sw-color-primary", type: :color },
      color_primary_hover: { css: "--sw-color-primary-hover", type: :color },
      color_primary_light: { css: "--sw-color-primary-light", type: :color },
      color_primary_glow: { css: "--sw-color-primary-glow", type: :color },

      # Colors - Neutrals
      color_text: { css: "--sw-color-text", type: :color },
      color_text_muted: { css: "--sw-color-text-muted", type: :color },
      color_text_light: { css: "--sw-color-text-light", type: :color },
      color_bg: { css: "--sw-color-bg", type: :color },
      color_bg_card: { css: "--sw-color-bg-card", type: :color },
      color_bg_elevated: { css: "--sw-color-bg-elevated", type: :color },
      color_border: { css: "--sw-color-border", type: :color },
      color_border_strong: { css: "--sw-color-border-strong", type: :color },
      color_border_focus: { css: "--sw-color-border-focus", type: :color },

      # Colors - Secondary
      color_secondary: { css: "--sw-color-secondary", type: :color },
      color_secondary_hover: { css: "--sw-color-secondary-hover", type: :color },

      # Colors - Accent
      color_accent: { css: "--sw-color-accent", type: :color },
      color_accent_light: { css: "--sw-color-accent-light", type: :color },

      # Spacing
      spacing_xs: { css: "--sw-spacing-xs", type: :size },
      spacing_sm: { css: "--sw-spacing-sm", type: :size },
      spacing_md: { css: "--sw-spacing-md", type: :size },
      spacing_lg: { css: "--sw-spacing-lg", type: :size },
      spacing_xl: { css: "--sw-spacing-xl", type: :size },
      spacing_2xl: { css: "--sw-spacing-2xl", type: :size },

      # Border Radius
      radius_sm: { css: "--sw-radius-sm", type: :size },
      radius_md: { css: "--sw-radius-md", type: :size },
      radius_lg: { css: "--sw-radius-lg", type: :size },
      radius_xl: { css: "--sw-radius-xl", type: :size },

      # Shadows
      shadow_sm: { css: "--sw-shadow-sm", type: :string },
      shadow_md: { css: "--sw-shadow-md", type: :string },
      shadow_lg: { css: "--sw-shadow-lg", type: :string },
      shadow_xl: { css: "--sw-shadow-xl", type: :string },
      shadow_inner: { css: "--sw-shadow-inner", type: :string },

      # Card styling
      card_border_left: { css: "--sw-card-border-left", type: :string },

      # Term highlighting
      term_color: { css: "--sw-term-color", type: :color },
      term_bg_hover: { css: "--sw-term-bg-hover", type: :color },

      # ============================================
      # Visual Skills Semantic Tokens (T2 foundation)
      # These short-form --sw-* tokens are the primary
      # vocabulary for visual skills components.
      # ============================================

      # Surfaces
      vs_bg: { css: "--sw-bg", type: :color },
      vs_surface: { css: "--sw-surface", type: :color },
      vs_surface_elevated: { css: "--sw-surface-elevated", type: :color },
      vs_border: { css: "--sw-border", type: :color },

      # Text
      vs_text: { css: "--sw-text", type: :color },
      vs_text_dim: { css: "--sw-text-dim", type: :color },
      vs_accent: { css: "--sw-accent", type: :color },

      # Diagram node colors
      vs_node_a: { css: "--sw-node-a", type: :color },
      vs_node_b: { css: "--sw-node-b", type: :color },
      vs_node_c: { css: "--sw-node-c", type: :color },

      # Status colors
      vs_success: { css: "--sw-success", type: :color },
      vs_warning: { css: "--sw-warning", type: :color },
      vs_error: { css: "--sw-error", type: :color },
      vs_info: { css: "--sw-info", type: :color },

      # Monospace font (for code blocks, dir trees)
      font_mono: { css: "--sw-font-mono", type: :string }
    }.freeze

    # Built-in theme definitions (matches CSS in views.rb)
    BUILT_IN_THEMES = {
      default: {
        name: "Default",
        description: "Warm Industrial",
        variables: {
          font_display: "'Source Sans 3', system-ui, sans-serif",
          font_body: "'Source Sans 3', system-ui, sans-serif",
          font_size_base: "17px",
          line_height: "1.7",
          color_primary: "#c2410c",
          color_bg: "#f8f8f8",
          color_text: "#111111",
          spacing_md: "1.25rem",
          card_border_left: "3px solid var(--sw-color-primary)"
        }
      },
      dashboard: {
        name: "Dashboard",
        description: "Data Dense",
        variables: {
          font_display: "'Source Sans 3', system-ui, sans-serif",
          font_body: "'Source Sans 3', system-ui, sans-serif",
          font_size_base: "15px",
          line_height: "1.5",
          color_primary: "#c2410c",
          color_bg: "#fafafa",
          color_text: "#111111",
          spacing_md: "0.875rem",
          card_border_left: "1px solid var(--sw-color-border)"
        }
      },
      document: {
        name: "Document",
        description: "Reading Mode",
        variables: {
          font_display: "'Source Sans 3', system-ui, sans-serif",
          font_body: "'Crimson Pro', Georgia, 'Times New Roman', serif",
          font_size_base: "19px",
          line_height: "1.85",
          color_primary: "#6b7280",
          color_bg: "#faf8f5",
          color_text: "#1a1a1a",
          spacing_md: "1.5rem",
          card_border_left: "none"
        }
      }
    }.freeze

    attr_reader :name, :variables, :base_theme, :label, :description

    # @param name [Symbol] Theme identifier
    # @param variables [Hash] Theme variable overrides
    # @param base [Symbol] Base theme to inherit from (:default, :dashboard, :document)
    # @param label [String] Human-readable name
    # @param description [String] Short description
    def initialize(name, variables = {}, base: :default, label: nil, description: nil)
      @name = name.to_sym
      @base_theme = base.to_sym
      @variables = normalize_variables(variables)
      @label = label || name.to_s.split('_').map(&:capitalize).join(' ')
      @description = description || "Custom theme"
    end

    # Generate CSS variable declarations for this theme
    #
    # @return [String] CSS variable block
    def to_css
      css_lines = @variables.map do |key, value|
        schema = VARIABLE_SCHEMA[key]
        css_var = schema ? schema[:css] : "--sw-#{key.to_s.tr('_', '-')}"
        "  #{css_var}: #{value};"
      end

      "body.sw-theme-#{@name} {\n#{css_lines.join("\n")}\n}"
    end

    # Export as Ruby registration code
    #
    # @return [String] Ruby code to register this theme
    def to_ruby
      vars = @variables.map { |k, v| "    #{k}: #{v.inspect}" }.join(",\n")
      <<~RUBY
        StreamWeaver.register_theme :#{@name}, {
        #{vars}
        }, base: :#{@base_theme}, label: #{@label.inspect}, description: #{@description.inspect}
      RUBY
    end

    # Export as JSON
    #
    # @return [String] JSON representation
    def to_json(*_args)
      JSON.pretty_generate(
        name: @name,
        label: @label,
        description: @description,
        base_theme: @base_theme,
        variables: @variables
      )
    end

    # Export as Hash
    #
    # @return [Hash] Hash representation
    def to_h
      {
        name: @name,
        label: @label,
        description: @description,
        base_theme: @base_theme,
        variables: @variables
      }
    end

    # Load theme from JSON
    #
    # @param json_string [String] JSON theme definition
    # @return [Theme] New theme instance
    def self.from_json(json_string)
      data = JSON.parse(json_string, symbolize_names: true)
      new(
        data[:name],
        data[:variables],
        base: data[:base_theme] || :default,
        label: data[:label],
        description: data[:description]
      )
    end

    # Load theme from file
    #
    # @param path [String] Path to JSON file
    # @return [Theme] New theme instance
    def self.from_file(path)
      from_json(File.read(path))
    end

    # Get all available variable names
    #
    # @return [Array<Symbol>] Variable names
    def self.variable_names
      VARIABLE_SCHEMA.keys
    end

    # Get variables grouped by category
    #
    # @return [Hash] Variables grouped by category
    def self.variables_by_category
      {
        typography: %i[font_display font_body font_family font_size_base font_size_sm font_size_lg font_size_xl line_height],
        colors_primary: %i[color_primary color_primary_hover color_primary_light color_primary_glow],
        colors_neutral: %i[color_text color_text_muted color_text_light color_bg color_bg_card color_bg_elevated color_border color_border_strong color_border_focus],
        colors_secondary: %i[color_secondary color_secondary_hover color_accent color_accent_light],
        spacing: %i[spacing_xs spacing_sm spacing_md spacing_lg spacing_xl spacing_2xl],
        border_radius: %i[radius_sm radius_md radius_lg radius_xl],
        shadows: %i[shadow_sm shadow_md shadow_lg shadow_xl shadow_inner],
        components: %i[card_border_left term_color term_bg_hover]
      }
    end

    # Generate the visual skills CSS custom properties block.
    # This produces the --sw-* semantic tokens for both light and dark modes,
    # using sensible defaults that bridge to existing --sw-color-* tokens.
    #
    # @return [String] CSS with :root and html.dark blocks
    def self.visual_skills_css
      <<~CSS
        /* ===========================================
           Visual Skills CSS Foundation (T2)
           Semantic tokens for visual skills components.
           All classes use sw- prefix with BEM modifiers:
             sw-component--variant  (e.g. sw-card--hero)
             sw-is-active           (state classes)
           =========================================== */

        /* Light mode defaults -- bridge to existing --sw-color-* tokens */
        :root {
          --sw-bg: var(--sw-color-bg, #f8f8f8);
          --sw-surface: var(--sw-color-bg-card, #ffffff);
          --sw-surface-elevated: var(--sw-color-bg-elevated, #f3f3f3);
          --sw-border: var(--sw-color-border, #e0e0e0);
          --sw-text: var(--sw-color-text, #111111);
          --sw-text-dim: var(--sw-color-text-muted, #444444);
          --sw-accent: var(--sw-color-accent, #0d9488);
          --sw-font-mono: 'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace;

          /* Diagram node palette */
          --sw-node-a: var(--sw-color-primary, #c2410c);
          --sw-node-b: var(--sw-color-accent, #0d9488);
          --sw-node-c: #7c3aed;

          /* Status colors */
          --sw-success: #16a34a;
          --sw-warning: #d97706;
          --sw-error: #dc2626;
          --sw-info: #2563eb;
        }

        /* Theme toggle button (sw- prefixed, BEM) */
        .sw-theme-toggle {
          display: inline-flex;
          align-items: center;
          gap: 0.375rem;
        }

        .sw-theme-toggle__btn {
          background: transparent;
          border: 1px solid var(--sw-border);
          border-radius: var(--sw-radius-md, 6px);
          padding: 0.375rem 0.5rem;
          cursor: pointer;
          font-size: 1.1rem;
          line-height: 1;
          color: var(--sw-text);
          transition: background 200ms ease-out, border-color 200ms ease-out;
        }

        .sw-theme-toggle__btn:hover {
          background: var(--sw-surface-elevated);
          border-color: var(--sw-accent);
        }

        .sw-theme-toggle__label {
          font-size: 0.75rem;
          color: var(--sw-text-dim);
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }

        /* Dark mode overrides */
        html.dark {
          --sw-bg: var(--sw-color-bg, oklch(0.145 0 0));
          --sw-surface: var(--sw-color-bg-card, oklch(0.205 0 0));
          --sw-surface-elevated: var(--sw-color-bg-elevated, oklch(0.269 0 0));
          --sw-border: var(--sw-color-border, oklch(1 0 0 / 10%));
          --sw-text: var(--sw-color-text, oklch(0.985 0 0));
          --sw-text-dim: var(--sw-color-text-muted, oklch(0.708 0 0));
          --sw-accent: var(--sw-color-accent, #2dd4bf);

          /* Brighter node colors for dark backgrounds */
          --sw-node-a: #f97316;
          --sw-node-b: #2dd4bf;
          --sw-node-c: #a78bfa;

          /* Brighter status colors for dark backgrounds */
          --sw-success: #22c55e;
          --sw-warning: #fbbf24;
          --sw-error: #f87171;
          --sw-info: #60a5fa;
        }

        /* ===========================================
           Card Depth Tiers (T6)
           sw-card--{depth} classes for visual hierarchy.
           =========================================== */

        .sw-card--hero {
          background: color-mix(in oklch, var(--sw-accent) 8%, var(--sw-surface));
          box-shadow: 0 4px 24px rgba(0, 0, 0, 0.12), 0 1px 4px rgba(0, 0, 0, 0.08);
          border-left: 4px solid var(--sw-accent);
        }

        .sw-card--elevated {
          background: var(--sw-surface);
          box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08), 0 1px 3px rgba(0, 0, 0, 0.06);
        }

        .sw-card--default {
          background: var(--sw-surface);
          border: 1px solid var(--sw-border);
          box-shadow: none;
        }

        .sw-card--recessed {
          background: var(--sw-surface-elevated);
          box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
          border: 1px solid var(--sw-border);
        }

        .sw-card--glass {
          background: rgba(255, 255, 255, 0.08);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
          border: 1px solid rgba(255, 255, 255, 0.15);
          box-shadow: 0 2px 16px rgba(0, 0, 0, 0.06);
        }

        html.dark .sw-card--glass {
          background: rgba(255, 255, 255, 0.05);
          border-color: rgba(255, 255, 255, 0.1);
        }

        /* Card accent borders (left border colored by node palette) */
        .sw-card--accent-a { border-left: 4px solid var(--sw-node-a); }
        .sw-card--accent-b { border-left: 4px solid var(--sw-node-b); }
        .sw-card--accent-c { border-left: 4px solid var(--sw-node-c); }
        .sw-card--accent   { border-left: 4px solid; }

        /* Card corner label */
        .sw-card__label {
          position: absolute;
          top: 0.5rem;
          right: 0.5rem;
          font-size: 0.625rem;
          font-weight: 700;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          padding: 0.125rem 0.5rem;
          border-radius: var(--sw-radius-sm, 4px);
          background: var(--sw-accent);
          color: white;
          line-height: 1.4;
        }

        /* Card with label: position: relative is applied inline by the component */

        /* ===========================================
           Table Enhancements (T6)
           sw-table--{feature} classes for enhanced tables.
           =========================================== */

        /* Alternating row backgrounds */
        .sw-table--alternating .sw-table__row--alt {
          background: var(--sw-surface-elevated, rgba(0, 0, 0, 0.02));
        }

        html.dark .sw-table--alternating .sw-table__row--alt {
          background: rgba(255, 255, 255, 0.03);
        }

        /* Row hover highlight */
        .sw-table--hover .sw-table__row--hover:hover {
          background: color-mix(in oklch, var(--sw-accent) 6%, transparent);
          transition: background 150ms ease-out;
        }

        /* Scrollable wrapper */
        .sw-table--scrollable {
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-md, 6px);
        }

        /* Sticky header styling */
        .sw-table--sticky-header thead {
          position: sticky;
          top: 0;
          z-index: 1;
        }

        #{Presets.animations_css}
      CSS
    end

    # Generate a Google Fonts <link> tag URL for the given font families.
    #
    # @param families [Array<String>] Google Fonts family strings
    #   e.g. ["Instrument+Serif:ital@0;1", "JetBrains+Mono:wght@400;500"]
    # @return [String] Full Google Fonts CSS URL
    def self.google_fonts_url(*families)
      families = families.flatten
      query = families.map { |f| "family=#{f}" }.join("&")
      "https://fonts.googleapis.com/css2?#{query}&display=swap"
    end

    private

    # Normalize variable keys to symbols
    def normalize_variables(vars)
      vars.transform_keys(&:to_sym)
    end
  end

  # Theme registry - stores custom themes
  @themes = {}

  class << self
    # Access the theme registry
    #
    # @return [Hash<Symbol, Theme>] Registered themes
    def themes
      @themes
    end

    # Register a custom theme
    #
    # @param name [Symbol] Theme identifier (used in theme: :name)
    # @param variables [Hash] CSS variable overrides
    # @param base [Symbol] Base theme to inherit from
    # @param label [String] Human-readable name
    # @param description [String] Short description
    # @return [Theme] The registered theme
    #
    # @example Basic registration
    #   StreamWeaver.register_theme :corporate, {
    #     color_primary: "#0066cc",
    #     font_family: "'Inter', system-ui, sans-serif"
    #   }
    #
    # @example With base theme
    #   StreamWeaver.register_theme :compact_corporate, {
    #     color_primary: "#0066cc"
    #   }, base: :dashboard
    def register_theme(name, variables = {}, base: :default, label: nil, description: nil)
      theme = Theme.new(name, variables, base: base, label: label, description: description)
      @themes[name.to_sym] = theme
      theme
    end

    # Get a theme by name (custom or built-in)
    #
    # @param name [Symbol] Theme name
    # @return [Theme, nil] The theme or nil if not found
    def get_theme(name)
      name = name.to_sym
      @themes[name] || (Theme::BUILT_IN_THEMES[name] && Theme.new(
        name,
        Theme::BUILT_IN_THEMES[name][:variables],
        label: Theme::BUILT_IN_THEMES[name][:name],
        description: Theme::BUILT_IN_THEMES[name][:description]
      ))
    end

    # Check if a theme exists (custom or built-in)
    #
    # @param name [Symbol] Theme name
    # @return [Boolean]
    def theme_exists?(name)
      name = name.to_sym
      @themes.key?(name) || Theme::BUILT_IN_THEMES.key?(name)
    end

    # Get all available theme names
    #
    # @return [Array<Symbol>] Theme names
    def available_themes
      (Theme::BUILT_IN_THEMES.keys + @themes.keys).uniq
    end

    # Get all themes as an array suitable for theme_switcher
    #
    # @return [Array<Hash>] Array of theme info hashes
    def all_themes_for_switcher
      built_in = Theme::BUILT_IN_THEMES.map do |id, info|
        { id: id, label: info[:name], description: info[:description] }
      end

      custom = @themes.map do |id, theme|
        { id: id, label: theme.label, description: theme.description }
      end

      built_in + custom
    end
  end
end
