# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/node_js'
require 'stream_weaver/org/reader'

# The replay component inside the browser extension, run against the real
# shipped Opal bundle (extension/vendor/sw-runtime.js), not a MRI stand-in.
#
# Two things only the Opal runtime can show: Replay and the org reader compile
# and behave identically to MRI (a Symbol is a String under Opal, which broke
# the reader's symbol emission before this spec existed), and the shipped page
# and build actually carry the engine. Whether the animation survives a real
# morphdom pass is a browser gate, recorded on the Tyrion story.
RSpec.describe 'replay in the browser extension' do
  include NodeJS

  let(:root) { File.expand_path('../..', __dir__) }
  let(:runtime) { File.join(root, 'extension', 'vendor', 'sw-runtime.js') }
  let(:example) { File.read(File.join(root, 'examples', 'components', 'replay_thursday.rb')) }
  let(:org) do
    <<~'ORG'
      #+STREAMWEAVER_DSL: 1

      #+NAME: lanes
      | id        | name         | sub  | color |
      |-----------+--------------+------+-------|
      | doc-parity | Doc parity  | a, b | cyan  |
      | prep      | Meeting prep |      | #123456 |

      #+NAME: events
      | at        | lane       | text      | my-count | milestone |
      |-----------+------------+-----------+----------+-----------|
      | Thu 09:48 | doc-parity | did a     |        2 |           |
      | Thu 09:50 | prep       | asked     |          | t         |

      #+begin_src replay :title "T" :counters "my-count:things"
      #+FINALE: Done. | {my-count} things
      #+end_src
    ORG
  end

  def load_runtime
    <<~JS
      const fs = require("fs"), vm = require("vm");
      global.marked = require(#{File.join(root, 'extension', 'vendor', 'marked.umd.js').to_json});
      vm.runInThisContext(fs.readFileSync(#{runtime.to_json}, "utf8"), { filename: "sw-runtime.js" });
    JS
  end

  describe 'under the Opal runtime' do
    before do
      skip "#{runtime} is missing -- run bin/build_extension" unless File.exist?(runtime)
    end

    it 'renders a replay with the same stage id as MRI (content-derived, engine-independent)' do
      src = example
      mri_id = StreamWeaver::App.new('t') { instance_eval(src) }.tap { |a| a.rebuild_with_state({}) }
                                .components.find { |c| c.is_a?(StreamWeaver::Components::Replay) }.fingerprint
      result = run_node_json(load_runtime, <<~JS)
        Opal.eval(`app("T") do\n${#{example.to_json}}\nend`);
        const html = SWRender.staticHtml();
        const cfg = JSON.parse(html.match(/class="sw-replay__data">([\\s\\S]*?)<\\/script>/)[1]);
        console.log(JSON.stringify({
          id: (html.match(/id="(sw-replay-[0-9a-z]+)"/) || [])[1],
          lanes: cfg.lanes.length, events: cfg.events.length, finale: cfg.finale.sub,
          dataKey: html.includes('data-key="commit"'), dataLane: html.includes('data-lane="access"')
        }));
      JS

      expect(result['id']).to eq("sw-replay-#{mri_id}")
      expect(result).to include('lanes' => 5, 'events' => 29, 'dataKey' => true, 'dataLane' => true)
      expect(result['finale']).to start_with('14 commits, 5 invites')
    end

    it 'derives auto windows and generated gap cards identically to MRI (dates, midnight, week-long gap)' do
      dsl = <<~RUBY
        replay(title: "T") do
          counter :n, "things"
          lane :a, "A"
          auto_windows idle: 120
          event "Wed 09-30 18:44", :a, "x", n: 1
          event "Thu 10-01 09:48", :a, "y"
          event "Thu 10-01 09:50", :a, "z", n: 2
          event "Thu 10-08 09:00", :a, "w"
          finale "Done.", "{n} things"
        end
      RUBY
      mri = StreamWeaver::App.new('t') { instance_eval(dsl) }.tap { |a| a.rebuild_with_state({}) }
                             .components.find { |c| c.is_a?(StreamWeaver::Components::Replay) }
      opal = run_node_json(load_runtime, <<~JS)
        Opal.eval(`app("T") do\n${#{dsl.to_json}}\nend`);
        const html = SWRender.staticHtml();
        console.log(html.match(/class="sw-replay__data">([\\s\\S]*?)<\\/script>/)[1]);
      JS

      expect(opal).to eq(JSON.parse(mri.to_json_safe))
      expect(opal['gaps'].map { |g| g['caption'] }).to eq(['15h 4m later', '6d 23h later'])
      expect(opal['windows'].size).to eq(3)
    end

    it 'reads a replay from org identically to MRI, including hyphenated ids (Symbol is a String in Opal)' do
      opal_dsl = run_node_json(load_runtime, <<~JS)
        console.log(JSON.stringify({ dsl: Opal.StreamWeaver.Org.Reader.$to_dsl(#{org.to_json}) }));
      JS

      expect(opal_dsl['dsl']).to eq(StreamWeaver::Org::Reader.to_dsl(org))
      expect(opal_dsl['dsl']).to include('lane :"doc-parity"', '"my-count": 2')
    end

    it 'compiles and renders that org-derived replay' do
      result = run_node_json(load_runtime, <<~JS)
        const { rewriteHeredocs } = require(#{File.join(root, 'extension', 'vendor', 'sw-heredoc-rewrite.js').to_json});
        const dsl = Opal.StreamWeaver.Org.Reader.$to_dsl(#{org.to_json});
        Opal.eval(`app("T") do\n${rewriteHeredocs(dsl)}\nend`);
        const html = SWRender.staticHtml();
        console.log(JSON.stringify({ stage: html.includes('class="sw-replay"'), key: html.includes('data-key="my-count"') }));
      JS

      expect(result).to eq('stage' => true, 'key' => true)
    end
  end

  describe 'what ships' do
    let(:engine) { File.read(File.join(root, 'lib', 'stream_weaver', 'assets', 'js', 'sw-replay.js')) }

    it 'loads the engine in the sandbox page and copies it into the bundle' do
      expect(File.read(File.join(root, 'extension', 'sandbox.html'))).to include('vendor/sw-replay.js')
      expect(File.read(File.join(root, 'bin', 'build_extension'))).to include('"sw-replay.js"')
    end

    it 'bundles the engine for opal-build pages too' do
      expect(File.read(File.join(root, 'lib', 'stream_weaver', 'opal', 'builder.rb'))).to include('"sw-replay.js"')
    end

    # The sandbox CSP closes network and eval; this keeps the engine a thing
    # that never needs them, so the "interactive with zero egress" claim holds.
    it 'needs no network, eval, or navigation' do
      %w[fetch( XMLHttpRequest WebSocket EventSource sendBeacon eval( new\ Function import( window.open location.].each do |banned|
        expect(engine).not_to include(banned), "sw-replay.js must not use #{banned}"
      end
    end
  end

  describe 'morph guard (runtime.rb)' do
    it 'skips an initialized replay stage the same way it skips a decorated mermaid node' do
      runtime_rb = File.read(File.join(root, 'lib', 'stream_weaver', 'opal', 'runtime.rb'))
      expect(runtime_rb).to include("fromEl.hasAttribute('data-sw-ready')")
    end
  end
end
