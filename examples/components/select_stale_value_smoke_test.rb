# frozen_string_literal: true

# Smoke test: browser-cached select value should NOT override server default
#
# Steps to reproduce the bug (before fix):
#   1. Run this app, open in Brave/Chrome
#   2. Change the select to "banana" or "cherry"
#   3. Navigate away (e.g. open a different URL)
#   4. Navigate back — WITHOUT the fix, you'll see the stale "banana"/"cherry"
#      instead of the server default "orange"
#
# Expected after fix: always shows "orange" on fresh load
#
# Run with: ruby examples/components/select_stale_value_smoke_test.rb

require_relative "../../lib/stream_weaver"

app = StreamWeaver.app "Select Stale Value Smoke Test" do
  header1 "Select Stale Value Smoke Test"

  md "**Expected:** the select always shows **orange** after a page refresh or navigate-away-and-back."
  md "**Bug symptom:** Brave/Chrome restores the previous selection instead of the server-rendered default."

  # Default is "orange" — intentionally NOT the first option
  state[:fruit] ||= "orange"

  select :fruit, %w[apple orange banana cherry], submit: false

  card do
    text "Server sees: #{state[:fruit]}"
  end

  md "---"
  button "Reset to orange", style: :secondary do |s|
    s[:fruit] = "orange"
  end
end

app.run!
