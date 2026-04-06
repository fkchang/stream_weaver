# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe "Deck Selection Behavior (T8)" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:tmpdir) { Dir.mktmpdir("deck_selection_test") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  # Helper to render a deck app with optional deck_state in state hash
  def render_deck_app(state = {}, &block)
    app = StreamWeaver::App.new("Test", &block)
    app.rebuild_with_state(state)
    deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
    StreamWeaver::ComponentRenderer.render_html(adapter, [deck], state)
  end

  def build_deck_state(session_id = "test-session")
    StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir)
  end

  # =========================================
  # DeckOption slide_id and option_index
  # =========================================

  describe "DeckOption slide context" do
    it "sets slide_id on options via DSL" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Test" do
          slide "arch", "Architecture" do
            option "Monolith" do
              text "Simple"
            end
            option "Microservices" do
              text "Complex"
            end
          end
        end
      end
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      slide = deck.children.first
      opts = slide.children.select { |c| c.is_a?(StreamWeaver::Components::Deck::DeckOption) }

      expect(opts[0].slide_id).to eq("arch")
      expect(opts[1].slide_id).to eq("arch")
    end

    it "sets option_index on options (0-based)" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
            option "B" do text "B" end
            option "C" do text "C" end
          end
        end
      end
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      slide = deck.children.first
      opts = slide.children.select { |c| c.is_a?(StreamWeaver::Components::Deck::DeckOption) }

      expect(opts[0].option_index).to eq(0)
      expect(opts[1].option_index).to eq(1)
      expect(opts[2].option_index).to eq(2)
    end
  end

  # =========================================
  # Selection Rendering
  # =========================================

  describe "selection rendering" do
    it "renders unselected state by default (no deck_state)" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include('aria-checked="false"')
      # No element should have the selected class attribute (CSS in <style> tag has the class name, so check attribute context)
      expect(html).not_to include('class="sw-deck-option sw-deck-option--selected')
    end

    it "renders selected state when option is selected in deck_state" do
      deck_state = build_deck_state
      deck_state.select("s1", "A")
      state = { _deck_state: deck_state }

      html = render_deck_app(state) do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
            option "B" do text "B" end
          end
        end
      end

      # Parse out the option cards
      expect(html).to include('sw-deck-option--selected')
      expect(html).to include('aria-checked="true"')
    end

    it "renders only one option as selected per slide" do
      deck_state = build_deck_state
      deck_state.select("s1", "B")
      state = { _deck_state: deck_state }

      html = render_deck_app(state) do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
            option "B" do text "B" end
          end
        end
      end

      # Count aria-checked="true" occurrences (more reliable than CSS class which appears in <style>)
      checked_count = html.scan('aria-checked="true"').length
      expect(checked_count).to eq(1)
    end

    it "renders data-slide-id and data-option-label attributes" do
      html = render_deck_app do
        design_deck "Test" do
          slide "arch" do
            option "Monolith" do text "Simple" end
          end
        end
      end
      expect(html).to include('data-slide-id="arch"')
      expect(html).to include('data-option-label="Monolith"')
    end

    it "renders data-option-index attribute" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
            option "B" do text "B" end
          end
        end
      end
      expect(html).to include('data-option-index="0"')
      expect(html).to include('data-option-index="1"')
    end
  end

  # =========================================
  # Notes Rendering
  # =========================================

  describe "notes rendering" do
    it "renders empty textarea when no notes exist" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include("sw-deck-option__notes-input")
      expect(html).to include("Add notes...")
    end

    it "renders persisted note text in textarea" do
      deck_state = build_deck_state
      deck_state.set_note("s1", "A", "My important note")
      state = { _deck_state: deck_state }

      html = render_deck_app(state) do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include("My important note")
    end

    it "renders blur handler on notes textarea" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include('@blur="swDeckSaveNote($el)"')
    end
  end

  # =========================================
  # Click Handler
  # =========================================

  describe "click handler" do
    it "renders @click handler for selection" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include('@click="swDeckSelect($el)"')
    end
  end

  # =========================================
  # Selection JS
  # =========================================

  describe "selection JavaScript" do
    it "injects selection JS" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include("swDeckSelect")
      expect(html).to include("swDeckSaveNote")
    end

    it "includes number key quick-select handler" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include("parseInt(e.key)")
    end
  end

  # =========================================
  # CSS Selection Styles
  # =========================================

  describe "CSS selection styles" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::DECK_CSS }

    it "includes selected state styles" do
      expect(css).to include(".sw-deck-option--selected")
    end

    it "includes selected radio dot style" do
      expect(css).to include(".sw-deck-option--selected .sw-deck-option__radio-dot")
    end

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # DeckOption css_classes with selection
  # =========================================

  describe "DeckOption#css_classes" do
    it "includes sw-deck-option--selected when selected: true" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A")
      expect(opt.css_classes(selected: true)).to include("sw-deck-option--selected")
    end

    it "does not include selected class by default" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A")
      expect(opt.css_classes).not_to include("sw-deck-option--selected")
    end

    it "combines selected with recommended" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A", recommended: true)
      classes = opt.css_classes(selected: true)
      expect(classes).to include("sw-deck-option--recommended")
      expect(classes).to include("sw-deck-option--selected")
    end
  end

  # =========================================
  # ARIA Attributes
  # =========================================

  describe "ARIA attributes" do
    it "renders role=radio on options" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include('role="radio"')
    end

    it "renders role=radiogroup on options grid" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1", "Title" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include('role="radiogroup"')
    end

    it "renders aria-checked=true for selected option" do
      deck_state = build_deck_state
      deck_state.select("s1", "A")
      state = { _deck_state: deck_state }

      html = render_deck_app(state) do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
          end
        end
      end
      expect(html).to include('aria-checked="true"')
    end

    it "renders aria-checked=false for unselected option" do
      deck_state = build_deck_state
      deck_state.select("s1", "B")
      state = { _deck_state: deck_state }

      html = render_deck_app(state) do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
            option "B" do text "B" end
          end
        end
      end
      # Option A should be unchecked
      # We need to verify through the structure - A comes before B
      # and only B is selected
      expect(html).to include('aria-checked="false"')
      expect(html).to include('aria-checked="true"')
    end
  end

  # =========================================
  # Integration: Selection + Notes together
  # =========================================

  describe "integration: selection + notes" do
    it "renders both selection state and notes" do
      deck_state = build_deck_state
      deck_state.select("s1", "A")
      deck_state.set_note("s1", "A", "Great choice!")
      deck_state.set_note("s1", "B", "Also good")
      state = { _deck_state: deck_state }

      html = render_deck_app(state) do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
            option "B" do text "B" end
          end
        end
      end

      expect(html).to include("sw-deck-option--selected")
      expect(html).to include("Great choice!")
      expect(html).to include("Also good")
    end

    it "works across multiple slides" do
      deck_state = build_deck_state
      deck_state.select("s1", "A")
      deck_state.select("s2", "Y")
      state = { _deck_state: deck_state }

      html = render_deck_app(state) do
        design_deck "Test" do
          slide "s1" do
            option "A" do text "A" end
            option "B" do text "B" end
          end
          slide "s2" do
            option "X" do text "X" end
            option "Y" do text "Y" end
          end
        end
      end

      # Both slides should have a selected option
      checked_count = html.scan('aria-checked="true"').length
      expect(checked_count).to eq(2)
    end
  end
end
