# frozen_string_literal: true

# StreamWeaver University -- step 3's decision form (story:
# step-3-form-modes).
#
# ONE artifact, two surfaces. The same question -- a mermaid diagram of two
# candidate architectures, a comparison table, a radio_group and a rationale
# text_field -- is rendered either as a standalone blocking app or as a
# canvas push. Nothing is duplicated between the two modes; that identity is
# the lesson, and the worker is told to say so out loud.
#
# Mode 1, the founding loop (step 3's opening move):
#
#   ruby "$(streamweaver university-demo decision-form)"
#
# `run_once!` finds a free port, OPENS the browser itself, and BLOCKS. The
# user answers in the page that just appeared; the process prints the
# submitted state as JSON and exits. The user never opens a page and never
# has to tell the agent "done" -- round-5 UAT found both of those to be
# homework the course was silently assigning.
#
# Mode 2, the same form on the canvas:
#
#   streamweaver panel decision
#   ruby "$(streamweaver university-demo decision-form)" canvas decision
#   streamweaver canvas-wait decision
#
# Input components are radio_group / text_field only. disc-098 and disc-105:
# checkbox_group and multi chip_group harvest the wrong values back through
# canvas-wait.

require 'stream_weaver'
require 'stream_weaver/canvas/client'

module StreamWeaver
  module University
    module Demos
      module DecisionForm
        # The question and its evidence. Everything a terminal prompt cannot
        # carry: a rendered diagram of both designs, and a table putting them
        # side by side on three axes.
        CONTEXT = <<~RUBY
          header1 "Which way should the canvas bridge hold sessions?"

          md "This is a real decision, not a demo prompt -- and it is the kind an agent normally has to ask you in prose, one option per paragraph, hoping you can hold both designs in your head at once."

          mermaid <<~DIAGRAM
            graph TB
              subgraph A["A · One shared bridge"]
                A1["streamweaver CLI"] --> A2["single bridge process"]
                A2 --> A3["session: dashboard"]
                A2 --> A4["session: decision"]
                A2 --> A5["session: doc-demo"]
              end
              subgraph B["B · A process per session"]
                B1["streamweaver CLI"] --> B2["bridge: dashboard"]
                B1 --> B3["bridge: decision"]
                B1 --> B4["bridge: doc-demo"]
              end
          DIAGRAM

          table [
            { axis: "Memory", shared: "One process, one Puma", per_session: "N processes, N Pumas" },
            { axis: "Blast radius", shared: "A crash takes every pane", per_session: "A crash takes one pane" },
            { axis: "Cross-session reads", shared: "Free -- same object graph", per_session: "Needs IPC or a store" }
          ]
        RUBY

        # The inputs. Shared verbatim by both surfaces -- change a label here
        # and both the standalone app and the canvas form change with it.
        FORM = <<~RUBY
          radio_group :architecture, [
            "A -- one shared bridge, all sessions inside it",
            "B -- one bridge process per session"
          ]

          md "**Why?** One line. Your agent reads this back to you verbatim and reacts to it."

          text_field :rationale, placeholder: "Because..."
        RUBY

        # The canvas surface says out loud what is happening to the worker's
        # terminal, because on the canvas there is nothing else to tell you.
        # The standalone surface does not need it: `run_once!` prints
        # "Waiting for form submission" in the very terminal that is stuck.
        BLOCKING_CALLOUT = <<~RUBY
          callout(variant: :warning, title: "Your agent is frozen right now") do
            md "This is a **blocking** form. The worker terminal is sitting inside `streamweaver canvas-wait decision` and will not print another line until you press Submit. Look over at it -- nothing is moving."
          end
        RUBY

        SUBMIT = <<~RUBY
          button "Submit decision"
        RUBY

        # Standalone gets no explicit button: agentic mode (`run_once!`)
        # renders its own submit control and uses it to unblock.
        def self.standalone_dsl
          "#{CONTEXT}\n#{FORM}"
        end

        def self.canvas_dsl
          "#{BLOCKING_CALLOUT}\n#{CONTEXT}\n#{FORM}\n#{SUBMIT}"
        end

        # Mode 1. Blocks; opens the browser; prints the submitted state as
        # JSON on stdout when the user submits.
        def self.standalone!
          dsl = standalone_dsl
          ::StreamWeaver.app("A real decision") { instance_eval(dsl) }.run_once!
        end

        # Mode 2. Pushes the same question into a canvas session, for
        # `streamweaver canvas-wait <session>` to block on.
        def self.push!(session_name)
          ::StreamWeaver::Canvas::Client.ensure_bridge_running
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.create(session_name, layout: :fluid)
          )
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.push(session_name, canvas_dsl, source_dir: nil)
          )
          puts "Pushed the same decision form to canvas session '#{session_name}'. " \
               "Block on it with: streamweaver canvas-wait #{session_name}"
        rescue ::StreamWeaver::Canvas::Client::NotRunningError,
               ::StreamWeaver::Canvas::Client::ConnectionError => e
          warn "decision_form: could not reach the canvas bridge (#{e.message}) -- " \
               "run `streamweaver panel #{session_name}` first"
        end

        def self.run!(argv = ARGV)
          if argv.first == 'canvas'
            push!(argv[1] || 'decision')
          else
            standalone!
          end
        end
      end
    end
  end
end

StreamWeaver::University::Demos::DecisionForm.run! if $PROGRAM_NAME == __FILE__
