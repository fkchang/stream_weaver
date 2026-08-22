# frozen_string_literal: true

# "Build My Todos: the StreamWeaver Way" is authored once, in
# examples/tutorials/tutorial_content.rb, and rendered twice -- as a :doc-theme
# StreamWeaver app and as checked-in markdown. Nothing stops an editor from
# fixing a typo in the generated markdown instead of the outline, at which point
# the two twins say different things and only one of them is the source. This
# spec is what makes that a failing build rather than a slow discovery.

require_relative "../examples/tutorials/render_markdown"

RSpec.describe "Tutorial twins" do
  let(:content) { TutorialContent }

  describe "the checked-in markdown" do
    it "matches a fresh render of the shared outline" do
      expect(File.read(TutorialMarkdown::OUTPUT_PATH)).to eq(TutorialMarkdown.render),
                                                          "docs/tutorials/the-streamweaver-way.md has drifted from " \
                                                          "examples/tutorials/tutorial_content.rb. Edit the outline, " \
                                                          "then run: ruby examples/tutorials/render_markdown.rb"
    end
  end

  describe "the shared outline" do
    it "gives every section an anchor the table of contents can reach" do
      expect(content.toc.map { |s| s[:id] }).to eq(content::SECTIONS.map { |s| s[:id] })
    end

    it "uses only block kinds both renderers implement" do
      kinds = content::SECTIONS.flat_map { |s| s[:blocks].map(&:first) }.uniq
      expect(kinds).to all(satisfy { |k| %i[md code callout table].include?(k) })
    end

    it "gives every callout a variant the markdown renderer can map" do
      variants = content::SECTIONS.flat_map { |s| s[:blocks] }
                                  .select { |b| b.first == :callout }.map { |b| b[1] }
      expect(variants.uniq).to all(satisfy { |v| TutorialMarkdown::VARIANT_ALERTS.key?(v) })
    end

    it "keeps every table rectangular, so the markdown separator row is correct" do
      content::SECTIONS.each do |section|
        section[:blocks].select { |b| b.first == :table }.each do |(_, headers, rows)|
          rows.each do |row|
            expect(row.length).to eq(headers.length),
                                  "section #{section[:id]}: row #{row.first.inspect} has #{row.length} " \
                                  "cells, headers have #{headers.length}"
          end
        end
      end
    end

    it "teaches all four benchmark features" do
      ids = content::SECTIONS.map { |s| s[:id] }
      expect(ids).to include("inline-editing", "search", "hover-cards", "infinite-scroll")
    end
  end

  describe "the :doc-theme twin" do
    it "renders every section header the sidebar TOC links to" do
      load File.expand_path("../examples/tutorials/streamweaver_way_tutorial.rb", __dir__)
      doc_app = TutorialApp.settings.streamlit_app
      state = {}
      doc_app.rebuild_with_state(state)
      html = StreamWeaver::Views::AppView.new(doc_app, state, StreamWeaver::Adapter::AlpineJS.new).call

      expect(html).to include("sw-theme-doc")
      content.toc.each { |section| expect(html).to include(%(id="#{section[:id]}")) }
    end
  end
end
