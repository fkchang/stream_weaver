# frozen_string_literal: true

require "stream_weaver"
require_relative "../../lib/stream_weaver/org/writer"

RSpec.describe StreamWeaver::Org::Writer do
  def write(dsl)
    described_class.from_dsl(dsl)
  end

  it "emits the version marker, title, and eyebrow/pills quote block" do
    org = write(<<~RUBY)
      sidebar_toc sections: [{ id: "summary", label: "Summary" }]
      doc_header(eyebrow: "Team · Project", title: "My Report", pills: [{ text: "Draft", variant: :warn }, "2026-08-13"])
      doc_section_header "00", "Summary", id: "summary"
    RUBY

    expect(org).to start_with(<<~ORG)
      #+STREAMWEAVER_DSL: 1
      #+TITLE: My Report

      #+begin_quote
      /Team · Project/
      *[warn] Draft* · 2026-08-13
      #+end_quote
    ORG
  end

  it "emits a depth-1 headline with CUSTOM_ID for a section in the sidebar_toc list" do
    org = write(<<~RUBY)
      sidebar_toc sections: [{ id: "summary", label: "Summary" }]
      doc_header(title: "T", pills: [])
      doc_section_header "00", "Summary", id: "summary"
    RUBY
    expect(org).to include(<<~ORG)
      * 00 Summary
      :PROPERTIES:
      :CUSTOM_ID: summary
      :END:
    ORG
  end

  it "emits a depth-2 headline for a section NOT in the sidebar_toc list" do
    org = write(<<~RUBY)
      sidebar_toc sections: [{ id: "summary", label: "Summary" }]
      doc_header(title: "T", pills: [])
      doc_section_header "00", "Summary", id: "summary"
      doc_section_header "00.1", "Detail", id: "detail"
    RUBY
    expect(org).to include(<<~ORG)
      ** 00.1 Detail
      :PROPERTIES:
      :CUSTOM_ID: detail
      :END:
    ORG
  end

  it "emits TOC_LABEL only when the sidebar_toc label differs from the section title" do
    org = write(<<~RUBY)
      sidebar_toc sections: [{ id: "how", label: "How It Works" }]
      doc_header(title: "T", pills: [])
      doc_section_header "01", "How It Works — Reference", id: "how"
    RUBY
    expect(org).to include(<<~ORG)
      * 01 How It Works — Reference
      :PROPERTIES:
      :CUSTOM_ID: how
      :TOC_LABEL: How It Works
      :END:
    ORG
  end

  it "emits a markdown component as a plain paragraph, converted to org inline syntax" do
    org = write(%(md "hello **world**"\n))
    expect(org).to include("hello *world*")
  end

  it "emits a table as native org table syntax" do
    org = write(<<~RUBY)
      table(headers: ["A", "B"], rows: [["1", "2"], ["3", "4"]])
    RUBY
    expect(org).to include(<<~ORG.strip)
      | A | B |
      |---|---|
      | 1 | 2 |
      | 3 | 4 |
    ORG
  end

  it "converts inline emphasis inside table cells when markdown: true" do
    org = write(%(table(headers: ["A"], rows: [["**bold**"]], markdown: true)\n))
    expect(org).to include("| *bold* |")
  end

  it "leaves table cells byte-identical when markdown: false (the default) -- same principle as code content never running through inline conversion" do
    org = write(%(table(headers: ["A"], rows: [["**bold**"]])\n))
    expect(org).to include("| **bold** |")
  end

  it "marks a markdown: false table with #+ATTR_STREAMWEAVER: :markdown nil, so the Reader can tell it apart from the (unmarked) markdown: true default" do
    org = write(%(table(headers: ["A"], rows: [["literal"]])\n))
    expect(org).to include("#+ATTR_STREAMWEAVER: :markdown nil")
  end

  it "does NOT mark a markdown: true table with the ATTR line" do
    org = write(%(table(headers: ["A"], rows: [["x"]], markdown: true)\n))
    expect(org).not_to include("#+ATTR_STREAMWEAVER")
  end

  it "emits a callout as a quote block with an emoji marker line" do
    org = write(<<~RUBY)
      callout(variant: :warning, title: "What happened") do
        md "Something happened."
      end
    RUBY
    expect(org).to include(<<~ORG)
      #+begin_quote
      *⚠️ What happened*
      Something happened.
      #+end_quote
    ORG
  end

  it "emits a titleless callout with no trailing space after the emoji marker" do
    org = write(<<~RUBY)
      callout(variant: :warning) do
        md "body"
      end
    RUBY
    expect(org).to include("*⚠️*\nbody")
  end

  it "emits doc_header with only a title (no eyebrow, no pills) as bare preamble, with no quote block at all" do
    org = write(%(doc_header(title: "T")\n))
    expect(org).to eq(<<~ORG)
      #+STREAMWEAVER_DSL: 1
      #+TITLE: T
    ORG
  end

  it "emits a plain (non-variant-tagged) pills line even with no eyebrow" do
    org = write(%(doc_header(title: "T", pills: ["Draft", "2026-08-13"])\n))
    expect(org).to include(<<~ORG)
      #+begin_quote
      Draft · 2026-08-13
      #+end_quote
    ORG
  end

  it "falls back to raw-passthrough for a table built with data: (not headers:/rows:), instead of silently emitting a garbage empty table" do
    org = write(%(table(data: [{ name: "Alice" }])\n))
    expect(org).to include("#+begin_src ruby :streamweaver-raw t")
    expect(org).not_to include("|  |")
  end

  it "emits a card as a quote block with a bracket-badge marker line and meta" do
    org = write(<<~RUBY)
      card do
        card_header "Title", badge: "1", meta: "note"
        card_body do
          md "Body."
        end
      end
    RUBY
    expect(org).to include(<<~ORG)
      #+begin_quote
      *[1] Title* /(note)/
      Body.
      #+end_quote
    ORG
  end

  it "emits a card with no badge/meta as a plain bold marker line" do
    org = write(<<~RUBY)
      card do
        card_header "Title"
        card_body { md "Body." }
      end
    RUBY
    expect(org).to include("*Title*\nBody.")
  end

  it "emits a comparison as two consecutive before/after quote blocks" do
    org = write(<<~RUBY)
      comparison(before_label: "Old", after_label: "New") do
        before { md "old" }
        after { md "new" }
      end
    RUBY
    expect(org).to include(<<~ORG)
      #+begin_quote
      *◀ Before — Old*
      old
      #+end_quote
      #+begin_quote
      *▶ After — New*
      new
      #+end_quote
    ORG
  end

  it "falls back to raw-passthrough for a card with no CardHeader, instead of crashing (a real pattern elsewhere in this codebase, e.g. admin dashboard stat tiles)" do
    org = write(<<~RUBY)
      card do
        md "loose content, no header"
      end
    RUBY
    expect(org).to include("#+begin_src ruby :streamweaver-raw t")
    expect(org).to include("#+end_src")
  end

  it "delegates callout emoji to Components::Callout#icon rather than a separate mapping, so it can never drift from the real icon" do
    org = write(<<~RUBY)
      callout(variant: :decision, title: "Pick one") do
        md "body"
      end
    RUBY
    expect(org).to include("*⚖️ Pick one*")
  end

  it "emits a mermaid component as a #+begin_src mermaid block, content untouched" do
    org = write(<<~'RUBY')
      mermaid <<~MERMAID, zoom: true
        graph LR
          A["a/b/c"] --> B
      MERMAID
    RUBY
    expect(org).to include(<<~ORG)
      #+begin_src mermaid :zoom t
      graph LR
        A["a/b/c"] --> B
      #+end_src
    ORG
  end

  it "emits a code_block component as a #+begin_src block with its language" do
    org = write(<<~'RUBY')
      code_block(<<~TXT, lang: "text")
        lib/foo.rb:1-10
      TXT
    RUBY
    expect(org).to include(<<~ORG)
      #+begin_src text
      lib/foo.rb:1-10
      #+end_src
    ORG
  end

  it "wraps an unrecognized component's rendered class name in a raw passthrough block rather than dropping it" do
    org = write(%(implementation_map(files: [{ path: "x", note: "y" }])\n))
    expect(org).to include("#+begin_src ruby :streamweaver-raw t")
    expect(org).to include("#+end_src")
  end
end
