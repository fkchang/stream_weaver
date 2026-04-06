# frozen_string_literal: true

RSpec.describe "Theme Enhancement + CSS Foundation (T2)" do
  # =========================================
  # Visual Skills CSS Custom Properties
  # =========================================

  describe "StreamWeaver::Theme.visual_skills_css" do
    let(:css) { StreamWeaver::Theme.visual_skills_css }

    it "generates CSS with --sw-* semantic tokens" do
      expect(css).to include("--sw-bg:")
      expect(css).to include("--sw-surface:")
      expect(css).to include("--sw-surface-elevated:")
      expect(css).to include("--sw-border:")
      expect(css).to include("--sw-text:")
      expect(css).to include("--sw-text-dim:")
      expect(css).to include("--sw-accent:")
    end

    it "includes node colors for diagrams" do
      expect(css).to include("--sw-node-a:")
      expect(css).to include("--sw-node-b:")
      expect(css).to include("--sw-node-c:")
    end

    it "includes status colors" do
      expect(css).to include("--sw-success:")
      expect(css).to include("--sw-warning:")
      expect(css).to include("--sw-error:")
      expect(css).to include("--sw-info:")
    end

    it "includes monospace font variable" do
      expect(css).to include("--sw-font-mono:")
    end

    it "defines light mode in :root" do
      expect(css).to match(/:root\s*\{[^}]*--sw-bg:/m)
    end

    it "defines dark mode overrides in html.dark" do
      expect(css).to match(/html\.dark\s*\{[^}]*--sw-bg:/m)
    end

    it "bridges to existing --sw-color-* tokens via var() fallbacks" do
      # Light mode should reference existing tokens for backward compat
      expect(css).to include("var(--sw-color-bg")
      expect(css).to include("var(--sw-color-text")
      expect(css).to include("var(--sw-color-border")
    end

    it "includes sw-theme-toggle CSS" do
      expect(css).to include(".sw-theme-toggle")
      expect(css).to include(".sw-theme-toggle__btn")
      expect(css).to include(".sw-theme-toggle__label")
    end
  end

  # =========================================
  # Theme Variable Schema
  # =========================================

  describe "StreamWeaver::Theme::VARIABLE_SCHEMA" do
    let(:schema) { StreamWeaver::Theme::VARIABLE_SCHEMA }

    it "includes visual skills semantic tokens" do
      expect(schema).to have_key(:vs_bg)
      expect(schema).to have_key(:vs_surface)
      expect(schema).to have_key(:vs_surface_elevated)
      expect(schema).to have_key(:vs_border)
      expect(schema).to have_key(:vs_text)
      expect(schema).to have_key(:vs_text_dim)
      expect(schema).to have_key(:vs_accent)
    end

    it "includes node color tokens" do
      expect(schema).to have_key(:vs_node_a)
      expect(schema).to have_key(:vs_node_b)
      expect(schema).to have_key(:vs_node_c)
    end

    it "includes status color tokens" do
      expect(schema).to have_key(:vs_success)
      expect(schema).to have_key(:vs_warning)
      expect(schema).to have_key(:vs_error)
      expect(schema).to have_key(:vs_info)
    end

    it "includes font_mono" do
      expect(schema).to have_key(:font_mono)
      expect(schema[:font_mono][:css]).to eq("--sw-font-mono")
    end

    it "maps vs_bg to --sw-bg CSS variable" do
      expect(schema[:vs_bg][:css]).to eq("--sw-bg")
    end

    it "preserves existing schema entries" do
      expect(schema).to have_key(:color_primary)
      expect(schema).to have_key(:font_display)
      expect(schema).to have_key(:spacing_md)
    end
  end

  # =========================================
  # Theme Presets
  # =========================================

  describe StreamWeaver::Theme::Presets do
    describe ".available" do
      it "returns at least editorial and technical" do
        expect(described_class.available).to include(:editorial, :technical)
      end
    end

    describe ".get" do
      it "returns editorial preset" do
        preset = described_class.get(:editorial)
        expect(preset).not_to be_nil
        expect(preset[:name]).to eq(:editorial)
        expect(preset[:fonts]).to have_key(:display)
        expect(preset[:fonts]).to have_key(:body)
        expect(preset[:fonts]).to have_key(:mono)
      end

      it "returns technical preset" do
        preset = described_class.get(:technical)
        expect(preset).not_to be_nil
        expect(preset[:name]).to eq(:technical)
      end

      it "returns nil for unknown preset" do
        expect(described_class.get(:nonexistent)).to be_nil
      end
    end

    describe ".google_fonts_url" do
      it "generates a valid Google Fonts URL for editorial" do
        preset = described_class.get(:editorial)
        url = described_class.google_fonts_url(preset)
        expect(url).to start_with("https://fonts.googleapis.com/css2?")
        expect(url).to include("Instrument+Serif")
        expect(url).to include("JetBrains+Mono")
        expect(url).to include("display=swap")
      end

      it "generates a valid Google Fonts URL for technical" do
        preset = described_class.get(:technical)
        url = described_class.google_fonts_url(preset)
        expect(url).to include("DM+Sans")
        expect(url).to include("Fira+Code")
      end
    end

    describe ".css_variables" do
      it "generates light mode variables" do
        preset = described_class.get(:editorial)
        vars = described_class.css_variables(preset, mode: :light)
        expect(vars["--sw-bg"]).to eq("#faf8f5")
        expect(vars["--sw-text"]).to eq("#1a1a1a")
        expect(vars["--sw-accent"]).to eq("#c2410c")
        expect(vars["--sw-font-display"]).to include("Instrument Serif")
        expect(vars["--sw-font-mono"]).to include("JetBrains Mono")
      end

      it "generates dark mode variables" do
        preset = described_class.get(:editorial)
        vars = described_class.css_variables(preset, mode: :dark)
        expect(vars["--sw-bg"]).to eq("#1a1816")
        expect(vars["--sw-text"]).to eq("#f5f0eb")
      end

      it "includes node and status colors" do
        preset = described_class.get(:technical)
        vars = described_class.css_variables(preset, mode: :light)
        expect(vars).to have_key("--sw-node-a")
        expect(vars).to have_key("--sw-node-b")
        expect(vars).to have_key("--sw-node-c")
        expect(vars).to have_key("--sw-success")
        expect(vars).to have_key("--sw-warning")
        expect(vars).to have_key("--sw-error")
        expect(vars).to have_key("--sw-info")
      end
    end

    describe "preset data-only constraint" do
      it "presets contain only data, not rendering logic" do
        StreamWeaver::Theme::Presets::REGISTRY.each do |name, preset|
          expect(preset).to be_a(Hash)
          expect(preset).to have_key(:name)
          expect(preset).to have_key(:fonts)
          expect(preset).to have_key(:colors)
          expect(preset).to have_key(:google_fonts)
          # No Proc, no Method, no blocks
          preset.each_value do |v|
            expect(v).not_to be_a(Proc)
            expect(v).not_to be_a(Method)
          end
        end
      end
    end
  end

  # =========================================
  # Auto Mode
  # =========================================

  describe StreamWeaver::Theme::AutoMode do
    describe ".inline_script" do
      let(:script) { described_class.inline_script }

      it "generates JavaScript" do
        expect(script).to be_a(String)
        expect(script.length).to be > 100
      end

      it "references localStorage for persistence" do
        expect(script).to include("localStorage")
        expect(script).to include("sw-theme-preference")
      end

      it "references prefers-color-scheme media query" do
        expect(script).to include("prefers-color-scheme")
      end

      it "defines swToggleTheme global function" do
        expect(script).to include("swToggleTheme")
      end

      it "defines swGetTheme global function" do
        expect(script).to include("swGetTheme")
      end

      it "manages data-sw-theme attribute" do
        expect(script).to include("data-sw-theme")
      end

      it "manages meta theme-color" do
        expect(script).to include("theme-color")
      end

      it "adds/removes html.dark class" do
        expect(script).to include("classList.toggle")
        expect(script).to include("'dark'")
      end

      it "accepts custom meta_colors" do
        custom = described_class.inline_script(meta_colors: { light: "#fff", dark: "#000" })
        expect(custom).to include("#fff")
        expect(custom).to include("#000")
      end
    end

    describe ".alpine_data" do
      let(:data) { described_class.alpine_data }

      it "returns a string for x-data" do
        expect(data).to be_a(String)
        expect(data).to include("preference")
        expect(data).to include("effective")
        expect(data).to include("toggle()")
        expect(data).to include("setMode(mode)")
      end

      it "references swToggleTheme" do
        expect(data).to include("swToggleTheme")
      end
    end
  end

  # =========================================
  # ThemeToggle Component
  # =========================================

  describe StreamWeaver::Components::ThemeToggle do
    it "initializes with default options" do
      toggle = described_class.new
      expect(toggle.mode).to eq(:auto)
      expect(toggle.hotkey).to be_nil
      expect(toggle.persist).to eq(true)
    end

    it "accepts custom options" do
      toggle = described_class.new(mode: :dark, hotkey: "mod+shift+l", persist: false)
      expect(toggle.mode).to eq(:dark)
      expect(toggle.hotkey).to eq("mod+shift+l")
      expect(toggle.persist).to eq(false)
    end
  end

  # =========================================
  # Google Fonts CDN Helper
  # =========================================

  describe "StreamWeaver::Theme.google_fonts_url" do
    it "generates a URL for single family" do
      url = StreamWeaver::Theme.google_fonts_url("DM+Sans:wght@400;500;600")
      expect(url).to start_with("https://fonts.googleapis.com/css2?")
      expect(url).to include("family=DM+Sans")
      expect(url).to include("display=swap")
    end

    it "generates a URL for multiple families" do
      url = StreamWeaver::Theme.google_fonts_url(
        "Instrument+Serif:ital@0;1",
        "JetBrains+Mono:wght@400;500"
      )
      expect(url).to include("family=Instrument+Serif")
      expect(url).to include("family=JetBrains+Mono")
    end

    it "accepts an array of families" do
      families = ["DM+Sans:wght@400", "Fira+Code:wght@400"]
      url = StreamWeaver::Theme.google_fonts_url(families)
      expect(url).to include("DM+Sans")
      expect(url).to include("Fira+Code")
    end
  end

  # =========================================
  # Backward Compatibility
  # =========================================

  describe "backward compatibility" do
    it "existing theme registration still works" do
      theme = StreamWeaver.register_theme(:test_compat, {
        color_primary: "#ff0000",
        font_family: "Arial"
      })
      expect(theme).to be_a(StreamWeaver::Theme)
      expect(theme.variables[:color_primary]).to eq("#ff0000")
      # Cleanup
      StreamWeaver.themes.delete(:test_compat)
    end

    it "existing built-in themes still exist" do
      expect(StreamWeaver.theme_exists?(:default)).to be true
      expect(StreamWeaver.theme_exists?(:dashboard)).to be true
      expect(StreamWeaver.theme_exists?(:document)).to be true
    end

    it "Theme#to_css still works" do
      theme = StreamWeaver::Theme.new(:test_css, { color_primary: "#ff0000" })
      css = theme.to_css
      expect(css).to include("body.sw-theme-test_css")
      expect(css).to include("--sw-color-primary: #ff0000")
    end

    it "existing VARIABLE_SCHEMA keys are preserved" do
      schema = StreamWeaver::Theme::VARIABLE_SCHEMA
      # Spot check existing keys haven't been removed
      %i[font_display font_body color_primary color_text color_bg
         spacing_md radius_md shadow_md card_border_left].each do |key|
        expect(schema).to have_key(key), "Expected schema to have key :#{key}"
      end
    end

    it "App accepts theme: parameter" do
      app = StreamWeaver::App.new("Test", theme: :default) { text "hello" }
      expect(app.theme).to eq(:default)
    end

    it "ThemeSwitcher still exists" do
      switcher = StreamWeaver::Components::ThemeSwitcher.new
      expect(switcher).to be_a(StreamWeaver::Components::ThemeSwitcher)
      expect(switcher.themes).to be_an(Array)
    end
  end

  # =========================================
  # DSL Integration
  # =========================================

  describe "DisplayDSL#theme_toggle" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        theme_toggle mode: :auto
      end
      app.rebuild_with_state({})
      toggle = app.components.find { |c| c.is_a?(StreamWeaver::Components::ThemeToggle) }
      expect(toggle).not_to be_nil
      expect(toggle.mode).to eq(:auto)
    end
  end

  # =========================================
  # sw- CSS Prefix Convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Theme.visual_skills_css }

    it "all new CSS class selectors use sw- prefix" do
      # Known framework-level exceptions (html.dark is the standard dark mode class)
      exceptions = %w[dark]

      # Extract only selector lines (lines containing '{' that define rules)
      # and pull class names from those lines only.
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq - exceptions

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end
end
