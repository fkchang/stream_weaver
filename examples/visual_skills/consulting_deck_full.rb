#!/usr/bin/env ruby
# frozen_string_literal: true

# Consulting Deck Full: Northstar Research Kickoff (20 slides)
# -------------------------------------------------------------
# Standalone wrapper for the shared DSL fragment in
# consulting_deck_full_dsl.rb (which is also the file to hand to
# `streamweaver export` / canvas-push). See the fragment for details.

require_relative '../../lib/stream_weaver'

DSL_PATH = File.join(__dir__, 'consulting_deck_full_dsl.rb')

App = app "Northstar Research — Kickoff Deck (Full)" do
  instance_eval(File.read(DSL_PATH, encoding: Encoding::UTF_8), DSL_PATH)
end

App.run! if __FILE__ == $0
