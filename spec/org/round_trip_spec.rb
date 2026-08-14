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
end
