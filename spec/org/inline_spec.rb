# frozen_string_literal: true

require_relative "../../lib/stream_weaver/org/inline"

RSpec.describe StreamWeaver::Org::Inline do
  describe ".md_to_org" do
    it "converts markdown bold to org bold" do
      expect(described_class.md_to_org("hello **world**")).to eq("hello *world*")
    end

    it "converts markdown italic to org italic" do
      expect(described_class.md_to_org("a *quick* fox")).to eq("a /quick/ fox")
    end

    it "converts markdown code spans to org verbatim" do
      expect(described_class.md_to_org("run `foo bar`")).to eq("run =foo bar=")
    end

    it "converts internal markdown links to org links" do
      expect(described_class.md_to_org("see [Evidence](#evidence)")).to eq("see [[#evidence][Evidence]]")
    end

    it "converts external markdown links to org links" do
      # stream_weaver-043f: link conversion used to be scoped to internal
      # #anchor targets only. Org's own [[target][text]] syntax is generic
      # across target shapes (confirmed against the real org-ruby parser --
      # see the org-ruby generic-renderer smoke spec), so md_to_org/org_to_md
      # should be too, not special-cased to one target shape.
      expect(described_class.md_to_org("watch [5:54](https://example.com/watch?v=X&t=354s)"))
        .to eq("watch [[https://example.com/watch?v=X&t=354s][5:54]]")
    end

    it "converts relative-path markdown links to org links" do
      expect(described_class.md_to_org("see [the other doc](../other-doc.md)"))
        .to eq("see [[../other-doc.md][the other doc]]")
    end

    it "normalizes approximation tildes to the unicode approx sign" do
      expect(described_class.md_to_org("~4,600 recipients")).to eq("≈4,600 recipients")
    end

    it "does not treat slashes inside a file path as italic markers" do
      text = "see `app/admin/cms/stock_positions.rb:216` for details"
      expect(described_class.md_to_org(text)).to eq("see =app/admin/cms/stock_positions.rb:216= for details")
    end

    it "does not treat an 'X / Y' separator as italic markers" do
      expect(described_class.md_to_org("Operations / Discussion channel"))
        .to eq("Operations / Discussion channel")
    end

    it "handles emphasis spans that wrap across a line break" do
      text = "the **identical error**: `Socket::ResolutionError: opened\nover two lines`"
      expect(described_class.md_to_org(text))
        .to eq("the *identical error*: =Socket::ResolutionError: opened\nover two lines=")
    end

    it "does not corrupt adjacent same-delimiter spans on one line" do
      expect(described_class.md_to_org("*a* *b*")).to eq("/a/ /b/")
      expect(described_class.md_to_org("**a** **b**")).to eq("*a* *b*")
      expect(described_class.md_to_org("`a` `b`")).to eq("=a= =b=")
    end

    it "protects code-span content from other conversions" do
      expect(described_class.md_to_org("run `foo *bar* baz`")).to eq("run =foo *bar* baz=")
      expect(described_class.md_to_org("run `foo **bar** baz`")).to eq("run =foo **bar** baz=")
    end

    it "does not normalize a tilde in a path (only converts when followed by a digit)" do
      expect(described_class.md_to_org("edit ~/.bashrc then restart")).to eq("edit ~/.bashrc then restart")
    end

    it "converts a code span whose content contains the org verbatim delimiter itself" do
      # Round-trip counterpart to the .org_to_md regression test below --
      # this direction (backtick delimiter, "=" only in the content) never
      # actually broke, since CODE_MD only needs to worry about its own
      # delimiter ("`") appearing in content, not "=". Kept for symmetry.
      text = "Result: `queued=true, sent=false`, hides the position."
      expect(described_class.md_to_org(text))
        .to eq("Result: =queued=true, sent=false=, hides the position.")
    end
  end

  describe ".org_to_md" do
    it "converts org bold to markdown bold" do
      expect(described_class.org_to_md("hello *world*")).to eq("hello **world**")
    end

    it "converts org italic to markdown italic" do
      expect(described_class.org_to_md("a /quick/ fox")).to eq("a *quick* fox")
    end

    it "converts org verbatim to markdown code spans" do
      expect(described_class.org_to_md("run =foo bar=")).to eq("run `foo bar`")
    end

    it "converts org links to internal markdown links" do
      expect(described_class.org_to_md("see [[#evidence][Evidence]]")).to eq("see [Evidence](#evidence)")
    end

    it "converts external org links to markdown links" do
      # stream_weaver-043f: this used to fail the match entirely (LINK_ORG
      # required a literal "#" right after "[["), so an external link like
      # this passed through org_to_md unconverted and rendered as literal
      # bracket text instead of a clickable link.
      expect(described_class.org_to_md("watch [[https://example.com/watch?v=X&t=354s][5:54]]"))
        .to eq("watch [5:54](https://example.com/watch?v=X&t=354s)")
    end

    it "converts relative-path org links to markdown links" do
      expect(described_class.org_to_md("see [[../other-doc.md][the other doc]]"))
        .to eq("see [the other doc](../other-doc.md)")
    end

    it "does not treat slashes inside a file path as italic markers" do
      text = "see =app/admin/cms/stock_positions.rb:216= for details"
      expect(described_class.org_to_md(text)).to eq("see `app/admin/cms/stock_positions.rb:216` for details")
    end

    it "converts a verbatim span whose content contains the org delimiter itself back to a code span" do
      text = "Result: =queued=true, sent=false=, hides the position."
      expect(described_class.org_to_md(text))
        .to eq("Result: `queued=true, sent=false`, hides the position.")
    end

    it "still separates two adjacent verbatim spans on one line rather than bridging them" do
      expect(described_class.org_to_md("=a= =b=")).to eq("`a` `b`")
    end
  end
end
