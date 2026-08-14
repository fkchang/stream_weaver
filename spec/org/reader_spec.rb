# frozen_string_literal: true

require "timeout"
require_relative "../../lib/stream_weaver/org/reader"

RSpec.describe StreamWeaver::Org::Reader do
  describe ".chunks (private, tested via send — internal structure worth locking down)" do
    it "splits headline, quote, table, src, and paragraph chunks" do
      org = <<~ORG
        * 00 Summary
        :PROPERTIES:
        :CUSTOM_ID: summary
        :END:

        #+begin_quote
        *⚠️ Title*
        body
        #+end_quote

        | A | B |
        |---|---|
        | 1 | 2 |

        #+begin_src text
        code
        #+end_src

        plain paragraph text
      ORG

      chunks = described_class.new(org).send(:chunks)
      expect(chunks.map { |c| c[:type] }).to eq(%i[headline quote table src paragraph])
      expect(chunks[0][:depth]).to eq(1)
      expect(chunks[0][:number]).to eq("00")
      expect(chunks[0][:title]).to eq("Summary")
      expect(chunks[0][:custom_id]).to eq("summary")
    end
  end

  describe "malformed input safety (the infinite-loop regression)" do
    it "raises rather than hanging on an unterminated src block" do
      expect do
        Timeout.timeout(5) { described_class.to_dsl("#+begin_src text\nfoo\n") }
      end.to raise_error(ArgumentError)
    end

    it "raises rather than hanging on an unterminated quote block" do
      expect do
        Timeout.timeout(5) { described_class.to_dsl("#+begin_quote\nfoo\n") }
      end.to raise_error(ArgumentError)
    end
  end

  it "converts a paragraph chunk to an md call with markdown inline syntax restored" do
    dsl = described_class.to_dsl("hello *world*\n")
    expect(dsl).to include('md <<~MD')
    expect(dsl).to include("hello **world**")
  end

  it "converts a table chunk to a table call with markdown: true, inline conversion applied to cells" do
    org = <<~ORG
      | A | B |
      |---|---|
      | *x* | 2 |
    ORG
    dsl = described_class.to_dsl(org)
    expect(dsl).to include('markdown: true')
    expect(dsl).to include('headers: ["A", "B"]')
    expect(dsl).to include('["**x**", "2"]')
  end

  it "parses the doc_header preamble quote block (title, eyebrow, and variant-tagged pills)" do
    org = <<~ORG
      #+STREAMWEAVER_DSL: 1
      #+TITLE: My Report

      #+begin_quote
      /Team · Project/
      *[warn] Draft* · 2026-08-13
      #+end_quote

      * 00 Summary
      :PROPERTIES:
      :CUSTOM_ID: summary
      :END:
    ORG
    dsl = described_class.to_dsl(org)
    expect(dsl).to include('title: "My Report"')
    expect(dsl).to include('eyebrow: "Team · Project"')
    expect(dsl).to include('{ text: "Draft", variant: :warn }')
    expect(dsl).to include('"2026-08-13"')
    expect(dsl.scan(/doc_header\(/).length).to eq(1)
    # Confirms the preamble-leak fix: no stray literal md call for the
    # #+STREAMWEAVER_DSL:/#+TITLE: lines themselves.
    expect(dsl.scan(/md <<~MD/).length).to eq(0)
  end

  it "keeps a multi-paragraph prose block as ONE md call, not split on its internal blank line" do
    org = <<~ORG
      This is paragraph one.

      This is paragraph two.
    ORG
    dsl = described_class.to_dsl(org)
    expect(dsl.scan(/md <<~MD/).length).to eq(1)
    expect(dsl).to include("This is paragraph one.")
    expect(dsl).to include("This is paragraph two.")
  end

  it "still splits two components separated by a real structural boundary (not just a blank line)" do
    org = <<~ORG
      First paragraph.

      * 00 Section
      :PROPERTIES:
      :CUSTOM_ID: sec
      :END:

      Second paragraph after a real section boundary.
    ORG
    dsl = described_class.to_dsl(org)
    expect(dsl.scan(/md <<~MD/).length).to eq(2)
  end

  it "preserves markdown: false on a table marked with #+ATTR_STREAMWEAVER: :markdown nil, without reinterpreting literal characters as emphasis" do
    org = <<~ORG
      #+ATTR_STREAMWEAVER: :markdown nil
      | Hypothesis |
      |---|
      | 5 min *after* the 10:28 failure |
    ORG
    dsl = described_class.to_dsl(org)
    expect(dsl).not_to include("markdown: true")
    expect(dsl).to include('"5 min *after* the 10:28 failure"')
  end

  it "does not leak an ATTR_STREAMWEAVER marker onto a later, unrelated table separated by a paragraph" do
    org = <<~ORG
      #+ATTR_STREAMWEAVER: :markdown nil

      Just a plain paragraph, not a table at all.

      | A |
      |---|
      | *should convert normally, unaffected* |
    ORG
    dsl = described_class.to_dsl(org)
    expect(dsl).to include("markdown: true")
    expect(dsl).to include('"**should convert normally, unaffected**"')
  end

  it "parses a reserved-emoji quote block as a callout, even with no headline anywhere in the document" do
    org = "#+begin_quote\n*⚠️ Heads up*\nbody text\n#+end_quote\n"
    dsl = described_class.to_dsl(org)
    expect(dsl).to include('callout(variant: :warning, title: "Heads up")')
    expect(dsl).not_to include("doc_header(") # the regression this test guards against
  end

  it "parses a bracket-badge quote block as a card, even with no headline anywhere in the document" do
    org = "#+begin_quote\n*[1] Title* /(note)/\nBody.\n#+end_quote\n"
    dsl = described_class.to_dsl(org)
    expect(dsl).to include("card do")
    expect(dsl).to include('badge: "1"')
    expect(dsl).not_to include("doc_header(")
  end

  it "parses two consecutive before/after quote blocks as a comparison, even with no headline anywhere in the document" do
    org = "#+begin_quote\n*◀ Before — Old*\nold\n#+end_quote\n#+begin_quote\n*▶ After — New*\nnew\n#+end_quote\n"
    dsl = described_class.to_dsl(org)
    expect(dsl).to include('comparison(')
    expect(dsl).to include('before_label: "Old"')
    expect(dsl).to include('after_label: "New"')
  end

  it "recognizes a src block nested inside a card's quote body, instead of flattening it into one md call" do
    org = <<~ORG
      #+begin_quote
      *Pipeline* /(team · service)/
      Some intro text.
      #+begin_src mermaid :zoom t
      graph LR
        A --> B
      #+end_src
      Some trailing text.
      #+end_quote
    ORG
    dsl = described_class.to_dsl(org)
    expect(dsl).to include("mermaid <<~MERMAID")
    expect(dsl).to include("A --> B")
    expect(dsl).to include("Some intro text")
    expect(dsl).to include("Some trailing text")
  end
end
