# frozen_string_literal: true

# StreamWeaver University -- step 4's growing-doc appender
# (story: step-4-growing-doc).
#
# Pushes to one canvas session four times in a row, each push carrying
# everything before it plus one more section, with a visible pause in
# between so the pane grows into a real document while you watch. The
# sections are chosen to show doc features a terminal has no answer for --
# a doc header with an outline, a two-column section, syntax-highlighted
# code, a callout, and a rendered diagram -- and every one of them is a
# component `streamweaver org-export` recognizes natively, so the file the
# user saves at the end survives the round trip step 5 puts it through.
#
# Content-only DSL throughout: no buttons (disc-095 -- canvas-read's
# controls grey out and do nothing, so a doc meant to be reviewed there
# must not lean on any) and no chart shorthands (disc-094 -- `streamweaver
# export` drops Chart.js for those).
#
# Ships inside the stream_weaver gem, so a fresh `gem install stream_weaver`
# already has it on the load path -- no path to type, no home directory to
# know about:
#
#   ruby -e "require 'stream_weaver'; require 'stream_weaver/university/scripts/growing_doc'" SESSION_NAME
#
# SESSION_NAME (first ARGV, default "doc-demo") must already be open --
# `streamweaver panel SESSION_NAME --theme=doc` first, so there's a pane to
# watch grow. Pause between pushes is STREAMWEAVER_GROWING_DOC_PAUSE
# seconds (default 3; specs override it to run fast).

require 'stream_weaver/canvas/client'

module StreamWeaver
  module University
    module Scripts
      module GrowingDoc
        OPENING = <<~RUBY
          doc_header(
            eyebrow: "StreamWeaver University · Step 4",
            title: "A doc that writes itself",
            pills: [{ text: "Live" }, "written by a script, while you watch"]
          )

          md "A script is writing this document into your pane, one push at a time. Each push carries everything before it plus one new section, so the page grows instead of blinking. Watch the outline on the left fill in as it goes."
        RUBY

        COMPARE = <<~RUBY
          doc_section_header "01", "Terminal vs canvas", id: "compare"

          comparison(before_label: "What a terminal can do", after_label: "What this pane adds") do
            before do
              md "- One column of text, redrawn top to bottom\\n- Code and prose look the same\\n- A diagram is ASCII art, or nothing\\n- Scrollback is the only memory"
            end
            after do
              md "- A laid-out document with its own outline\\n- Syntax-highlighted code beside prose\\n- Real diagrams, rendered\\n- One click away from a file you keep"
            end
          end
        RUBY

        PUSH = <<~RUBY
          doc_section_header "02", "The push itself", id: "push"

          md "Every section you have watched appear arrived through the same short loop. No server restart, no page reload, no editor open anywhere:"

          code_block(<<~SNIPPET, lang: "ruby")
            stages.each do |stage|
              body << stage
              Canvas::Client.send_message(
                Canvas::Protocol::Messages.push(session, body, source_dir: nil)
              )
              sleep 3
            end
          SNIPPET

          callout(variant: :tip, title: "Whole document, every time") do
            md "Each push carries the entire document, not just the new part. That is why the earlier sections are still sitting there -- and why the last push is a complete, self-contained file you can save and reopen."
          end
        RUBY

        FLOW = <<~RUBY
          doc_section_header "03", "Where it goes next", id: "flow"

          mermaid <<~DIAGRAM
            graph LR
              A["growing_doc.rb"] -->|"4 pushes"| B["canvas bridge"]
              B --> C["this pane"]
              C -->|"Save as doc"| D["docs/streamweaver_canvas/*.rb"]
              D -->|"org-export"| E["a plain .org file"]
          DIAGRAM

          md "Everything above lives only as long as the canvas bridge does. The floating **Save as doc** button at the bottom right is what turns it into a file -- and that file is what step 5 takes with it."
        RUBY

        # Each stage appends to the running document; `toc` is the outline
        # entry that stage introduces (nil for the opening, which has no
        # section of its own). The sidebar is rebuilt from the entries so
        # far on every push, so it never links at an anchor that has not
        # been pushed yet.
        STAGES = [
          { toc: nil, dsl: OPENING },
          { toc: { id: 'compare', label: 'Terminal vs canvas' }, dsl: COMPARE },
          { toc: { id: 'push', label: 'The push itself' }, dsl: PUSH },
          { toc: { id: 'flow', label: 'Where it goes next' }, dsl: FLOW }
        ].freeze

        def self.run!(session_name: ARGV.first || 'doc-demo',
                      pause: Float(ENV.fetch('STREAMWEAVER_GROWING_DOC_PAUSE', 3)))
          ::StreamWeaver::Canvas::Client.ensure_bridge_running
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.create(session_name, layout: :fluid, theme: :doc)
          )

          toc = []
          body = +''
          STAGES.each_with_index do |stage, i|
            toc << stage[:toc] if stage[:toc]
            body << stage[:dsl] << "\n"
            ::StreamWeaver::Canvas::Client.send_message(
              ::StreamWeaver::Canvas::Protocol::Messages.push(session_name, document(toc, body), source_dir: nil)
            )
            sleep(pause) unless i == STAGES.length - 1
          end
        rescue ::StreamWeaver::Canvas::Client::NotRunningError, ::StreamWeaver::Canvas::Client::ConnectionError => e
          warn "growing_doc: could not reach the canvas bridge (#{e.message}) -- " \
               "run `streamweaver panel #{session_name} --theme=doc` first"
        end

        # One flat DSL body: a sidebar_toc of the sections pushed so far,
        # then everything accumulated. Flat and one-statement-per-component
        # on purpose -- `streamweaver org-export`'s verbatim-source recovery
        # relies on that 1:1 correspondence (lib/stream_weaver/org/writer.rb,
        # #build_raw_sources).
        def self.document(toc, body)
          return body if toc.empty?

          "sidebar_toc sections: #{toc.inspect}\n\n#{body}"
        end
      end
    end
  end
end

StreamWeaver::University::Scripts::GrowingDoc.run!
