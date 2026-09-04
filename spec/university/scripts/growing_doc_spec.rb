# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
require 'stringio'
require 'stream_weaver'
require 'stream_weaver/org/writer'
require 'stream_weaver/org/reader'

SCRIPT_PATH = File.expand_path(
  '../../../lib/stream_weaver/university/scripts/growing_doc.rb', __dir__
)

# Story step-4-growing-doc's script: a background boot smoke test, not a
# canvas-integration test (that's UAT -- see the story's consolidated
# handoff note on step-1-canvas-push). Confirms the file requires and
# starts cleanly under SW_NO_OPEN=1 without a Ruby-level crash, then is
# killed by PID rather than waited out to completion -- a live bridge
# would otherwise keep it sleeping between pushes for the full pause.
RSpec.describe 'stream_weaver/university/scripts/growing_doc.rb' do
  let(:script_path) { SCRIPT_PATH }
  let(:session_name) { "growing-doc-smoke-#{Process.pid}" }

  # Loaded once for every describe below that inspects the module directly
  # (in-process, no bridge, no subprocess) -- eval'd with the trailing
  # `run!` stripped, same reason each of them used to do this individually.
  before(:all) do
    source = File.read(SCRIPT_PATH)
                 .sub(/^StreamWeaver::University::Scripts::GrowingDoc\.run!\s*\z/, '')
    eval(source, TOPLEVEL_BINDING, SCRIPT_PATH) # rubocop:disable Security/Eval
  end

  let(:mod) { StreamWeaver::University::Scripts::GrowingDoc }

  after do
    require 'stream_weaver/canvas/client'
    StreamWeaver::Canvas::Client.send_message(
      StreamWeaver::Canvas::Protocol::Messages.close(session_name)
    )
  rescue StandardError
    nil # best-effort cleanup; no bridge reachable is fine here
  end

  it 'boots under SW_NO_OPEN=1 without raising, and can be killed by PID' do
    pid = Process.spawn(
      { 'SW_NO_OPEN' => '1', 'STREAMWEAVER_GROWING_DOC_PAUSE' => '5' },
      Gem.ruby, '-I', File.expand_path('../../../lib', __dir__), script_path, session_name,
      out: File::NULL, err: File::NULL
    )

    killed_mid_run = false
    status = begin
      Timeout.timeout(1) { Process.waitpid2(pid).last }
    rescue Timeout::Error
      Process.kill('TERM', pid)
      Process.waitpid2(pid)
      killed_mid_run = true
      nil
    end

    # Either it finished fast (no bridge reachable -- the rescued warning
    # path exits 0) or it was still mid-run against a live bridge and we
    # killed it by PID; both mean the script loaded and ran, not crashed.
    expect(killed_mid_run || status.success?).to be(true)
  end

  # Step 4's payoff is a document, and step 5 carries that same document out
  # through `streamweaver org-export` to a gist. These check the content the
  # script actually pushes, in-process -- no bridge, no subprocess. The
  # script is eval'd with its trailing `run!` stripped, because requiring
  # the file outright would try to reach (and start) a canvas bridge.
  describe 'the finished document' do
    # What the pane holds after the last push: every stage accumulated,
    # exactly as #run! builds it.
    let(:final_body) do
      toc = []
      body = +''
      mod::STAGES.each do |stage|
        toc << stage[:toc] if stage[:toc]
        body << stage[:dsl] << "\n"
      end
      mod.document(toc, body)
    end

    def components_of(dsl)
      ctx = StreamWeaver::Org::RecordingContext.new
      ctx.instance_eval(dsl)
      ctx.components.map { |c| c.class.name.split('::').last }
    end

    # Six outline entries is the floor, not a coincidence: below it the doc
    # theme's sidebar nav has nothing worth showing, and round-5 UAT ended
    # step 5 pointing at a nav that wasn't there.
    it 'grows in enough pushes to fill a sidebar outline, each carrying everything before it' do
      expect(mod::STAGES.count { |s| s[:toc] }).to be >= 6
      bodies = mod::STAGES.each_with_object([+'']) { |s, acc| acc << (acc.last + s[:dsl]) }.drop(1)
      bodies.each_cons(2) { |earlier, later| expect(later).to start_with(earlier) }
    end

    it 'holds the doc features step 4 promises' do
      expect(components_of(final_body)).to include(
        'SidebarToc', 'DocHeader', 'Comparison', 'CodeBlock', 'Callout', 'Mermaid'
      )
    end

    it 'anchors every sidebar_toc entry on a real doc_section_header id' do
      toc_ids = mod::STAGES.filter_map { |s| s[:toc]&.fetch(:id) }
      expect(toc_ids).not_to be_empty
      toc_ids.each { |id| expect(final_body).to include(%(id: "#{id}")) }
    end

    # Prose may name the canvas's own "Save as doc" button; what must not
    # appear is a DSL call for one -- canvas-read greys those out and an
    # export leaves them silently dead (disc-095), and this doc is meant to
    # be reopened in both.
    it 'stays content-only -- no controls that die outside the live canvas (disc-095)' do
      expect(final_body).not_to match(/^\s*(?:button|radio_group|chip_group|tag_buttons|form)\b/)
    end

    it 'uses no chart shorthand, so the export keeps its Chart.js (disc-094)' do
      %w[bar_chart hbar_chart line_chart area_chart pie_chart doughnut_chart
         stacked_bar_chart sparkline].each do |shorthand|
        expect(final_body).not_to include(shorthand)
      end
    end

    # The one that bites: `text` inside a callout is not a component the org
    # writer recognizes, and nested passthrough has no verbatim source to
    # fall back on -- the callout body is replaced by an "unrecognized
    # component" placeholder, silently. `md` survives. Any future editor who
    # reaches for `text` here fails this.
    it 'org-exports with every component recognized -- nothing falls through' do
      writer = StreamWeaver::Org::Writer.new(final_body)
      writer.call
      expect(writer.coverage).to include(passthrough_verbatim: 0, passthrough_lossy: 0)
      expect(writer.coverage[:recognized]).to eq(writer.coverage[:total])
    end

    it 'round-trips DSL -> org -> DSL with the same components in the same order' do
      org = StreamWeaver::Org::Writer.from_dsl(final_body)
      expect(components_of(StreamWeaver::Org::Reader.to_dsl(org)))
        .to eq(components_of(final_body))
    end

    it 'keeps the code block and the mermaid diagram intact in the org text' do
      org = StreamWeaver::Org::Writer.from_dsl(final_body)
      expect(org).to include('#+begin_src mermaid')
      expect(org).to include('#+begin_src ruby')
      expect(org).not_to include('unrecognized component')
    end

    # Save-format callout (round-6): the doc's own "reading it back" section
    # explains what .rb and .org are each FOR, not just what they're named.
    it 'explains why .rb and .org both exist -- fidelity vs portability' do
      expect(final_body).to match(/full fidelity/i)
      expect(final_body).to match(/nothing to install/i)
    end
  end

  # Round-6 UAT bug: the picker's radio choice used to be a human label and
  # `--extend` expected the bare key -- a worker had to parse one out of
  # the other, got it wrong, and the doc silently never grew (the
  # unknown-key branch warned to stderr, easy to miss, and `run!` still
  # printed "Saved: <path>" as though the pick had landed). `apply_extensions!`
  # is the extracted fix, testable with no canvas bridge involved.
  describe '.apply_extensions!' do
    it 'adds a known extension, prints OK with the exact rendered header, and returns true' do
      toc = []
      body = +''
      result = nil
      expect { result = mod.apply_extensions!(['tradeoffs'], toc, body) }
        .to output("growing_doc: OK tradeoffs → section 'Tradeoffs — two ways to share it'\n").to_stdout
      expect(result).to be(true)
      expect(toc).to eq([{ id: 'tradeoffs', label: mod::EXTENSIONS['tradeoffs'][:header] }])
      expect(body).to include(mod::EXTENSIONS['tradeoffs'][:dsl])
    end

    it 'fails loudly to stderr and leaves toc/body untouched for an unknown key' do
      toc = []
      body = +''
      result = nil
      expect { result = mod.apply_extensions!(['bogus'], toc, body) }
        .to output(/FAILED -- no such extension "bogus"/).to_stderr
      expect(result).to be(false)
      expect(toc).to be_empty
      expect(body).to be_empty
    end

    it 'is false overall when any key in a multi-key batch is unknown, but still applies the valid ones' do
      toc = []
      body = +''
      result = nil
      expect { result = mod.apply_extensions!(%w[tradeoffs bogus], toc, body) }.to output.to_stdout
      expect(result).to be(false)
      expect(toc).to eq([{ id: 'tradeoffs', label: mod::EXTENSIONS['tradeoffs'][:header] }])
    end

    # Order independence: a failure has to stay a failure regardless of
    # whether it comes before or after a success in the batch -- `map { }.
    # all?` makes this true by construction, where a hand-threaded fold
    # accumulator could silently regress to "only the last key counts".
    it 'is false overall even when the unknown key comes before a valid one' do
      toc = []
      body = +''
      result = nil
      expect { result = mod.apply_extensions!(%w[bogus tradeoffs], toc, body) }.to output.to_stdout
      expect(result).to be(false)
      expect(toc).to eq([{ id: 'tradeoffs', label: mod::EXTENSIONS['tradeoffs'][:header] }])
    end
  end

  # Round-6 UAT: the old path printed "Saved: <path>" on stdout as
  # unqualified success even when a pick had silently failed to land, with
  # the only sign of trouble on stderr. `save_message` makes the save line
  # itself say so.
  describe '.save_message' do
    it 'reads as plain success when every extension landed' do
      expect(mod.save_message('/tmp/university-doc.rb', 'university-doc', true))
        .to eq('Saved: /tmp/university-doc.rb')
    end

    it 'calls out a failed extension right on the save line itself' do
      expect(mod.save_message('/tmp/university-doc.rb', 'university-doc', false))
        .to eq('Saved: /tmp/university-doc.rb -- WITH FAILED EXTENSIONS, see above')
    end

    it 'still calls it out when the bridge reported no path' do
      expect(mod.save_message(nil, 'university-doc', false)).to include('WITH FAILED EXTENSIONS')
    end
  end

  # Round-6 UAT: step 4's push cadence was narrated only after the whole run
  # finished. `announce_stage` gives the worker a stdout line right before
  # and right after each of the growing doc's own pushes to relay live.
  describe '.announce_stage' do
    it 'names the stage and total, before the push' do
      expect { mod.announce_stage(2, 'pushing') }
        .to output(%r{stage 3/#{mod::STAGES.length} pushing: The push itself}).to_stdout
    end

    it 'names the stage and total, after the push' do
      expect { mod.announce_stage(2, 'pushed') }
        .to output(%r{stage 3/#{mod::STAGES.length} pushed: The push itself}).to_stdout
    end

    it 'announces the opening stage (no toc entry of its own) as "opening"' do
      expect { mod.announce_stage(0, 'pushing') }
        .to output(%r{stage 1/#{mod::STAGES.length} pushing: opening}).to_stdout
    end
  end

  # Round-7 UAT: the user picked "cheatsheet" and could not find a matching
  # header -- the rendered title never said which key it came from. Every
  # extension's header now begins with its own key, capitalized.
  describe 'the key -> header convention (every EXTENSIONS entry)' do
    it 'renders a header that begins with its own key, capitalized -- for every extension' do
      mod::EXTENSIONS.each do |key, ext|
        expect(ext[:header]).to start_with(key.capitalize)
      end
    end

    it 'keeps the header field and the doc_section_header title identical -- no drift' do
      mod::EXTENSIONS.each do |key, ext|
        expect(ext[:dsl]).to include(%(doc_section_header "07", "#{ext[:header]}", id: "#{key}"))
      end
    end

    it 'surfaces every header in the picker legend, not just the label' do
      mod::EXTENSIONS.each_value do |ext|
        expect(mod.picker_dsl).to include(ext[:header])
      end
    end
  end

  # Round-7 UAT: a worker re-ran `--picker` without re-passing `--extend`
  # and clobbered the doc -- the rebuild had no memory of an earlier
  # invocation's picks. `resolve_extend_keys` is the extracted merge,
  # testable with no canvas bridge involved (same reason apply_extensions!
  # was extracted before it).
  describe '.resolve_extend_keys (picker state persists across invocations)' do
    let(:state_session) { "growing-doc-state-spec-#{Process.pid}" }

    around do |example|
      Dir.mktmpdir('growing_doc_resolve') do |dir|
        prev = ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR']
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = dir
        example.run
      ensure
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = prev
      end
    end

    it 'is empty with no persisted state and no --extend given (plain --picker)' do
      expect(mod.resolve_extend_keys(state_session, ['--picker'])).to eq([])
    end

    it 'picks up a fresh --extend with nothing persisted yet' do
      expect(mod.resolve_extend_keys(state_session, ['--extend=tradeoffs'])).to eq(['tradeoffs'])
    end

    # The exact live failure: run picker -> extend(tradeoffs) [persists] ->
    # picker again, with NO --extend flag -- tradeoffs must still resolve.
    it 'keeps a persisted key on a LATER --picker call that passes no --extend at all' do
      StreamWeaver::University::Scripts::GrowingDocState.save(state_session, ['tradeoffs'])

      expect(mod.resolve_extend_keys(state_session, ['--picker'])).to eq(['tradeoffs'])
    end

    it 'adds a new --extend key to what was already persisted, not replacing it' do
      StreamWeaver::University::Scripts::GrowingDocState.save(state_session, ['tradeoffs'])

      expect(mod.resolve_extend_keys(state_session, ['--extend=cheatsheet']))
        .to eq(%w[tradeoffs cheatsheet])
    end

    it 'never lists the same key twice, persisted and re-passed' do
      StreamWeaver::University::Scripts::GrowingDocState.save(state_session, ['tradeoffs'])

      expect(mod.resolve_extend_keys(state_session, ['--extend=tradeoffs'])).to eq(['tradeoffs'])
    end
  end

  # DHH review of the round-7 fix caught a hole it opened: resolve_extend_keys
  # merges PERSISTED keys into every call, so a later PLAIN re-run (clicking
  # Repeat on step 4, no flags at all) would silently inherit an earlier
  # --picker round's picks and skip the six-stage growing animation --
  # step 4's entire payoff. fresh_start? plus clearing state on it is the fix.
  describe '.fresh_start?' do
    it 'is true for a bare invocation -- no --picker, no --extend' do
      expect(mod.fresh_start?(['doc-demo'])).to be true
    end

    it 'is false when --picker is present' do
      expect(mod.fresh_start?(['doc-demo', '--picker'])).to be false
    end

    it 'is false when --extend= is present' do
      expect(mod.fresh_start?(['doc-demo', '--extend=tradeoffs'])).to be false
    end
  end

  describe 'a bare re-run forgets persisted picks and starts the demo over' do
    let(:state_session) { "growing-doc-fresh-start-spec-#{Process.pid}" }

    around do |example|
      Dir.mktmpdir('growing_doc_fresh_start') do |dir|
        prev = ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR']
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = dir
        example.run
      ensure
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = prev
      end
    end

    it 'resolves to no extend keys on a plain re-run, even with picks persisted from an earlier --picker round' do
      StreamWeaver::University::Scripts::GrowingDocState.save(state_session, ['tradeoffs'])

      argv = [state_session]
      StreamWeaver::University::Scripts::GrowingDocState.clear(state_session) if mod.fresh_start?(argv)

      expect(mod.resolve_extend_keys(state_session, argv)).to eq([])
    end
  end

  describe 'the space form of --extend (round-6-class failure)' do
    it 'aborts loudly instead of silently ignoring the flag and reporting success' do
      expect { mod.run!(['doc-demo', '--extend', 'tradeoffs']) }
        .to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }
    end
  end

  # Round-8 UAT: a hand-written free-text section (not a canned EXTENSIONS
  # key) had nowhere to persist, so the next --picker round clobbered it
  # back out -- a live run lost a user's own Star Wars chart section this
  # way. custom_toc_entry/apply_custom_sections! are the extracted pieces,
  # testable with no canvas bridge involved, same as apply_extensions!.
  describe '.custom_toc_entry' do
    it "parses the id and title out of the section's own doc_section_header call" do
      dsl = 'doc_section_header "07", "Starwars — a custom chart", id: "starwars"'
      expect(mod.custom_toc_entry('starwars', dsl)).to eq(id: 'starwars', label: 'Starwars — a custom chart')
    end

    # A silently key-defaulted id could point the sidebar at an anchor the
    # section itself never declared, if the snippet used a DIFFERENT id --
    # a dead sidebar link in exactly the doc step 5 exists to show off the
    # nav of.
    it "uses the snippet's own id, even when it differs from the persisted key" do
      dsl = 'doc_section_header "07", "Starwars", id: "sw-chart"'
      expect(mod.custom_toc_entry('starwars', dsl)[:id]).to eq('sw-chart')
    end

    it 'falls back to the key itself (and its capitalized form) when the snippet has no doc_section_header call' do
      expect(mod.custom_toc_entry('starwars', 'md "just prose"')).to eq(id: 'starwars', label: 'Starwars')
    end
  end

  describe '.apply_custom_sections!' do
    it 'appends every custom section to the body and gives each a toc entry' do
      toc = []
      body = +''
      customs = { 'starwars' => 'doc_section_header "07", "Starwars", id: "starwars"' }

      mod.apply_custom_sections!(customs, toc, body)

      expect(body).to include(customs['starwars'])
      expect(toc).to eq([{ id: 'starwars', label: 'Starwars' }])
    end

    it 'applies multiple custom sections in order' do
      toc = []
      body = +''
      customs = { 'a' => 'doc_section_header "07", "A", id: "a"', 'b' => 'doc_section_header "08", "B", id: "b"' }

      mod.apply_custom_sections!(customs, toc, body)

      expect(toc.map { |t| t[:id] }).to eq(%w[a b])
    end
  end

  describe 'a custom section survives picker -> extend -> picker (round-8 UAT)' do
    let(:state_session) { "growing-doc-custom-spec-#{Process.pid}" }

    around do |example|
      Dir.mktmpdir('growing_doc_custom') do |dir|
        prev = ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR']
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = dir
        example.run
      ensure
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = prev
      end
    end

    it 'keeps a persisted custom section through a later canned --extend and another bare --picker round' do
      # Round 1: the user's free-text pick gets persisted via --add-custom.
      StreamWeaver::University::Scripts::GrowingDocState.save_custom(
        state_session, 'starwars', 'doc_section_header "07", "Starwars — a custom chart", id: "starwars"'
      )

      # Round 2: a canned --extend=tradeoffs pick, same session.
      extend_keys = mod.resolve_extend_keys(state_session, ['--extend=tradeoffs'])
      StreamWeaver::University::Scripts::GrowingDocState.save(state_session, extend_keys)

      # Round 3: a bare --picker round, re-passing neither flag.
      resolved_extend = mod.resolve_extend_keys(state_session, ['--picker'])
      resolved_custom = StreamWeaver::University::Scripts::GrowingDocState.load_custom(state_session)
      expect(resolved_extend).to eq(['tradeoffs'])
      expect(resolved_custom).to have_key('starwars')

      toc = []
      body = +''
      mod.apply_extensions!(resolved_extend, toc, body)
      mod.apply_custom_sections!(resolved_custom, toc, body)

      expect(body).to include('Starwars — a custom chart')
      expect(toc.map { |t| t[:id] }).to contain_exactly('tradeoffs', 'starwars')
    end
  end

  describe '.fresh_start? treats --add-custom like --extend (not a fresh start)' do
    it 'is false when --add-custom is present' do
      expect(mod.fresh_start?(['doc-demo', '--add-custom', 'starwars', '/tmp/snippet.rb'])).to be false
    end
  end

  describe '--add-custom (run!)' do
    let(:state_session) { "growing-doc-add-custom-spec-#{Process.pid}" }

    around do |example|
      Dir.mktmpdir('growing_doc_add_custom') do |dir|
        prev = ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR']
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = dir
        example.run
      ensure
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = prev
      end
    end

    it 'aborts loudly when the key or snippet file is missing' do
      expect { mod.run!([state_session, '--add-custom', 'starwars']) }
        .to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }
    end

    it 'aborts loudly when the snippet file does not exist' do
      expect { mod.run!([state_session, '--add-custom', 'starwars', '/no/such/file.rb']) }
        .to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }
    end

    # Persisted state is sticky -- every rebuild replays it, and the only
    # escape is --reset, which throws away every OTHER persisted pick too.
    # A syntax error must never make it into the file.
    it 'aborts loudly, and never persists, when the snippet is not valid Ruby' do
      Dir.mktmpdir('growing_doc_add_custom_snippet') do |snippet_dir|
        bad_snippet = File.join(snippet_dir, 'bad.rb')
        File.write(bad_snippet, 'doc_section_header "07", "Oops", id: "oops" do |')

        expect { mod.run!([state_session, '--add-custom', 'oops', bad_snippet]) }
          .to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }

        expect(StreamWeaver::University::Scripts::GrowingDocState.load_custom(state_session)).to eq({})
      end
    end
  end

  describe '.fresh_start? treats --finish as NOT a fresh start' do
    it 'is false when --finish is present, even with no other flag' do
      expect(mod.fresh_start?(['doc-demo', '--finish'])).to be false
    end
  end

  # Round-10 UAT: the co-edit picker's own last-pushed html has a submitted
  # form in it, and nothing re-pushes once "done" is chosen -- the pane is
  # left showing the canvas-wait adapter's own terminal "Submitted -- you
  # can close this window" screen instead of the document. --finish is the
  # loop's exit: one push of the finished document, no picker form, saved.
  describe '--finish (run!)' do
    let(:state_session) { "growing-doc-finish-spec-#{Process.pid}" }

    around do |example|
      Dir.mktmpdir('growing_doc_finish') do |dir|
        prev = ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR']
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = dir
        example.run
      ensure
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = prev
      end
    end

    def stub_bridge!(pushes)
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(port: nil)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        pushes << msg if msg[:type] == 'push'
        {}
      end
    end

    def capture_stdout
      original = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end

    it 'pushes the finished document exactly once, with no picker form -- even with nothing ever extended' do
      pushes = []
      stub_bridge!(pushes)

      mod.run!([state_session, '--finish'])

      # A single push proves growing did NOT replay -- a wrongly-true
      # `growing` would push once per stage (STAGES.length times) instead.
      expect(pushes.length).to eq(1)
      expect(pushes.first[:dsl]).to include('Terminal vs canvas') # section 01's own heading (COMPARE)
      expect(pushes.first[:dsl]).not_to include('radio_group')
    end

    it 'reaches the save branch, not the picker branch' do
      stub_bridge!([])

      captured = capture_stdout { mod.run!([state_session, '--finish']) }

      expect(captured).to match(/Saved/)
      expect(captured).not_to match(/canvas-wait/) # the picker branch's own message names it
    end

    it 'keeps everything already persisted -- does not wipe state the way a truly fresh run would' do
      StreamWeaver::University::Scripts::GrowingDocState.save(state_session, ['tradeoffs'])
      pushes = []
      stub_bridge!(pushes)

      mod.run!([state_session, '--finish'])

      expect(pushes.first[:dsl]).to include(mod::EXTENSIONS['tradeoffs'][:header])
      expect(StreamWeaver::University::Scripts::GrowingDocState.load(state_session)).to eq(['tradeoffs'])
    end
  end

  describe '--reset (run!)' do
    let(:state_session) { "growing-doc-reset-spec-#{Process.pid}" }

    around do |example|
      Dir.mktmpdir('growing_doc_reset') do |dir|
        prev = ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR']
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = dir
        example.run
      ensure
        ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = prev
      end
    end

    it 'clears persisted extend keys and returns without touching the canvas bridge' do
      StreamWeaver::University::Scripts::GrowingDocState.save(state_session, ['tradeoffs'])
      expect(StreamWeaver::Canvas::Client).not_to receive(:ensure_bridge_running)

      expect { mod.run!([state_session, '--reset']) }.to output(/cleared persisted extensions/).to_stdout

      expect(StreamWeaver::University::Scripts::GrowingDocState.load(state_session)).to eq([])
    end
  end
end
