# frozen_string_literal: true

require "stream_weaver"
require_relative "../../lib/stream_weaver/org/recording_context"
require_relative "../../lib/stream_weaver/org/writer"
require_relative "../../lib/stream_weaver/org/reader"
require "stream_weaver/university/demos"

RSpec.describe StreamWeaver::Org::RecordingContext do
  it "captures top-level components in source order" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      md "first"
      md "second"
    RUBY
    expect(ctx.components.map(&:class)).to eq([StreamWeaver::Components::Markdown, StreamWeaver::Components::Markdown])
    expect(ctx.components.map(&:content)).to eq(["first", "second"])
  end

  it "captures nested children inside a card" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      card do
        card_header "Title", badge: "1"
        card_body do
          md "body text"
        end
      end
    RUBY
    card = ctx.components.first
    expect(card).to be_a(StreamWeaver::Components::Card)
    header, body = card.children
    expect(header.content).to eq("Title")
    expect(header.badge).to eq("1")
    expect(body.children.first.content).to eq("body text")
  end

  it "captures comparison before/after children separately" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      comparison(before_label: "Old", after_label: "New") do
        before { md "old text" }
        after { md "new text" }
      end
    RUBY
    comparison = ctx.components.first
    expect(comparison.before_children.first.content).to eq("old text")
    expect(comparison.after_children.first.content).to eq("new text")
  end

  it "captures a table component without crashing (table's DSL method always calls #state/#render_state, even for static headers/rows tables)" do
    ctx = described_class.new
    ctx.instance_eval(%(table(headers: ["A"], rows: [["1"]])\n))
    expect(ctx.components.first).to be_a(StreamWeaver::Components::Table)
  end

  it "does not crash on a real saved doc's leading use_theme/use_layout lines (DocStore.dsl_with_metadata prepends these to every real Save-as-doc output)" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      use_theme :doc
      use_layout :full
      md "hello"
    RUBY
    expect(ctx.components.first.content).to eq("hello")
  end

  # Save-as-Org used to die with `undefined method 'radio_group' for an
  # instance of StreamWeaver::Org::RecordingContext` on any session whose
  # DSL carried a form -- which the University step-4 doc-demo session does
  # by design (the blocking picker is pushed into the same session as the
  # document). This context includes DisplayDSL only, so App's entire
  # interactive vocabulary was a NoMethodError waiting to happen mid-save.
  #
  # The rule: this context tolerates EVERY call the DSL can make, and the
  # Writer decides what to do with the ones it has no component for.
  describe "calls it has no component for" do
    it "records a placeholder naming the call, instead of raising" do
      ctx = described_class.new
      ctx.instance_eval(%(radio_group :section, ["a", "b"]\n))
      expect(ctx.components.first).to be_a(described_class::UnsupportedCall)
      expect(ctx.components.first.name).to eq(:radio_group)
    end

    it "records the same placeholder for a call that is not a control -- what to do with it is the Writer's call" do
      ctx = described_class.new
      ctx.instance_eval(%(bar_chart labels: ["a"], values: [1]\n))
      expect(ctx.components.first).to be_a(described_class::UnsupportedCall)
      expect(ctx.components.first.name).to eq(:bar_chart)
    end

    # A container's children are part of the control being recorded: running
    # the block would strew fragments of a form through the component tree
    # (and, for a non-interactive call, duplicate what raw_passthrough
    # already recovers verbatim from the statement's own source).
    it "does not evaluate the block of a call it cannot build" do
      ctx = described_class.new
      ctx.instance_eval(<<~RUBY)
        form :picker do
          md "this belongs to the form, not the document"
        end
      RUBY
      expect(ctx.components.map(&:class)).to eq([described_class::UnsupportedCall])
    end

    # `select` is the trap in this family: it IS defined (on DisplayDSL), so
    # method_missing never sees it -- it writes straight to @_state, which
    # this context has to set up or the save dies on `nil[]=` instead.
    it "builds a select without tripping over DisplayDSL's @_state" do
      ctx = described_class.new
      ctx.instance_eval(%(select :env, ["dev", "prod"]\n))
      expect(ctx.components.first).to be_a(StreamWeaver::Components::Select)
    end

    # Answering Ruby's implicit-conversion probes with a nil placeholder
    # turns a harmless duck-type check into a TypeError somewhere far away.
    it "still raises for implicit-conversion probes" do
      expect { described_class.new.to_ary }.to raise_error(NoMethodError)
      expect(described_class.new).not_to respond_to(:to_ary)
    end
  end

  describe "what Org::Writer does with them" do
    def write(dsl)
      StreamWeaver::Org::Writer.from_dsl(dsl)
    end

    def coverage_for(dsl)
      writer = StreamWeaver::Org::Writer.new(dsl)
      writer.call
      writer.coverage
    end

    let(:form_dsl) do
      <<~RUBY
        md "Pick one."
        radio_group :section, ["a", "b"]
        select :env, ["dev", "prod"]
        text_field :describe, placeholder: "e.g. ..."
        button "Add it"
      RUBY
    end

    it "converts a doc carrying a form instead of raising NoMethodError" do
      expect { write(form_dsl) }.not_to raise_error
    end

    it "drops each control, leaving an org keyword breadcrumb where it was" do
      org = write(form_dsl)
      expect(org).to include("#+STREAMWEAVER_OMITTED: radio_group")
      expect(org).to include("#+STREAMWEAVER_OMITTED: text_field")
      # button and select are real components (DisplayDSL builds them), so
      # their breadcrumb comes from the component class, not a call name.
      expect(org).to include("#+STREAMWEAVER_OMITTED: button")
      expect(org).to include("#+STREAMWEAVER_OMITTED: select")
    end

    it "leaves no dead control source behind, and keeps the document around it" do
      org = write(form_dsl)
      expect(org).to include("Pick one.")
      expect(org).not_to include("radio_group :section")
      expect(org).not_to include("text_field :describe")
      expect(org).not_to include(":streamweaver-raw t")
    end

    it "counts dropped controls as omitted -- not recognized, not passthrough" do
      expect(coverage_for(form_dsl))
        .to eq(total: 5, recognized: 1, passthrough_verbatim: 0, passthrough_lossy: 0, omitted: 4)
    end

    # The breadcrumb is an org keyword line, not a `# comment`, precisely so
    # Org::Reader's PREAMBLE_RE already skips it -- a comment line would come
    # back as an `md "#..."` call and render as a stray heading.
    it "does not reappear as prose when the org is read back" do
      dsl = StreamWeaver::Org::Reader.to_dsl(write(form_dsl))
      expect(dsl).to include("Pick one.")
      expect(dsl).not_to include("STREAMWEAVER_OMITTED")
      expect { RubyVM::InstructionSequence.compile(dsl) }.not_to raise_error
    end

    it "drops a form container whole, as one omission" do
      org = write(<<~RUBY)
        form :picker do
          text_field :name
          submit "Go"
        end
      RUBY
      expect(org.scan("#+STREAMWEAVER_OMITTED").length).to eq(1)
      expect(org).to include("#+STREAMWEAVER_OMITTED: form")
    end

    # Charts, layout shells and the rest are not controls -- there is nothing
    # dishonest about keeping their source, and raw passthrough is what makes
    # them survive the org -> DSL round trip.
    it "raw-passes-through a non-interactive App-only call, verbatim" do
      dsl = %(bar_chart labels: ["a"], values: [1]\n)
      expect(write(dsl)).to include("bar_chart labels:")
      expect(coverage_for(dsl))
        .to eq(total: 1, recognized: 0, passthrough_verbatim: 1, passthrough_lossy: 0, omitted: 0)
    end

    it "does not raise on a call no version of the DSL defines" do
      expect { write(%(some_component_from_the_future "x"\n)) }.not_to raise_error
    end
  end

  # The standing guarantee behind Save-as-Org: whatever a University step
  # pushes at a session, saving that session as .org must not crash.
  describe "every University demo body" do
    before(:all) do
      path = StreamWeaver::University::Demos.path("doc")
      original = File.read(path)
      source = original.sub(/^StreamWeaver::University::Scripts::GrowingDoc\.run!\s*\z/, "")
      # If growing_doc.rb ever grows a line after its `run!`, that sub
      # silently no-ops and this eval BOOTS THE DEMO (bridge push and all)
      # inside the suite. Fail loudly instead of hanging on a canvas push.
      raise "growing_doc.rb no longer ends with its run! line -- refusing to eval it" if source == original

      eval(source, TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
      require "stream_weaver/university/demos/dashboard"
      require "stream_weaver/university/demos/decision_form"
    end

    let(:growing_doc) { StreamWeaver::University::Scripts::GrowingDoc }

    def coverage_for(dsl)
      writer = StreamWeaver::Org::Writer.new(dsl)
      writer.call
      writer.coverage
    end

    # counter.rb is `app "Counter" do ... end.run!` at the top level -- it
    # cannot be required (that boots a server), so its DSL body is read out
    # of the file, the same way demos_spec reads its line count.
    def counter_body
      lines = File.readlines(StreamWeaver::University::Demos.path("counter"))
      first = lines.index { |l| l.start_with?('app "Counter"') } + 1
      lines[first...lines.index { |l| l.start_with?("end.run!") }].join
    end

    def document_body
      toc = []
      body = +""
      growing_doc::STAGES.each { |s| toc << s[:toc] if s[:toc]; body << s[:dsl] << "\n" }
      growing_doc.document(toc, body)
    end

    def demo_bodies
      bodies = {
        "counter" => counter_body,
        "decision-form standalone" => StreamWeaver::University::Demos::DecisionForm.standalone_dsl,
        "decision-form canvas" => StreamWeaver::University::Demos::DecisionForm.canvas_dsl,
        "doc" => document_body,
        "doc + picker" => "#{document_body}\n#{growing_doc.picker_dsl}",
        "picker" => growing_doc.picker_dsl
      }
      StreamWeaver::University::Demos::Dashboard::SNAPSHOTS.each_index do |i|
        bodies["dashboard snapshot #{i}"] = StreamWeaver::University::Demos::Dashboard.dsl(i)
      end
      growing_doc::EXTENSIONS.each { |key, ext| bodies["extension #{key}"] = ext[:dsl] }
      bodies
    end

    it "converts to org without raising" do
      demo_bodies.each do |name, dsl|
        expect { StreamWeaver::Org::Writer.from_dsl(dsl) }
          .not_to raise_error, "#{name} does not survive Save-as-Org"
      end
    end

    # The live bug, verbatim: the doc-demo session holds step 4's document
    # AND the blocking picker form pushed on top of it.
    it "keeps the whole document when the step-4 picker is pushed on top of it" do
      with_picker = coverage_for("#{document_body}\n#{growing_doc.picker_dsl}")
      expect(with_picker[:omitted]).to eq(3) # radio_group, text_field, button
      expect(with_picker[:passthrough_lossy]).to eq(0)
      expect(with_picker[:recognized]).to eq(with_picker[:total] - 3)
    end

    # Regression for the format's own promise: nothing about the form
    # handling may cost the pure document any fidelity.
    it "still exports the pure document with zero passthrough and zero omissions" do
      coverage = coverage_for(document_body)
      expect(coverage).to include(passthrough_verbatim: 0, passthrough_lossy: 0, omitted: 0)
      expect(coverage[:recognized]).to eq(coverage[:total])
    end
  end
end
