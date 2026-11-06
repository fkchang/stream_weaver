# frozen_string_literal: true

require "stream_weaver"
require "org-ruby"
require_relative "../../lib/stream_weaver/canvas/reader"
require_relative "../../lib/stream_weaver/org/writer"
require_relative "../../lib/stream_weaver/org/reader"

# Tabs in the org format: each tab is a level-1 headline whose property drawer
# names the group key (:STREAMWEAVER_TAB:), and the Reader regroups them. See
# Writer#render_tabs and the "Tabs" section of
# docs/superpowers/specs/2026-08-13-org-doc-format-design.md.
RSpec.describe "org tabs" do
  def to_org(dsl) = StreamWeaver::Org::Writer.from_dsl(dsl)
  def to_dsl(org) = StreamWeaver::Org::Reader.to_dsl(org)

  def record(dsl)
    ctx = StreamWeaver::Org::RecordingContext.new
    ctx.instance_eval(dsl)
    ctx.components
  end

  # Mermaid ids are per-render, unrelated to the round trip (see round_trip_spec).
  def render(dsl)
    html = StreamWeaver::Canvas::Reader.render_dsl(dsl)
    expect(html).not_to include("DSL error")
    html.gsub(/sw-mermaid-\w+/, "sw-mermaid-ID")
  end

  # No two md calls in a row in these fixtures: the Reader merges an md run
  # into one call (stream_weaver-spw), a separate, known difference.
  let(:tabbed_dsl) do
    <<~'RUBY'
      doc_header title: "Chat Review", eyebrow: "review"
      md "Read the tabs in order."
      tabs :chat do
        tab "Start here" do
          md "Where to begin."
        end
        tab "1 PRD protocol" do
          md "What the PRD says."
          callout variant: :warning, title: "Heads up" do
            md "The PRD and the build disagree."
          end
        end
      end
    RUBY
  end

  describe "a tab whose label looks like a numbered section" do
    it "writes each tab as a headline carrying the group key in its drawer" do
      org = to_org(tabbed_dsl)

      expect(org).to include("* Start here\n:PROPERTIES:\n:STREAMWEAVER_TAB: chat\n:END:\n")
      expect(org).to include("* 1 PRD protocol\n:PROPERTIES:\n:STREAMWEAVER_TAB: chat\n:END:\n")
      expect(org).not_to include("unrecognized component")
    end

    it "reads the numbered label back as a tab, not a doc_section_header" do
      dsl = to_dsl(to_org(tabbed_dsl))

      expect(dsl).not_to include("doc_section_header")
      tabs = record(dsl).grep(StreamWeaver::Components::Tabs)
      expect(tabs.size).to eq(1)
      expect(tabs.first.key).to eq(:chat)
      expect(tabs.first.children.map(&:label)).to eq(["Start here", "1 PRD protocol"])
    end

    it "renders the same HTML after rb -> org -> rb" do
      regenerated = to_dsl(to_org(tabbed_dsl))

      expect { RubyVM::InstructionSequence.compile(regenerated) }.not_to raise_error
      expect(render(regenerated)).to eq(render(tabbed_dsl))
    end

    # From the Reader's own output: the first pass also turns md "x" into an
    # md heredoc, a whitespace-only change that has nothing to do with tabs.
    it "reaches a fixed point after one round trip" do
      dsl = to_dsl(to_org(tabbed_dsl))
      expect(to_dsl(to_org(dsl))).to eq(dsl)
    end
  end

  describe "canvas_continue" do
    let(:dsl) do
      <<~RUBY
        use_theme :default
        md "Some prose."
        bar_chart labels: ["a"], values: [1]
        canvas_continue message: "Received. I will act and refresh this page."
      RUBY
    end

    it "leaves no trace in the org" do
      org = to_org(dsl)
      expect(org).not_to include("canvas_continue")
      expect(org).not_to include("Received.")
    end

    it "is not counted, so coverage only sees the document's own statements" do
      writer = StreamWeaver::Org::Writer.new(dsl)
      writer.call
      expect(writer.coverage).to eq(total: 2, recognized: 1, passthrough_verbatim: 1, passthrough_lossy: 0, omitted: 0)
    end

    # The 1:1 statement<->component alignment build_raw_sources relies on:
    # had canvas_continue not been skipped as a no-op statement, the counts
    # would disagree and bar_chart would fall back to the lossy placeholder.
    it "keeps verbatim source recovery aligned for the other statements" do
      org = to_org(dsl)
      expect(org).to include(%(bar_chart labels: ["a"], values: [1]))
      expect(org).not_to include("unrecognized component")
    end

    it "keeps alignment when a tabbed doc ends with it" do
      writer = StreamWeaver::Org::Writer.new("#{tabbed_dsl}canvas_continue message: \"Working\"\n")
      org = writer.call
      expect(org).to include(":STREAMWEAVER_TAB: chat")
      expect(writer.coverage).to eq(total: 2, recognized: 2, passthrough_verbatim: 0, passthrough_lossy: 0, omitted: 0)
    end
  end

  describe "two tab groups followed by a numbered section" do
    let(:org) do
      <<~ORG
        #+STREAMWEAVER_DSL: 1

        * Overview
        :PROPERTIES:
        :STREAMWEAVER_TAB: first
        :END:

        First group, tab one.

        * Details
        :PROPERTIES:
        :STREAMWEAVER_TAB: first
        :END:

        First group, tab two.

        * Alpha
        :PROPERTIES:
        :STREAMWEAVER_TAB: second
        :END:

        Second group, only tab.

        * 01 Afterword
        :PROPERTIES:
        :CUSTOM_ID: afterword
        :END:

        This belongs to the section, not to any tab.
      ORG
    end

    it "emits two tabs blocks and leaves the section and its content outside them" do
      components = record(to_dsl(org))
      types = components.map(&:class)

      expect(types).to eq([
        StreamWeaver::Components::SidebarToc,
        StreamWeaver::Components::Tabs,
        StreamWeaver::Components::Tabs,
        StreamWeaver::Components::DocSectionHeader,
        StreamWeaver::Components::Markdown
      ])
      first, second = components.grep(StreamWeaver::Components::Tabs)
      expect([first.key, second.key]).to eq(%i[first second])
      expect(first.children.map(&:label)).to eq(%w[Overview Details])
      expect(second.children.map(&:label)).to eq(%w[Alpha])
      expect(second.children.first.children.map { |c| c.content.chomp }).to eq(["Second group, only tab."])
      expect(components.last.content.chomp).to eq("This belongs to the section, not to any tab.")
    end

    it "keeps tabs out of the sidebar TOC" do
      toc = record(to_dsl(org)).first
      expect(toc.sections).to eq([{ id: "afterword", label: "Afterword" }])
    end

    it "round trips the same structure through the Writer" do
      dsl = <<~RUBY
        tabs :first do
          tab "Overview" do
            md "First group, tab one."
          end
        end
        tabs :second do
          tab "Alpha" do
            md "Second group."
          end
        end
        doc_section_header "01", "Afterword", id: "afterword"
        md "Section prose."
      RUBY
      org = to_org(dsl)

      expect(org.scan(/^:STREAMWEAVER_TAB: (\w+)$/).flatten).to eq(%w[first second])
      expect(render(to_dsl(org))).to eq(render(dsl))
    end

    it "rejects a tab drawer with no key" do
      bad = "* Lonely\n:PROPERTIES:\n:STREAMWEAVER_TAB:\n:END:\n"
      expect { to_dsl(bad) }.to raise_error(ArgumentError, /empty :STREAMWEAVER_TAB: key/)
    end

    it "rejects an unterminated tab drawer" do
      bad = "* Lonely\n:PROPERTIES:\n:STREAMWEAVER_TAB: x\n"
      expect { to_dsl(bad) }.to raise_error(ArgumentError, /unterminated property drawer for tab/)
    end
  end

  describe "tab children" do
    let(:dsl) do
      <<~'RUBY'
        tabs :views do
          tab "Mixed" do
            md "Intro prose."
            callout variant: :tip, title: "Tip" do
              md "Inside a callout."
            end
            mermaid <<~MERMAID
              graph TD
                A --> B
            MERMAID
            table headers: ["Name", "Status"], rows: [["api", "up"]]
            bar_chart labels: ["a"], values: [1]
          end
        end
      RUBY
    end

    it "keeps md, callout, mermaid and table as real components inside the tab" do
      tab = record(to_dsl(to_org(dsl))).first.children.first

      expect(tab.children.map(&:class)).to eq([
        StreamWeaver::Components::Markdown,
        StreamWeaver::Components::Callout,
        StreamWeaver::Components::Mermaid,
        StreamWeaver::Components::Table
      ])
    end

    it "falls back to a raw passthrough block inside its tab for an unsupported component" do
      org = to_org(dsl)

      tab_body = org.split(":STREAMWEAVER_TAB: views\n:END:\n", 2).last
      expect(tab_body).to include("#+begin_src ruby :streamweaver-raw t\n# unrecognized component: bar_chart (unsupported call)\n#+end_src")
      expect(to_dsl(org)).to include("  tab \"Mixed\" do\n").and include("    # unrecognized component: bar_chart (unsupported call)")
    end

    # Writer#count only counts at @nesting_depth zero; render_tabs raises the
    # depth, so the nested passthrough is not counted on its own and
    # `recognized` cannot go below zero.
    it "counts the tabs group once and never lets coverage go negative" do
      writer = StreamWeaver::Org::Writer.new(dsl)
      writer.call
      expect(writer.coverage).to eq(total: 1, recognized: 1, passthrough_verbatim: 0, passthrough_lossy: 0, omitted: 0)
    end
  end

  describe "in a generic org viewer (org-ruby, GitHub's renderer)" do
    let(:html) { Orgmode::Parser.new(to_org(tabbed_dsl)).to_html }

    it "shows one h1 per tab (after the #+TITLE: h1)" do
      expect(html.scan(%r{<h1[^>]*>(.*?)</h1>}).flatten).to eq(["Chat Review", "Start here", "1 PRD protocol"])
    end

    it "shows no drawer or property text" do
      expect(html).not_to include("STREAMWEAVER_TAB")
      expect(html).not_to include("PROPERTIES")
      expect(html).not_to include(":END:")
    end

    it "leaks no keyword line as a paragraph" do
      expect(html).not_to match(/#\+|STREAMWEAVER_/)
    end
  end

  # Shapes a headline-delimited group cannot hold without loss. Each one is
  # written as raw passthrough -- its verbatim source -- rather than as tab
  # headlines that would read back wrong.
  describe "shapes written as raw passthrough instead" do
    def expect_verbatim(dsl, statement_start)
      writer = StreamWeaver::Org::Writer.new(dsl)
      org = writer.call
      expect(org).not_to include(":STREAMWEAVER_TAB:")
      expect(org).to include("#+begin_src ruby :streamweaver-raw t\n#{statement_start}")
      expect(writer.coverage[:passthrough_lossy]).to eq(0)
      org
    end

    it "url: tabs (the option has no place in a headline)" do
      expect_verbatim(<<~RUBY, "tabs :views, url: true do")
        tabs :views, url: true do
          tab("One") { md "one" }
        end
      RUBY
    end

    it "lazy: tabs" do
      expect_verbatim(<<~RUBY, "tabs :views, lazy: true do")
        tabs :views, lazy: true do
          tab("One") { md "one" }
        end
      RUBY
    end

    it "a non-default variant" do
      expect_verbatim(<<~RUBY, "tabs :views, variant: :enclosed do")
        tabs :views, variant: :enclosed do
          tab("One") { md "one" }
        end
      RUBY
    end

    it "nested tabs (a headline inside a headline-delimited group)" do
      expect_verbatim(<<~RUBY, "tabs :outer do")
        tabs :outer do
          tab "Outer" do
            tabs :inner do
              tab("Inner") { md "deep" }
            end
          end
        end
      RUBY
    end

    # With no end marker, the md would read back as part of the last tab.
    it "tabs followed by content that is not a numbered section headline" do
      org = expect_verbatim(<<~RUBY, "tabs :views do")
        tabs :views do
          tab("One") { md "one" }
        end
        md "After the tabs."
      RUBY
      expect(record(to_dsl(org)).last.content.chomp).to eq("After the tabs.")
    end

    # Same-key neighbours would merge into one group on the way back; the
    # second still qualifies (EOF follows it) and stays a headline group.
    it "the first of two adjacent groups with the same key" do
      org = to_org(<<~RUBY)
        tabs :views do
          tab("One") { md "one" }
        end
        tabs :views do
          tab("Two") { md "two" }
        end
      RUBY
      expect(org).to include("#+begin_src ruby :streamweaver-raw t\ntabs :views do")
      expect(org.scan(":STREAMWEAVER_TAB: views").size).to eq(1)
    end

    it "a tabs group nested in a callout is the existing nested-passthrough placeholder" do
      writer = StreamWeaver::Org::Writer.new(<<~RUBY)
        callout variant: :info, title: "Wrapper" do
          tabs :views do
            tab("One") { md "one" }
          end
        end
      RUBY
      org = writer.call
      expect(org).not_to include(":STREAMWEAVER_TAB:")
      expect(org).to include("# unrecognized component: StreamWeaver::Components::Tabs")
      expect(writer.coverage).to eq(total: 1, recognized: 1, passthrough_verbatim: 0, passthrough_lossy: 0, omitted: 0)
    end
  end
end
