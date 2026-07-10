#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual-verification harness for button loading state (FAC-P1.5).
# The spinner + dim/disabled treatment is automatic now -- no hand-built markup
# needed. Button action sleeps 2s so you can see it before the page updates:
#   - the clicked button dims, disables, and spins (button.htmx-request::after)
#   - #app-container dims subtly after a ~150ms delay (no flicker on fast responses)
# "Opted Out" demonstrates the per-component `loading: false` escape hatch.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "stream_weaver"

app "Button Loading Test" do
  header "Button Loading State Test"
  md "Click a button — it should dim and spin for ~2 seconds before the page updates."

  button "Primary (2s delay)" do |s|
    sleep 2
    s[:last] = "primary clicked at #{Time.now.strftime('%H:%M:%S')}"
  end

  button "Secondary (2s delay)", style: :secondary do |s|
    sleep 2
    s[:last] = "secondary clicked at #{Time.now.strftime('%H:%M:%S')}"
  end

  button "Opted Out (2s delay, loading: false)", loading: false do |s|
    sleep 2
    s[:last] = "opted-out clicked at #{Time.now.strftime('%H:%M:%S')}"
  end

  if state[:last]
    md "**Last action:** #{state[:last]}"
  end
end.run!
