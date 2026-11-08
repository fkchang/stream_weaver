# frozen_string_literal: true

require "rexml/document"

RSpec.describe "ide_titlebar and ide_statusbar" do
  def render_page(&block)
    app = StreamWeaver::App.new("IDE", chrome: false, theme: :ide) { ide_shell(&block) }
    app.rebuild_with_state({})
    StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call
  end

  # The region's element, parsed (its markup is well-formed XML).
  def region(html, tag, block_class)
    fragment = html[%r{<#{tag} class="#{block_class}[^"]*"[^>]*>.*?</#{tag}>}m]
    REXML::Document.new(fragment).root
  end

  def first(node, xpath) = REXML::XPath.first(node, xpath)
  def all(node, xpath) = REXML::XPath.match(node, xpath)
  def text_of(node) = REXML::XPath.match(node, ".//text()").join

  describe "ide_titlebar" do
    let(:titlebar) do
      region(render_page do
        ide_titlebar(
          crumbs: %w[stream_weaver landing],
          branch: "main",
          links: [
            { label: "GitHub", href: "https://github.com/example/stream_weaver", icon: "★" },
            { label: "Docs", href: "/docs" }
          ]
        ) { text "SW" }
      end, "header", "sw-ide-titlebar")
    end

    it "renders the logo slot from the block" do
      expect(text_of(first(titlebar, "span[@class='sw-ide-titlebar__logo']"))).to eq("SW")
    end

    it "renders the crumbs in a breadcrumb nav, the last one current" do
      nav = first(titlebar, ".//nav[@aria-label='Breadcrumb']")
      crumbs = all(nav, "span[contains(@class, 'sw-ide-titlebar__crumb') and not(@aria-hidden)]")
      expect(crumbs.map { |c| text_of(c) }).to eq(%w[stream_weaver landing])
      expect(crumbs.last.attributes["aria-current"]).to eq("page")
      expect(all(nav, "span[@aria-hidden='true']").map { |s| text_of(s) }).to eq(["›"])
    end

    it "renders the branch label" do
      expect(text_of(first(titlebar, ".//span[@class='sw-ide-titlebar__branch']"))).to eq("main")
    end

    it "names each link by its label and opens external ones in a new tab" do
      github, docs = all(titlebar, ".//a[@class='sw-ide-titlebar__link']")
      expect(github.attributes["aria-label"]).to eq("GitHub")
      expect(github.attributes["target"]).to eq("_blank")
      expect(github.attributes["rel"]).to eq("noopener noreferrer")
      expect(first(github, "span[@aria-hidden='true']/span[@class='sw-ide-titlebar__link-icon']").text).to eq("★")
      expect(docs.attributes["aria-label"]).to eq("Docs")
      expect(docs.attributes["target"]).to be_nil
    end

    it "accepts a single link hash" do
      bar = region(render_page { ide_titlebar(links: { label: "Docs", href: "/docs" }) }, "header", "sw-ide-titlebar")
      expect(all(bar, ".//a").map { |a| a.attributes["href"] }).to eq(["/docs"])
    end

    it "renders a theme toggle that flips the current mode through a plain onclick" do
      toggle = first(titlebar, ".//button[@class='sw-ide-titlebar__theme-toggle']")
      expect(toggle.attributes["onclick"]).to eq(
        "window.swToggleTheme(document.documentElement.classList.contains('dark') ? 'light' : 'dark')"
      )
      expect(toggle.attributes["aria-label"]).to eq("Switch between light and dark theme")
    end

    it "omits the parts it was not given, including the toggle when asked" do
      bar = region(render_page { ide_titlebar(theme_toggle: false) }, "header", "sw-ide-titlebar")
      expect(all(bar, ".//*[@class='sw-ide-titlebar__logo']")).to be_empty
      expect(all(bar, ".//nav")).to be_empty
      expect(all(bar, ".//*[@class='sw-ide-titlebar__branch']")).to be_empty
      expect(all(bar, ".//a | .//button")).to be_empty
    end

    it "swaps the sun and moon icons on html.dark" do
      expect(StreamWeaver::Components::Ide::CSS).to match(/html\.dark \.sw-ide-titlebar__theme-icon--sun \{[^}]*display: block;/)
    end
  end

  describe "ide_statusbar" do
    let(:statusbar) do
      region(render_page do
        ide_statusbar(
          left: ["MIT", { label: "StreamWeaver", href: "https://example.com" }],
          right: ["Ruby 3.3"]
        )
      end, "footer", "sw-ide-statusbar")
    end

    it "renders left items, a spacer, then right items" do
      parts = statusbar.elements.map { |e| [e.attributes["class"], text_of(e)] }
      expect(parts).to eq([
        ["sw-ide-statusbar__item", "MIT"],
        ["sw-ide-statusbar__item", "StreamWeaver"],
        ["sw-ide-statusbar__spacer", ""],
        ["sw-ide-statusbar__item", "Ruby 3.3"]
      ])
    end

    it "renders a { label:, href: } item as an anchor" do
      link = first(statusbar, "a[@class='sw-ide-statusbar__item']")
      expect([link.attributes["href"], link.text]).to eq(["https://example.com", "StreamWeaver"])
    end

    it "accepts a single item hash and still renders block children" do
      bar = region(render_page { ide_statusbar(left: { label: "MIT" }) { text "custom" } }, "footer", "sw-ide-statusbar")
      expect(all(bar, "span[@class='sw-ide-statusbar__item']").map(&:text)).to eq(["MIT"])
      expect(text_of(bar)).to include("custom")
    end
  end
end
