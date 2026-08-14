# frozen_string_literal: true

require_relative "recording_context"
require_relative "inline"
require_relative "source_splitter"

module StreamWeaver
  module Org
    # Converts a StreamWeaver doc-builder DSL body (the text canvas-read
    # instance_evals) into StreamWeaver-flavored org-mode text. See
    # docs/superpowers/specs/2026-08-13-org-doc-format-design.md for the
    # full format spec this implements.
    class Writer
      def self.from_dsl(dsl_text)
        new(dsl_text).call
      end

      def initialize(dsl_text)
        @dsl_text = dsl_text
      end

      # Top-level DSL statements RecordingContext deliberately no-ops (see
      # its class comment) -- these produce zero components, so they'd
      # otherwise break the 1:1 statement<->component correspondence
      # #build_raw_sources relies on. Every real saved doc has at least one
      # of these prepended by DocStore.dsl_with_metadata.
      NO_OP_STATEMENT_RE = /\Ause_(?:theme|layout)\b/

      def call
        ctx = RecordingContext.new
        ctx.instance_eval(@dsl_text)
        components = ctx.components
        @raw_sources = build_raw_sources(components)

        toc_sections = components.find { |c| c.is_a?(Components::SidebarToc) }&.sections || []
        toc_by_id = toc_sections.each_with_object({}) { |s, h| h[s[:id]] = s[:label] }

        header = components.find { |c| c.is_a?(Components::DocHeader) }
        body_components = components.reject { |c| c.is_a?(Components::SidebarToc) || c.is_a?(Components::DocHeader) }

        [preamble(header), sections_and_body(body_components, toc_by_id)].join("\n").rstrip + "\n"
      end

      private

      def preamble(header)
        return "#+STREAMWEAVER_DSL: 1\n" unless header

        out = +"#+STREAMWEAVER_DSL: 1\n#+TITLE: #{header.title}\n"
        if header.eyebrow || (header.pills && !header.pills.empty?)
          out << "\n#+begin_quote\n"
          out << "/#{header.eyebrow}/\n" if header.eyebrow
          if header.pills && !header.pills.empty?
            out << header.pills.map { |p| render_pill(p) }.join(" · ") + "\n"
          end
          out << "#+end_quote\n"
        end
        out
      end

      def render_pill(pill)
        return pill unless pill.is_a?(Hash)
        variant = pill[:variant] || pill["variant"]
        text = pill[:text] || pill["text"]
        variant ? "*[#{variant}] #{text}*" : text
      end

      def sections_and_body(components, toc_by_id)
        out = +""
        components.each do |c|
          out << if c.is_a?(Components::DocSectionHeader)
            section_headline(c, toc_by_id)
          else
            render_component(c)
          end
        end
        out
      end

      def section_headline(section, toc_by_id)
        in_toc = toc_by_id.key?(section.anchor_id)
        depth = in_toc ? "*" : "**"
        headline = "\n#{depth} #{section.number} #{section.title}\n:PROPERTIES:\n:CUSTOM_ID: #{section.anchor_id}\n"
        toc_label = toc_by_id[section.anchor_id]
        headline << ":TOC_LABEL: #{toc_label}\n" if in_toc && toc_label != section.title
        headline << ":END:\n"
      end

      def render_component(component)
        case component
        when Components::Markdown
          "\n#{Inline.md_to_org(component.content)}\n"
        when Components::Table
          render_table(component)
        when Components::Callout
          marker = component.title ? "*#{component.icon} #{component.title}*" : "*#{component.icon}*"
          render_quote(marker, component.children)
        when Components::Card
          render_card(component)
        when Components::Comparison
          render_comparison(component)
        when Components::Mermaid
          header = component.zoom ? "mermaid :zoom t" : "mermaid"
          "\n#+begin_src #{header}\n#{component.code.to_s.rstrip}\n#+end_src\n"
        when Components::CodeBlock
          "\n#+begin_src #{component.lang}\n#{component.code.to_s.rstrip}\n#+end_src\n"
        else
          raw_passthrough(component)
        end
      end

      def render_table(table)
        # table.headers/#rows are the raw constructor args, nil for any form
        # other than table(headers:, rows:) -- e.g. table(data:) or the
        # column DSL, which resolve their actual content lazily elsewhere
        # and are out of scope for this format (see the design spec's
        # Tables section). Falling through to the normal empty-array
        # default here would silently emit a garbage 1-empty-column table
        # with all row data gone; raw-passthrough matches the same
        # unrecognized-shape convention used elsewhere in this file.
        return raw_passthrough(table) if table.headers.nil?

        headers = table.headers
        rows = table.rows || []
        convert = ->(s) { table.markdown ? Inline.md_to_org(s.to_s) : s.to_s }
        widths = headers.each_index.map { |i| ([headers[i]] + rows.map { |r| r[i] }).map { |s| convert.call(s).length }.max }
        out = +"\n"
        out << "#+ATTR_STREAMWEAVER: :markdown nil\n" unless table.markdown
        out << row_line(headers.map { |h| convert.call(h) }, widths)
        out << "|" + widths.map { |w| "-" * (w + 2) }.join("|") + "|\n"
        rows.each { |r| out << row_line(r.map { |c| convert.call(c) }, widths) }
        out
      end

      def row_line(cells, widths)
        "| " + cells.each_with_index.map { |c, i| c.ljust(widths[i]) }.join(" | ") + " |\n"
      end

      def render_card(card)
        header = card.children.find { |c| c.is_a?(Components::CardHeader) }
        # A card with no CardHeader (loose children directly under card
        # do...end -- a real pattern elsewhere in this codebase, e.g. admin
        # dashboard stat tiles) has no natural title for the marker-line
        # convention and isn't part of the doc-builder vocabulary this
        # format targets. Fall back to the same raw-passthrough convention
        # render_component's unrecognized-component branch uses, rather
        # than crash or silently drop the content.
        return raw_passthrough(card) unless header

        body = card.children.find { |c| c.is_a?(Components::CardBody) }
        marker = header.badge ? "*[#{header.badge}] #{header.content}*" : "*#{header.content}*"
        marker << " /(#{header.meta})/" if header.meta
        render_quote(marker, body ? body.children : [])
      end

      # Best-effort verbatim-source recovery for the raw-passthrough escape
      # hatch: maps each top-level component to the literal DSL source text
      # of the top-level statement that produced it, ONLY when that
      # correspondence is unambiguous (exactly one top-level statement per
      # top-level component, after filtering out known no-ops -- the common
      # case for the flat DSL body this format targets). Falls back to an
      # empty map (raw_passthrough's comment-only placeholder) rather than
      # guessing when a doc uses top-level control flow (loops,
      # conditionals producing zero-or-many components per statement) that
      # breaks the 1:1 assumption -- silent-but-safe beats attributing the
      # wrong source to a component.
      def build_raw_sources(components)
        statements = SourceSplitter.top_level_statements(@dsl_text)
        return {} unless statements

        statements = statements.reject { |s| s.strip.match?(NO_OP_STATEMENT_RE) }
        return {} unless statements.length == components.length

        components.each_with_index.to_h { |c, i| [c.object_id, statements[i]] }
      rescue StandardError
        {}
      end

      def raw_passthrough(component)
        source = @raw_sources[component.object_id]
        content = source || "# unrecognized component: #{component.class}"
        "\n#+begin_src ruby :streamweaver-raw t\n#{content.rstrip}\n#+end_src\n"
      end

      def render_comparison(comparison)
        before = render_quote("*◀ Before — #{comparison.before_label}*", comparison.before_children)
        after  = render_quote("*▶ After — #{comparison.after_label}*", comparison.after_children)
        "\n" + before.strip + "\n" + after.strip + "\n"
      end

      def render_quote(marker, children)
        body = children.map { |c| render_component(c) }.join.strip
        "\n#+begin_quote\n#{marker}\n#{body}\n#+end_quote\n"
      end
    end
  end
end
