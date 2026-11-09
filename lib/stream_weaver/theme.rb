# frozen_string_literal: true

require 'json'
require_relative 'fonts' unless RUBY_ENGINE == 'opal' # register_theme resolves self-hosted fonts
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
      color_secondary_foreground: { css: "--sw-color-secondary-foreground", type: :color },

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

    # Surface tokens (the colors_neutral and shadows groups): the ones the
    # framework's dark block (html.dark body in master_theme_css) gives its
    # own value. Owner decision 2: a light value for a surface token applies
    # in light mode only unless the caller passes dark:, while every other
    # token (primary, accent, type, spacing) applies in both modes.
    SURFACE_TOKENS = %i[
      color_text color_text_muted color_text_light color_bg color_bg_card color_bg_elevated
      color_border color_border_strong color_border_focus
      shadow_sm shadow_md shadow_lg shadow_xl shadow_inner
    ].freeze

    # Where an app's own tokens (theme_tokens, theme_overrides:) apply: the
    # body of any themed page. Same specificity as a theme's body.sw-theme-X
    # block, and emitted after it, so it wins in light mode; the framework's
    # dark blocks still outrank its light block, so a surface token keeps
    # losing in dark mode. Theme-agnostic because a canvas push does not know
    # the page theme.
    TOKEN_SCOPE = 'body[class*="sw-theme-"]'

    # The selectors that mean "dark mode": AutoMode and the theme toggle set
    # both on <html>, and the built-in themes key on one or the other.
    # Generated CSS matches either, so a host that sets only
    # data-sw-theme="dark" on :default (which keys on html.dark alone) gets a
    # dark: background with :default's light-mode text unless dark: also
    # gives a text token.
    DARK_SIGNALS = ['html.dark', 'html[data-sw-theme="dark"]'].freeze

    # The scope that means <html> itself, where the dark signals live.
    ROOT_SCOPE = ":root"

    # The one token CSS generator: scope {} for the light tokens, then the
    # scope under either dark signal for the dark tokens (left out if none).
    #
    # @param scope [String] a selector, or ROOT_SCOPE for <html> itself
    # @param light [Hash] VARIABLE_SCHEMA keys or raw custom property names => values
    # @param dark [Hash] the same, for dark mode
    # @param carry [Boolean] true carries the light tokens into dark mode
    #   under owner decision 2 (dark_tokens); false uses dark: as given
    # @return [String] CSS
    def self.token_css(scope, light, dark: {}, carry: false)
      dark = dark_tokens(light, dark) if carry
      dark_scope = DARK_SIGNALS.map { |signal| scope == ROOT_SCOPE ? signal : "#{signal} #{scope}" }.join(", ")
      [[scope, light], [dark_scope, dark]].reject { |_, tokens| tokens.empty? }.map do |selector, tokens|
        "#{selector} {\n#{tokens.map { |key, value| "  #{css_property(key)}: #{value};" }.join("\n")}\n}\n"
      end.join
    end

    # Owner decision 2: dark mode carries every light token except the
    # surface ones, then the caller's dark: tokens.
    #
    # @return [Hash] the dark tokens for token_css
    def self.dark_tokens(light, dark)
      light.reject { |key, _| SURFACE_TOKENS.include?(key.to_sym) }.merge(dark)
    end

    # @return [String] the custom property a token key names
    def self.css_property(key)
      name = key.to_s
      return name if name.start_with?("--")

      VARIABLE_SCHEMA.dig(key.to_sym, :css) || "--sw-#{name.tr('_', '-').delete_prefix('sw-')}"
    end

    attr_reader :name, :variables, :dark, :css, :base_theme, :label, :description, :fonts, :stylesheets

    # @param name [Symbol] Theme identifier
    # @param variables [Hash] Theme variable overrides
    # @param base [Symbol] Base theme to inherit from (:default, :dashboard, :document)
    # @param label [String] Human-readable name
    # @param description [String] Short description
    # @param fonts [Array<String>] Google Fonts entries (Fonts.google_fonts_href format) the page head loads
    # @param stylesheets [Array<String>] Stylesheet URLs the page head loads
    # @param dark [Hash] dark-mode token values (see SURFACE_TOKENS for what carries over without one)
    # @param css [String, nil] extra CSS appended after the generated token CSS
    # @param built_in [Boolean] true for the framework's own themes, whose CSS lives in master_theme_css
    def initialize(name, variables = {}, base: :default, label: nil, description: nil,
                   fonts: [], stylesheets: [], dark: {}, css: nil, built_in: false)
      @name = name.to_sym
      @base_theme = base.to_sym
      @variables = normalize_variables(variables)
      @dark = normalize_variables(dark)
      @css = css
      @label = label || name.to_s.split('_').map(&:capitalize).join(' ')
      @description = description || "Custom theme"
      @fonts = fonts
      @stylesheets = stylesheets
      @built_in = built_in
    end

    def built_in?
      @built_in
    end

    # This theme's CSS: its light and dark tokens from the generator, then its css:.
    #
    # @return [String] CSS
    def to_css
      tokens = Theme.token_css("body.sw-theme-#{@name}", @variables, dark: @dark, carry: true)
      @css ? "#{tokens}#{@css}\n" : tokens
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
        colors_secondary: %i[color_secondary color_secondary_hover color_secondary_foreground color_accent color_accent_light],
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

        /* Re-bridge on body: --sw-color-* (what these fall back to) is itself
           declared on body (per-theme, or an app's theme_overrides:), a
           descendant of :root -- so the :root block above can never see it and
           is stuck on its own light-mode fallback. Redeclaring here lets these
           short tokens track whatever theme body actually ends up with
           (stream_weaver-9u2). */
        body {
          --sw-bg: var(--sw-color-bg, #f8f8f8);
          --sw-surface: var(--sw-color-bg-card, #ffffff);
          --sw-surface-elevated: var(--sw-color-bg-elevated, #f3f3f3);
          --sw-border: var(--sw-color-border, #e0e0e0);
          --sw-text: var(--sw-color-text, #111111);
          --sw-text-dim: var(--sw-color-text-muted, #444444);
          --sw-accent: var(--sw-color-accent, #0d9488);
          --sw-node-a: var(--sw-color-primary, #c2410c);
          --sw-node-b: var(--sw-color-accent, #0d9488);
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

    private

    # Normalize variable keys to symbols
    def normalize_variables(vars)
      vars.transform_keys(&:to_sym)
    end
  end

  # Theme registry: the built-in themes (theme/built_ins.rb) and any custom ones
  @themes = {}

  class << self
    # Access the theme registry
    #
    # @return [Hash<Symbol, Theme>] Registered themes, built-ins first
    def themes
      @themes
    end

    # Register a theme
    #
    # @param name [Symbol] Theme identifier (used in theme: :name)
    # @param variables [Hash] CSS variable overrides
    # @param base [Symbol] Base theme to inherit from
    # @param label [String] Human-readable name
    # @param description [String] Short description
    # @param fonts [Array<String, Hash>] fonts the page head loads: Google Fonts
    #   entries, or { family:, src: } for a self-hosted file (a relative src
    #   resolves against the file that registers the theme)
    # @param stylesheets [Array<String>] Stylesheet URLs the page head loads
    # @param dark [Hash] dark-mode token values; without one a surface token
    #   (Theme::SURFACE_TOKENS) is light-only and every other token applies in both modes
    # @param css [String, nil] extra CSS emitted after the generated token CSS
    # @return [Theme] The registered theme
    #
    # @example A theme from a hash, light and dark, no hand-written token CSS
    #   StreamWeaver.register_theme :harbor,
    #     { color_primary: "#0e7490", color_bg: "#f7fafa" },
    #     dark: { color_primary: "#22d3ee", color_bg: "#0b1416" },
    #     fonts: ["Inter:wght@400;600"], label: "Harbor",
    #     css: "body.sw-theme-harbor h2 { letter-spacing: -0.01em; }"
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
    def register_theme(name, variables = {}, base: :default, label: nil, description: nil,
                       fonts: [], stylesheets: [], dark: {}, css: nil)
      warn_replacing_built_in_theme(name.to_sym)
      if fonts.any?(Hash)
        fonts = Fonts.resolve(fonts, File.dirname(File.expand_path(caller_locations(1, 1).first.path)))
      end
      @themes[name.to_sym] = Theme.new(name, variables, base: base, label: label, description: description,
                                                        fonts: fonts, stylesheets: stylesheets, dark: dark, css: css)
    end

    # Names of the framework's own themes, in registry order
    #
    # @return [Array<Symbol>]
    def built_in_themes
      @themes.values.select(&:built_in?).map(&:name)
    end

    # The framework's own themes register here (theme/built_ins.rb): listed
    # like any theme, but their CSS lives in master_theme_css.
    private def register_built_in_theme(name, label:, description:, fonts: [], stylesheets: [])
      @themes[name.to_sym] = Theme.new(name, label: label, description: description,
                                             fonts: fonts, stylesheets: stylesheets, built_in: true)
    end

    # Registering a built-in's name replaces it with a custom theme: its page
    # wears the base class plus its own (sw-theme-default sw-theme-default),
    # loses the hand-tuned CSS and drops out of built_in_themes. Say so once.
    private def warn_replacing_built_in_theme(name)
      return unless get_theme(name)&.built_in?

      @warned_built_in_names ||= []
      return if @warned_built_in_names.include?(name)

      @warned_built_in_names << name
      warn "StreamWeaver: register_theme #{name.inspect} replaces the built-in #{name.inspect} theme " \
           "with a custom one; pick another name and base: #{name.inspect} to build on it."
    end

    # Get a theme by name (custom or built-in)
    #
    # @param name [Symbol] Theme name
    # @return [Theme, nil] The theme or nil if not found
    def get_theme(name)
      @themes[name.to_sym]
    end

    # Google Fonts entries (Fonts.google_fonts_href format) a theme loads.
    #
    # @param name [Symbol, nil] Theme name
    # @return [Array<String>]
    def theme_fonts(name)
      (name && get_theme(name)&.fonts) || []
    end

    # Stylesheet URLs a theme loads (version-pinned CDN fonts).
    #
    # @param name [Symbol, nil] Theme name
    # @return [Array<String>]
    def theme_stylesheets(name)
      (name && get_theme(name)&.stylesheets) || []
    end

    # Check if a theme exists (custom or built-in)
    #
    # @param name [Symbol] Theme name
    # @return [Boolean]
    def theme_exists?(name)
      @themes.key?(name.to_sym)
    end

    # Get all available theme names
    #
    # @return [Array<Symbol>] Theme names
    def available_themes
      @themes.keys
    end

    # Get all themes as an array suitable for theme_switcher
    #
    # @return [Array<Hash>] Array of theme info hashes
    def all_themes_for_switcher
      @themes.map do |id, theme|
        { id: id, label: theme.label, description: theme.description }
      end
    end
  end
end

require_relative 'theme/built_ins'
