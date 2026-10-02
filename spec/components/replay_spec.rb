# frozen_string_literal: true

require "stream_weaver/opal/renderer"
require "stream_weaver/adapter/opal"

RSpec.describe StreamWeaver::Components::Replay do
  def build(**opts, &block)
    described_class.new(title: "T", **opts, &block)
  end

  let(:basic) do
    build do
      counter :commit, "commits"
      lane :a, "Lane A", sub: "sub", color: :cyan
      window "Wed 18:40".."Wed 18:50"
      gap "Away", sub: "back later"
      window "Thu 09:00".."Thu 09:10"
      event "Wed 18:44", :a, "first", commit: 1
      milestone "Thu 09:05", :a, "ask"
      event "Thu 09:06", :a, "second", commit: 2
      finale "Done.", "{commit} commits"
    end
  end

  describe "#to_config" do
    it "converts day-labelled times to absolute minutes in order of first appearance" do
      cfg = basic.to_config
      expect(cfg[:days]).to eq(%w[Wed Thu])
      expect(cfg[:windows]).to eq([[1120, 1130], [1440 + 540, 1440 + 550]])
      expect(cfg[:events].map { |e| e[:m] }).to eq([1124, 1985, 1986])
    end

    it "keeps the display time and marks milestones as human" do
      ev = basic.to_config[:events]
      expect(ev.map { |e| e[:t] }).to eq(%w[18:44 09:05 09:06])
      expect(ev.map { |e| e[:human] }).to eq([false, true, false])
    end

    it "resolves palette colors and passes hex through" do
      c = build { lane :a, "A", color: :magenta; lane :b, "B", color: "#123456"; counter :x, "x" }
      expect(c.to_config[:lanes].map { |l| l[:color] }).to eq(["#d33682", "#123456"])
    end

    it "interpolates counter totals into the finale" do
      expect(basic.to_config[:finale]).to eq(caption: "Done.", sub: "3 commits")
    end

    it "infers one window around the events when none are declared" do
      c = build do
        counter :x, "x"
        lane :a, "A"
        event "09:00", :a, "e"
        event "09:30", :a, "f"
      end
      expect(c.to_config[:windows]).to eq([[539, 571]])
    end

    it "yields itself when the block takes an argument" do
      c = build { |r| r.lane :a, "A" }
      expect(c.to_config[:lanes].size).to eq(1)
    end

    it "sorts events chronologically regardless of declaration order" do
      c = build do
        lane :a, "A"
        event "10:00", :a, "late"
        event "09:00", :a, "early"
      end
      expect(c.to_config[:events].map { |e| e[:text] }).to eq(%w[early late])
    end
  end

  describe "validation" do
    it "rejects an unknown lane" do
      c = build { event "09:00", :nope, "x" }
      expect { c.to_config }.to raise_error(ArgumentError, /unknown lane nope/)
    end

    it "rejects an unknown counter" do
      c = build { lane :a, "A"; event "09:00", :a, "x", bogus: 1 }
      expect { c.to_config }.to raise_error(ArgumentError, /unknown counter bogus/)
    end

    it "rejects an event outside every window" do
      c = build { lane :a, "A"; window "09:00".."09:10"; event "10:00", :a, "x" }
      expect { c.to_config }.to raise_error(ArgumentError, /outside every window/)
    end

    it "requires a gap between each pair of windows" do
      c = build { lane :a, "A"; window "09:00".."09:10"; window "10:00".."10:10" }
      expect { c.to_config }.to raise_error(ArgumentError, /needs 1 gap/)
    end

    it "rejects an unknown finale placeholder" do
      c = build { lane :a, "A"; event "09:00", :a, "x"; finale "{nope}" }
      expect { c.to_config }.to raise_error(ArgumentError, /unknown counter \{nope\}/)
    end

    it "rejects a malformed time" do
      expect { build { event "9am", :a, "x" } }.to raise_error(ArgumentError, /bad replay time/)
    end
  end

  describe ".events_from_skeleton" do
    let(:report) do
      { "effects" => {
        "git_commit" => { "count" => 3, "items" => [{ "at" => "Thu 10-01 09:48", "cmd" => "git commit -m x", "count" => 2 }] },
        "teams_post" => { "count" => 1, "items" => [{ "at" => "Thu 10-01 10:00", "cmd" => "teams send", "count" => 1 }] },
        "files" => { "count" => 1, "items" => [{ "at" => "Thu 10-01 10:05", "cmd" => "skipped" }] }
      } }
    end

    it "maps effect kinds to lane + counter and drops unmapped kinds" do
      rows = described_class.events_from_skeleton(report, map: { git_commit: [:dev, :commit], teams_post: [:dev, nil] })
      expect(rows).to eq([["Thu 09:48", :dev, "git commit -m x", { commit: 2 }],
                          ["Thu 10:00", :dev, "teams send", {}]])
    end

    it "feeds #events" do
      rows = described_class.events_from_skeleton(report, map: { git_commit: [:dev, :commit] })
      c = build { counter :commit, "commits"; lane :dev, "Dev" }
      c.events(rows)
      expect(c.to_config[:events].first[:inc]).to eq("commit" => 2)
    end
  end

  describe "rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:html) { StreamWeaver::ComponentRenderer.render_html(adapter, [basic], {}) }

    it "renders the stage, counters, lanes and controls" do
      expect(html).to include('class="sw-replay"')
      expect(html).to include('data-key="commit"')
      expect(html).to include('data-lane="a"')
      expect(html).to include("sw-replay__play", "sw-replay__restart", "sw-replay__speed")
    end

    it "embeds the config as JSON and inlines the engine without any CDN" do
      expect(html).to include('class="sw-replay__data"')
      expect(html).to include('"msPerMinute":340')
      expect(html).to include("window.swReplayInit")
      expect(html).not_to match(%r{<script[^>]+src=})
    end

    it "cannot be broken out of by event text containing </script>" do
      c = build { lane :a, "A"; event "09:00", :a, "</script><b>x" }
      out = StreamWeaver::ComponentRenderer.render_html(adapter, [c], {})
      expect(out).not_to include("</script><b>x")
    end

    it "injects CSS and engine once for two replays" do
      out = StreamWeaver::ComponentRenderer.render_html(adapter, [basic, basic], {})
      expect(out.scan(".sw-replay__chip--old {").size).to eq(1)
      expect(out.scan("window.swReplayInit) return").size).to eq(1)
    end
  end

  describe "Opal adapter parity (renderer lives in Adapter::Static)" do
    let(:opal) { StreamWeaver::Adapter::Opal.new }
    let(:view) { StreamWeaver::Opal::OpalRenderer.new(opal, {}) }

    it "renders the same markup through the Opal renderer, with string data attributes" do
      basic.render(view, {})
      out = view.to_html
      expect(out).to include('class="sw-replay"', 'data-key="commit"', 'data-lane="a"', "sw-replay__data")
      expect(out).not_to include("data=")
    end

    it "contributes CSS but no engine script (the host bundles sw-replay.js)" do
      basic.render(view, {})
      expect(opal.collected_css_text).to include(".sw-replay__chip")
      expect(view.to_html).not_to include("sw-replay.js")
      expect(view.to_html).not_to include("var SPEEDS")
    end
  end

  describe "canvas and reader shells (tripwires; behavior verified in a browser, see Tyrion evidence)" do
    root = File.expand_path("../..", __dir__)
    read = ->(rel) { File.read(File.join(root, rel)) }

    it "ships the engine in the canvas page shell so a replay in a LATER push (inert inline scripts) still initializes" do
      expect(read.("lib/stream_weaver/canvas/bridge_server.rb")).to include("sw-replay.js")
    end

    it "ships the engine in every reader render path" do
      reader = read.("lib/stream_weaver/canvas/reader.rb")
      expect(reader.scan("@replay_js = REPLAY_JS").size).to eq(reader.scan("@mermaid_zoom_js = MERMAID_ZOOM_JS").size)
      expect(read.("lib/stream_weaver/views/canvas/reader_layout.erb")).to include("@replay_js")
    end

    it "self-initializes new stages and stops loops on detached ones (morphs replace the DOM)" do
      js = read.("lib/stream_weaver/assets/js/sw-replay.js")
      expect(js).to include("MutationObserver")
      expect(js).to include("isConnected")
    end
  end

  describe "bare export" do
    let(:exporter) { StreamWeaver::Export::HtmlExporter.from_dsl(%(replay(title: "T") { lane :a, "A"; event "09:00", :a, "x" }), layout: :fluid) }

    it "keeps the page shell by default and drops it with bare: true" do
      expect(exporter.to_html).not_to include(".sw-replay{height:100vh!important")
      expect(exporter.to_html(bare: true)).to include(".sw-replay{height:100vh!important")
    end

    it "needs no external script (offline and iframe safe)" do
      expect(exporter.to_html(bare: true)).not_to match(%r{<script[^>]+src=})
    end
  end

  describe "DSL" do
      it "registers replay on the app DSL" do
        app = StreamWeaver::App.new("t") { replay(title: "T") { lane :a, "A" } }
        app.rebuild_with_state({})
        expect(app.components.first).to be_a(described_class)
      end
    end
end
