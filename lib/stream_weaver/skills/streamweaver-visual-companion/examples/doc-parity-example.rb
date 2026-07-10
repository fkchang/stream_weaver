#!/usr/bin/env ruby
# frozen_string_literal: true

# Bundled copy of the doc-parity proof example (see canonical source at
# examples/components/prd_demo.rb + prd_dsl.rb). Duplicated here — rather than
# referenced by relative path — so the skill stays self-contained when
# installed as a gem or copied in isolation from the rest of the repo.
#
# Demonstrates: theme: :doc reaching 1:1 visual parity with a claude.ai-hosted
# Artifact (docs/reference/travel-state-prd.artifact.html in the source repo),
# built via canvas-push + Save-as-doc, not by leaving the terminal.
#
# Run: ruby doc-parity-example.rb

require_relative "../../../../stream_weaver"

DSL_PATH = File.join(__dir__, "doc-parity-example_dsl.rb")

DocParityExample = app "PRD: Calendar-Driven Travel State", theme: :doc do
  theme_toggle mode: :light
  instance_eval(File.read(DSL_PATH), DSL_PATH)
end

DocParityExample.run! if __FILE__ == $0
