# frozen_string_literal: true

# StreamWeaver University -- step 1's dashboard demo (story:
# step-1-canvas-push).
#
# Three things a terminal cannot draw, in one push: a 2x2 grid of KPI tiles,
# a Chart.js bar chart, and a mermaid sequence diagram of the very
# canvas-push that put them there. Then the same layout again with different
# numbers, so the pane mutates in place while the worker narrates.
#
#   streamweaver panel dashboard                      # open the pane first
#   ruby "$(streamweaver university-demo dashboard)" dashboard      # week 1
#   ruby "$(streamweaver university-demo dashboard)" dashboard 2    # mutate
#   ruby "$(streamweaver university-demo dashboard)" dashboard 3    # mutate
#
# ARGV: SESSION_NAME (default "dashboard"), SNAPSHOT (1-3, default 1).
#
# Why a push script rather than three DSL files piped through
# `canvas-push`: the DSL is rendered inside the bridge process, so a file
# cannot read the caller's environment, and three near-identical DSL files
# would be three places for the layout to drift. One parameterized script,
# three snapshots of the same layout.
#
# Design constraints baked in:
#
# - Pane width. This renders in a ~750-800px split pane
#   (features/university-getting-started.context.md, "Pane-width rule"), so
#   the tiles are two rows of two rather than one row of four -- `.sw-columns`
#   only stacks below 640px, and four tiles across 750px is unreadable.
# - `chart type:` explicitly, never the `bar_chart` shorthand: the shorthand
#   family renders through Alpine `x-init`, and disc-094 kills it on export.
#   The explicit form is what commit 51beb6c fixed for bridge poll swaps.

require 'stream_weaver/canvas/client'

module StreamWeaver
  module University
    module Demos
      module Dashboard
        # Each snapshot is one frame of the same dashboard. Same tile
        # labels, same chart series, different numbers -- so a re-push reads
        # as "the data moved", not "a different page".
        SNAPSHOTS = [
          {
            caption: 'Sprint 14 · Monday standup',
            tiles: [
              { value: 128, label: 'PUSHES', color: :default },
              { value: 12, label: 'SESSIONS', color: :blue },
              { value: 3, label: 'BLOCKED', color: :red },
              { value: 41, label: 'DOCS SAVED', color: :purple }
            ],
            bars: [18, 24, 31, 22, 33]
          },
          {
            caption: 'Sprint 14 · Wednesday standup',
            tiles: [
              { value: 164, label: 'PUSHES', color: :default },
              { value: 15, label: 'SESSIONS', color: :blue },
              { value: 1, label: 'BLOCKED', color: :red },
              { value: 52, label: 'DOCS SAVED', color: :purple }
            ],
            bars: [18, 24, 31, 29, 47]
          },
          {
            caption: 'Sprint 14 · Friday standup',
            tiles: [
              { value: 203, label: 'PUSHES', color: :default },
              { value: 19, label: 'SESSIONS', color: :blue },
              { value: 0, label: 'BLOCKED', color: :red },
              { value: 68, label: 'DOCS SAVED', color: :purple }
            ],
            bars: [18, 24, 31, 29, 61]
          }
        ].freeze

        DAYS = %w[Mon Tue Wed Thu Fri].freeze

        # One flat DSL body for the given snapshot. Flat and
        # one-statement-per-component on purpose (same rule the growing-doc
        # script follows) so the text stays legible when a curious user
        # reads the file this course just ran.
        def self.dsl(index = 0)
          snap = SNAPSHOTS[index]
          top, bottom = snap[:tiles].each_slice(2).to_a

          <<~RUBY
            header1 "Canvas activity"

            text #{snap[:caption].inspect}

            columns 2 do
              column { stat_display value: #{top[0][:value]}, label: #{top[0][:label].inspect}, color: :#{top[0][:color]}, size: :lg }
              column { stat_display value: #{top[1][:value]}, label: #{top[1][:label].inspect}, color: :#{top[1][:color]}, size: :lg }
            end

            columns 2 do
              column { stat_display value: #{bottom[0][:value]}, label: #{bottom[0][:label].inspect}, color: :#{bottom[0][:color]}, size: :lg }
              column { stat_display value: #{bottom[1][:value]}, label: #{bottom[1][:label].inspect}, color: :#{bottom[1][:color]}, size: :lg }
            end

            chart type: :bar, data: {
              labels: #{DAYS.inspect},
              datasets: [
                { label: "Pushes", data: #{snap[:bars].inspect}, backgroundColor: "#6366f1" }
              ]
            }, height: 240

            md "**How this got here.** Not a screenshot, not a file your agent opened in a browser -- one command, and the pane you are looking at redrew itself:"

            mermaid <<~DIAGRAM
              sequenceDiagram
                participant A as Your agent
                participant C as streamweaver CLI
                participant B as canvas bridge
                participant P as this pane
                A->>C: ruby dashboard.rb dashboard #{index + 1}
                C->>B: push(session, DSL)
                B->>B: render DSL -> HTML
                B-->>P: poll swap, in place
                P-->>A: no reload, no flicker
            DIAGRAM
          RUBY
        end

        def self.run!(session_name: ARGV[0] || 'dashboard',
                      snapshot: Integer(ARGV[1] || 1))
          index = snapshot.clamp(1, SNAPSHOTS.length) - 1

          ::StreamWeaver::Canvas::Client.ensure_bridge_running
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.create(session_name, layout: :fluid)
          )
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.push(session_name, dsl(index), source_dir: nil)
          )
          puts "Pushed snapshot #{index + 1} of #{SNAPSHOTS.length} (#{SNAPSHOTS[index][:caption]}) to canvas session '#{session_name}'."
        rescue ::StreamWeaver::Canvas::Client::NotRunningError,
               ::StreamWeaver::Canvas::Client::ConnectionError => e
          warn "dashboard: could not reach the canvas bridge (#{e.message}) -- " \
               "run `streamweaver panel #{session_name}` first"
        end
      end
    end
  end
end

StreamWeaver::University::Demos::Dashboard.run! if $PROGRAM_NAME == __FILE__
