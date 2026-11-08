# frozen_string_literal: true

RSpec.describe "ide_* list arguments and title bar link icons" do
  def render_app(&block)
    app = StreamWeaver::App.new("IDE", chrome: false, theme: :ide, &block)
    state = {}
    app.rebuild_with_state(state)
    StreamWeaver::Views::AppView.new(app, state, StreamWeaver::Adapter::AlpineJS.new).call
  end

  describe "Components::Ide.list" do
    it "keeps a lone Hash or String as one item and passes arrays through" do
      expect(StreamWeaver::Components::Ide.list({ label: "Files" })).to eq([{ label: "Files" }])
      expect(StreamWeaver::Components::Ide.list("MIT")).to eq(["MIT"])
      expect(StreamWeaver::Components::Ide.list(%w[a b])).to eq(%w[a b])
      expect(StreamWeaver::Components::Ide.list(nil)).to eq([])
    end

    it "lets ide_rail_tabs take a single tab hash" do
      tabs = StreamWeaver::Components::IdeRailTabs.new({ label: "Files", active: true }).tabs
      expect(tabs).to eq([{ label: "Files", active: true }])
    end

    it "lets ide_terminal take a single command hash" do
      lines = StreamWeaver::Components::IdeTerminal.new(lines: { command: "ls" }).lines
      expect(lines).to eq([{ command: "ls" }])
    end
  end

  describe "title bar link icons" do
    it "draws an icon given by name as the named SVG, not as text" do
      html = render_app do
        ide_shell { ide_titlebar(links: [{ label: "Branches", href: "/b", icon: :branch }]) }
      end
      link = html[%r{<a [^>]*sw-ide-titlebar__link".*?</a>}m]
      expect(link).to include('<svg class="sw-ide-titlebar__link-icon"')
      expect(link).not_to include(">branch<")
    end

    it "still draws a literal glyph as text" do
      html = render_app do
        ide_shell { ide_titlebar(links: [{ label: "GitHub", href: "https://example.com", icon: "★" }]) }
      end
      link = html[%r{<a [^>]*sw-ide-titlebar__link".*?</a>}m]
      expect(link).to include("★")
      expect(link).not_to include("<svg")
    end
  end
end
