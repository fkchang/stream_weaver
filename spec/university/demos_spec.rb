# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver'
require 'stream_weaver/university/demos'
require 'stream_weaver/org/writer'

# The canned-artifacts rule (round-5 UAT, 2026-09-03): every course demo
# ships finished inside the gem, so a worker session runs it instead of
# composing one live and never needs a checkout of this repo. These specs
# are the standing proof that each one still parses and renders.
RSpec.describe StreamWeaver::University::Demos do
  describe '.path' do
    it 'resolves every registered name to a file that exists in the gem' do
      described_class::NAMES.each do |name|
        path = described_class.path(name)
        expect(path).to be_a(String), "no path registered for #{name}"
        expect(File.exist?(path)).to be(true), "#{name} points at a missing file: #{path}"
        expect(path).to start_with(File.expand_path('../../lib', __dir__))
      end
    end

    it 'accepts underscores, hyphens and case for the same demo' do
      expect(described_class.path('decision_form')).to eq(described_class.path('decision-form'))
      expect(described_class.path('Decision Form')).to eq(described_class.path('decision-form'))
    end

    it 'returns nil for an unknown demo' do
      expect(described_class.path('nope')).to be_nil
    end

    it 'covers the four steps that have a canned artifact' do
      expect(described_class::NAMES).to contain_exactly('dashboard', 'counter', 'decision-form', 'doc')
    end
  end

  # Step 1. A push script rather than three DSL files: the DSL is rendered
  # inside the bridge process, so a file cannot read the caller's ENV, and
  # three near-identical files would be three places for the layout to drift.
  describe 'dashboard' do
    before { require 'stream_weaver/university/demos/dashboard' }

    let(:mod) { StreamWeaver::University::Demos::Dashboard }

    it 'ships three snapshots of one layout, so a re-push reads as new data' do
      expect(mod::SNAPSHOTS.length).to eq(3)
      labels = mod::SNAPSHOTS.map { |s| s[:tiles].map { |t| t[:label] } }
      expect(labels.uniq.length).to eq(1)
      values = mod::SNAPSHOTS.map { |s| s[:tiles].map { |t| t[:value] } }
      expect(values.uniq.length).to eq(3)
    end

    it 'renders every snapshot to HTML without raising' do
      mod::SNAPSHOTS.each_index do |i|
        html = StreamWeaver::CLI.render_dsl_to_html(mod.dsl(i), session_name: 'demo-smoke')
        expect(html).to include('sw-stat-value')
      end
    end

    it 'carries stat tiles, an explicit chart and a mermaid diagram in one push' do
      dsl = mod.dsl(0)
      expect(dsl).to include('stat_display')
      expect(dsl).to include('chart type: :bar')
      expect(dsl).to include('mermaid')
    end

    # The pane is ~750-800px (context.md, "Pane-width rule") and .sw-columns
    # only stacks below 640px, so four tiles across one row is unreadable.
    it 'lays the four tiles out 2x2 rather than 1x4' do
      expect(mod.dsl(0).scan(/^columns 2 do$/).length).to eq(2)
    end

    # disc-094 plus the 51beb6c bridge fix: the shorthand family renders
    # through Alpine x-init and is dropped on export; the explicit form is
    # the one that survives a bridge poll swap.
    it 'never reaches for a chart shorthand' do
      %w[bar_chart hbar_chart line_chart area_chart pie_chart doughnut_chart
         stacked_bar_chart sparkline].each do |shorthand|
        mod::SNAPSHOTS.each_index { |i| expect(mod.dsl(i)).not_to include(shorthand) }
      end
    end
  end

  # Step 2. Verbatim, because two real worker sessions each lost a debug
  # cycle to the "six-line app" framing hiding one of these two lines.
  describe 'counter' do
    let(:source) { File.read(described_class.path('counter')) }
    let(:code) { source.lines[0..source.lines.index { |l| l.start_with?('end.run!') }] }

    it 'is a runnable file that keeps both lines the six-line framing hides' do
      expect(source).to include("require 'stream_weaver'")
      expect(source).to include('end.run!')
    end

    # Round-6 UAT: the app introduces itself with a callout the moment it
    # opens, so the file grew by one line -- "six lines in an eight-line
    # file" (unchanged content, unchanged claim) plus a ninth, the callout,
    # which is deliberately not part of that count.
    it 'is the same six-line mechanism in an eight-line core, plus one caption line' do
      expect(code.length).to eq(9)
      mechanism = code.select do |line|
        line.match?(/^\s*(state\[|header1 |text "Count|button\("\+1|app "Counter"|end\.run!)/)
      end
      expect(mechanism.length).to eq(6)
    end

    # Deliberately no line count in the callout's own text: the callout is
    # aimed at whoever tabs over before the narration explains anything, and
    # a stale count in it would repeat the exact "six-line app" framing trap
    # this step spends its narration warning about.
    it 'introduces itself on screen with a callout that names no stale line count' do
      expect(source).to match(/callout "This whole app is the file your agent just ran/)
      expect(source.lines.find { |l| l.include?('callout "This whole app') }).not_to match(/\d+ lines?/)
    end

    it 'parses' do
      expect { RubyVM::InstructionSequence.compile(source) }.not_to raise_error
    end
  end

  # Step 3. ONE artifact, two surfaces -- that identity is the lesson, so a
  # spec holds the two modes to the same question and the same inputs.
  describe 'decision_form' do
    before { require 'stream_weaver/university/demos/decision_form' }

    let(:mod) { StreamWeaver::University::Demos::DecisionForm }

    it 'builds both surfaces from the same context and the same inputs' do
      expect(mod.standalone_dsl).to include(mod::CONTEXT)
      expect(mod.standalone_dsl).to include(mod::FORM)
      expect(mod.canvas_dsl).to include(mod::CONTEXT)
      expect(mod.canvas_dsl).to include(mod::FORM)
    end

    it 'renders both surfaces to HTML without raising' do
      [mod.standalone_dsl, mod.canvas_dsl].each do |dsl|
        html = StreamWeaver::CLI.render_dsl_to_html(dsl, session_name: 'decision-smoke')
        expect(html).to include('rationale')
      end
    end

    it 'carries the diagram and the comparison table a terminal prompt cannot' do
      expect(mod::CONTEXT).to include('mermaid')
      expect(mod::CONTEXT).to include('table')
    end

    # disc-098 / disc-105: checkbox_group and multi chip_group harvest the
    # wrong values back through canvas-wait.
    it 'uses only radio_group and text_field for input' do
      expect(mod::FORM).to include('radio_group')
      expect(mod::FORM).to include('text_field')
      expect(mod::FORM).not_to match(/checkbox_group|chip_group/)
    end

    # The canvas surface has no terminal next to it to say "I am blocked";
    # the standalone surface's own run_once! banner already does.
    it 'only the canvas surface carries the blocking callout and a submit button' do
      expect(mod.canvas_dsl).to include('callout')
      expect(mod.canvas_dsl).to include('button "Submit decision"')
      expect(mod.standalone_dsl).not_to include('button')
    end
  end

  # Step 4's co-edit loop. Every option has to be a component the org writer
  # recognizes natively -- a timeline or a kpi_dashboard would look fine in
  # the pane and then leave as an unrecognized placeholder, which is exactly
  # what step 5 exists to disprove.
  describe 'doc extensions' do
    before(:all) do
      path = StreamWeaver::University::Demos.path('doc')
      source = File.read(path).sub(/^StreamWeaver::University::Scripts::GrowingDoc\.run!\s*\z/, '')
      eval(source, TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
    end

    let(:mod) { StreamWeaver::University::Scripts::GrowingDoc }

    def base_document
      toc = []
      body = +''
      mod::STAGES.each { |s| toc << s[:toc] if s[:toc]; body << s[:dsl] << "\n" }
      [toc, body]
    end

    it 'offers three or more canned sections plus a free-text escape' do
      expect(mod::EXTENSIONS.length).to be >= 3
      expect(mod.picker_dsl).to include('text_field :describe')
      expect(mod.picker_dsl).to match(/\*\*done\*\* -- the doc is finished/)
    end

    # Round-6 UAT bug: the picker's radio VALUE used to be a human label
    # ("tradeoffs -- A before/after comparison ..."), and `--extend`
    # expected the bare EXTENSIONS key -- a worker had to parse one out of
    # the other, got it wrong, and the doc silently never grew. Single
    # source of truth: the radio choices are exactly EXTENSIONS.keys (plus
    # "done"), so the submitted value already IS a valid --extend key with
    # nothing left to parse.
    it 'presents the picker radio choices as exactly the --extend keys, with no parsing needed' do
      choices = mod::EXTENSIONS.keys + ['done']
      expect(mod.picker_dsl).to include("radio_group :section, #{choices.inspect}")
    end

    it 'documents every extension key in a legend above the radio choices' do
      mod::EXTENSIONS.each_key { |key| expect(mod.picker_dsl).to include("**#{key}**") }
    end

    it 'org-exports cleanly with any one extension appended' do
      toc, body = base_document
      mod::EXTENSIONS.each do |key, ext|
        dsl = mod.document(toc + [{ id: key, label: ext[:header] }], body + ext[:dsl] + "\n")
        writer = StreamWeaver::Org::Writer.new(dsl)
        writer.call
        expect(writer.coverage).to include(passthrough_verbatim: 0, passthrough_lossy: 0),
                                   "extension #{key} does not survive org-export"
      end
    end

    it 'renders the picker form on top of the finished document' do
      toc, body = base_document
      html = StreamWeaver::CLI.render_dsl_to_html(
        "#{mod.document(toc, body)}\n#{mod.picker_dsl}", session_name: 'doc-smoke'
      )
      expect(html).to include('section')
    end

    it 'saves under a deterministic name step 5 can find without asking' do
      expect(mod::DEFAULT_DOC_NAME).to eq('university-doc')
    end
  end
end
