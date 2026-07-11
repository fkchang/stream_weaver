# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Accordion do
  describe "initialization" do
    it "initializes with empty children" do
      expect(described_class.new.children).to eq([])
    end
  end
end

RSpec.describe StreamWeaver::Components::AccordionSection do
  describe "initialization" do
    it "stores the title" do
      section = described_class.new("Details")
      expect(section.title).to eq("Details")
    end

    it "defaults open to false" do
      section = described_class.new("Details")
      expect(section.open).to eq(false)
    end

    it "stores an explicit open: true" do
      section = described_class.new("Details", open: true)
      expect(section.open).to eq(true)
    end

    it "initializes with empty children" do
      expect(described_class.new("Details").children).to eq([])
    end
  end
end

RSpec.describe "accordion/section DSL" do
  let(:app) { StreamWeaver::App.new("Test") {} }

  it "adds an Accordion component" do
    app.accordion {}
    expect(app.components.first).to be_a(StreamWeaver::Components::Accordion)
  end

  it "captures section children" do
    app.accordion do
      section("First") { text "One" }
      section("Second", open: true) { text "Two" }
    end

    accordion = app.components.first
    expect(accordion.children.length).to eq(2)
    expect(accordion.children[0]).to be_a(StreamWeaver::Components::AccordionSection)
    expect(accordion.children[0].title).to eq("First")
    expect(accordion.children[0].open).to eq(false)
    expect(accordion.children[1].title).to eq("Second")
    expect(accordion.children[1].open).to eq(true)
  end

  it "captures nested components inside a section" do
    app.accordion do
      section("Details") do
        text "Line one"
        text "Line two"
      end
    end

    section_component = app.components.first.children.first
    expect(section_component.children.length).to eq(2)
    expect(section_component.children[0]).to be_a(StreamWeaver::Components::Text)
  end
end

RSpec.describe "accordion HTML rendering" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  it "renders native <details>/<summary> elements, zero Alpine data" do
    accordion = StreamWeaver::Components::Accordion.new
    section = StreamWeaver::Components::AccordionSection.new("Details")
    section.children = [StreamWeaver::Components::Text.new("Body")]
    accordion.children = [section]

    html = render_html(accordion)
    expect(html).to include("<details")
    expect(html).to include("<summary")
    expect(html).to include("Details")
    expect(html).to include("Body")
    expect(html).not_to include("x-data")
  end

  it "renders the open attribute when open: true" do
    accordion = StreamWeaver::Components::Accordion.new
    section = StreamWeaver::Components::AccordionSection.new("Details", open: true)
    accordion.children = [section]

    html = render_html(accordion)
    expect(html).to match(/<details[^>]*\bopen\b/)
  end

  it "omits the open attribute when open: false" do
    accordion = StreamWeaver::Components::Accordion.new
    section = StreamWeaver::Components::AccordionSection.new("Details", open: false)
    accordion.children = [section]

    html = render_html(accordion)
    expect(html).not_to match(/<details[^>]*\bopen\b/)
  end
end
