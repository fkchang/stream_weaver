# frozen_string_literal: true

require_relative "../../lib/stream_weaver/org/source_splitter"

RSpec.describe StreamWeaver::Org::SourceSplitter do
  def split(source)
    described_class.top_level_statements(source)
  end

  it "splits simple one-line top-level statements" do
    expect(split(%(header1 "Title"\ndiv(style: "x")\n)))
      .to eq([%(header1 "Title"), %(div(style: "x"))])
  end

  it "keeps a multi-line do..end block as ONE statement" do
    source = <<~RUBY
      columns widths: ["50%", "50%"] do
        column do
          card do
            header3 "x"
          end
        end
      end

      div(style: "y")
    RUBY
    result = split(source)
    expect(result.length).to eq(2)
    expect(result[0]).to eq(<<~RUBY.chomp)
      columns widths: ["50%", "50%"] do
        column do
          card do
            header3 "x"
          end
        end
      end
    RUBY
    expect(result[1]).to eq(%(div(style: "y")))
  end

  it "keeps a multi-line method call (parens spanning lines) as ONE statement" do
    source = <<~RUBY
      table(
        headers: ["A"],
        rows: [["1"]]
      )

      md "after"
    RUBY
    result = split(source)
    expect(result.length).to eq(2)
    expect(result[0]).to eq(<<~RUBY.chomp)
      table(
        headers: ["A"],
        rows: [["1"]]
      )
    RUBY
  end

  it "keeps a heredoc body as part of its statement, not split on internal newlines" do
    source = <<~'RUBY'
      md <<~MD
        Hello **world**
        multi line
      MD

      table(headers: ["A"], rows: [["1"]])
    RUBY
    result = split(source)
    expect(result.length).to eq(2)
    expect(result[0]).to include("multi line")
  end

  it "correctly treats a modifier-if as ONE statement, not a block needing 'end'" do
    source = %(md "warn" if some_flag\n\ntable(headers: ["A"], rows: [["1"]])\n)
    result = split(source)
    expect(result.length).to eq(2)
    expect(result[0]).to eq(%(md "warn" if some_flag))
  end

  it "returns an empty array for empty source" do
    expect(split("")).to eq([])
  end

  it "returns nil for unparseable source" do
    expect(split("this is not valid ruby {{{")).to be_nil
  end
end
