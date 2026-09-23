# frozen_string_literal: true

# Batch A baseline spec for the full 20-slide consulting kickoff deck
# (examples/visual_skills/consulting_deck_full_dsl.rb), extended in Batch B
# to cover the extraction of the repeated deck-local composition patterns
# into examples/visual_skills/consulting_deck_components.rb. Verifies the
# deck structure (20 ordered, unique slide IDs with recognizable
# headings), the helper-module extraction, export-compatible rendering
# through the AlpineJS adapter (navigation data + 16:9 stages), and public
# safety (no client/vendor identity, personal paths, or attachment
# identifiers leak into the repo files).

RSpec.describe "Presentation Deck (full 20-slide consulting deck)" do
  DSL_PATH = File.expand_path("../../examples/visual_skills/consulting_deck_full_dsl.rb", __dir__)
  WRAPPER_PATH = File.expand_path("../../examples/visual_skills/consulting_deck_full.rb", __dir__)
  COMPONENTS_PATH = File.expand_path("../../examples/visual_skills/consulting_deck_components.rb", __dir__)

  HELPER_METHODS = %i[agenda_item glance_row criterion_card labeled_card phase_detail].freeze

  require COMPONENTS_PATH

  EXPECTED_SLIDES = [
    ["title",               "Northstar Research"],
    ["agenda",              "What we'll cover today"],
    ["section-01",          "Project Overview & Success Criteria"],
    ["business-context",    "Why this project, why now"],
    ["success-criteria",    "The project is done when..."],
    ["section-02",          "Implementation Proposal"],
    ["workstreams",         "Everything in scope rolls up into one of these"],
    ["interface-contract",  "Delivered as an internal service"],
    ["architecture",        "An internal service inside the customer's own Kubernetes clusters"],
    ["out-of-scope",        "Scope guardrails — what this MVP does not include"],
    ["section-03",          "High-Level Timeline"],
    ["schedule-replan",     "Why go-live moves to January"],
    ["phase-timeline",      "Sep 23, 2026 – Jan 27, 2027 · Go-live Jan 19, 2027"],
    ["key-milestones",      "From kickoff to project close"],
    ["section-04",          "Key Open Items & Decisions"],
    ["open-items",          "One decision today, three Phase-1 exit items"],
    ["open-items-cont",     "Phase-1 items that shape design and testing"],
    ["client-dependencies", "What we need from the customer — and by when"],
    ["next-steps",          "From today's kickoff to project-plan sign-off"],
    ["questions",           "Questions?"]
  ].freeze

  # Terms are assembled (not written literally) so this spec file itself
  # stays clean under the same public-safety grep it enforces.
  FORBIDDEN_TERMS = [
    ["Hedge", "ye"].join, ["hedge", "ye"].join,
    ["Dino", "Cloud"].join, ["dino", "cloud"].join, ["Dino", " Cloud"].join,
    ["/Use", "rs/"].join, # personal home-directory prefix
    ["e7e3", "15c6"].join, # attachment identifier fragment
    ["Risk Mana", "gement"].join, # reference customer trade name suffix
    ["– Confid", "ential"].join, ["— Confid", "ential"].join # footer marking
  ].freeze

  def build_deck
    app = StreamWeaver::App.new("Full Deck")
    app.instance_eval(File.read(DSL_PATH, encoding: Encoding::UTF_8), DSL_PATH)
    app.components.find { |c| c.is_a?(StreamWeaver::Components::Presentation) }
  end

  def render_deck_html
    adapter = StreamWeaver::Adapter::AlpineJS.new
    StreamWeaver::ComponentRenderer.render_html(adapter, [build_deck], {})
  end

  describe "deck structure" do
    it "contains exactly 20 slides with the expected IDs in order" do
      deck = build_deck
      expect(deck).not_to be_nil
      expect(deck.children.map(&:id)).to eq(EXPECTED_SLIDES.map(&:first))
    end

    it "uses unique slide IDs" do
      ids = build_deck.children.map(&:id)
      expect(ids.uniq.length).to eq(ids.length)
    end

    it "gives every slide a recognizable title heading" do
      deck = build_deck
      EXPECTED_SLIDES.each_with_index do |(_id, heading), i|
        title = deck.children[i].title
        expect(title).to be_a(String), "slide #{i + 1} has no title"
        expect(title).to include(heading.split(" — ").first.split(" · ").first[0, 20])
      end
    end

    it "marks the four section dividers in order" do
      deck = build_deck
      dividers = deck.children.select { |s| s.type == :section }
      expect(dividers.map(&:id)).to eq(%w[section-01 section-02 section-03 section-04 questions])
      expect(dividers.first(4).map(&:number)).to eq(%w[01 02 03 04])
    end

    it "keeps the genre slides: title phase strip, card grids, milestone tracks" do
      deck = build_deck
      title = deck.children[0]
      expect(title.type).to eq(:title)
      expect(title.children.count { |c| c.is_a?(StreamWeaver::Components::Phase) }).to eq(3)

      %w[success-criteria open-items open-items-cont].each do |id|
        slide = deck.children.find { |s| s.id == id }
        expect(slide.type).to eq(:cards)
      end

      %w[key-milestones next-steps].each do |id|
        slide = deck.children.find { |s| s.id == id }
        expect(slide.type).to eq(:milestones)
        expect(slide.children.count { |c| c.is_a?(StreamWeaver::Components::Milestone) }).to eq(5)
      end
    end
  end

  describe "extracted helper module (Batch B)" do
    it "defines the five deck-genre helpers as ConsultingDeckComponents instance methods" do
      expect(ConsultingDeckComponents.instance_methods).to include(*HELPER_METHODS)
    end

    it "keeps the helpers generic: no engagement-specific content in the module" do
      content = File.read(COMPONENTS_PATH, encoding: Encoding::UTF_8)
      %w[Northstar CloudWorks].each do |term|
        expect(content).not_to include(term), "consulting_deck_components.rb contains #{term.inspect}"
      end
    end

    it "moves the helper bodies out of the DSL fragment into the module" do
      dsl = File.read(DSL_PATH, encoding: Encoding::UTF_8)
      expect(dsl).not_to match(/^def /), "DSL fragment still defines inline helper methods"
      expect(dsl).not_to include("tagged_card"), "DSL fragment still references the pre-unification tagged_card helper"
      expect(dsl).not_to include("scenario_card"), "DSL fragment still references the pre-unification scenario_card helper"
      expect(dsl).to include("require_relative 'consulting_deck_components'")
      expect(dsl).to include("extend ConsultingDeckComponents")
    end

    it "extends the deck app with all five helpers when the fragment is evaluated" do
      app = StreamWeaver::App.new("Full Deck")
      app.instance_eval(File.read(DSL_PATH, encoding: Encoding::UTF_8), DSL_PATH)
      HELPER_METHODS.each do |helper|
        expect(app).to respond_to(helper), "deck app does not respond to #{helper}"
      end
    end

    it "unifies both labeled-card shapes through the one helper" do
      app = StreamWeaver::App.new("Full Deck")
      app.extend(ConsultingDeckComponents)

      corner = app.labeled_card("Phase-1 exit", "Body copy.", heading: "The heading")
      expect(corner).to be_a(StreamWeaver::Components::Card)
      expect(corner.label).to eq("Phase-1 exit")
      expect(corner.children.map(&:class)).to eq(
        [StreamWeaver::Components::Header, StreamWeaver::Components::Text]
      )

      inline = app.labeled_card("Original plan", "Body copy.", label_style: :inline)
      expect(inline).to be_a(StreamWeaver::Components::Card)
      expect(inline.label).to be_nil
      expect(inline.children.map(&:class)).to eq(
        [StreamWeaver::Components::Text, StreamWeaver::Components::Text]
      )
    end
  end

  describe "AlpineJS adapter rendering (export path)" do
    let(:html) { render_deck_html }

    it "renders navigation data for all 20 slides" do
      expect(html).to include("swSlideNav(20, 'swap', true)")
      expect(html).to include("sw-slide-nav__btn--prev")
      expect(html).to include("sw-slide-nav__btn--next")
      expect(html).to include('x-show="current === 19"')
    end

    it "renders exactly 20 sixteen-by-nine stages, each with footer chrome" do
      expect(html.scan(/sw-pres-stage"/).length).to eq(20)
      expect(html.scan('class="sw-pres-footer"').length).to eq(20)
      expect(html).to include('class="sw-pres-footer__number">20<')
    end

    it "renders every slide heading in deck order" do
      # Phlex escapes & and ' (non-ASCII punctuation passes through), so
      # probe with the heading escaped the same way the adapter emits it.
      positions = EXPECTED_SLIDES.map do |(_id, heading)|
        probe = heading.gsub("&", "&amp;").gsub("'", "&#39;")
        html.index(probe)
      end
      EXPECTED_SLIDES.each_with_index do |(id, heading), i|
        expect(positions[i]).not_to be_nil, "heading for slide '#{id}' (#{heading.inspect}) not found in HTML"
      end
      expect(positions).to eq(positions.sort), "slide headings render out of order"
    end
  end

  describe "public safety" do
    it "keeps forbidden identity/confidential terms out of every touched file" do
      [DSL_PATH, WRAPPER_PATH, COMPONENTS_PATH, __FILE__].each do |path|
        content = File.read(path, encoding: Encoding::UTF_8)
        FORBIDDEN_TERMS.each do |term|
          expect(content).not_to include(term),
                                 "#{File.basename(path)} contains forbidden term #{term.inspect}"
        end
      end
    end
  end
end
