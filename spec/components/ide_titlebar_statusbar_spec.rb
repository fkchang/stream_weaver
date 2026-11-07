# frozen_string_literal: true

RSpec.describe "ide_titlebar and ide_statusbar" do
  def render_page(&block)
    app = StreamWeaver::App.new("IDE", chrome: false, theme: :ide) { ide_shell(&block) }
    app.rebuild_with_state({})
    StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call
  end

  def section(html, tag, block_class)
    html[%r{<#{tag} class="#{block_class}[^"]*"[^>]*>.*?</#{tag}>}m]
  end

  let(:css) { StreamWeaver::Components::Ide::CSS }

  describe "ide_titlebar" do
    let(:titlebar) do
      section(render_page do
        ide_titlebar(
          crumbs: ["stream_weaver", "landing"],
          branch: "main",
          links: [
            { label: "GitHub", href: "https://github.com/example/stream_weaver", icon: "★" },
            { label: "Docs", href: "/docs" }
          ]
        ) { text "SW" }
      end, "header", "sw-ide-titlebar")
    end

    it "renders the logo slot from the block" do
      expect(titlebar).to match(%r{<span class="sw-ide-titlebar__logo">.*SW.*</span>}m)
    end

    it "renders the crumbs with a separator, the last one current" do
      expect(titlebar).to include(%(<span class="sw-ide-titlebar__crumb">stream_weaver</span>))
      expect(titlebar).to include(%(<span class="sw-ide-titlebar__crumb-sep" aria-hidden="true">›</span>))
      expect(titlebar).to include(%(<span class="sw-ide-titlebar__crumb sw-ide-titlebar__crumb--current" aria-current="page">landing</span>))
    end

    it "renders the branch label" do
      expect(titlebar).to match(%r{<span class="sw-ide-titlebar__branch">.*main</span>}m)
    end

    it "renders link buttons, opening external ones in a new tab" do
      expect(titlebar).to match(%r{<a class="sw-ide-titlebar__link" href="https://github.com/example/stream_weaver" target="_blank" rel="noopener noreferrer"><span class="sw-ide-titlebar__link-icon">★</span><span class="sw-ide-titlebar__link-label">GitHub</span></a>})
      expect(titlebar).to include(%(<a class="sw-ide-titlebar__link" href="/docs"><span class="sw-ide-titlebar__link-label">Docs</span></a>))
    end

    it "renders a theme toggle that flips the current mode through swToggleTheme" do
      expect(titlebar).to match(/<button[^>]*class="sw-ide-titlebar__theme-toggle"/)
      expect(titlebar).to include(%(@click="window.swToggleTheme(document.documentElement.classList.contains('dark') ? 'light' : 'dark')"))
      expect(titlebar).to include("sw-ide-titlebar__theme-icon--sun")
      expect(titlebar).to include("sw-ide-titlebar__theme-icon--moon")
    end

    it "can leave the theme toggle out" do
      html = section(render_page { ide_titlebar(theme_toggle: false) }, "header", "sw-ide-titlebar")
      expect(html).not_to include("sw-ide-titlebar__theme-toggle")
    end

    it "omits the parts it was not given" do
      html = section(render_page { ide_titlebar(theme_toggle: false) }, "header", "sw-ide-titlebar")
      expect(html).not_to include("sw-ide-titlebar__logo")
      expect(html).not_to include("sw-ide-titlebar__crumbs")
      expect(html).not_to include("sw-ide-titlebar__branch")
      expect(html).not_to include("sw-ide-titlebar__link")
    end

    it "styles each part from the shared stylesheet" do
      %w[__logo __scope __crumbs __crumb--current __branch __actions __link __theme-toggle].each do |part|
        expect(css).to include(".sw-ide-titlebar#{part}")
      end
      expect(css).to match(/html\.dark \.sw-ide-titlebar__theme-icon--sun \{[^}]*display: block;/)
    end
  end

  describe "ide_statusbar" do
    let(:statusbar) do
      section(render_page do
        ide_statusbar(
          left: ["MIT", { text: "StreamWeaver", href: "https://example.com" }],
          right: ["Ruby 3.3"]
        )
      end, "footer", "sw-ide-statusbar")
    end

    it "renders left items, a spacer, then right items" do
      left = statusbar.index(%(<span class="sw-ide-statusbar__item">MIT</span>))
      spacer = statusbar.index(%(<span class="sw-ide-statusbar__spacer"></span>))
      right = statusbar.index(%(<span class="sw-ide-statusbar__item">Ruby 3.3</span>))
      expect([left, spacer, right]).to all(be_a(Integer))
      expect([left, spacer, right]).to eq([left, spacer, right].sort)
    end

    it "renders a linked item as an anchor" do
      expect(statusbar).to include(%(<a class="sw-ide-statusbar__item" href="https://example.com">StreamWeaver</a>))
    end

    it "still renders block children" do
      html = section(render_page { ide_statusbar { text "custom" } }, "footer", "sw-ide-statusbar")
      expect(html).to include("custom")
    end

    it "styles the items from the shared stylesheet" do
      expect(css).to include(".sw-ide-statusbar__item")
      expect(css).to match(/\.sw-ide-statusbar__spacer \{[^}]*flex: 1;/)
    end
  end
end
