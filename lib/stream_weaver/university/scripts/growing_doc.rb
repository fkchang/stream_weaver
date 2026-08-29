# frozen_string_literal: true

# StreamWeaver University -- step 4's growing-doc appender
# (story: step-4-growing-doc).
#
# Pushes to one canvas session three times in a row, each push holding a
# little more than the last, with a pause in between so the pane visibly
# grows into a document while you watch. Content-only DSL throughout: no
# buttons (disc-095 -- canvas-read's controls grey out and do nothing, so a
# doc meant to be reviewed there must not lean on any) and no chart
# shorthands (disc-094 -- `streamweaver export` drops Chart.js for those).
#
# Ships inside the stream_weaver gem, so a fresh `gem install stream_weaver`
# already has it on the load path -- no path to type, no home directory to
# know about:
#
#   ruby -e "require 'stream_weaver'; require 'stream_weaver/university/scripts/growing_doc'" SESSION_NAME
#
# SESSION_NAME (first ARGV, default "doc-demo") must already be open --
# `streamweaver panel SESSION_NAME` (or `streamweaver canvas SESSION_NAME`)
# first, so there's a pane to watch grow. Pause between pushes is
# STREAMWEAVER_GROWING_DOC_PAUSE seconds (default 2; specs override it to
# run fast).

require 'stream_weaver/canvas/client'

module StreamWeaver
  module University
    module Scripts
      module GrowingDoc
        # Each entry is appended, not replaced -- the pane accumulates all
        # prior sections plus this one, so the doc visibly grows rather
        # than getting swapped out from under the reader.
        NEW_SECTIONS = [
          "This paragraph is the first thing the script pushed.",
          "A few seconds later, the script pushed this second paragraph on top of the first.",
          "And now a third -- the pane just grew into a document while you watched, with no edits from you."
        ].freeze

        def self.run!(session_name: ARGV.first || 'doc-demo',
                       pause: Float(ENV.fetch('STREAMWEAVER_GROWING_DOC_PAUSE', 2)))
          ::StreamWeaver::Canvas::Client.ensure_bridge_running
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.create(session_name, layout: :fluid, theme: :doc)
          )

          sections = []
          NEW_SECTIONS.each_with_index do |section, i|
            sections << section
            dsl = <<~RUBY
              header1 "A doc that writes itself"
              md #{sections.join("\n\n").inspect}
            RUBY
            ::StreamWeaver::Canvas::Client.send_message(
              ::StreamWeaver::Canvas::Protocol::Messages.push(session_name, dsl, source_dir: nil)
            )
            sleep(pause) unless i == NEW_SECTIONS.length - 1
          end
        rescue ::StreamWeaver::Canvas::Client::NotRunningError, ::StreamWeaver::Canvas::Client::ConnectionError => e
          warn "growing_doc: could not reach the canvas bridge (#{e.message}) -- " \
               "run `streamweaver panel #{session_name}` first"
        end
      end
    end
  end
end

StreamWeaver::University::Scripts::GrowingDoc.run!
