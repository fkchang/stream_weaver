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
end
