#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual-verification harness for deferred fragments (`fragment ..., defer: true`)
# -- the Turbo `turbo_frame_tag ..., src:` equivalent. Every deferred block below
# sleeps, so the point is visible: the shell paints immediately and each region
# fills in on its own afterwards, with zero JavaScript in this file.
#
#   SW_NO_OPEN=1 STREAMWEAVER_PORT=4599 ruby examples/deferred_fragments_demo.rb
#
# SW_DEFER_DELAY overrides the per-fragment sleep (default 1.5s, matching the
# learnhotwire course's `sleep 1.5` hover-card demo).

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "stream_weaver"

DELAY = (ENV["SW_DEFER_DELAY"] || "1.5").to_f

def slow_work(label)
  sleep DELAY
  "#{label} finished at #{Time.now.strftime('%H:%M:%S.%L')}"
end

app "Deferred Fragments" do
  header1 "Deferred fragments"
  md "This line and everything above it render **immediately**. Each panel below " \
     "sleeps #{DELAY}s inside its `defer: true` block, so the block cannot run " \
     "during the page render -- the shell would take #{(DELAY * 3).round(1)}s if it did."
  text "Shell rendered at #{Time.now.strftime('%H:%M:%S.%L')}"

  header3 "1. Default placeholder (spinner)"
  fragment :default_placeholder, defer: true do
    text slow_work("Panel 1")
  end

  header3 "2. String placeholder"
  fragment :string_placeholder, defer: true, placeholder: "Crunching numbers…" do
    text slow_work("Panel 2")
  end

  header3 "3. Custom DSL placeholder, reading state from the field above it"
  text_field :who, placeholder: "type a name, then reload", label: "Who"
  fragment :reads_state, defer: true, placeholder: -> { alert(variant: :info) { text "Waiting for the server…" } } do
    text slow_work("Panel 3 for #{state[:who].to_s.empty? ? '(nobody)' : state[:who]}")
  end

  header3 "4. Deferred nested inside deferred (loads as a chain)"
  fragment :outer_panel, defer: true, placeholder: "Outer loading…" do
    text slow_work("Outer")
    fragment :inner_panel, defer: true, placeholder: "Inner loading…" do
      text slow_work("Inner")
    end
  end

  header3 "5. Full-container swap"
  md "This button swaps the whole app container. The panels above should return " \
     "to their placeholders and fetch again rather than sticking on a placeholder."
  button "Re-render the page" do |s|
    s[:renders] = s[:renders].to_i + 1
  end
  text "Full re-renders so far: #{state[:renders].to_i}"
end.run!
