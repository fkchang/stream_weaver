# frozen_string_literal: true

# Diffy shells out to the system diff(1) binary, so it exists only on the
# server. In the browser the equivalent work is done by jsdiff -- see
# #unified_diff below.
require "diffy" unless RUBY_ENGINE == "opal"

module StreamWeaver
  module Components
    # Unified diff viewer: removed lines red, added green, context neutral.
    # Two-column line-number gutter (before | after). Prism.js highlights per-line
    # fragments — multi-line constructs (heredocs, block comments) highlight each line
    # independently, same limitation as AnnotatedCode.
    class DiffBlock < Base
      DiffLine = Struct.new(:type, :old_num, :new_num, :prefix, :content, keyword_init: true)

      attr_accessor :before_code, :after_code
      attr_reader :language

      def initialize(language: nil, **options)
        @language = language
        @before_code = ""
        @after_code = ""
        @options = options
      end

      def language_class
        language ? "language-#{language}" : "language-none"
      end

      def parsed_lines
        before = before_code.to_s
        after = after_code.to_s
        return [] if before.empty? && after.empty?

        before += "\n" unless before.end_with?("\n")
        after  += "\n" unless after.end_with?("\n")

        parse_unified_diff(unified_diff(before, after))
      end

      def render(view, state)
        view.adapter.render_diff_block(view, self, state)
      end

      private

      CONTEXT_LINES = 3

      if RUBY_ENGINE == "opal"
        # jsdiff, so the browser never needs a diff(1) binary it cannot have.
        #
        # structuredPatch rather than createPatch: the latter prepends an
        # Index:/=== header that the server-side output has no equivalent for,
        # and stripping a fixed number of lines back off is the kind of thing
        # that breaks quietly. Building the unified text from the hunks keeps
        # both engines feeding #parse_unified_diff the same shape.
        #
        # "\ No newline at end of file" markers are dropped -- they are
        # annotations rather than content, and parse_unified_diff would read
        # the leading backslash as a context line.
        def unified_diff(before, after)
          # :nocov:
          %x{
            var patch = Diff.structuredPatch("", "", #{before}, #{after}, "", "",
                                             { context: #{CONTEXT_LINES} });
            var out = [];
            patch.hunks.forEach(function(h) {
              out.push("@@ -" + h.oldStart + "," + h.oldLines +
                       " +" + h.newStart + "," + h.newLines + " @@");
              h.lines.forEach(function(l) {
                if (l.charAt(0) !== "\\\\") out.push(l);
              });
            });
            return out.length ? out.join("\n") + "\n" : "";
          }
          # :nocov:
        end
      else
        def unified_diff(before, after)
          Diffy::Diff.new(before, after, context: CONTEXT_LINES).to_s(:text)
        end
      end

      HUNK_HEADER_RE = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.freeze

      def parse_unified_diff(text)
        lines = []
        old_line = 1
        new_line = 1

        text.each_line do |raw_line|
          line = raw_line.chomp

          if (m = HUNK_HEADER_RE.match(line))
            old_line = m[1].to_i
            new_line = m[2].to_i
            lines << DiffLine.new(type: :hunk_header, old_num: nil, new_num: nil, prefix: "@@", content: line)
            next
          end

          next if line.start_with?("---", "+++")

          prefix = line[0] || " "
          content = line[1..] || ""

          case prefix
          when "-"
            lines << DiffLine.new(type: :removed, old_num: old_line, new_num: nil, prefix: "-", content: content)
            old_line += 1
          when "+"
            lines << DiffLine.new(type: :added, old_num: nil, new_num: new_line, prefix: "+", content: content)
            new_line += 1
          else
            lines << DiffLine.new(type: :context, old_num: old_line, new_num: new_line, prefix: " ", content: content)
            old_line += 1
            new_line += 1
          end
        end

        lines
      end
    end
  end
end
