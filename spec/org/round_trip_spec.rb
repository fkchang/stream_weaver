# frozen_string_literal: true

require "stream_weaver"
require_relative "../../lib/stream_weaver/canvas/reader"
require_relative "../../lib/stream_weaver/org/writer"
require_relative "../../lib/stream_weaver/org/reader"

RSpec.describe "org round trip" do
  let(:original_dsl) { eval(File.read(File.join(__dir__, "../fixtures/org/sample_doc.rb"))) } # rubocop:disable Security/Eval

  # Components::Mermaid#diagram_id embeds Ruby's object_id ("sw-mermaid-#{object_id}"),
  # which is never the same across two separate renders of even identical DSL text --
  # confirmed by rendering the same DSL twice and diffing. This is unrelated to
  # Writer/Reader correctness, so it must be normalized out before comparing, or
  # this spec fails deterministically regardless of how correct the round-trip is.
  def normalize_ids(html)
    html.gsub(/sw-mermaid-\d+/, "sw-mermaid-ID")
  end

  it "rb -> org -> rb renders equivalent output to the original" do
    org = StreamWeaver::Org::Writer.from_dsl(original_dsl)
    regenerated_dsl = StreamWeaver::Org::Reader.to_dsl(org)

    expect { RubyVM::InstructionSequence.compile(regenerated_dsl) }.not_to raise_error

    original_html    = StreamWeaver::Canvas::Reader.render_dsl(original_dsl)
    regenerated_html = StreamWeaver::Canvas::Reader.render_dsl(regenerated_dsl)

    expect(original_html).not_to include("DSL error")
    expect(regenerated_html).not_to include("DSL error")
    expect(normalize_ids(regenerated_html)).to eq(normalize_ids(original_html))
  end

  it "org -> rb -> org is stable on already-canonical (Writer-generated) org text" do
    org = StreamWeaver::Org::Writer.from_dsl(original_dsl)
    round_tripped_dsl = StreamWeaver::Org::Reader.to_dsl(org)
    org_again = StreamWeaver::Org::Writer.from_dsl(round_tripped_dsl)
    expect(org_again).to eq(org)
  end

  it "org -> rb -> org settles into a stable canonical form on genuinely hand-typed org text" do
    # Unlike the example above (Writer-generated org, already in canonical
    # form), this is text a human editing the format directly would actually
    # write: inconsistent table column padding, no doc_header/preamble at
    # all, ordinary prose -- the Reader needs to be robust to this kind of
    # variance, not just its own Writer's exact output shape.
    hand_typed = <<~ORG
      * 00 Notes
      :PROPERTIES:
      :CUSTOM_ID: notes
      :END:

      A quick note before the table.

      #+begin_quote
      *✅ Looks good*
      Reviewed and approved.
      #+end_quote

      | Name | Status |
      |---|------|
      | Alice | done |
      | Bob | *pending* |
    ORG

    dsl = StreamWeaver::Org::Reader.to_dsl(hand_typed)
    expect { RubyVM::InstructionSequence.compile(dsl) }.not_to raise_error

    org_once = StreamWeaver::Org::Writer.from_dsl(dsl)
    dsl_again = StreamWeaver::Org::Reader.to_dsl(org_once)
    org_twice = StreamWeaver::Org::Writer.from_dsl(dsl_again)

    expect(org_twice).to eq(org_once)
  end

  it "renders a standard external org link inside a table cell as a real link, not literal brackets" do
    # stream_weaver-043f: reported live in a table cell specifically --
    # emit_table calls Inline.org_to_md per cell by default, and the old
    # #anchor-only LINK_ORG regex left an external link like this as
    # literal, unclickable brackets in the rendered output.
    hand_typed = <<~ORG
      * 00 Notes
      :PROPERTIES:
      :CUSTOM_ID: notes
      :END:

      | Concept | Detail | Watch |
      |---|---|---|
      | Grip break | Rotate wrist | [[https://example.com/watch?v=X&t=354s][5:54]] |
    ORG

    dsl = StreamWeaver::Org::Reader.to_dsl(hand_typed)
    expect { RubyVM::InstructionSequence.compile(dsl) }.not_to raise_error

    html = StreamWeaver::Canvas::Reader.render_dsl(dsl)
    expect(html).not_to include("[[https://example.com")
    expect(html).to match(%r{href=['"]https://example\.com/watch\?v=X&(?:amp;)?t=354s['"]})

    # And it's stable under a second round trip, same as the plain-table case above.
    org_once = StreamWeaver::Org::Writer.from_dsl(dsl)
    dsl_again = StreamWeaver::Org::Reader.to_dsl(org_once)
    org_twice = StreamWeaver::Org::Writer.from_dsl(dsl_again)
    expect(org_twice).to eq(org_once)
  end

  it "round-trips a doc_header with no eyebrow, only plain pills, without crashing or losing data" do
    # Regression: the final full-branch review found this crashed with
    # "ArgumentError: malformed card header" -- a doc_header without an
    # eyebrow used to be undetectable from the eyebrow-only shape check,
    # so its pills line fell through to the card-marker parser instead.
    original_dsl = <<~RUBY
      doc_header(title: "Sample Report", pills: ["Draft", "2026-08-13"])
      doc_section_header "00", "Overview", id: "overview"
    RUBY

    org = StreamWeaver::Org::Writer.from_dsl(original_dsl)
    regenerated_dsl = StreamWeaver::Org::Reader.to_dsl(org)

    expect { RubyVM::InstructionSequence.compile(regenerated_dsl) }.not_to raise_error

    original_html    = StreamWeaver::Canvas::Reader.render_dsl(original_dsl)
    regenerated_html = StreamWeaver::Canvas::Reader.render_dsl(regenerated_dsl)

    expect(original_html).not_to include("DSL error")
    expect(regenerated_html).not_to include("DSL error")
    expect(regenerated_html).to eq(original_html)
  end

  # Round 2 of the final full-branch review found the fix above was too
  # narrow: it only tested a single, non-variant-tagged pill. A doc_header
  # with no eyebrow whose pills mix in variant tags renders as syntactically
  # valid card-marker text (e.g. "*[warn] Draft* · *[success] v2*"), which
  # crashed or silently corrupted data via the card-marker parser -- the
  # exact same failure class the fix above was meant to close. Fixed by
  # switching doc_header detection from content shape to chunk position
  # (Writer never emits body content before doc_header's own block).
  it "round-trips a doc_header with no eyebrow whose FIRST pill is variant-tagged, without crashing" do
    original_dsl = <<~RUBY
      doc_header(title: "T", pills: [{ text: "Draft", variant: :warn }, "Q3 2026"])
      doc_section_header "00", "Overview", id: "overview"
    RUBY

    org = StreamWeaver::Org::Writer.from_dsl(original_dsl)
    regenerated_dsl = StreamWeaver::Org::Reader.to_dsl(org)
    expect { RubyVM::InstructionSequence.compile(regenerated_dsl) }.not_to raise_error

    original_html    = StreamWeaver::Canvas::Reader.render_dsl(original_dsl)
    regenerated_html = StreamWeaver::Canvas::Reader.render_dsl(regenerated_dsl)
    expect(regenerated_html).not_to include("DSL error")
    expect(regenerated_html).to eq(original_html)
  end

  it "round-trips a doc_header with no eyebrow whose LAST pill is variant-tagged (the shape that fully matches a card marker regex), without corrupting the title text" do
    original_dsl = <<~RUBY
      doc_header(title: "T", pills: [{ text: "Draft", variant: :warn }, { text: "v2", variant: :success }])
      doc_section_header "00", "Overview", id: "overview"
    RUBY

    org = StreamWeaver::Org::Writer.from_dsl(original_dsl)
    regenerated_dsl = StreamWeaver::Org::Reader.to_dsl(org)
    expect { RubyVM::InstructionSequence.compile(regenerated_dsl) }.not_to raise_error
    expect(regenerated_dsl).not_to include("card do") # must not be misclassified as a card

    original_html    = StreamWeaver::Canvas::Reader.render_dsl(original_dsl)
    regenerated_html = StreamWeaver::Canvas::Reader.render_dsl(regenerated_dsl)
    expect(regenerated_html).not_to include("DSL error")
    expect(regenerated_html).to eq(original_html)
  end

  it "round-trips a top-level component outside the doc-builder vocabulary via genuine verbatim source recovery, not a lossy placeholder" do
    # Regression: bin/org_uat run against real saved docs found this --
    # header1 (a generic canvas component, not part of the :doc-theme
    # vocabulary) used to come back as a fake code_block(...) call
    # (Prism.js CSS/JS injected, original title text replaced by a
    # "# unrecognized component" comment) instead of the original title
    # rendering at all.
    original_dsl = <<~RUBY
      header1 "Save as doc button"
      md "Some prose."
    RUBY

    org = StreamWeaver::Org::Writer.from_dsl(original_dsl)
    regenerated_dsl = StreamWeaver::Org::Reader.to_dsl(org)
    expect { RubyVM::InstructionSequence.compile(regenerated_dsl) }.not_to raise_error
    expect(regenerated_dsl).to include('header1 "Save as doc button"')
    expect(regenerated_dsl).not_to include("code_block(")

    original_html    = StreamWeaver::Canvas::Reader.render_dsl(original_dsl)
    regenerated_html = StreamWeaver::Canvas::Reader.render_dsl(regenerated_dsl)
    expect(regenerated_html).not_to include("DSL error")
    expect(regenerated_html).to eq(original_html)
  end

  it "documents the residual known limitation gracefully: a title-only doc_header immediately followed by a real standalone card (no eyebrow/pills block to anchor position on) gets misclassified as doc_header pills, but does not crash, hang, or produce invalid Ruby" do
    original_dsl = <<~RUBY
      doc_header(title: "T")
      card do
        card_header "Real Card"
        card_body { md "hi" }
      end
    RUBY

    org = StreamWeaver::Org::Writer.from_dsl(original_dsl)
    regenerated_dsl = StreamWeaver::Org::Reader.to_dsl(org)
    expect { RubyVM::InstructionSequence.compile(regenerated_dsl) }.not_to raise_error
    expect { StreamWeaver::Canvas::Reader.render_dsl(regenerated_dsl) }.not_to raise_error
  end
end
