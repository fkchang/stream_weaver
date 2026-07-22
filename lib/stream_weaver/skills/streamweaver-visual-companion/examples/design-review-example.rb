#!/usr/bin/env ruby
# frozen_string_literal: true

# Bundled copy of the design-review proof example (see canonical source at
# examples/components/design_review_demo.rb + design_review_dsl.rb +
# design_review.css). Duplicated here -- rather than referenced by relative
# path -- so the skill stays self-contained when installed as a gem or
# copied in isolation from the rest of the repo.
#
# Demonstrates: a full bespoke re-skin (one unlayered CSS file targeting
# only documented sw- hooks) reaching 1:1 visual parity with a claude.ai-
# hosted Artifact for the "editorial design review" genre -- option cards
# with status-dot chips, a picked/winning state reused across both a card
# and a table row, and checklist tiles with no dedicated component. See
# docs/porting-artifacts.md for the process this was built through.
#
# Run: ruby design-review-example.rb

require_relative "../../../../stream_weaver"

DSL_PATH = File.join(__dir__, "design-review-example_dsl.rb")
CSS_PATH = File.join(__dir__, "design-review-example.css")

# Uses StreamWeaver::App.new directly (not the top-level `app` helper) --
# the helper's fixed kwarg list has no assets_dirs:, and App#script_dir is
# derived from its *direct* caller's file, which resolves wrong when routed
# through the helper. See docs/porting-artifacts.md, step (d).
DesignReviewExample = StreamWeaver::App.new(
  "Design Review — Wayfinder & Beacon",
  theme: :doc,
  stylesheets: [CSS_PATH],
  assets_dirs: [__dir__]
) do
  theme_toggle mode: :auto
  instance_eval(File.read(DSL_PATH), DSL_PATH)
end.generate

DesignReviewExample.run! if __FILE__ == $0
