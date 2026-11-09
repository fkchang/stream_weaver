# frozen_string_literal: true

require "stream_weaver/canvas/bridge"

RSpec.describe "ide_shell" do
  def render_app(app)
    state = {}
    app.rebuild_with_state(state)
    StreamWeaver::Views::AppView.new(app, state, StreamWeaver::Adapter::AlpineJS.new).call
  end

  def ide_app(&block)
    StreamWeaver::App.new("IDE", chrome: false, theme: :ide, &block)
  end

  let(:full_shell) do
    ide_app do
      ide_shell do
        ide_titlebar { text "title" }
        ide_rail_left { text "left" }
        ide_editor { text "center" }
        ide_rail_right { text "right" }
        ide_statusbar { text "status" }
      end
    end
  end

  let(:html) { render_app(full_shell) }

  describe "components" do
    it "is a container whose regions are its children" do
      shell = full_shell.tap { |a| a.rebuild_with_state({}) }.components.first
      expect(shell).to be_a(StreamWeaver::Components::IdeShell)
      expect(shell.children.map(&:class)).to eq([
        StreamWeaver::Components::IdeTitlebar,
        StreamWeaver::Components::IdeRailLeft,
        StreamWeaver::Components::IdeEditor,
        StreamWeaver::Components::IdeRailRight,
        StreamWeaver::Components::IdeStatusbar
      ])
    end
  end

  describe "region structure" do
    it "renders every region, in order, inside .sw-ide-shell" do
      shell_html = html[/<div[^>]*class="sw-ide-shell"[^>]*>.*/m]
      expect(shell_html).not_to be_nil
      order = [
        %(<header class="sw-ide-titlebar"),
        %(<aside class="sw-ide-rail-left"),
        %(<main class="sw-ide-editor"),
        %(<aside class="sw-ide-rail-right"),
        %(<footer class="sw-ide-statusbar")
      ].map { |tag| shell_html.index(tag) }
      expect(order).to all(be_a(Integer))
      expect(order).to eq(order.sort)
    end

    it "renders each region's children inside it" do
      expect(html).to match(%r{<aside class="sw-ide-rail-left"[^>]*>.*left.*</aside>}m)
      expect(html).to match(%r{<main class="sw-ide-editor"[^>]*>.*center.*</main>}m)
      expect(html).to match(%r{<footer class="sw-ide-statusbar"[^>]*>.*status.*</footer>}m)
    end

    it "labels the rails as landmarks and ties the toggle to the right rail" do
      expect(html).to match(/<aside class="sw-ide-rail-right" id="sw-ide-rail-right"/)
      expect(html).to include(%(aria-controls="sw-ide-rail-right"))
    end

    it "appends class: and style: to the framework classes" do
      page = render_app(ide_app { ide_shell(class: "mine", style: "color: red") { ide_editor(class: "ed") { text "x" } } })
      expect(page).to include(%(class="sw-ide-shell mine"))
      expect(page).to include(%(style="color: red"))
      expect(page).to include(%(<main class="sw-ide-editor ed"))
    end
  end

  it "emits the shared IDE stylesheet once on the page" do
    expect(html.scan("IDE shell: titlebar / left | editor | right / statusbar").size).to eq(1)
  end

  # Markup only: the collapse itself, Escape and the backdrop are checked in
  # a browser.
  # Browser-verified at 1000px (focus lands in the rail, the toggle stays
  # clickable); these pin the two CSS facts that made it work.
  describe "rail layering in the page stylesheet" do
    let(:mobile) { html[/@media \(max-width: 1180px\) \{.*?\n\}/m] }

    it "starts the open rail and its backdrop below the titlebar, using the titlebar's own height" do
      expect(html).to match(/\.sw-ide-titlebar \{[^}]*height: var\(--sw-ide-titlebar-height\);/)
      expect(mobile).to match(/\.sw-ide-rail-right \{[^}]*top: var\(--sw-ide-titlebar-height\);/)
      expect(mobile).to match(/\.sw-ide-shell__backdrop \{[^}]*inset: var\(--sw-ide-titlebar-height\) 0 0 0;/)
    end

    it "makes the rail visible at once on open, so focus() can land in it" do
      expect(mobile).to match(/\.sw-ide-shell--rail-open \.sw-ide-rail-right \{[^}]*transition: transform 0\.2s, visibility 0s;/)
    end
  end

  describe "mobile collapse markup" do
    it "renders the nav toggle before every region, so it comes first in the tab order" do
      shell_html = html[/<div[^>]*class="sw-ide-shell"[^>]*>.*/m]
      expect(shell_html.index("sw-ide-shell__nav-toggle")).to be < shell_html.index(%(<header class="sw-ide-titlebar"))
    end

    it "opens the rail from the toggle and closes it from the backdrop and Escape" do
      expect(html).to match(/<button[^>]*class="sw-ide-shell__nav-toggle"[^>]*x-ref="toggle"[^>]*@click="railOpen = !railOpen"/)
      expect(html).to match(/<div[^>]*class="sw-ide-shell__backdrop"[^>]*@click="closeRail\(\)"/)
      expect(html).to include(%(@keydown.escape.window="closeRail()"))
    end

    it "makes the rail focusable and moves focus into it on open" do
      expect(html).to match(/<aside class="sw-ide-rail-right" id="sw-ide-rail-right" tabindex="-1" x-ref="rail"/)
      expect(html).to include(%(x-effect="railOpen && $nextTick(() => $refs.rail?.focus())"))
    end

    it "omits the toggle and backdrop when there is no right rail" do
      page = render_app(ide_app { ide_shell { ide_editor { text "x" } } })
      expect(page).to include(%(class="sw-ide-shell"))
      expect(page).not_to include(%(class="sw-ide-shell__nav-toggle"))
      expect(page).not_to include(%(class="sw-ide-shell__backdrop"))
    end
  end

  describe "canvas path" do
    it "renders the shell and its stylesheet through the canvas bridge" do
      dsl = <<~RUBY
        ide_shell do
          ide_titlebar { text "title" }
          ide_editor { text "center" }
          ide_statusbar { text "status" }
        end
      RUBY
      result = StreamWeaver::Canvas::Fragment.render(dsl, adapter: StreamWeaver::Adapter::AlpineJS.new(url_prefix: "/canvas/ide", mode: :websocket))
      expect(result.html).to include(%(class="sw-ide-shell"))
      expect(result.html).to include(%(<main class="sw-ide-editor"))
      expect(result.html).to include(".sw-ide-shell {")
    end
  end
end
