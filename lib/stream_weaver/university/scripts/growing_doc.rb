# frozen_string_literal: true

# StreamWeaver University -- step 4's growing-doc appender
# (story: step-4-growing-doc).
#
# Pushes to one canvas session six times in a row, each push carrying
# everything before it plus one more section, with a visible pause in
# between so the pane grows into a real document while you watch. Six
# sections is not decoration: below that the doc theme's sidebar outline has
# nothing worth showing, and round-5 UAT ended step 5 looking at a doc too
# short to demonstrate the nav it was supposed to demonstrate.
#
# The sections are chosen to show doc features a terminal has no answer for
# -- a doc header with an outline, a two-column section, syntax-highlighted
# code, a callout, a rendered diagram, a table -- and every one of them is a
# component `streamweaver org-export` recognizes natively, so the file the
# user saves at the end survives the round trip step 5 puts it through.
#
# Content-only DSL in the document itself: no buttons (disc-095 --
# canvas-read's controls grey out and do nothing, so a doc meant to be
# reviewed there must not lean on any) and no chart shorthands (disc-094 --
# `streamweaver export` drops Chart.js for those). The one exception is
# `--picker`, which appends a live form BELOW the document for the co-edit
# loop; that push is never saved.
#
# Ships inside the stream_weaver gem, so a fresh `gem install stream_weaver`
# already has it on the load path -- no path to type, no home directory to
# know about:
#
#   streamweaver panel doc-demo --theme=doc
#   ruby "$(streamweaver university-demo doc)" doc-demo
#
# SESSION_NAME (first ARGV, default "doc-demo") must already be open, so
# there's a pane to watch grow. Flags:
#
#   --save-as NAME   doc name to save under (default "university-doc")
#   --no-save        grow only; don't save
#   --extend=a,b     append these canned extension sections before saving
#   --picker         append the co-edit picker form and DON'T save
#
# Pause between pushes is STREAMWEAVER_GROWING_DOC_PAUSE seconds (default 3;
# specs override it to run fast).

require 'stream_weaver/canvas/client'

module StreamWeaver
  module University
    module Scripts
      module GrowingDoc
        # The name step 5 goes looking for. Deterministic on purpose: round-5
        # UAT made the user type a name into the Save dialog and then made
        # step 5 hunt for whatever they typed. The script saves under this
        # name itself; the user's own manual save is a bonus lap, not the
        # dependency.
        DEFAULT_DOC_NAME = 'university-doc'

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
              A["growing_doc.rb"] -->|"6 pushes"| B["canvas bridge"]
              B --> C["this pane"]
              C -->|"save-doc"| D["docs/streamweaver_canvas/*.rb"]
              D -->|"org-export"| E["a plain .org file"]
          DIAGRAM

          md "Everything above lives only as long as the canvas bridge does. The save is what turns it into a file -- and that file is what step 5 takes with it."
        RUBY

        SURVIVES = <<~RUBY
          doc_section_header "04", "What survives the export", id: "survives"

          md "A canvas doc is only portable if `streamweaver org-export` recognizes every component in it. These are the ones this document is built from, and the reason it is built from exactly these:"

          table headers: ["Component", "Becomes", "Why it is in this doc"], rows: [
            ["doc_section_header", "A heading", "Becomes the outline, and the outline becomes the nav"],
            ["md", "Body text", "The safe body anywhere, including inside a callout"],
            ["comparison", "Two-column block", "Survives where a raw columns/column pair would not"],
            ["code_block", "#+begin_src", "Keeps its language, so the highlighting comes back"],
            ["callout", "Quote block", "Keeps its variant and its title"],
            ["mermaid", "#+begin_src mermaid", "The diagram source travels; the reader re-renders it"],
            ["table", "An org table", "Round-trips cell for cell -- including this one"]
          ]

          md "The `headers:`/`rows:` form is deliberate: it is the shape `org-export` can read back. An array of hashes renders identically in the pane and then leaves as an unrecognized block -- the kind of silent loss this section exists to warn you about."
        RUBY

        READBACK = <<~RUBY
          doc_section_header "05", "Reading it back", id: "readback"

          md "The saved `.rb` is the document, not a snapshot of it. `streamweaver canvas-read <file>` re-renders it with no live session behind it, and `streamweaver org-export <file>` writes the `.org` sibling that step 5 pushes to a gist."

          callout(variant: :info, title: "Content-only on purpose") do
            md "There is not one button in this document. Outside the live canvas -- in `canvas-read`, in an export, in the gist -- controls grey out and do nothing. A doc meant to travel is written to be read, not clicked."
          end
        RUBY

        LOOP = <<~RUBY
          doc_section_header "06", "The loop you are in", id: "loop"

          md "A script wrote the six sections above without asking you anything. That is the easy half. The interesting half is what happens next: your agent asks you what else the document should say, blocks until you answer, adds it, and saves again."

          code_block(<<~SNIPPET, lang: "text")
            agent  -> pushes doc + a form
            agent  -> canvas-wait  (blocked, in the background)
            you    -> pick a section, or describe one
            agent  -> appends it, re-pushes, re-saves
            repeat until you say "done"
          SNIPPET

          md "That is co-editing a document with an agent, in a pane, with no file open on either side."
        RUBY

        # Each stage appends to the running document; `toc` is the outline
        # entry that stage introduces (nil for the opening, which has no
        # section of its own). The sidebar is rebuilt from the entries so
        # far on every push, so it never links at an anchor that has not
        # been pushed yet. Six entries is the floor for a sidebar worth
        # showing -- do not drop below it.
        STAGES = [
          { toc: nil, dsl: OPENING },
          { toc: { id: 'compare', label: 'Terminal vs canvas' }, dsl: COMPARE },
          { toc: { id: 'push', label: 'The push itself' }, dsl: PUSH },
          { toc: { id: 'flow', label: 'Where it goes next' }, dsl: FLOW },
          { toc: { id: 'survives', label: 'What survives the export' }, dsl: SURVIVES },
          { toc: { id: 'readback', label: 'Reading it back' }, dsl: READBACK },
          { toc: { id: 'loop', label: 'The loop you are in' }, dsl: LOOP }
        ].freeze

        # The co-edit loop's menu. Every option is a component the org
        # writer recognizes natively (see the table in section 04) -- a
        # timeline or a kpi_dashboard would look fine in the pane and then
        # fall out of the export as an unrecognized placeholder, which is
        # exactly the trap this course spends step 5 avoiding.
        EXTENSIONS = {
          'timeline' => {
            label: 'A release timeline (as an org-safe table)',
            toc: { id: 'timeline', label: 'How it got here' },
            dsl: <<~RUBY
              doc_section_header "07", "How it got here", id: "timeline"

              table headers: ["Milestone", "What changed"], rows: [
                ["First push", "One session, one DSL string, one pane"],
                ["Growing docs", "Repeated pushes that accumulate instead of replacing"],
                ["Save as doc", "A canvas becomes a git-tracked file"],
                ["org-export", "The file becomes plain text anyone can read"]
              ]
            RUBY
          },
          'tradeoffs' => {
            label: 'A before/after comparison of the two ways to share a doc',
            toc: { id: 'tradeoffs', label: 'Two ways to share it' },
            dsl: <<~RUBY
              doc_section_header "07", "Two ways to share it", id: "tradeoffs"

              comparison(before_label: "Paste the terminal output", after_label: "Send the .org file") do
                before do
                  md "- Loses every heading\\n- Code and prose look identical\\n- Diagrams do not survive at all\\n- Unreadable in a week"
                end
                after do
                  md "- Keeps the outline and the nav\\n- Code keeps its language\\n- Diagrams re-render for the reader\\n- Opens in any editor, forever"
                end
              end
            RUBY
          },
          'cheatsheet' => {
            label: 'A cheat-sheet callout of the commands used so far',
            toc: { id: 'cheatsheet', label: 'Commands used so far' },
            dsl: <<~RUBY
              doc_section_header "07", "Commands used so far", id: "cheatsheet"

              callout(variant: :tip, title: "The whole course, in six commands") do
                md "- `streamweaver panel <name>` -- open a pane\\n- `streamweaver canvas-push <name>` -- draw into it\\n- `streamweaver canvas-wait <name>` -- block on a human\\n- `streamweaver canvas-list` / `canvas-close` -- housekeeping\\n- `streamweaver org-export <file>` -- make it portable\\n- `streamweaver canvas-read <file>` -- read it back later"
              end
            RUBY
          },
          'architecture' => {
            label: 'A diagram of where a saved doc can travel next',
            toc: { id: 'architecture', label: 'Where a saved doc travels' },
            dsl: <<~RUBY
              doc_section_header "07", "Where a saved doc travels", id: "architecture"

              mermaid <<~DIAGRAM
                graph TD
                  F["docs/streamweaver_canvas/university-doc.rb"]
                  F -->|"canvas-read"| R["re-rendered, no live session"]
                  F -->|"org-export"| O["university-doc.org"]
                  O -->|"gh gist create"| G["a gist anyone can open"]
                  G -->|"Doc Viewer extension"| V["rendered, with nav and diagrams"]
              DIAGRAM
            RUBY
          }
        }.freeze

        # Appended BELOW the finished document for the co-edit loop. Never
        # saved -- `--picker` and saving are mutually exclusive, so no
        # control ever lands in the file step 5 carries out.
        def self.picker_dsl
          options = EXTENSIONS.map { |key, ext| "#{key} -- #{ext[:label]}" }
          <<~RUBY
            doc_section_header "--", "Your turn", id: "your-turn"

            callout(variant: :warning, title: "Your agent is waiting on you") do
              md "This is the same blocking form from step 3, doing a real job. Your agent is sitting inside `streamweaver canvas-wait` and will not move until you answer."
            end

            radio_group :section, #{(options + ['done -- the doc is finished, move on']).inspect}

            md "**Or describe a section in your own words.** If you type something here your agent writes that section itself instead of using a canned one."

            text_field :describe, placeholder: "e.g. a table of every canvas command and what it costs"

            button "Add it"
          RUBY
        end

        def self.run!(argv = ARGV)
          session_name = argv.find { |a| !a.start_with?('-') } || 'doc-demo'
          pause = Float(ENV.fetch('STREAMWEAVER_GROWING_DOC_PAUSE', 3))
          picker = argv.include?('--picker')
          save = !picker && !argv.include?('--no-save')
          doc_name = argv.grep(/\A--save-as=/) { |a| a.split('=', 2).last }.first ||
                     (argv.include?('--save-as') ? argv[argv.index('--save-as') + 1] : nil) ||
                     DEFAULT_DOC_NAME
          extend_keys = argv.grep(/\A--extend=/) { |a| a.split('=', 2).last }
                            .flat_map { |v| v.split(',') }
                            .map(&:strip).reject(&:empty?)

          bridge = ::StreamWeaver::Canvas::Client.ensure_bridge_running
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.create(session_name, layout: :fluid, theme: :doc)
          )

          toc = []
          body = +''

          # Growing the base document is skipped once extensions are in play:
          # a re-push during the co-edit loop must land in one beat, not
          # re-run the whole six-push show the user already watched.
          growing = extend_keys.empty? && !picker
          STAGES.each_with_index do |stage, i|
            toc << stage[:toc] if stage[:toc]
            body << stage[:dsl] << "\n"
            next unless growing

            push(session_name, document(toc, body))
            sleep(pause) unless i == STAGES.length - 1
          end

          extend_keys.each do |key|
            ext = EXTENSIONS[key]
            unless ext
              warn "growing_doc: no such extension #{key.inspect} (have: #{EXTENSIONS.keys.join(', ')})"
              next
            end
            toc << ext[:toc]
            body << ext[:dsl] << "\n"
          end

          document_body = document(toc, body)
          push(session_name, picker ? "#{document_body}\n#{picker_dsl}" : document_body)

          if picker
            puts "Pushed the document plus the co-edit picker to '#{session_name}'. " \
                 "Now block on it -- in the BACKGROUND, not the foreground: " \
                 "streamweaver canvas-wait #{session_name}"
          elsif save
            path = save_doc(bridge, session_name, doc_name)
            puts(path ? "Saved: #{path}" : "Saved as '#{doc_name}' (the bridge did not report a path).")
          end
        rescue ::StreamWeaver::Canvas::Client::NotRunningError,
               ::StreamWeaver::Canvas::Client::ConnectionError => e
          warn "growing_doc: could not reach the canvas bridge (#{e.message}) -- " \
               "run `streamweaver panel #{session_name} --theme=doc` first"
        end

        def self.push(session_name, dsl)
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.push(session_name, dsl, source_dir: nil)
          )
        end

        # The save the user used to have to do by hand. POSTs the session's
        # last-good DSL to the bridge's own `/canvas/:name/save-doc` -- the
        # exact endpoint the floating "Save as doc" button calls, so the
        # script and the button cannot diverge -- and returns the path the
        # bridge reports, which is the path step 5 needs and the one round-5
        # UAT made a human transcribe.
        def self.save_doc(bridge, session_name, doc_name)
          require 'net/http'
          require 'json'
          port = bridge && bridge[:port]
          unless port
            warn 'growing_doc: no bridge port reported; skipping save'
            return nil
          end

          response = Net::HTTP.start('127.0.0.1', port, open_timeout: 3, read_timeout: 10) do |http|
            http.post(
              "/canvas/#{session_name}/save-doc",
              JSON.generate(name: doc_name, format: 'rb'),
              'Content-Type' => 'application/json'
            )
          end
          payload = JSON.parse(response.body, symbolize_names: true) rescue {}
          return payload[:path] if payload[:ok]

          warn "growing_doc: save-doc failed (#{response.code}): #{payload[:error] || response.body}"
          nil
        rescue StandardError => e
          warn "growing_doc: save-doc failed (#{e.class}: #{e.message})"
          nil
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
