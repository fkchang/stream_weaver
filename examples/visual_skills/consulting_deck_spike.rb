#!/usr/bin/env ruby
# frozen_string_literal: true

# Consulting Deck Spike: Northstar Research Kickoff
# ------------------------------------------------------
# Standalone wrapper for the shared DSL fragment in
# consulting_deck_spike_dsl.rb (which is also the file to hand to
# `streamweaver export` / canvas-push). See the fragment for details.

require_relative '../../lib/stream_weaver'

DSL_PATH = File.join(__dir__, 'consulting_deck_spike_dsl.rb')

App = app "Northstar Research — Kickoff Deck (Spike)" do
  instance_eval(File.read(DSL_PATH), DSL_PATH)
end

App.run! if __FILE__ == $0
