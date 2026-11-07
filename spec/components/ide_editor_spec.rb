# frozen_string_literal: true

require_relative "../support/ide_markup"

RSpec.describe "ide_editor and file_section" do
  include IdeMarkup

  let(:page) do
    render_ide_page do
      ide_editor do
        file_section "readme", label: "README.md" do
          text "Hello"
        end
        file_section "install", label: "docs/INSTALL.md", icon: :package, comment: "INSTALL" do
          text "gem install stream_weaver"
        end
        file_section "faq", label: "FAQ.md", icon: "?", comment: false
      end
    end
  end
  let(:editor) { ide_region(page, "main", "sw-ide-editor") }
  let(:tabs) { find_all(editor, "nav[@class='sw-ide-tabstrip']/a") }
  let(:sections) { find_all(editor, "section") }

  describe "the generated tab strip" do
    it "comes first in the editor, one tab per file section, in order" do
      strip = editor.elements[1]
      expect(strip.name).to eq("nav")
      expect(strip.attributes["aria-label"]).to eq("Open files")
      expect(strip.attributes["data-sw-ide-links"]).to eq("")
      expect(tabs.map { |tab| text_of(first(tab, "span[@class='sw-ide-tab__label']")) })
        .to eq(%w[README.md INSTALL.md FAQ.md])
    end

    it "links each tab to its section by in-page href and spy target" do
      expect(tabs.map { |tab| tab.attributes["href"] }).to eq(%w[#readme #install #faq])
      expect(tabs.map { |tab| tab.attributes["data-sw-ide-target"] }).to eq(%w[readme install faq])
      expect(tabs.map { |tab| tab.attributes["class"] }).to all(eq("sw-ide-tab"))
    end

    it "shows each section's icon on its tab" do
      expect(first(tabs[0], "*[local-name()='svg'][@class='sw-ide-tab__icon']")).not_to be_nil
      expect(text_of(first(tabs[2], "span[@aria-hidden='true']/span[@class='sw-ide-tab__icon']"))).to eq("?")
    end

    it "is absent from an editor with no file sections, which loads no scroll spy" do
      plain = render_ide_page { ide_editor { text "Just text" } }
      expect(find_all(ide_region(plain, "main", "sw-ide-editor"), ".//nav")).to be_empty
      expect(plain).not_to include("swInitSidebarToc")
    end
  end

  describe "the file sections" do
    it "are anchors named by their name, carrying their file path" do
      expect(sections.map { |s| s.attributes["id"] }).to eq(%w[readme install faq])
      expect(sections.map { |s| s.attributes["data-file"] }).to eq(%w[README.md docs/INSTALL.md FAQ.md])
      expect(sections.map { |s| s.attributes["class"] }).to all(eq("sw-ide-file-section"))
    end

    it "can take focus from script but are not tab stops" do
      expect(sections.map { |s| s.attributes["tabindex"] }).to all(eq("-1"))
    end

    it "open with a comment line, defaulting to the label, unless comment: false" do
      comments = sections.map { |s| first(s, "p[@class='sw-ide-file-section__comment']") }
      expect(comments[0..1].map { |c| text_of(c) }).to eq(["<!-- README.md -->", "<!-- INSTALL -->"])
      expect(comments[2]).to be_nil
    end

    it "render their block as the section body" do
      expect(text_of(sections[1])).to include("gem install stream_weaver")
    end
  end
end
