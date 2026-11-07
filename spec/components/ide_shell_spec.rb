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
  let(:css) { StreamWeaver::Components::Ide::CSS }

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

  describe "grid" do
    it "is a full-viewport grid: titlebar over left | center | right over statusbar" do
      expect(css).to include("display: grid")
      expect(css).to include("height: 100dvh")
      expect(css).to include("grid-template-columns: 220px minmax(0, 1fr) 380px")
      expect(css).to include("grid-template-rows: auto minmax(0, 1fr) auto")
      expect(css).to match(/grid-template-areas:\s*"titlebar titlebar titlebar"\s*"left center right"\s*"status status status"/)
    end

    it "places each region in its grid area" do
      { "titlebar" => "titlebar", "rail-left" => "left", "editor" => "center",
        "rail-right" => "right", "statusbar" => "status" }.each do |block, area|
        expect(css).to match(/\.sw-ide-#{block} \{[^}]*grid-area: #{area};/)
      end
    end

    it "removes the page padding and card frame around the shell" do
      expect(css).to match(/html body:has\(\.sw-ide-shell\) \{[^}]*padding: 0;[^}]*max-width: none;/)
      expect(css).to match(/#app-container:has\(> \.sw-ide-shell\) \{[^}]*padding: 0;/)
    end

    it "emits the shared IDE stylesheet once on the page" do
      expect(html.scan("IDE shell: titlebar / left | editor | right / statusbar").size).to eq(1)
    end
  end

  describe "mobile collapse" do
    it "renders a nav toggle and a backdrop bound to one railOpen flag" do
      expect(html).to include(%(x-data="{ railOpen: false }"))
      expect(html).to match(/<button[^>]*class="sw-ide-shell__nav-toggle"[^>]*@click="railOpen = !railOpen"/)
      expect(html).to include(%(:aria-expanded="railOpen.toString()"))
      expect(html).to match(/<div[^>]*class="sw-ide-shell__backdrop"[^>]*@click="railOpen = false"/)
      expect(html).to include(%(:class="{ 'sw-ide-shell--rail-open': railOpen }"))
      expect(html).to include(%(@keydown.escape.window="railOpen = false"))
    end

    it "keeps the closed rail out of the tab order" do
      mobile = css[/@media \(max-width: 1180px\) \{.*?\n\}/m]
      expect(mobile).to match(/\.sw-ide-rail-right \{[^}]*visibility: hidden;/)
      expect(mobile).to match(/\.sw-ide-shell--rail-open \.sw-ide-rail-right \{[^}]*visibility: visible;/)
    end

    it "omits the toggle and backdrop when there is no right rail" do
      page = render_app(ide_app { ide_shell { ide_editor { text "x" } } })
      expect(page).to include(%(class="sw-ide-shell"))
      expect(page).not_to include("sw-ide-shell__nav-toggle\"")
      expect(page).not_to include("sw-ide-shell__backdrop\"")
    end

    it "moves the right rail off-canvas below 1180px and back when open" do
      mobile = css[/@media \(max-width: 1180px\) \{.*?\n\}/m]
      expect(mobile).not_to be_nil
      expect(mobile).to include("grid-template-columns: 200px minmax(0, 1fr)")
      expect(mobile).to match(/\.sw-ide-rail-right \{[^}]*position: fixed;[^}]*transform: translateX\(100%\);/)
      expect(mobile).to match(/\.sw-ide-shell--rail-open \.sw-ide-rail-right \{[^}]*transform: none;/)
      expect(mobile).to match(/\.sw-ide-shell__nav-toggle \{[^}]*display: inline-flex;/)
    end

    it "hides the toggle and backdrop on wide screens" do
      wide = css.split("@media").first
      expect(wide).to match(/\.sw-ide-shell__nav-toggle \{[^}]*display: none;/)
      expect(wide).to match(/\.sw-ide-shell__backdrop \{[^}]*display: none;/)
    end

    it "drops the left rail to a single column below 840px" do
      narrow = css[/@media \(max-width: 840px\) \{.*?\n\}/m]
      expect(narrow).to include("grid-template-columns: minmax(0, 1fr)")
      expect(narrow).to match(/\.sw-ide-rail-left \{[^}]*display: none;/)
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
      result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, dsl, session_name: "ide")
      expect(result.error).to be_nil
      expect(result.html).to include(%(class="sw-ide-shell"))
      expect(result.html).to include(%(<main class="sw-ide-editor"))
      expect(result.html).to include(".sw-ide-shell {")
    end
  end
end
