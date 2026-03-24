# frozen_string_literal: true

# Demonstrates: accessing `state` inside streamer.replace blocks
#
# KEY PATTERN: Pass `state: state` to streamer.replace/append/prepend whenever
# the block (or a helper it calls) needs to read session state.
#
# Without `state: state`, the replace block runs in FeedBuilder context where
# `state` is not defined — you'll see:
#   [StreamWeaver] Timer error: NameError: undefined local variable or method `state'
#
# Run with: ruby examples/components/timer_with_state_demo.rb

require_relative "../../lib/stream_weaver"

# Top-level helper — works inside replace blocks (global methods are accessible).
# Receives state as an argument (not via DSL) since the helper is display-only.
def render_status_panel(label:, count:, state:)
  card do
    hstack justify: :between do
      text label
      badge state[:filter] || "all", variant: :info
    end
    stat_display value: count, label: "items", color: :blue
    text "Last refresh: #{Time.now.strftime('%H:%M:%S')}"
  end
end

app "Timer + State Demo" do
  header1 "Timer + State Demo"
  md "Change the filter, then watch the panel refresh every 3 seconds. " \
     "The filter value persists across timer refreshes."

  state[:filter] ||= "all"

  select :filter, %w[all active paused archived], submit: true

  md "---"

  div id: "status-panel" do
    render_status_panel(
      label:  "Showing: #{state[:filter]}",
      count:  rand(10..99),
      state:  state
    )
  end

  # CORRECT: pass `state: state` so FeedBuilder exposes it inside the block
  every(3) do |streamer|
    streamer.replace("#status-panel", state: state) do
      render_status_panel(
        label:  "Showing: #{state[:filter]}",
        count:  rand(10..99),
        state:  state
      )
    end
  end
end.run!
