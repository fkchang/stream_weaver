# frozen_string_literal: true

RSpec.describe "read accessors needed for org export" do
  it "exposes Markdown#content" do
    md = StreamWeaver::Components::Markdown.new("hello **world**")
    expect(md.content).to eq("hello **world**")
  end

  it "exposes CardHeader#content, #badge, #meta" do
    ch = StreamWeaver::Components::CardHeader.new("Title", badge: "1", meta: "note")
    expect(ch.content).to eq("Title")
    expect(ch.badge).to eq("1")
    expect(ch.meta).to eq("note")
  end

  it "exposes Table#headers, #rows, #markdown" do
    t = StreamWeaver::Components::Table.new(headers: ["A", "B"], rows: [["1", "2"]], markdown: true)
    expect(t.headers).to eq(["A", "B"])
    expect(t.rows).to eq([["1", "2"]])
    expect(t.markdown).to eq(true)
  end
end
