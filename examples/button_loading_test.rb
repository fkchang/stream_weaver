#!/usr/bin/env ruby
# frozen_string_literal: true

# Test app to verify button loading state
# Button action sleeps 2s so you can see the spinner before page refreshes

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

  if state[:last]
    md "**Last action:** #{state[:last]}"
  end
end.run!
