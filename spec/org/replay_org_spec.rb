# frozen_string_literal: true

require "org-ruby"
require "stream_weaver"
require_relative "../../lib/stream_weaver/org/reader"
require_relative "../../lib/stream_weaver/org/writer"

RSpec.describe "replay in org (#+NAME tables + #+begin_src replay)" do
  let(:org) do
    <<~'ORG'
      #+STREAMWEAVER_DSL: 1

      Intro prose.

      #+NAME: lanes
      | id     | name             | sub         | color |
      |--------+------------------+-------------+-------|
      | access | DinoCloud access | AWS, GitHub | cyan  |
      | prep   | Meeting prep     |             | green |

      #+NAME: events
      | at        | lane   | text                       | commit | milestone |
      |-----------+--------+----------------------------+--------+-----------|
      | Wed 18:44 | access | Vendor logins              |        |           |
      | Thu 09:48 | access | commit: remove one-time    |      1 |           |
      | Thu 11:46 | prep   | Ask: I have 15 min to prep |        | t         |

      #+begin_src replay :title "Thursday" :ms-per-minute 200 :counters "commit:commits"
      #+WINDOW: Wed 18:40 .. Wed 18:50
      #+GAP: Then 6 hours away | Back after dinner
      #+WINDOW: Thu 09:05 .. Thu 12:02
      #+FINALE: Noon. | {commit} commits before lunch
      #+end_src

      After prose.
    ORG
  end

  def replay_of(dsl)
    app = StreamWeaver::App.new("t") { instance_eval(dsl) }
    app.rebuild_with_state({})
    app.components.find { |c| c.is_a?(StreamWeaver::Components::Replay) }
  end

  def dsl_of(text) = StreamWeaver::Org::Reader.to_dsl(text)

  describe "Reader" do
    let(:config) { replay_of(dsl_of(org)).to_config }

    it "builds the replay from named tables and header args" do
      expect(config[:title]).to eq("Thursday")
      expect(config[:msPerMinute]).to eq(200)
      expect(config[:lanes].map { |l| [l[:id], l[:color]] }).to eq([["access", "#2aa198"], ["prep", "#859900"]])
      expect(config[:counters]).to eq([{ key: "commit", label: "commits" }])
      expect(config[:events].map { |e| [e[:t], e[:lane], e[:inc], e[:human]] }).to eq(
        [["18:44", "access", {}, false], ["09:48", "access", { "commit" => 1 }, false], ["11:46", "prep", {}, true]]
      )
      expect(config[:finale]).to eq(caption: "Noon.", sub: "1 commits before lunch")
      expect(config[:gaps]).to eq([{ caption: "Then 6 hours away", sub: "Back after dinner" }])
    end

    it "consumes the data tables instead of also rendering them as tables" do
      expect(dsl_of(org)).not_to include("table(")
    end

    it "keeps the prose around the block" do
      dsl = dsl_of(org)
      expect(dsl).to include("Intro prose.", "After prose.")
    end

    it "falls back to the nearest preceding tables by header when no :lanes/:events are given" do
      unnamed = org.gsub(/^#\+NAME:.*\n/, "")
      expect(replay_of(dsl_of(unnamed)).to_config[:events].size).to eq(3)
    end

    it "infers counters from non-reserved event columns when :counters is omitted" do
      bare = org.sub(' :counters "commit:commits"', "")
      expect(replay_of(dsl_of(bare)).to_config[:counters]).to eq([{ key: "commit", label: "commit" }])
    end

    it "leaves an ordinary named table that no replay references as a normal table" do
      extra = "#+NAME: other\n| a | b |\n|---+---|\n| 1 | 2 |\n\n" + org
      expect(dsl_of(extra)).to include("table(")
    end

    it "raises on a reference to a table that does not exist" do
      expect { dsl_of(org.sub(":title", ":lanes nope :title")) }.to raise_error(ArgumentError, /no table named "nope"/)
    end

    it "raises when a table lacks a required column" do
      broken = org.sub("| at        |", "| when      |").sub(":title", ":lanes lanes :events events :title")
      expect { dsl_of(broken) }.to raise_error(ArgumentError, /missing column/)
    end

    it "raises on an unrecognized line inside the block" do
      expect { dsl_of(org.sub("#+FINALE:", "#+BOGUS:")) }.to raise_error(ArgumentError, /unrecognized line in replay block/)
    end

    it "raises on a non-integer counter cell" do
      expect { dsl_of(org.sub("|      1 |", "|    abc |")) }.to raise_error(ArgumentError)
    end
  end

  describe "Writer" do
    let(:dsl) { dsl_of(org) }

    it "reaches a fixpoint: writer(reader(writer(x))) == writer(x)" do
      out1 = StreamWeaver::Org::Writer.from_dsl(dsl)
      out2 = StreamWeaver::Org::Writer.from_dsl(dsl_of(out1))
      expect(out2).to eq(out1)
    end

    it "preserves the replay itself across the round trip" do
      out = StreamWeaver::Org::Writer.from_dsl(dsl)
      expect(replay_of(dsl_of(out)).to_config).to eq(replay_of(dsl).to_config)
    end

    it "emits the src form (never a special block) with named tables" do
      out = StreamWeaver::Org::Writer.from_dsl(dsl)
      expect(out).to include("#+NAME: lanes", "#+NAME: events", "#+begin_src replay :title \"Thursday\" :lanes lanes :events events")
      expect(out).not_to match(/#\+begin_replay/i)
    end

    it "omits the milestone column when no event is a milestone, and the round trip still holds" do
      plain = <<~RUBY
        replay(title: "T") do
          counter :n, "things"
          lane :a, "A"
          event "09:00", :a, "x", n: 2
        end
      RUBY
      out = StreamWeaver::Org::Writer.from_dsl(plain)
      expect(out).not_to include("milestone")
      expect(replay_of(dsl_of(out)).to_config).to eq(replay_of(plain).to_config)
    end

    it "gives a second replay its own table names" do
      one = <<~RUBY
        replay(title: "T") do
          counter :n, "things"
          lane :a, "A"
          event "09:00", :a, "x", n: 1
        end
      RUBY
      two = "#{one}\n#{one}"
      out = StreamWeaver::Org::Writer.from_dsl(two)
      expect(out).to include("#+NAME: lanes-2", "#+NAME: events-2")
      expect(StreamWeaver::Org::Writer.from_dsl(dsl_of(out))).to eq(out)
    end
  end

  describe "auto windows in org" do
    let(:auto_org) do
      org.sub(':title "Thursday"', ':title "Thursday" :auto-windows 120').gsub(/^#\+(WINDOW|GAP):.*\n/, "")
    end

    it "reads :auto-windows into auto_windows and round-trips it" do
      expect(dsl_of(auto_org)).to include("auto_windows idle: 120")
      cfg = replay_of(dsl_of(auto_org)).to_config
      expect(cfg[:windows].size).to eq(2)
      expect(cfg[:gaps].first[:caption]).to match(/later\z/)

      out = StreamWeaver::Org::Writer.from_dsl(dsl_of(auto_org))
      expect(out).to include(":auto-windows 120")
      expect(out).not_to include("#+WINDOW:")
      expect(StreamWeaver::Org::Writer.from_dsl(dsl_of(out))).to eq(out)
    end
  end

  describe "generic org renderers (what GitHub shows)" do
    it "shows the tables and the config lines instead of dropping the block" do
      out = StreamWeaver::Org::Writer.from_dsl(dsl_of(org))
      html = Orgmode::Parser.new(out).to_html
      expect(html).to include("<table>", "DinoCloud access", "Ask: I have 15 min to prep")
      expect(html).to include('<pre class="src" lang="replay">', "#+WINDOW: Wed 18:40 .. Wed 18:50")
    end
  end
end
