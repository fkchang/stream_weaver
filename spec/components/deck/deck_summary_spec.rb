# frozen_string_literal: true

RSpec.describe "DeckSummary Component (T9)" do
  # =========================================
  # DeckSummary Class
  # =========================================

  describe StreamWeaver::Components::Deck::DeckSummary do
    it "initializes with empty deck_slides" do
      summary = described_class.new
      expect(summary.deck_slides).to eq([])
    end

    it "allows setting deck_slides" do
      summary = described_class.new
      slide = StreamWeaver::Components::Deck::DeckSlide.new("s1", "Slide 1")
      summary.deck_slides = [slide]
      expect(summary.deck_slides.length).to eq(1)
    end

    describe "#css_classes" do
      it "returns sw-deck-summary" do
        summary = described_class.new
        expect(summary.css_classes).to eq("sw-deck-summary")
      end
    end

    describe "#render" do
      it "delegates to adapter" do
        summary = described_class.new
        adapter = double("adapter")
        view = double("view", adapter: adapter)
        expect(adapter).to receive(:render_deck_summary).with(view, summary, {})
        summary.render(view, {})
      end
    end

    describe "#all_selected?" do
      let(:slide1) { StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture") }
      let(:slide2) { StreamWeaver::Components::Deck::DeckSlide.new("db", "Database") }

      it "returns false when no deck_state" do
        summary = described_class.new
        summary.deck_slides = [slide1]
        expect(summary.all_selected?(nil)).to eq(false)
      end

      it "returns true when no slides" do
        summary = described_class.new
        summary.deck_slides = []
        deck_state = StreamWeaver::Components::Deck::DeckState.new(
          "test-all-selected-empty",
          state_dir: Dir.mktmpdir
        )
        expect(summary.all_selected?(deck_state)).to eq(true)
      end

      it "returns true when all slides have selections" do
        dir = Dir.mktmpdir
        deck_state = StreamWeaver::Components::Deck::DeckState.new("test-all-sel", state_dir: dir)
        deck_state.select("arch", "Monolith")
        deck_state.select("db", "PostgreSQL")

        summary = described_class.new
        summary.deck_slides = [slide1, slide2]
        expect(summary.all_selected?(deck_state)).to eq(true)
      ensure
        FileUtils.rm_rf(dir)
      end

      it "returns false when some slides lack selections" do
        dir = Dir.mktmpdir
        deck_state = StreamWeaver::Components::Deck::DeckState.new("test-partial", state_dir: dir)
        deck_state.select("arch", "Monolith")

        summary = described_class.new
        summary.deck_slides = [slide1, slide2]
        expect(summary.all_selected?(deck_state)).to eq(false)
      ensure
        FileUtils.rm_rf(dir)
      end
    end

    describe "#missing_slides" do
      let(:slide1) { StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture") }
      let(:slide2) { StreamWeaver::Components::Deck::DeckSlide.new("db", "Database") }

      it "returns all slide titles when no deck_state" do
        summary = described_class.new
        summary.deck_slides = [slide1, slide2]
        expect(summary.missing_slides(nil)).to eq(["Architecture", "Database"])
      end

      it "returns only unselected slide titles" do
        dir = Dir.mktmpdir
        deck_state = StreamWeaver::Components::Deck::DeckState.new("test-missing", state_dir: dir)
        deck_state.select("arch", "Monolith")

        summary = described_class.new
        summary.deck_slides = [slide1, slide2]
        expect(summary.missing_slides(deck_state)).to eq(["Database"])
      ensure
        FileUtils.rm_rf(dir)
      end

      it "returns empty when all selected" do
        dir = Dir.mktmpdir
        deck_state = StreamWeaver::Components::Deck::DeckState.new("test-none-missing", state_dir: dir)
        deck_state.select("arch", "Monolith")
        deck_state.select("db", "PostgreSQL")

        summary = described_class.new
        summary.deck_slides = [slide1, slide2]
        expect(summary.missing_slides(deck_state)).to eq([])
      ensure
        FileUtils.rm_rf(dir)
      end

      it "uses slide id when title is nil" do
        slide_no_title = StreamWeaver::Components::Deck::DeckSlide.new("notitled")
        summary = described_class.new
        summary.deck_slides = [slide_no_title]
        expect(summary.missing_slides(nil)).to eq(["notitled"])
      end
    end
  end

  # =========================================
  # DeckState submit/final_notes (T9 additions)
  # =========================================

  describe "DeckState submit and final_notes" do
    let(:dir) { Dir.mktmpdir }
    let(:deck_state) { StreamWeaver::Components::Deck::DeckState.new("test-submit", state_dir: dir) }

    after { FileUtils.rm_rf(dir) }

    describe "#submit!" do
      it "marks state as submitted" do
        expect(deck_state.submitted?).to eq(false)
        deck_state.submit!
        expect(deck_state.submitted?).to eq(true)
      end

      it "persists submitted state across instances" do
        deck_state.submit!
        other = StreamWeaver::Components::Deck::DeckState.new("test-submit", state_dir: dir)
        expect(other.submitted?).to eq(true)
      end
    end

    describe "#final_notes" do
      it "defaults to empty string" do
        expect(deck_state.final_notes).to eq("")
      end

      it "stores and retrieves final notes" do
        deck_state.set_final_notes("Overall this looks good")
        expect(deck_state.final_notes).to eq("Overall this looks good")
      end

      it "persists across instances" do
        deck_state.set_final_notes("Persist test")
        other = StreamWeaver::Components::Deck::DeckState.new("test-submit", state_dir: dir)
        expect(other.final_notes).to eq("Persist test")
      end
    end
  end

  # =========================================
  # Auto-append via design_deck DSL
  # =========================================

  describe "Auto-append in design_deck" do
    it "auto-appends DeckSummary as last child of deck" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Test Deck" do
          slide "arch", "Architecture" do
            option "Monolith" do
              text "Simple"
            end
          end
        end
      end
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      expect(deck.children.last).to be_a(StreamWeaver::Components::Deck::DeckSummary)
    end

    it "summary has references to all slides" do
      app = StreamWeaver::App.new("Test") do
        design_deck "Test Deck" do
          slide "arch", "Architecture" do
            option "Monolith" do
              text "A"
            end
          end
          slide "db", "Database" do
            option "PostgreSQL" do
              text "B"
            end
          end
        end
      end
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      summary = deck.children.last
      expect(summary.deck_slides.length).to eq(2)
      expect(summary.deck_slides[0].id).to eq("arch")
      expect(summary.deck_slides[1].id).to eq("db")
    end
  end

  # =========================================
  # HTML Rendering
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

    def render_summary(slides: [], deck_state: nil)
      summary = StreamWeaver::Components::Deck::DeckSummary.new
      summary.deck_slides = slides
      state = {}
      state[:_deck_state] = deck_state if deck_state
      StreamWeaver::ComponentRenderer.render_html(adapter, [summary], state)
    end

    it "renders summary container with sw-deck-summary class" do
      html = render_summary
      expect(html).to include('class="sw-deck-summary"')
    end

    it "renders Summary title" do
      html = render_summary
      expect(html).to include("Summary")
      expect(html).to include("sw-deck-summary__title")
    end

    it "renders cards for each slide" do
      slide1 = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      slide2 = StreamWeaver::Components::Deck::DeckSlide.new("db", "Database")
      html = render_summary(slides: [slide1, slide2])
      expect(html).to include("Architecture")
      expect(html).to include("Database")
      expect(html).to include("sw-deck-summary__card")
    end

    it "shows 'No selection' when no deck_state" do
      slide = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      html = render_summary(slides: [slide])
      expect(html).to include("No selection")
      expect(html).to include("sw-deck-summary__card--empty")
    end

    it "shows selected option label" do
      dir = Dir.mktmpdir
      ds = StreamWeaver::Components::Deck::DeckState.new("test-render-sel", state_dir: dir)
      ds.select("arch", "Monolith")

      slide = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      opt = StreamWeaver::Components::Deck::DeckOption.new("Monolith", aside: "Simple deploy")
      slide.children = [opt]

      html = render_summary(slides: [slide], deck_state: ds)
      expect(html).to include("Monolith")
      expect(html).to include("Simple deploy")
      expect(html).not_to include("No selection")
    ensure
      FileUtils.rm_rf(dir)
    end

    it "shows notes for selected option" do
      dir = Dir.mktmpdir
      ds = StreamWeaver::Components::Deck::DeckState.new("test-render-notes", state_dir: dir)
      ds.select("arch", "Monolith")
      ds.set_note("arch", "Monolith", "Great for small teams")

      slide = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      opt = StreamWeaver::Components::Deck::DeckOption.new("Monolith")
      slide.children = [opt]

      html = render_summary(slides: [slide], deck_state: ds)
      expect(html).to include("Great for small teams")
      expect(html).to include("sw-deck-summary__card-notes")
    ensure
      FileUtils.rm_rf(dir)
    end

    it "shows 'Still need' message when incomplete" do
      slide1 = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      slide2 = StreamWeaver::Components::Deck::DeckSlide.new("db", "Database")

      dir = Dir.mktmpdir
      ds = StreamWeaver::Components::Deck::DeckState.new("test-missing-msg", state_dir: dir)
      ds.select("arch", "Monolith")

      html = render_summary(slides: [slide1, slide2], deck_state: ds)
      expect(html).to include("Still need: Database")
      expect(html).to include("sw-deck-summary__missing")
    ensure
      FileUtils.rm_rf(dir)
    end

    it "renders disabled submit button when incomplete" do
      slide = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      html = render_summary(slides: [slide])
      expect(html).to include("Submit")
      expect(html).to include("sw-deck-summary__submit--disabled")
      expect(html).to include("disabled")
    end

    it "renders enabled submit button when complete" do
      dir = Dir.mktmpdir
      ds = StreamWeaver::Components::Deck::DeckState.new("test-btn-enabled", state_dir: dir)
      ds.select("arch", "Monolith")

      slide = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      html = render_summary(slides: [slide], deck_state: ds)
      # The submit button element itself should not have the disabled class
      expect(html).to match(/class="sw-deck-summary__submit"[^-]/)
      expect(html).not_to match(/class="sw-deck-summary__submit sw-deck-summary__submit--disabled"/)
    ensure
      FileUtils.rm_rf(dir)
    end

    it "shows 'Submitted' label after submission" do
      dir = Dir.mktmpdir
      ds = StreamWeaver::Components::Deck::DeckState.new("test-submitted", state_dir: dir)
      ds.select("arch", "Monolith")
      ds.submit!

      slide = StreamWeaver::Components::Deck::DeckSlide.new("arch", "Architecture")
      html = render_summary(slides: [slide], deck_state: ds)
      expect(html).to include("Submitted")
      expect(html).to include("sw-deck-summary__submitted")
      # Should not have a submit button element (only the "Submitted" div)
      expect(html).not_to include('<button')
    ensure
      FileUtils.rm_rf(dir)
    end

    it "renders final notes textarea" do
      html = render_summary
      expect(html).to include("sw-deck-summary__final-notes")
      expect(html).to include("Final notes")
      expect(html).to include("sw-deck-summary__final-notes-input")
    end

    it "populates final notes from deck state" do
      dir = Dir.mktmpdir
      ds = StreamWeaver::Components::Deck::DeckState.new("test-fn-render", state_dir: dir)
      ds.set_final_notes("Great overall direction")

      html = render_summary(deck_state: ds)
      expect(html).to include("Great overall direction")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  # =========================================
  # Design Deck with Summary HTML Rendering
  # =========================================

  describe "Full deck with summary rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

    def render_deck_app(&block)
      app = StreamWeaver::App.new("Test", &block)
      app.rebuild_with_state({})
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Deck::DesignDeck) }
      StreamWeaver::ComponentRenderer.render_html(adapter, [deck], {})
    end

    it "includes summary slide in slide navigation count" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1", "Slide 1" do
            option "A" do
              text "A"
            end
          end
          slide "s2", "Slide 2" do
            option "B" do
              text "B"
            end
          end
        end
      end
      # 2 slides + 1 summary = 3 total
      expect(html).to include("swSlideNav(3")
    end

    it "renders summary slide within the deck" do
      html = render_deck_app do
        design_deck "Test" do
          slide "s1", "Architecture" do
            option "A" do
              text "A"
            end
          end
        end
      end
      expect(html).to include("sw-deck-summary")
      expect(html).to include("sw-deck-slide-summary")
    end
  end

  # =========================================
  # CSS Prefix Convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::DECK_CSS }

    it "summary CSS classes all use sw- prefix" do
      # Extract class selectors from the summary section
      summary_section = css[/Deck Summary Styles.*\z/m]
      next unless summary_section

      selector_lines = summary_section.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") }
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

    it "#render_deck_summary raises NotImplementedError" do
      expect {
        adapter.render_deck_summary(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_deck_summary/)
    end
  end
end
