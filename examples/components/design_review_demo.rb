#!/usr/bin/env ruby
# frozen_string_literal: true

# Component-parity port of a claude.ai-hosted Artifact: a fictional
# editorial design-review document ("Getting Wayfinder and Beacon in front
# of every agent"). Loads design_review_dsl.rb as its body so standalone
# and canvas-push stay in content sync, following the doc-parity-example.rb
# / prd_demo.rb precedent. See docs/porting-artifacts.md for the general
# process this example proves out.
#
# Demonstrates: doc_header, doc_section_header, callout (framing box,
# recommendation panel, dashed aside), card/card_header/card_body (option
# cards A-F with a "picked" state), table with markdown: true (landscape +
# comparison-matrix tables, one with a highlighted pick row), status_dot
# (chips, legend, matrix rating cells), columns/column (verified/unverified
# split), badge (recommended tag) -- re-skinned end to end via ONE
# unlayered stylesheet (design_review.css) targeting only documented
# sw- hooks, per docs/theming-hooks.md.
#
# Run: ruby examples/components/design_review_demo.rb

require_relative "../../lib/stream_weaver"

DSL_PATH = File.join(__dir__, "design_review_dsl.rb")
CSS_PATH = File.join(__dir__, "design_review.css")

# Uses StreamWeaver::App.new directly (not the top-level `app` helper) --
# the helper's fixed kwarg list has no assets_dirs:, and App#script_dir is
# derived from its *direct* caller's file (caller_locations(1,1) inside
# #initialize), which resolves to lib/stream_weaver.rb itself when routed
# through the helper. Same workaround examples/parity/tyrion_warroom_components.rb
# uses for its own stylesheets:.
App = StreamWeaver::App.new(
  "Design Review — Wayfinder & Beacon",
  theme: :doc,
  stylesheets: [CSS_PATH],
  assets_dirs: [__dir__]
) do
  theme_toggle mode: :auto
  instance_eval(File.read(DSL_PATH), DSL_PATH)
end

App.generate.run! if __FILE__ == $0
