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
      expect(rows).to eq([["Thu 10-01 09:48", :dev, "2 commits", { commit: 2 }],
                          ["Thu 10-01 10:00", :dev, "Teams post", {}]])
    end

    it "labels with a humanized effect kind by default, not the raw (truncated, compound) command" do
      expect(described_class.skeleton_label(:git_commit, { "count" => 1, "cmd" => "sed -i x; git commit" })).to eq("commit")
      expect(described_class.skeleton_label(:pr_opened, { "count" => 3 })).to eq("3 PRs opened")
      expect(described_class.skeleton_label(:something_new, { "count" => 1 })).to eq("something new")
    end

    it "accepts a label lambda to override" do
      rows = described_class.events_from_skeleton(report, map: { git_commit: [:dev, :commit] }, label: ->(_k, i) { i["cmd"] })
      expect(rows.first[2]).to eq("git commit -m x")
    end

    it "feeds #events" do
      rows = described_class.events_from_skeleton(report, map: { git_commit: [:dev, :commit] })
      c = build { counter :commit, "commits"; lane :dev, "Dev" }
      c.events(rows)
      expect(c.to_config[:events].first[:inc]).to eq("commit" => 2)
    end
  end

  describe ".events_from_skeletons (several sessions, one lane each)" do
    def report(items)
      { "effects" => { "git_commit" => { "count" => items.size, "items" => items.map { |at| { "at" => at, "cmd" => "c #{at}", "count" => 1 } } } } }
    end

    it "merges sessions into one oldest-first list, lane per session" do
      rows = described_class.events_from_skeletons(
        { dev: report(["Thu 10-01 10:00", "Wed 09-30 18:44"]), ops: report(["Thu 10-01 09:12"]) },
        counters: { git_commit: :commit }
      )
      expect(rows.map { |r| [r[0], r[1]] }).to eq([["Wed 09-30 18:44", :dev], ["Thu 10-01 09:12", :ops], ["Thu 10-01 10:00", :dev]])
    end

    it "keeps two different Thursdays apart as separate days, both labelled Thu" do
      c = build do
        counter :commit, "commits"
        lane :dev, "Dev"
        auto_windows idle: 120
      end
      c.events(described_class.events_from_skeleton(report(["Thu 10-01 09:00", "Thu 10-08 09:00"]), map: { git_commit: [:dev, :commit] }))
      cfg = c.to_config
      expect(cfg[:days]).to eq(%w[Thu Thu])
      expect(cfg[:windows].size).to eq(2)
    end

    it "builds a whole replay with no windows or captions written by hand" do
      c = build do
        counter :commit, "commits"
        lane :dev, "Dev"
        lane :ops, "Ops"
        auto_windows idle: 120
      end
      rows = described_class.events_from_skeletons(
        { dev: report(["Wed 09-30 18:44", "Thu 10-01 09:48"]), ops: report(["Thu 10-01 09:50"]) },
        counters: { git_commit: :commit }
      )
      c.events(rows)
      cfg = c.to_config
      expect(cfg[:windows].size).to eq(2)
      expect(cfg[:gaps]).to eq([{ caption: "15h 4m later", sub: "Back at Thu 10-01 09:48" }])
      expect(cfg[:events].size).to eq(3)
    end
  end

  describe "#auto_windows" do
    def auto(idle: 120, times:)
      build do
        counter :n, "n"
        lane :a, "A"
        auto_windows idle: idle
        times.each { |t| event t, :a, "e" }
      end.to_config
    end

    it "splits where consecutive events are more than idle minutes apart" do
      cfg = auto(times: ["09:00", "09:10", "13:30"])
      expect(cfg[:windows]).to eq([[539, 551], [809, 811]])
    end

    it "does not split at exactly the idle threshold" do
      expect(auto(times: ["09:00", "11:00"])[:windows].size).to eq(1)
      expect(auto(times: ["09:00", "11:01"])[:windows].size).to eq(2)
    end

    it "generates a gap card: hours and minutes, with the day when the replay has day labels" do
      expect(auto(times: ["09:00", "13:30"])[:gaps]).to eq([{ caption: "4h 30m later", sub: "Back at 13:30" }])
      cfg = build do
        lane :a, "A"
        auto_windows idle: 60
        event "Wed 18:00", :a, "x"
        event "Thu 09:00", :a, "y"
      end.to_config
      expect(cfg[:gaps]).to eq([{ caption: "15h later", sub: "Back at Thu 09:00" }])
    end

    it "spells out days and drops minutes once a gap passes 24 hours" do
      cfg = build do
        lane :a, "A"
        auto_windows idle: 120
        event "Mon 09:00", :a, "x"
        event "Tue 11:30", :a, "y"
      end.to_config
      expect(cfg[:gaps].first[:caption]).to eq("1d 2h later")
    end

    it "uses the real calendar distance when day labels carry dates (a week is not one day)" do
      cfg = build do
        lane :a, "A"
        auto_windows idle: 120
        event "Thu 10-01 09:00", :a, "x"
        event "Thu 10-08 09:00", :a, "y"
      end.to_config
      expect(cfg[:gaps]).to eq([{ caption: "7d later", sub: "Back at Thu 10-08 09:00" }])
    end

    it "assumes consecutive labels are consecutive days when there are no dates (documented limitation)" do
      cfg = build do
        lane :a, "A"
        auto_windows idle: 120
        event "Mon 09:00", :a, "x"
        event "Fri 09:00", :a, "y"
      end.to_config
      expect(cfg[:gaps].first[:caption]).to eq("1d later")
    end

    it "lets an authored gap win at its position and generates the rest" do
      cfg = build do
        lane :a, "A"
        auto_windows idle: 120
        gap "Sleep.", sub: "Picked up at 9"
        event "09:00", :a, "x"
        event "13:00", :a, "y"
        event "20:00", :a, "z"
      end.to_config
      expect(cfg[:gaps].map { |g| g[:caption] }).to eq(["Sleep.", "7h later"])
    end

    it "never starts a window before minute 0" do
      expect(auto(times: ["00:00", "00:30"])[:windows]).to eq([[0, 31]])
    end

    it "rejects mixing with explicit windows and a nonsensical idle" do
      mixed = build { lane :a, "A"; auto_windows idle: 120; window "09:00".."10:00"; event "09:30", :a, "x" }
      expect { mixed.to_config }.to raise_error(ArgumentError, /either window or auto_windows/)
      expect { build { auto_windows idle: 1 } }.to raise_error(ArgumentError, /at least 2/)
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

    it "styles the title tag the markup actually emits (a doc theme's dark text must not win)" do
      basic.render(view, {})
      tag = view.to_html[%r{sw-replay__title"><(\w+)>}, 1]
      expect(opal.collected_css_text).to include(".sw-replay__title #{tag} {")
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
