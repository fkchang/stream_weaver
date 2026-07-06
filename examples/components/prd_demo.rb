#!/usr/bin/env ruby
# frozen_string_literal: true

# PRD document pattern demo — replicates the "Calendar-Driven Travel State" PRD artifact.
# Loads prd_dsl.rb as its body so standalone and canvas-push stay in content sync.
# Demonstrates: doc_header, doc_section_header, sidebar_toc, callout, mermaid,
#   comparison (scope grid), table, code_block, card.
#
# Run: ruby examples/components/prd_demo.rb
# Or for canvas push: streamweaver canvas-push <session> < examples/components/prd_dsl.rb

require_relative "../../lib/stream_weaver"

PRD_DSL_PATH = File.join(__dir__, "prd_dsl.rb")

PrdDemo = app "PRD: Calendar-Driven Travel State", theme: :doc do
  theme_toggle mode: :light
  instance_eval(File.read(PRD_DSL_PATH), PRD_DSL_PATH)
end

PrdDemo.run! if __FILE__ == $0
