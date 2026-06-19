# frozen_string_literal: true

RSpec.describe "Theme Presets + Typography + Animations (T15)" do
  # =========================================
  # Preset Registry (5 total)
  # =========================================

  describe StreamWeaver::Theme::Presets do
    describe ".available" do
      it "returns 6 presets" do
        expect(described_class.available.length).to eq(6)
      end

      it "includes all expected preset names" do
        expect(described_class.available).to contain_exactly(
          :editorial, :technical, :warm, :minimal, :terminal, :sketch
        )
      end
    end

    describe ".get" do
      %i[editorial technical warm minimal terminal].each do |name|
        context "#{name} preset" do
          let(:preset) { described_class.get(name) }

          it "returns a non-nil preset" do
            expect(preset).not_to be_nil
          end

          it "has correct name" do
            expect(preset[:name]).to eq(name)
          end

          it "has a label" do
            expect(preset[:label]).to be_a(String)
            expect(preset[:label]).not_to be_empty
          end

          it "has a description" do
            expect(preset[:description]).to be_a(String)
            expect(preset[:description]).not_to be_empty
          end

          it "defines display, body, and mono fonts" do
            expect(preset[:fonts]).to have_key(:display)
            expect(preset[:fonts]).to have_key(:body)
            expect(preset[:fonts]).to have_key(:mono)
          end

          it "has Google Fonts families" do
            expect(preset[:google_fonts]).to be_an(Array)
            expect(preset[:google_fonts]).not_to be_empty
          end

          it "defines light palette" do
            light = preset[:colors][:light]
            expect(light).to have_key(:bg)
            expect(light).to have_key(:surface)
            expect(light).to have_key(:text)
            expect(light).to have_key(:accent)
            expect(light).to have_key(:node_a)
            expect(light).to have_key(:success)
          end

          it "defines dark palette" do
            dark = preset[:colors][:dark]
            expect(dark).to have_key(:bg)
            expect(dark).to have_key(:surface)
            expect(dark).to have_key(:text)
            expect(dark).to have_key(:accent)
            expect(dark).to have_key(:node_a)
            expect(dark).to have_key(:success)
          end
        end
      end

      it "returns nil for unknown preset" do
        expect(described_class.get(:nonexistent)).to be_nil
      end
    end

    # =========================================
    # Preset-specific font/color assertions
    # =========================================

    describe "editorial preset fonts+colors" do
      let(:preset) { described_class.get(:editorial) }

      it "uses Instrument Serif for display" do
        expect(preset[:fonts][:display]).to include("Instrument Serif")
      end

      it "uses JetBrains Mono for monospace" do
        expect(preset[:fonts][:mono]).to include("JetBrains Mono")
      end

      it "has terracotta accent in light mode" do
        expect(preset[:colors][:light][:accent]).to eq("#c2410c")
      end
    end

    describe "warm preset fonts+colors" do
      let(:preset) { described_class.get(:warm) }

      it "uses Nunito for display" do
        expect(preset[:fonts][:display]).to include("Nunito")
      end

      it "uses Source Serif 4 for body" do
        expect(preset[:fonts][:body]).to include("Source Serif 4")
      end

      it "has amber accent" do
        expect(preset[:colors][:light][:accent]).to eq("#d97706")
      end
    end

    describe "terminal preset fonts+colors" do
      let(:preset) { described_class.get(:terminal) }

      it "uses monospace for all fonts" do
        expect(preset[:fonts][:display]).to include("JetBrains Mono")
        expect(preset[:fonts][:body]).to include("JetBrains Mono")
        expect(preset[:fonts][:mono]).to include("JetBrains Mono")
      end

      it "has green accent in dark mode" do
        expect(preset[:colors][:dark][:accent]).to eq("#00ff41")
      end

      it "has green text in dark mode" do
        expect(preset[:colors][:dark][:text]).to eq("#00ff41")
      end
    end

    describe "minimal preset fonts+colors" do
      let(:preset) { described_class.get(:minimal) }

      it "uses Inter for display and body" do
        expect(preset[:fonts][:display]).to include("Inter")
        expect(preset[:fonts][:body]).to include("Inter")
      end

      it "uses IBM Plex Mono for monospace" do
        expect(preset[:fonts][:mono]).to include("IBM Plex Mono")
      end

      it "has near-black accent (monochrome)" do
        expect(preset[:colors][:light][:accent]).to eq("#171717")
      end
    end

    describe "sketch preset" do
      let(:preset) { described_class.get(:sketch) }

      it "is registered" do
        expect(preset).not_to be_nil
      end

      it "has sketch flag set to true" do
        expect(preset[:sketch]).to be true
      end

      it "uses a hand-drawn font (Caveat)" do
        expect(preset[:fonts][:display]).to include("Caveat")
        expect(preset[:fonts][:body]).to include("Caveat")
      end

      it "includes Caveat in google_fonts" do
        expect(preset[:google_fonts].first).to include("Caveat")
      end
    end

    # =========================================
    # Google Fonts URL generation
    # =========================================

    describe ".google_fonts_url" do
      it "generates valid URL for warm preset" do
        preset = described_class.get(:warm)
        url = described_class.google_fonts_url(preset)
        expect(url).to start_with("https://fonts.googleapis.com/css2?")
        expect(url).to include("Nunito")
        expect(url).to include("Source+Serif+4")
        expect(url).to include("display=swap")
      end

      it "generates valid URL for terminal preset" do
        preset = described_class.get(:terminal)
        url = described_class.google_fonts_url(preset)
        expect(url).to include("JetBrains+Mono")
      end

      it "generates valid URL for minimal preset" do
        preset = described_class.get(:minimal)
        url = described_class.google_fonts_url(preset)
        expect(url).to include("Inter")
        expect(url).to include("IBM+Plex+Mono")
      end
    end

    # =========================================
    # CSS variable generation
    # =========================================

    describe ".css_variables" do
      %i[warm minimal terminal].each do |name|
        context "#{name} preset" do
          let(:preset) { described_class.get(name) }

          it "generates light mode variables" do
            vars = described_class.css_variables(preset, mode: :light)
            expect(vars).to have_key("--sw-bg")
            expect(vars).to have_key("--sw-text")
            expect(vars).to have_key("--sw-accent")
            expect(vars).to have_key("--sw-font-display")
            expect(vars).to have_key("--sw-font-body")
            expect(vars).to have_key("--sw-font-mono")
          end

          it "generates dark mode variables" do
            vars = described_class.css_variables(preset, mode: :dark)
            expect(vars).to have_key("--sw-bg")
            expect(vars).to have_key("--sw-text")
            expect(vars).to have_key("--sw-accent")
          end

          it "includes node and status colors" do
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
      end
    end

    # =========================================
    # Preset CSS generation
    # =========================================

    describe ".generate_preset_css" do
      it "generates CSS for editorial preset" do
        css = described_class.generate_preset_css(:editorial)
        expect(css).to include("Theme preset: Editorial")
        expect(css).to include(":root {")
        expect(css).to include("html.dark {")
        expect(css).to include("--sw-bg:")
        expect(css).to include("--sw-text:")
        expect(css).to include("--sw-accent:")
        expect(css).to include("Instrument Serif")
      end

      it "generates CSS for warm preset" do
        css = described_class.generate_preset_css(:warm)
        expect(css).to include("Theme preset: Warm")
        expect(css).to include("Nunito")
        expect(css).to include("Source Serif 4")
      end

      it "generates CSS for terminal preset" do
        css = described_class.generate_preset_css(:terminal)
        expect(css).to include("Theme preset: Terminal")
        expect(css).to include("JetBrains Mono")
        expect(css).to include("#00ff41") # dark mode green
      end

      it "includes font-family rules for body and headings" do
        css = described_class.generate_preset_css(:editorial)
        expect(css).to include("body {")
        expect(css).to include("h1, h2, h3, h4, h5, h6 {")
        expect(css).to include("code, pre, .sw-code-block {")
      end

      it "returns empty string for unknown preset" do
        expect(described_class.generate_preset_css(:nonexistent)).to eq("")
      end
    end

    # =========================================
    # Data-only constraint
    # =========================================

    describe "preset data-only constraint" do
      it "all presets contain only data, not rendering logic" do
        StreamWeaver::Theme::Presets::REGISTRY.each do |name, preset|
          expect(preset).to be_a(Hash), "#{name} is not a Hash"
          expect(preset).to have_key(:name)
          expect(preset).to have_key(:fonts)
          expect(preset).to have_key(:colors)
          expect(preset).to have_key(:google_fonts)
          preset.each_value do |v|
            expect(v).not_to be_a(Proc)
            expect(v).not_to be_a(Method)
          end
        end
      end
    end
  end

  # =========================================
  # ThemePreset Component
  # =========================================

  describe StreamWeaver::Components::ThemePreset do
    it "initializes with a valid preset name" do
      component = described_class.new(:editorial)
      expect(component.preset_name).to eq(:editorial)
      expect(component.preset).not_to be_nil
      expect(component.preset[:name]).to eq(:editorial)
    end

    it "accepts string preset name" do
      component = described_class.new("warm")
      expect(component.preset_name).to eq(:warm)
    end

    it "raises ArgumentError for unknown preset" do
      expect { described_class.new(:nonexistent) }.to raise_error(ArgumentError, /Unknown theme preset/)
    end

    %i[editorial technical warm minimal terminal sketch].each do |name|
      it "accepts :#{name} preset" do
        component = described_class.new(name)
        expect(component.preset_name).to eq(name)
      end
    end
  end

  # =========================================
  # DSL Integration
  # =========================================

  describe "DisplayDSL#theme_preset" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        theme_preset :editorial
      end
      app.rebuild_with_state({})
      preset_component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ThemePreset) }
      expect(preset_component).not_to be_nil
      expect(preset_component.preset_name).to eq(:editorial)
    end

    it "applies warm preset via DSL" do
      app = StreamWeaver::App.new("Warm Test") do
        theme_preset :warm
        text "Hello warm world"
      end
      app.rebuild_with_state({})
      preset_component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ThemePreset) }
      expect(preset_component).not_to be_nil
      expect(preset_component.preset_name).to eq(:warm)
    end

    it "applies terminal preset via DSL" do
      app = StreamWeaver::App.new("Terminal Test") do
        theme_preset :terminal
      end
      app.rebuild_with_state({})
      preset_component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ThemePreset) }
      expect(preset_component.preset_name).to eq(:terminal)
    end
  end

  # =========================================
  # CSS Animations
  # =========================================

  describe "StreamWeaver::Theme::Presets.animations_css" do
    let(:css) { StreamWeaver::Theme::Presets.animations_css }

    it "defines sw-fadeIn keyframes" do
      expect(css).to include("@keyframes sw-fadeIn")
    end

    it "defines sw-slideUp keyframes" do
      expect(css).to include("@keyframes sw-slideUp")
    end

    it "defines sw-fadeScale keyframes" do
      expect(css).to include("@keyframes sw-fadeScale")
    end

    it "defines sw-shimmer keyframes" do
      expect(css).to include("@keyframes sw-shimmer")
    end

    it "defines sw-slideDown keyframes" do
      expect(css).to include("@keyframes sw-slideDown")
    end

    it "provides sw-animate-fadeIn utility class" do
      expect(css).to include(".sw-animate-fadeIn")
    end

    it "provides sw-animate-slideUp utility class" do
      expect(css).to include(".sw-animate-slideUp")
    end

    it "provides sw-animate-fadeScale utility class" do
      expect(css).to include(".sw-animate-fadeScale")
    end

    it "provides sw-animate-shimmer utility class" do
      expect(css).to include(".sw-animate-shimmer")
    end

    it "provides stagger delay helpers" do
      expect(css).to include(".sw-stagger")
      expect(css).to include("--sw-stagger-delay")
    end

    it "provides slide transition classes" do
      expect(css).to include(".sw-slide-transition")
      expect(css).to include(".sw-slide-enter")
      expect(css).to include(".sw-slide-exit")
    end

    it "respects prefers-reduced-motion" do
      expect(css).to include("prefers-reduced-motion: reduce")
      expect(css).to include("animation: none !important")
    end

    it "all CSS classes use sw- prefix" do
      # Extract class selectors from the animations CSS
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "Animation CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # Animations in visual_skills_css
  # =========================================

  describe "animations in visual_skills_css" do
    let(:css) { StreamWeaver::Theme.visual_skills_css }

    it "includes fadeIn animation" do
      expect(css).to include("@keyframes sw-fadeIn")
      expect(css).to include(".sw-animate-fadeIn")
    end

    it "includes slideUp animation" do
      expect(css).to include("@keyframes sw-slideUp")
      expect(css).to include(".sw-animate-slideUp")
    end

    it "includes fadeScale animation" do
      expect(css).to include("@keyframes sw-fadeScale")
      expect(css).to include(".sw-animate-fadeScale")
    end

    it "includes stagger helpers" do
      expect(css).to include(".sw-stagger")
    end
  end

  # =========================================
  # Backward Compatibility
  # =========================================

  describe "backward compatibility" do
    it "existing theme registration still works" do
      theme = StreamWeaver.register_theme(:t15_compat, {
        color_primary: "#ff0000"
      })
      expect(theme).to be_a(StreamWeaver::Theme)
      StreamWeaver.themes.delete(:t15_compat)
    end

    it "existing presets (editorial, technical) unchanged" do
      editorial = StreamWeaver::Theme::Presets.get(:editorial)
      expect(editorial[:fonts][:display]).to include("Instrument Serif")
      expect(editorial[:colors][:light][:accent]).to eq("#c2410c")

      technical = StreamWeaver::Theme::Presets.get(:technical)
      expect(technical[:fonts][:display]).to include("DM Sans")
      expect(technical[:colors][:light][:accent]).to eq("#0d9488")
    end

    it "theme_toggle DSL still works" do
      app = StreamWeaver::App.new("Compat Test") do
        theme_toggle mode: :auto
      end
      app.rebuild_with_state({})
      toggle = app.components.find { |c| c.is_a?(StreamWeaver::Components::ThemeToggle) }
      expect(toggle).not_to be_nil
    end
  end
end
