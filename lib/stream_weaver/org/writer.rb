# frozen_string_literal: true

require_relative "recording_context"
require_relative "inline"

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

      def call
        ctx = RecordingContext.new
        ctx.instance_eval(@dsl_text)
        components = ctx.components

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
            render_component(c) # implemented in later tasks
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

      # Filled in by later tasks: md/table/callout/card/comparison/code_block/mermaid.
      def render_component(_component)
        ""
      end
    end
  end
end
