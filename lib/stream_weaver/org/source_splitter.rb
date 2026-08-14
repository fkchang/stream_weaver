# frozen_string_literal: true

require "ripper"

module StreamWeaver
  module Org
    # Splits DSL source text into its top-level statements, each as a
    # literal source-text slice, using Ripper for grammar-accurate
    # boundaries -- correctly distinguishes a modifier-if ("md \"x\" if
    # flag", one statement) from a block-if, and isn't confused by heredoc
    # bodies or nested do..end blocks the way a naive newline/bracket-depth
    # split would be.
    #
    # Used by Writer to recover a genuinely verbatim source span for the
    # raw-passthrough escape hatch (see Writer#raw_passthrough), when the
    # top-level statement <-> component correspondence is unambiguous.
    module SourceSplitter
      # Returns an array of source-text strings, one per top-level
      # statement, in document order. Returns nil if `source` doesn't parse
      # (callers should already have proven it parses -- Writer only calls
      # this after RecordingContext's own instance_eval succeeded -- so this
      # is a defensive fallback, not an expected path).
      def self.top_level_statements(source)
        sexp = Ripper.sexp(source)
        return nil unless sexp

        # Empty (or whitespace/comment-only) source parses to a single
        # synthetic :void_stmt node with no position of its own.
        stmts = sexp[1]
        return [] if stmts == [[:void_stmt]] || stmts.empty?

        lines = source.lines
        starts = stmts.map { |s| start_line(s) }
        starts.each_with_index.map do |line, i|
          end_line = i + 1 < starts.length ? starts[i + 1] - 1 : lines.length
          span = lines[(line - 1)...end_line]
          span.pop while span.last&.strip == ""
          span.join.chomp
        end
      end

      # Recursively finds the line number of the leftmost terminal token in
      # a Ripper sexp subtree (as returned by Ripper.sexp, which -- unlike
      # bare Ripper::SexpBuilder -- both reliably signals a syntax error
      # (nil) and flattens :program's body into a plain array). Terminal
      # (scanner-event) nodes are 3-element arrays whose last element is a
      # [lineno, column] pair; composite (parser-event) nodes have no
      # position of their own -- the position comes from the earliest
      # terminal nested inside.
      def self.start_line(node, best = nil)
        return best unless node.is_a?(Array)

        if node.length == 3 && node[2].is_a?(Array) && node[2].length == 2 && node[2].all? { |x| x.is_a?(Integer) }
          pos = node[2][0]
          best = pos if best.nil? || pos < best
        end
        node.each { |n| best = start_line(n, best) }
        best
      end
      private_class_method :start_line
    end
  end
end
