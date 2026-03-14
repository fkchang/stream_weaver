#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Run Viewer Timeline
# Replicates the DTO Run Viewer event log using the TimelineEvent component.
# Run with: ruby examples/components/run_viewer_demo.rb

require_relative "../../lib/stream_weaver"

RunViewerApp = app "Run Viewer — abc-123", theme: :dark do
  # Header metadata
  header1 "Run Viewer"
  hstack spacing: :lg do
    text "run_id: abc-123"
    text "target: codex"
    text "duration: 60.0s"
    text "events: 11"
  end
  hstack spacing: :lg do
    text "interventions: 2"
    text "timeouts: 0"
    text "snapshots: 2"
  end
  text "source: demo/sample_run.jsonl"

  # Timeline events
  vstack spacing: :none do
    timeline_event index: 0, event_type: :phase, timestamp: "10:00:00",
                   label: "launch",
                   fields: { run_id: "abc-123", phase: "launch", target: "codex",
                             baseline_files: "lib/app.rb", step_id: "launch",
                             target_socket_name: "dto-codex", target_session_name: "run-1" }

    timeline_event index: 1, event_type: :phase, timestamp: "10:00:05",
                   label: "settle step=1",
                   fields: { run_id: "abc-123", phase: "settle", step: 1, step_id: "step-1" }

    timeline_event index: 2, event_type: :phase, timestamp: "10:00:15",
                   label: "observe step=1",
                   fields: { run_id: "abc-123", phase: "observe", step: 1, step_id: "step-1" }

    timeline_event index: 3, event_type: :snapshot, timestamp: "10:00:16",
                   label: "state=working verification_ok=false step=1",
                   fields: { run_id: "abc-123", step: 1, step_id: "step-1", state: "working",
                             waiting_for_input: false, busy: true, likely_complete: false,
                             signals_found: "[]", signals_missing: "test passes",
                             verification_ok: false, changed_files: "lib/app.rb",
                             last_assistant_lines: "Writing the initial implementation..." }

    timeline_event index: 4, event_type: :phase, timestamp: "10:00:17",
                   label: "decide step=1",
                   fields: { run_id: "abc-123", phase: "decide", step: 1, step_id: "step-1",
                             driver: "ClaudeDriverBackend" }

    timeline_event index: 5, event_type: :intervention, timestamp: "10:00:22",
                   label: "action=question terminal=false step=1",
                   fields: { run_id: "abc-123", step: 1, step_id: "step-1", action: "question",
                             intent: "Clarify scope",
                             why: "Worker jumped into coding without asking about interface shape",
                             next_step: "List the product choices before writing code",
                             stop_if: "Worker starts asking clarifying questions",
                             rendered_message: "INTENT: Clarify scope\nWHY: You started coding without clarifying the interface shape.\nNEXT: List the product choices first.\nSTOP IF: You start asking clarifying questions.",
                             terminal: false }

    timeline_event index: 6, event_type: :phase, timestamp: "10:00:23",
                   label: "send step=1",
                   fields: { run_id: "abc-123", phase: "send", step: 1, step_id: "step-1" }

    timeline_event index: 7, event_type: :phase, timestamp: "10:00:35",
                   label: "settle step=2",
                   fields: { run_id: "abc-123", phase: "settle", step: 2, step_id: "step-2" }

    timeline_event index: 8, event_type: :snapshot, timestamp: "10:00:45",
                   label: "state=waiting verification_ok=true step=2",
                   fields: { run_id: "abc-123", step: 2, step_id: "step-2", state: "waiting",
                             waiting_for_input: true, busy: false, likely_complete: false,
                             signals_found: "test passes", signals_missing: "[]",
                             verification_ok: true,
                             changed_files: "lib/app.rb, test/test_app.rb",
                             last_assistant_lines: "All tests pass. Here is the summary..." }

    timeline_event index: 9, event_type: :intervention, timestamp: "10:00:50",
                   label: "action=verify terminal=true step=2",
                   fields: { run_id: "abc-123", step: 2, step_id: "step-2", action: "verify",
                             intent: "Confirm completion",
                             why: "Signals met and verification passes",
                             next_step: "Summarize what changed",
                             stop_if: "nil",
                             rendered_message: "INTENT: Confirm completion\nWHY: All signals met.\nNEXT: Summarize.\nSTOP IF: n/a",
                             terminal: true }

    timeline_event index: 10, event_type: :final, timestamp: "10:01:00",
                   label: "interventions=2",
                   fields: { run_id: "abc-123", interventions: 2,
                             final_transcript_tail: "Done. All tests pass.",
                             step_id: "final" }
  end
end

RunViewerApp.run! if __FILE__ == $0
