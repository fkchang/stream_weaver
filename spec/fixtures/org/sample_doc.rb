# frozen_string_literal: true
# Synthetic fixture exercising the full doc-builder component vocabulary.
# Deliberately generic content -- do not replace with real project docs
# (see docs/superpowers/specs/2026-08-13-org-doc-format-design.md, Testing).

<<~'DSL'
sidebar_toc sections: [
  { id: "overview", label: "Overview" },
  { id: "details", label: "Details" }
]

doc_header(
  eyebrow: "Team · Project",
  title: "Sample Report",
  pills: [{ text: "Draft", variant: :warn }, "2026-08-13"]
)

doc_section_header "00", "Overview", id: "overview"

callout(variant: :warning, title: "Heads up") do
  md "Something **important** happened, see `path/to/file.rb` for detail."
end

card do
  card_header "Pipeline", badge: "1", meta: "team · service"
  card_body do
    mermaid <<~MERMAID, zoom: true
      graph LR
        A["a/b/c"] --> B
    MERMAID
  end
end

comparison(before_label: "Old", after_label: "New") do
  before { md "- old item one\n- old item two" }
  after { md "- new item one" }
end

table(
  headers: ["Name", "Role"],
  rows: [["Alice", "Lead"], ["Bob", "Engineer"]]
)

doc_section_header "01", "Details", id: "details"

code_block(<<~TXT, lang: "text")
  lib/foo.rb:1-10
TXT
DSL
