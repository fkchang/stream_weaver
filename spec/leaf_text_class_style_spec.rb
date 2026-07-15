# frozen_string_literal: true

RSpec.describe "class:/style: on leaf text components (stream_weaver-1lo)" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  describe StreamWeaver::Components::Text do
    it "merges class: into the <p> when no tone is set" do
      html = render_html(described_class.new("Hi", class: "tyrion-card-title"))
      expect(html).to include('<p class="tyrion-card-title">Hi</p>')
    end

    it "applies style: when no tone is set" do
      html = render_html(described_class.new("Hi", style: "color: red;"))
      expect(html).to include('style="color: red;"')
    end

    it "composes class: with the tone-derived class" do
      html = render_html(described_class.new("Hi", tone: :muted, class: "tyrion-note"))
      expect(html).to include("sw-text sw-text--muted tyrion-note")
    end

    it "stays a bare <p> with no attrs when neither tone nor options given (unchanged)" do
      html = render_html(described_class.new("Hi"))
      expect(html).to include("<p>Hi</p>")
    end
  end

  describe "header1-6" do
    it "merges class: and style: via the DSL" do
      app = StreamWeaver::App.new("Test") { header3 "Story", class: "tyrion-heading", style: "font-family: Cinzel;" }
      app.rebuild_with_state({})
      html = render_html(app.components.first)
      expect(html).to include('<h3 class="tyrion-heading" style="font-family: Cinzel;">Story</h3>')
    end

    it "renders a bare header with no attrs when no options given (unchanged)" do
      html = render_html(StreamWeaver::Components::Header.new("Story", level: 2))
      expect(html).to include("<h2>Story</h2>")
    end
  end

  describe StreamWeaver::Components::Phrase do
    it "merges class:/style: onto the <span>" do
      html = render_html(described_class.new("inline text", class: "chip", style: "font-weight: 600;"))
      expect(html).to include('<span class="chip" style="font-weight: 600;">inline text</span>')
    end
  end

  describe "md wrapper" do
    it "merges class:/style: with markdown-content" do
      app = StreamWeaver::App.new("Test") { md "**bold**", class: "tyrion-prose" }
      app.rebuild_with_state({})
      html = render_html(app.components.first)
      expect(html).to include('class="markdown-content tyrion-prose"')
    end
  end
end
