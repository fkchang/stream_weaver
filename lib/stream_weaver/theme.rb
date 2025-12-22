# frozen_string_literal: true

require 'json'

module StreamWeaver
  # Custom theme registration and management
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
      term_bg_hover: { css: "--sw-term-bg-hover", type: :color }
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
