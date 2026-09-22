# frozen_string_literal: true

require_relative "../../lib/stream_weaver/org/writer"
require_relative "../../lib/stream_weaver/org/reader"

RSpec.describe "Presentation Deck (consulting deck spike)" do
  # =========================================
  # Components
  # =========================================

  describe StreamWeaver::Components::Presentation do
    it "is a swap-mode SlideContainer with presentation chrome" do
      deck = described_class.new(footer: "Confidential")
      expect(deck).to be_a(StreamWeaver::Components::SlideContainer)
      expect(deck.mode).to eq(:swap)
      expect(deck.footer).to eq("Confidential")
      expect(deck.slide_numbers).to be true
      expect(deck.presentation?).to be true
    end

    it "pins mode to :swap even if another mode is passed" do
      deck = described_class.new(mode: :scroll_snap)
      expect(deck.mode).to eq(:swap)
    end

    it "adds the sw-presentation modifier class" do
      expect(described_class.new.css_classes).to include("sw-presentation")
      expect(described_class.new.css_classes).to include("sw-slide-container--swap")
    end

    it "plain SlideContainer is not a presentation" do
      expect(StreamWeaver::Components::SlideContainer.new.presentation?).to be false
    end
  end

  describe StreamWeaver::Components::Slide do
    it "accepts presentation header options" do
      slide = described_class.new("s1", "Title", type: :section,
                                  kicker: "KICKER", subtitle: "Sub",
                                  meta: "Meta", number: "01")
      expect(slide.kicker).to eq("KICKER")
      expect(slide.subtitle).to eq("Sub")
      expect(slide.meta).to eq("Meta")
      expect(slide.number).to eq("01")
    end

    it "defaults presentation header options to nil" do
      slide = described_class.new("s1")
      expect(slide.kicker).to be_nil
      expect(slide.subtitle).to be_nil
      expect(slide.meta).to be_nil
      expect(slide.number).to be_nil
    end
  end

  describe StreamWeaver::Components::Phase do
    it "holds label, title, and meta" do
      phase = described_class.new("PHASE 1", "Discovery & Planning", "2.5 weeks")
      expect(phase.label).to eq("PHASE 1")
      expect(phase.title).to eq("Discovery & Planning")
      expect(phase.meta).to eq("2.5 weeks")
    end
  end

  describe StreamWeaver::Components::Milestone do
    it "holds date, label, description" do
      m = described_class.new("Sep 22", "Kickoff", "Confirm counterparts.")
      expect(m.date).to eq("Sep 22")
      expect(m.label).to eq("Kickoff")
      expect(m.description).to eq("Confirm counterparts.")
      expect(m.number).to be_nil
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#presentation" do
    def build_app(&block)
      app = StreamWeaver::App.new("Test", &block)
      app.rebuild_with_state({})
      app
    end

    it "builds a Presentation with slides via the DSL" do
      app = build_app do
        presentation footer: "Footer" do
          slide "title", "Deck Title", type: :title do
            phase "PHASE 1", "Discovery", "2 weeks"
          end
          slide "sec1", "Overview", type: :section, number: "01"
        end
      end
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Presentation) }
      expect(deck).not_to be_nil
      expect(deck.footer).to eq("Footer")
      expect(deck.children.length).to eq(2)
      expect(deck.children[0].type).to eq(:title)
      expect(deck.children[0].children[0]).to be_a(StreamWeaver::Components::Phase)
      expect(deck.children[1].number).to eq("01")
    end

    it "nests milestones in a :milestones slide" do
      app = build_app do
        presentation do
          slide "next", "Next", type: :milestones do
            milestone "Sep 22", "Kickoff", "First."
            milestone "Sep 25", "RACI", "Second."
          end
        end
      end
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Presentation) }
      milestones = deck.children[0].children
      expect(milestones.map(&:class).uniq).to eq([StreamWeaver::Components::Milestone])
      expect(milestones.map(&:label)).to eq(["Kickoff", "RACI"])
    end
  end

  # =========================================
  # AlpineJS adapter rendering
  # =========================================

  describe "AlpineJS adapter rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_deck(&block)
      app = StreamWeaver::App.new("Test", &block)
      app.rebuild_with_state(state)
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Presentation) }
      StreamWeaver::ComponentRenderer.render_html(adapter, [deck], state)
    end

    it "renders each slide inside a 16:9 stage with footer and slide number" do
      html = render_deck do
        presentation footer: "Acme – Confidential" do
          slide "a", "First", type: :title
          slide "b", "Second", type: :content
        end
      end
      expect(html).to include("sw-presentation")
      expect(html.scan('sw-pres-stage').length).to be >= 2
      expect(html.scan('class="sw-pres-footer"').length).to eq(2)
      expect(html.scan("Acme – Confidential").length).to eq(2)
      expect(html).to include('class="sw-pres-footer__number">1<')
      expect(html).to include('class="sw-pres-footer__number">2<')
    end

    it "keeps Back/Next swap navigation through all slides" do
      html = render_deck do
        presentation do
          slide("a", "A") { text "one" }
          slide("b", "B") { text "two" }
          slide("c", "C") { text "three" }
        end
      end
      expect(html).to include("swSlideNav(3")
      expect(html).to include("sw-slide-nav__btn--prev")
      expect(html).to include("sw-slide-nav__btn--next")
      expect(html).to include('x-show="current === 2"')
    end

    it "omits footer chrome when footer and slide_numbers are disabled" do
      html = render_deck do
        presentation slide_numbers: false do
          slide "a", "A"
        end
      end
      expect(html).not_to include('class="sw-pres-footer"')
    end

    it "renders a title slide with kicker, subtitle, meta, and phase strip" do
      html = render_deck do
        presentation do
          slide "t", "Big Title", type: :title,
                kicker: "PROJECT KICKOFF", subtitle: "MVP", meta: "Dates" do
            phase "PHASE 1", "Discovery & Planning", "2.5 weeks"
            phase "PHASE 2", "Implementation", "10 weeks"
          end
        end
      end
      expect(html).to include("sw-pres-kicker")
      expect(html).to include("PROJECT KICKOFF")
      expect(html).to include("<h1 class=\"sw-slide__title\">Big Title</h1>")
      expect(html).to include("sw-pres-subtitle")
      expect(html).to include("sw-pres-phases")
      expect(html.scan('class="sw-phase__title"').length).to eq(2)
      expect(html).to include("Discovery &amp; Planning")
    end

    it "renders a section divider with big number and SECTION label" do
      html = render_deck do
        presentation do
          slide "s1", "Project Overview", type: :section, number: "01",
                subtitle: "Why now"
        end
      end
      expect(html).to include("sw-slide--section")
      expect(html).to include("sw-pres-section-number__value")
      expect(html).to include(">01</span>")
      expect(html).to include(">SECTION</span>")
      expect(html).to include("Why now")
    end

    it "renders milestone nodes numbered by position with a track" do
      html = render_deck do
        presentation do
          slide "m", "Milestones", type: :milestones, meta: "Cadence note." do
            milestone "Sep 22", "Kickoff", "First."
            milestone "Oct 9", "Sign-off", "Last."
          end
        end
      end
      expect(html).to include("sw-pres-track")
      expect(html).to include("sw-milestone__date")
      expect(html).to include('class="sw-milestone__dot" aria-hidden="true">1<')
      expect(html).to include('class="sw-milestone__dot" aria-hidden="true">2<')
      expect(html).to include("Cadence note.")
    end

    it "injects presentation CSS once, scoped under .sw-presentation" do
      html = render_deck do
        presentation { slide "a", "A" }
      end
      expect(html).to include(".sw-presentation .sw-pres-stage")
      expect(html).to include("aspect-ratio: 16 / 9")
    end

    it "all presentation CSS class selectors use sw- prefix" do
      css = StreamWeaver::Adapter::AlpineJS::PRESENTATION_CSS
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
      class_selectors = selector_lines.flat_map { |l|
        (l.split("{").first || "").scan(/\.([\w][\w-]*)/).flatten
      }.uniq
      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"), "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # Org Writer -> Reader preservation (raw-Ruby escape hatch)
  # =========================================

  describe "Org round trip" do
    let(:dsl) do
      <<~RUBY
        presentation footer: "Acme – Confidential" do
          slide "title", "Deck Title", type: :title, kicker: "KICKOFF" do
            phase "PHASE 1", "Discovery", "2 weeks"
          end
          slide "sec1", "Overview", type: :section, number: "01"
        end
      RUBY
    end

    it "Writer emits the presentation statement verbatim as streamweaver-raw" do
      org = StreamWeaver::Org::Writer.from_dsl(dsl)
      expect(org).to include("#+begin_src ruby :streamweaver-raw t")
      expect(org).to include(dsl.strip)
    end

    it "Reader restores the streamweaver-raw block losslessly as executable DSL" do
      org = StreamWeaver::Org::Writer.from_dsl(dsl)
      restored = StreamWeaver::Org::Reader.to_dsl(org)
      expect(restored.strip).to eq(dsl.strip)

      app = StreamWeaver::App.new("spec")
      expect { app.instance_eval(restored) }.not_to raise_error
      deck = app.components.find { |c| c.is_a?(StreamWeaver::Components::Presentation) }
      expect(deck).not_to be_nil
      expect(deck.children.map(&:id)).to eq(%w[title sec1])
    end
  end
end
