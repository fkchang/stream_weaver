# frozen_string_literal: true

require_relative "inline"

module StreamWeaver
  module Org
    # Converts StreamWeaver-flavored org text back into DSL body text (the
    # same shape canvas-read already instance_evals). See
    # docs/superpowers/specs/2026-08-13-org-doc-format-design.md for the
    # format this parses.
    #
    # Verified 2026-08-13 against synthetic scenarios AND the real,
    # untracked example doc that motivated this feature, covering:
    # infinite-loop safety on unterminated src/quote/property-drawer
    # blocks, standalone callout/card/comparison (no headline) NOT
    # misclassified as doc_header, a card with a nested mermaid src block
    # emitting both a real `mermaid` call and surrounding `md` prose (not
    # flattened), preamble lines never leaking as stray `md` calls,
    # TOC_LABEL overrides, table inline-emphasis conversion, a
    # multi-paragraph `md` block staying as ONE call (not split on its
    # internal blank line), a `markdown: false` table's literal
    # emphasis-like characters surviving the round trip untouched, and a
    # full realistic document producing syntactically valid Ruby end to end.
    class Reader
      VARIANT_EMOJI = {
        "⚠️" => :warning,
        "✅" => :success,
        "💡" => :tip,
        "ℹ️" => :info,
        "⚖️" => :decision,
        "❌" => :error,
        "🔺" => :risk
      }.freeze

      HEADLINE_RE = /\A(\*+)\s+(\d+(?:\.\d+)*)\s+(.+)\z/
      SRC_BEGIN_RE = /\A#\+begin_src(?:\s+(.*))?\z/i
      # Any "#+KEY: value" org keyword line, not just the two StreamWeaver reads
      # itself: an unrecognized keyword used to fall through to the generic
      # paragraph branch and derail whatever followed it, so a doc carrying a
      # plain #+AUTHOR:/#+DATE:/#+FILETAGS: -- or the #+TYPE: a UKF wiki member
      # needs to be indexed -- failed to parse at all. Two exclusions: block
      # directives (#+begin_src/#+begin_quote and their #+end_ partners, which
      # carry no colon anyway, kept explicit for the reader) and
      # #+ATTR_STREAMWEAVER:, which is consulted a few lines LATER (see #chunks)
      # -- matching it here would consume it as preamble and silently drop the
      # attribute from the table it belongs to.
      PREAMBLE_RE = /\A#\+(?!begin_|end_|ATTR_STREAMWEAVER:)\w+:/i
      ATTR_RE = /\A#\+ATTR_STREAMWEAVER:\s*(.*)\z/i

      def self.to_dsl(org_text)
        new(org_text).call
      end

      # True when `text` carries the `#+STREAMWEAVER_DSL:` marker within its
      # first 10 lines -- the same content-based check content.js/sandbox.js
      # already do client-side (there's no way to share the regex literally
      # across Ruby and JS, so each surface keeps its own copy; this is the
      # canonical Ruby-side one, for anything server-side that needs to tell
      # a StreamWeaver org doc apart from plain org/prose before parsing it).
      # Looser than the `\s*1\s*\z`-anchored check `initialize` uses for its
      # own @streamweaver_document flag (any digit, no end anchor) so a
      # future version bump stays recognized here without an update.
      def self.streamweaver_org?(text)
        return false unless text.is_a?(String)

        text.each_line.first(10).any? { |line| line.match?(/\A#\+STREAMWEAVER_DSL:\s*\d+/i) }
      end

      def initialize(org_text)
        @lines = org_text.lines.map(&:chomp)

        title_line = @lines.find { |line| line.match?(/\A#\+TITLE:/i) }
        @title = title_line&.sub(/\A#\+TITLE:\s*/i, "")

        @streamweaver_document =
          @lines.any? { |line| line.match?(/\A#\+STREAMWEAVER_DSL:\s*1\s*\z/i) }
      end

      def call
        chunk_list = chunks

        # sidebar_toc is derived from depth-1 headlines, in document order,
        # using TOC_LABEL when present and falling back to the headline's
        # own title otherwise -- never hand-authored.
        toc_entries = chunk_list.filter_map do |chunk|
          next unless chunk[:type] == :headline && chunk[:depth] == 1

          { id: chunk.fetch(:custom_id), label: chunk[:toc_label] || chunk.fetch(:title) }
        end

        output = []
        header_insert_at = 0
        unless toc_entries.empty?
          entries = toc_entries.map { |e| "{ id: #{e[:id].inspect}, label: #{e[:label].inspect} }" }
          output << "sidebar_toc sections: [#{entries.join(', ')}]"
          header_insert_at = 1
        end

        seen_headline = false
        emitted_doc_header = false
        i = 0

        while i < chunk_list.length
          chunk = chunk_list[i]

          case chunk[:type]
          when :headline
            seen_headline = true
            output << emit_headline(chunk)

          when :quote
            # Rule 1 (position, NOT content shape -- see doc_header_chunk?
            # below for why): only the doc_header preamble block qualifies,
            # never an arbitrary headline-less callout/card.
            if !seen_headline && !emitted_doc_header && doc_header_chunk?(chunk, i)
              output << emit_doc_header(chunk)
              emitted_doc_header = true
            else
              marker = chunk[:lines].first.to_s
              body = chunk[:lines].drop(1)

              # Rule 2: before/after comparison pairing.
              if (match = marker.match(/\A\*◀ Before — (.+)\*\z/))
                following = chunk_list[i + 1]
                after_marker = following[:lines].first.to_s if following&.dig(:type) == :quote
                after_match = after_marker&.match(/\A\*▶ After — (.+)\*\z/)
                raise ArgumentError, "malformed comparison: before block is not followed by an after block" unless after_match

                output << emit_comparison(match[1], body, after_match[1], following[:lines].drop(1))
                i += 1 # consume the paired 'after' chunk too
              elsif marker.match?(/\A\*▶ After — /)
                raise ArgumentError, "malformed comparison: after block has no preceding before block"
              # Rule 3: reserved-emoji callout.
              elsif (match = callout_marker_match(marker))
                output << emit_callout(VARIANT_EMOJI.fetch(match[1]), match[2], body)
              # Rule 4: card fallback.
              else
                output << emit_card(marker, body)
              end
            end

          else
            output << emit(chunk)
          end

          i += 1
        end

        # A doc_header with neither eyebrow nor pills has no quote block at
        # all (Writer only emits one when it has content to put in it), so
        # the loop above never gets a chance to match it -- synthesize a
        # title-only call here instead, in the position it would have
        # occupied (right after sidebar_toc, before everything else).
        if @streamweaver_document && @title && !emitted_doc_header
          output.insert(header_insert_at, emit_doc_header(nil))
        end

        output.reject!(&:empty?)
        output.empty? ? "" : "#{output.join("\n\n")}\n"
      end

      private

      # Splits org text into typed chunks. Every delimited construct
      # (headline property drawer, quote block, src block) has an EOF guard
      # that raises ArgumentError instead of looping forever when
      # unterminated -- this is the fix for the infinite-loop bug.
      #
      # Callable recursively on a sub-slice of lines (see emit_body) so a
      # quote block's own body can be re-chunked to recognize a nested src
      # block instead of being flattened into one md call.
      def chunks(lines = @lines)
        result = []
        i = 0
        pending_attr = nil

        while i < lines.length
          line = lines[i]

          if line.empty?
            i += 1
            next
          end

          # Preamble metadata lines are consumed by #initialize and must
          # never fall through to the generic paragraph branch -- this is
          # the fix for the preamble-leak bug.
          if line.match?(PREAMBLE_RE)
            i += 1
            next
          end

          # #+ATTR_STREAMWEAVER: :markdown nil marks the very next table as
          # markdown: false -- attach it to that table chunk (see emit_table)
          # rather than treating it as prose. Any other chunk type clears a
          # stale pending attribute rather than silently misapplying it.
          if (attr_match = line.match(ATTR_RE))
            pending_attr = attr_match[1]
            i += 1
            next
          end

          if (match = line.match(HEADLINE_RE))
            depth = match[1].length
            number = match[2]
            title = match[3]
            custom_id = nil
            toc_label = nil
            i += 1

            if lines[i] == ":PROPERTIES:"
              i += 1
              while i < lines.length && lines[i] != ":END:"
                property = lines[i]
                custom_id = $1 if property =~ /\A:CUSTOM_ID:\s*(.+)\z/
                toc_label = $1 if property =~ /\A:TOC_LABEL:\s*(.+)\z/
                i += 1
              end
              raise ArgumentError, "unterminated property drawer for #{number}" if i >= lines.length

              i += 1
            end
            raise ArgumentError, "headline #{number.inspect} has no CUSTOM_ID" unless custom_id

            result << { type: :headline, depth: depth, number: number, title: title, custom_id: custom_id, toc_label: toc_label }
            pending_attr = nil
            next
          end

          if line.casecmp?("#+begin_quote")
            body = []
            i += 1
            while i < lines.length && !lines[i].casecmp?("#+end_quote")
              body << lines[i]
              i += 1
            end
            raise ArgumentError, "unterminated quote block" if i >= lines.length

            i += 1
            result << { type: :quote, lines: body }
            pending_attr = nil
            next
          end

          if (match = line.match(SRC_BEGIN_RE))
            header = match[1].to_s.strip
            body = []
            i += 1
            while i < lines.length && !lines[i].casecmp?("#+end_src")
              body << lines[i]
              i += 1
            end
            raise ArgumentError, "unterminated source block" if i >= lines.length

            i += 1
            result << { type: :src, header: header, lines: body }
            pending_attr = nil
            next
          end

          if line.start_with?("|")
            rows = []
            while i < lines.length && lines[i].start_with?("|")
              rows << lines[i]
              i += 1
            end
            result << { type: :table, rows: rows, attr: pending_attr }
            pending_attr = nil
            next
          end

          # Paragraph collection: a blank line does NOT always end a
          # paragraph chunk (fix for the multi-paragraph md-splitting bug —
          # see revision note). If, after one or more blank lines, more
          # plain text follows rather than a structural element, the blank
          # line was an internal paragraph break within a single logical
          # prose block (one `md` call with multiple <p> tags), not a
          # component boundary -- keep collecting instead of splitting.
          paragraph = []
          loop do
            break if i >= lines.length || structural_start?(lines[i])

            if lines[i].empty?
              j = i
              j += 1 while j < lines.length && lines[j].empty?
              break if j >= lines.length || structural_start?(lines[j])

              paragraph << "" # normalize any blank-line run to one separator
              i = j
              next
            end

            paragraph << lines[i]
            i += 1
          end
          raise ArgumentError, "unexpected Org directive: #{lines[i].inspect}" if paragraph.empty?

          result << { type: :paragraph, lines: paragraph }
          pending_attr = nil # a paragraph between an ATTR line and a later,
          # unrelated table must not let that table inherit the attribute --
          # only a directly-adjacent table consumes it (see #emit_table).
        end

        result
      end

      def structural_start?(line)
        line.match?(HEADLINE_RE) || line.casecmp?("#+begin_quote") ||
          line.match?(SRC_BEGIN_RE) || line.start_with?("|") ||
          line.match?(PREAMBLE_RE) || line.match?(ATTR_RE)
      end

      def emit(chunk)
        case chunk.fetch(:type)
        when :paragraph then emit_paragraph(chunk)
        when :table     then emit_table(chunk)
        when :src       then emit_src(chunk)
        when :headline  then emit_headline(chunk)
        else raise ArgumentError, "cannot directly emit #{chunk[:type].inspect}"
        end
      end

      def emit_headline(chunk)
        "doc_section_header #{chunk[:number].inspect}, #{chunk[:title].inspect}, id: #{chunk[:custom_id].inspect}"
      end

      def emit_paragraph(chunk)
        text = Inline.org_to_md(chunk[:lines].join("\n"))
        heredoc("md ", text, "MD")
      end

      def emit_table(chunk)
        # markdown: true is the default (absent #+ATTR_STREAMWEAVER: :markdown
        # nil) -- only that explicit marker (see #chunks) means the Writer
        # copied these cells byte-identical from a markdown: false table, so
        # skip Inline.org_to_md for them too. Forcing markdown: true
        # unconditionally (an earlier version of this method did) silently
        # reinterprets literal characters -- e.g. "5 min *after* the
        # failure" -- as real emphasis on the way back. Confirmed against
        # real content; see the design spec's Tables section.
        markdown = !(chunk[:attr].to_s =~ /:markdown\s+nil/)
        rows = chunk[:rows].reject { |row| table_separator?(row) }.map { |row| parse_table_row(row) }
        rows = rows.map { |row| row.map { |cell| markdown ? Inline.org_to_md(cell) : cell } }
        raise ArgumentError, "table has no header row" if rows.empty?

        headers, *data = rows
        data_dsl = data.map { |row| "    [#{row.map(&:inspect).join(', ')}]" }.join(",\n")
        body = data_dsl.empty? ? "  rows: []" : "  rows: [\n#{data_dsl}\n  ]"
        markdown_line = markdown ? "  markdown: true,\n" : ""

        <<~RUBY.chomp
          table(
          #{markdown_line}  headers: [#{headers.map(&:inspect).join(', ')}],
          #{body}
          )
        RUBY
      end

      def emit_src(chunk)
        tokens = chunk[:header].split(/\s+/)
        lang = tokens.shift
        lang = "text" if lang.nil? || lang.empty?
        code = chunk[:lines].join("\n")

        # Writer#raw_passthrough's escape hatch (see also its NO_OP_STATEMENT_RE
        # comment): content here is either the verbatim original DSL
        # statement(s) or a "# unrecognized component" comment -- either way,
        # real Ruby text meant to be spliced back in AS-IS, not wrapped in a
        # code_block(...) call (which would misrender it: a fake code block
        # with Prism.js chrome around what used to be, say, a `header1` call).
        return code if tokens.each_cons(2).any? { |key, value| key == ":streamweaver-raw" && value == "t" }

        zoom = tokens.each_cons(2).any? { |key, value| key == ":zoom" && value == "t" }

        if lang == "mermaid"
          options = zoom ? ", zoom: true" : ""
          heredoc("mermaid ", code, "MERMAID", suffix: options)
        else
          heredoc("code_block(", code, "TXT", suffix: ", lang: #{lang.inspect})")
        end
      end

      # chunk is nil for a doc_header with neither eyebrow nor pills (see the
      # synthesis call in #call) -- title-only in that case. Otherwise,
      # each non-empty line is classified by its OWN shape rather than a
      # fixed line position, so eyebrow-only, pills-only, and eyebrow+pills
      # all parse correctly regardless of which one is actually present.
      def emit_doc_header(chunk)
        eyebrow = nil
        pills = []

        if chunk
          chunk[:lines].reject(&:empty?).each do |line|
            if (match = line.match(%r{\A/(.*)/\z}))
              eyebrow = match[1]
            else
              pills.concat(line.split(" · ").map { |pill| format_pill(pill) })
            end
          end
        end

        <<~RUBY.chomp
          doc_header(
            title: #{@title.inspect},
            eyebrow: #{eyebrow.inspect},
            pills: [#{pills.join(', ')}]
          )
        RUBY
      end

      def format_pill(pill)
        if (match = pill.match(/\A\*\[([A-Za-z_]\w*)\]\s*(.+)\*\z/))
          "{ text: #{match[2].inspect}, variant: #{match[1].to_sym.inspect} }"
        else
          pill.inspect
        end
      end

      def emit_callout(variant, title, body_lines)
        <<~RUBY.chomp
          callout(variant: #{variant.inspect}, title: #{title.inspect}) do
          #{indent_block(emit_body(body_lines), 2)}
          end
        RUBY
      end

      def emit_card(marker, body_lines)
        match = marker.match(%r{\A\*\[([^\]]+)\]\s*(.+?)\*(?:\s*/\((.+)\)/)?\z})
        if match
          badge, title, meta = match[1], match[2], match[3]
        else
          match = marker.match(%r{\A\*(.+?)\*(?:\s*/\((.+)\)/)?\z})
          raise ArgumentError, "malformed card header: #{marker.inspect}" unless match

          badge, title, meta = nil, match[1], match[2]
        end

        arguments = [title.inspect]
        arguments << "badge: #{badge.inspect}" if badge
        arguments << "meta: #{meta.inspect}" if meta

        <<~RUBY.chomp
          card do
            card_header #{arguments.join(', ')}
            card_body do
          #{indent_block(emit_body(body_lines), 4)}
            end
          end
        RUBY
      end

      def emit_comparison(before_label, before_lines, after_label, after_lines)
        <<~RUBY.chomp
          comparison(
            before_label: #{before_label.inspect},
            after_label: #{after_label.inspect}
          ) do
            before do
          #{indent_block(emit_body(before_lines), 4)}
            end
            after do
          #{indent_block(emit_body(after_lines), 4)}
            end
          end
        RUBY
      end

      # THE fix for the nested-src-in-card bug: a quote block's body is not
      # intrinsically one flat markdown paragraph. Re-chunk it (recursing
      # into #chunks on just these lines) so a mermaid/code src block nested
      # inside a card or callout emits as a real mermaid/code_block call
      # alongside any surrounding md prose, instead of being swallowed into
      # one md heredoc.
      def emit_body(lines)
        chunks(lines).map do |chunk|
          case chunk[:type]
          when :paragraph, :table, :src then emit(chunk)
          else raise ArgumentError, "unsupported #{chunk[:type]} block inside quote body"
          end
        end.join("\n\n")
      end

      # THE fix for the doc_header misclassification bug. An earlier version
      # of this check used content shape alone (eyebrow-line vs. a leading
      # "*"), which is unreliable: a doc_header with no eyebrow whose pills
      # are all variant-tagged renders as "*[warn] Draft* · *[success] v2*"
      # -- syntactically a valid card marker, not just visually similar to
      # one. That ambiguity is irreducible from shape alone (real-content
      # check found it crashing/corrupting via emit_card on exactly this
      # shape). Position is the reliable signal instead: Writer never emits
      # ANY body content before doc_header's own preamble block, so
      # whenever one exists it is unconditionally the very first chunk in
      # the whole document (index 0) -- no other quote block can ever
      # occupy that position while a title is set. Callout/comparison
      # markers still win even at position 0, since they use reserved
      # syntax (a fixed emoji set, "◀ Before —"/"▶ After —") that
      # eyebrow/pills text can never produce.
      #
      # Known limitation this doesn't resolve: a title-only doc_header (no
      # eyebrow/pills, so no preamble block at all -- see the post-loop
      # synthesis in #call) whose very first BODY element, before any
      # section headline, is itself a genuine standalone card. That's an
      # unusual, non-idiomatic document shape (cards normally live inside a
      # section, after a headline), so left unresolved.
      def doc_header_chunk?(chunk, index)
        return false unless @streamweaver_document && @title && index.zero?

        first_content_line = chunk[:lines].find { |line| !line.empty? }
        return false unless first_content_line

        !callout_marker_match(first_content_line) && !first_content_line.match?(/\A\*(?:◀|▶)\s/)
      end

      def callout_marker_match(marker)
        emoji_pattern = Regexp.union(VARIANT_EMOJI.keys)
        # Title is optional (match[2] is nil without one) -- a titleless
        # callout's marker is just "*<emoji>*", no trailing space (see
        # Writer#render_component).
        marker.match(/\A\*(#{emoji_pattern})(?:\s+(.+))?\*\z/)
      end

      def table_separator?(row)
        row.delete(" \t").match?(/\A\|[-+:|]+\|\z/)
      end

      def parse_table_row(row)
        row.sub(/\A\|/, "").sub(/\|\z/, "").split("|", -1).map(&:strip)
      end

      # Heredoc-with-trailing-args generation: `, zoom: true` / `, lang: ...)`
      # belong on the OPENING `<<~TAG` line, never appended after the bare
      # closing tag -- get this backwards and the emitted Ruby won't parse.
      # Also guards against a body line that happens to equal the tag itself
      # (which would terminate the heredoc early) by picking a fresh tag.
      def heredoc(prefix, text, base_tag, suffix: "")
        tag = unique_heredoc_tag(base_tag, text)
        content = text.split("\n", -1)
        content.pop if content.last == ""
        content = [""] if content.empty?

        "#{prefix}<<~#{tag}#{suffix}\n#{content.map { |line| line.empty? ? line : "  #{line}" }.join("\n")}\n#{tag}"
      end

      def unique_heredoc_tag(base_tag, text)
        occupied = text.lines.map(&:chomp)
        candidate = base_tag
        sequence = 1
        while occupied.include?(candidate)
          candidate = "#{base_tag}_#{sequence}"
          sequence += 1
        end
        candidate
      end

      def indent_block(text, width)
        pad = " " * width
        text.lines(chomp: true).map { |line| "#{pad}#{line}" }.join("\n")
      end
    end
  end
end
