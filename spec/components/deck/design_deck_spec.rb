# frozen_string_literal: true

RSpec.describe "DesignDeck Component (T7)" do
  # =========================================
  # DesignDeck Class
  # =========================================

  describe StreamWeaver::Components::Deck::DesignDeck do
    it "initializes with title" do
      deck = described_class.new("Architecture Direction")
      expect(deck.title).to eq("Architecture Direction")
    end

    it "has empty children by default" do
      deck = described_class.new("Test")
      expect(deck.children).to eq([])
    end

    it "allows setting children" do
      deck = described_class.new("Test")
      slide = StreamWeaver::Components::Deck::DeckSlide.new("s1", "Slide 1")
      deck.children = [slide]
      expect(deck.children.length).to eq(1)
    end

    describe "#css_classes" do
      it "returns sw-deck" do
        deck = described_class.new("Test")
        expect(deck.css_classes).to eq("sw-deck")
      end
    end

    describe "#validate!" do
      it "passes with unique slide IDs" do
        deck = described_class.new("Test")
        deck.children = [
          StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture"),
          StreamWeaver::Components::Deck::DeckSlide.new("db", "Database")
        ]
        expect { deck.validate! }.not_to raise_error
      end

      it "raises on duplicate slide IDs" do
        deck = described_class.new("Test")
        deck.children = [
          StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture"),
          StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture Again")
        ]
        expect { deck.validate! }.to raise_error(ArgumentError, /Duplicate slide IDs.*arch/)
      end

      it "passes with no slides" do
        deck = described_class.new("Empty")
        expect { deck.validate! }.not_to raise_error
      end
    end

    describe "#render" do
      it "delegates to adapter" do
        deck = described_class.new("Test")
        adapter = double("adapter")
        view = double("view", adapter: adapter)
        expect(adapter).to receive(:render_design_deck).with(view, deck, {})
        deck.render(view, {})
      end
    end
  end

  # =========================================
  # DSL Integration
  # =========================================

  describe "App#design_deck DSL" do
    it "creates a design deck via DSL" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Architecture Direction" do
          slide "arch", "System Architecture" do
            option "Monolith" do
              text "Simple"
            end
          end
        end
      end
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      expect(deck).not_to be_nil
      expect(deck.title).to eq("Architecture Direction")
    end

    it "creates slides as children of the deck" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Test Deck" do
          slide "arch", "Architecture" do
            option "A" do
              text "Option A"
            end
          end
          slide "db", "Database" do
            option "B" do
              text "Option B"
            end
          end
        end
      end
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      slides = deck.children.select { |c| c.is_a?(StreamWeaver::Components::Deck::DeckSlide) }
      expect(slides.length).to eq(2)
      expect(slides[0].id).to eq("arch")
      expect(slides[1].id).to eq("db")
    end

    it "creates options as children of slides" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Test Deck" do
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
      options = slide.children.select { |c| c.is_a?(StreamWeaver::Components::Deck::DeckOption) }
      expect(options.length).to eq(2)
      expect(options[0].label).to eq("Monolith")
      expect(options[1].label).to eq("Microservices")
    end

    it "nests preview blocks inside options" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Test Deck" do
          slide "arch", "Architecture" do
            option "Monolith" do
              code_block "app.listen(3000)", lang: "ts"
              text "Simple deployment"
            end
          end
        end
      end
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      opt = deck.children.first.children.first
      expect(opt.children.length).to eq(2)
      expect(opt.children[0]).to be_a(StreamWeaver::Components::CodeBlock)
      expect(opt.children[1]).to be_a(StreamWeaver::Components::Text)
    end

    it "validates duplicate slide IDs" do
      expect {
        app = StreamWeaver::App.new("Test") do
          design_deck "Test Deck" do
            slide "arch", "Architecture" do
              option "A" do
                text "A"
              end
            end
            slide "arch", "Architecture Again" do
              option "B" do
                text "B"
              end
            end
          end
        end
        app.rebuild_with_state({})
      }.to raise_error(ArgumentError, /Duplicate slide IDs/)
    end

    it "supports the full nesting example from the spec" do
      app = StreamWeaver::App.new("My Deck", theme: :dark) do
        design_deck "Architecture Direction" do
          slide "arch", "System Architecture", context: "Choose the backend" do
            option "Monolith", aside: "Simple deployment" do
              mermaid "graph TD; A-->B", compact: true
              code_block "app.listen(3000)", lang: "ts"
            end
            option "Microservices", recommended: true do
              mermaid "graph LR; A-->B; A-->C", compact: true
            end
          end
          slide "db", "Database Strategy" do
            option "PostgreSQL" do
              code_block "CREATE TABLE users (...)", lang: "sql"
            end
            option "MongoDB" do
              code_block "db.users.insertOne({...})", lang: "javascript"
            end
          end
        end
      end
      app.rebuild_with_state({})

      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      expect(deck).not_to be_nil
      expect(deck.title).to eq("Architecture Direction")

      slides = deck.children.select { |c| c.is_a?(StreamWeaver::Components::Deck::DeckSlide) }
      expect(slides.length).to eq(2)

      # First slide
      arch_slide = slides[0]
      expect(arch_slide.id).to eq("arch")
      expect(arch_slide.title).to eq("System Architecture")
      expect(arch_slide.context_text).to eq("Choose the backend")
      expect(arch_slide.option_count).to eq(2)

      monolith = arch_slide.children[0]
      expect(monolith.label).to eq("Monolith")
      expect(monolith.aside).to eq("Simple deployment")
      expect(monolith.recommended).to eq(false)
      expect(monolith.children.length).to eq(2)
      expect(monolith.children[0]).to be_a(StreamWeaver::Components::Mermaid)
      expect(monolith.children[1]).to be_a(StreamWeaver::Components::CodeBlock)

      micro = arch_slide.children[1]
      expect(micro.label).to eq("Microservices")
      expect(micro.recommended).to eq(true)
      expect(micro.children.length).to eq(1)

      # Second slide
      db_slide = slides[1]
      expect(db_slide.id).to eq("db")
      expect(db_slide.option_count).to eq(2)
    end

    it "does not interfere with slide_container slide" do
      app = StreamWeaver::App.new("Test") do
        slide_container mode: :swap do
          slide "intro", "Introduction" do
            text "Hello"
          end
        end
      end
      app.rebuild_with_state({})
      sc = app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
      expect(sc).not_to be_nil
      expect(sc.children.first).to be_a(StreamWeaver::Components::Slide)
      expect(sc.children.first.id).to eq("intro")
    end

    it "raises when option is used outside design_deck" do
      expect {
        app = StreamWeaver::App.new("Test") do
          option "Bad" do
            text "Should fail"
          end
        end
        app.rebuild_with_state({})
      }.to raise_error(RuntimeError, /option must be inside a slide/)
    end
  end

  # =========================================
  # HTML Rendering
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_deck_app(&block)
      app = StreamWeaver::App.new("Test", &block)
      app.rebuild_with_state(state)
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      StreamWeaver::ComponentRenderer.render_html(adapter, [deck], state)
    end

    it "renders deck with sw-deck class" do
      html = render_deck_app do
        design_deck "Test Deck" do
          slide "s1", "Slide 1" do
            option "A" do
              text "Option A"
            end
          end
        end
      end
      expect(html).to include('class="sw-deck"')
    end

    it "renders deck container" do
      html = render_deck_app do
        design_deck "My Architecture" do
          slide "s1", "Slide 1" do
            option "A" do
              text "A"
            end
          end
        end
      end
      # Deck title is rendered as the page-level H1, not inside the deck
      expect(html).to include("sw-deck")
      expect(html).to include("sw-slide-container")
    end

    it "renders slide container in swap mode" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1", "S1" do
            option "A" do
              text "A"
            end
          end
        end
      end
      expect(html).to include("sw-slide-container--swap")
      expect(html).to include("swSlideNav(")
    end

    it "renders Back and Next navigation buttons" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do
              text "A"
            end
          end
          slide "s2" do
            option "B" do
              text "B"
            end
          end
        end
      end
      expect(html).to include("Back")
      expect(html).to include("Next")
    end

    it "renders progress bar" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do
              text "A"
            end
          end
        end
      end
      expect(html).to include("sw-slide-progress")
    end

    it "renders options grid with radiogroup role" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1", "Architecture" do
            option "A" do
              text "A"
            end
            option "B" do
              text "B"
            end
          end
        end
      end
      expect(html).to include('role="radiogroup"')
    end

    it "renders option cards with radio role" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "Monolith" do
              text "Simple"
            end
          end
        end
      end
      expect(html).to include('role="radio"')
      expect(html).to include('aria-checked="false"')
    end

    it "renders recommended badge" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "Best", recommended: true do
              text "Best option"
            end
          end
        end
      end
      expect(html).to include("Recommended")
      expect(html).to include("sw-deck-option__badge")
      expect(html).to include("sw-deck-option--recommended")
    end

    it "does not render badge when not recommended" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "Normal" do
              text "Normal option"
            end
          end
        end
      end
      # Check no actual badge element (CSS may mention the class)
      expect(html).not_to include('class="sw-deck-option__badge"')
    end

    it "renders aside text" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A", aside: "Simple deployment" do
              text "A"
            end
          end
        end
      end
      expect(html).to include("Simple deployment")
      expect(html).to include("sw-deck-option__aside")
    end

    it "renders notes textarea" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do
              text "A"
            end
          end
        end
      end
      expect(html).to include("sw-deck-option__notes-input")
      expect(html).to include("Add notes...")
    end

    it "renders context text" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1", "Architecture", context: "Choose the backend pattern" do
            option "A" do
              text "A"
            end
          end
        end
      end
      expect(html).to include("Choose the backend pattern")
      expect(html).to include("sw-deck-slide__context")
    end

    it "renders preview content inside options" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "Monolith" do
              code_block "app.listen(3000)", lang: "ts"
            end
          end
        end
      end
      expect(html).to include("sw-deck-option__preview")
      expect(html).to include("sw-code-block")
      expect(html).to include("app.listen(3000)")
    end
  end

  # =========================================
  # Auto-Column Detection
  # =========================================

  describe "auto-column grid detection" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_deck_app(&block)
      app = StreamWeaver::App.new("Test", &block)
      app.rebuild_with_state(state)
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      StreamWeaver::ComponentRenderer.render_html(adapter, [deck], state)
    end

    it "uses 1 column for 1 option" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do
              text "A"
            end
          end
        end
      end
      expect(html).to include("repeat(1, 1fr)")
    end

    it "uses 2 columns for 2 options" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do
              text "A"
            end
            option "B" do
              text "B"
            end
          end
        end
      end
      expect(html).to include("repeat(2, 1fr)")
    end

    it "uses 3 columns for 3 options" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option "A" do
              text "A"
            end
            option "B" do
              text "B"
            end
            option "C" do
              text "C"
            end
          end
        end
      end
      expect(html).to include("repeat(3, 1fr)")
    end

    it "uses 2 columns for 4+ options" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1" do
            option("A") { text "A" }
            option("B") { text "B" }
            option("C") { text "C" }
            option("D") { text "D" }
          end
        end
      end
      expect(html).to include("repeat(2, 1fr)")
    end
  end

  # =========================================
  # CSS Prefix Convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::DECK_CSS }

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
  # Adapter Base Interface
  # =========================================

  describe "Adapter::Base" do
    let(:adapter) { StreamWeaver::Adapter::Base.new }

    it "#render_design_deck raises NotImplementedError" do
      expect {
        adapter.render_design_deck(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_design_deck/)
    end

    it "#render_deck_slide raises NotImplementedError" do
      expect {
        adapter.render_deck_slide(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_deck_slide/)
    end

    it "#render_deck_option raises NotImplementedError" do
      expect {
        adapter.render_deck_option(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_deck_option/)
    end
  end
end
