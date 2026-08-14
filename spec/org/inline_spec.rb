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

    it "does not treat slashes inside a file path as italic markers" do
      text = "see =app/admin/cms/stock_positions.rb:216= for details"
      expect(described_class.org_to_md(text)).to eq("see `app/admin/cms/stock_positions.rb:216` for details")
    end
  end
end
