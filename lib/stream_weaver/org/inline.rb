# frozen_string_literal: true

module StreamWeaver
  module Org
    # Bidirectional inline markup conversion between markdown (as used inside
    # `md "..."` DSL calls) and org-mode inline syntax. Boundary-aware: a
    # delimiter only opens/closes a span when flanked the way org itself
    # requires, so literal characters in file paths ("app/admin/cms/foo.rb")
    # or "X / Y" phrasing are never misread as emphasis markers.
    module Inline
      PRE  = /(?:\A|[\s\("])/.source
      POST = /(?:\z|[\s\.,;:!?\)"])/.source

      # Lookaround (not capturing) so the boundary character is never
      # "consumed" -- otherwise two adjacent spans sharing one space between
      # them ("*a* *b*") corrupt into one mismatched span, since the shared
      # space gets eaten as POST of the first match and is then unavailable
      # as PRE for the second. Content also excludes the delimiter itself
      # (not just the first/last char) -- otherwise a lazy .*? can bridge
      # across two separate same-delimiter spans into one corrupted match
      # spanning from the first opener to the last closer.
      def self.span(delim)
        d = Regexp.escape(delim)
        /(?<=#{PRE})#{d}([^\s#{d}](?:[^#{d}]*?[^\s#{d}])?)#{d}(?=#{POST})/m
      end

      BOLD_MD   = span("**")
      ITALIC_MD = span("*")
      CODE_MD   = span("`")
      LINK_MD   = /\[([^\]]+)\]\(#([^\)]+)\)/

      BOLD_ORG   = span("*")
      ITALIC_ORG = span("/")
      CODE_ORG   = span("=")
      LINK_ORG   = /\[\[#([^\]]+)\]\[([^\]]+)\]\]/

      PLACEHOLDER = "\x00CODE%d\x00"
      PLACEHOLDER_RE = /\x00CODE(\d+)\x00/

      def self.md_to_org(text)
        text, protected_spans = extract(text, CODE_MD)
        text = text.gsub(LINK_MD) { "[[##{$2}][#{$1}]]" }
        text = text.gsub(ITALIC_MD) { "/#{$1}/" }
        text = text.gsub(BOLD_MD) { "*#{$1}*" }
        text = text.gsub(/~(?=\d)/, "≈")
        restore(text, protected_spans) { |content| "=#{content}=" }
      end

      def self.org_to_md(text)
        text, protected_spans = extract(text, CODE_ORG)
        text = text.gsub(LINK_ORG) { "[#{$2}](##{$1})" }
        text = text.gsub(BOLD_ORG) { "**#{$1}**" }
        text = text.gsub(ITALIC_ORG) { "*#{$1}*" }
        restore(text, protected_spans) { |content| "`#{content}`" }
      end

      # Replaces every code/verbatim span with a placeholder token so later
      # passes (link/bold/italic/tilde) never see -- and can't corrupt --
      # content that's supposed to stay literal.
      def self.extract(text, code_pattern)
        spans = []
        replaced = text.gsub(code_pattern) do
          spans << $1
          PLACEHOLDER % (spans.length - 1)
        end
        [replaced, spans]
      end

      def self.restore(text, spans)
        text.gsub(PLACEHOLDER_RE) { yield spans[$1.to_i] }
      end
    end
  end
end
