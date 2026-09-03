# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
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
    before(:all) do
      source = File.read(SCRIPT_PATH)
                   .sub(/^StreamWeaver::University::Scripts::GrowingDoc\.run!\s*\z/, '')
      eval(source, TOPLEVEL_BINDING, SCRIPT_PATH) # rubocop:disable Security/Eval
    end

    let(:mod) { StreamWeaver::University::Scripts::GrowingDoc }

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
  end
end
