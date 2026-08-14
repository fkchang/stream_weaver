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
end
