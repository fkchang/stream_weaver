Feature: Interactive widgets — client-side doc components that animate with no server
  Self-contained widgets (JSON config + vanilla-JS engine + CSS, no network, no Alpine) that
  work in every StreamWeaver surface: standalone export/iframe, canvas, org docs, and the
  Chrome extension. `replay` (animated event replay) is the first; others follow the same recipe.
  Design + spike findings: docs/ideas/replay-component.md. Spike committed as 847d36a.

  Scenario: replay-component-spike
    # Intent: Prove a Ruby DSL can describe the hand-written Thursday replay page in far fewer tokens.
    # RIGOR: loose — SDRD spike, built fast outside Tyrion and backfilled
    Given the hand-written 186-line replay page
    When examples/components/replay_thursday.rb is exported with `streamweaver export --bare`
    Then the export plays in a browser with the same lanes, counters, gaps and finale totals
    And it embeds in an iframe edge to edge with no external script

  Scenario: replay-static-adapter
    # Intent: One renderer for the behavior-free widget so Alpine and Opal cannot drift (the Adapter::Static chokepoint).
    # RIGOR: loose — move plus a canvas smoke test
    Given render_replay currently lives only in adapter/alpinejs.rb
    When it moves to Adapter::Static and the replay is canvas-pushed twice
    Then the replay renders and animates in canvas
    And a re-push does not leave a dead (uninitialized) stage or duplicate the engine script

  Scenario: replay-org-src-block
    # Intent: Org docs author a replay as `#+begin_src replay`, which GitHub's org-ruby shows as readable text, never blank.
    # RIGOR: strict — writer/reader round trip can silently drop or reorder events
    Given org-ruby silently drops an unknown `#+begin_replay` block but renders `#+begin_src replay` as a code block
    When an .org doc holds `#+begin_src replay :title "T"` containing lane/counter lines and an org table of events
    Then org-ruby HTML shows the table and lines as a monospace block, not nothing
    And the StreamWeaver org reader renders it as an animated replay (same special-casing as lang mermaid, reader.rb:375)
    And the org writer round-trips the block byte-for-byte

  Scenario: replay-extension-opal
    # Intent: The replay animates inside the Chrome extension's hardened sandbox.
    # RIGOR: strict — Opal compile gaps and morphdom re-render can break it silently
    Given Components::Replay must compile under Opal and the engine JS is bundled by bin/build_extension
    When an .org doc with a replay block is opened in the extension viewer
    Then the replay animates with zero network requests under the hardened CSP
    And a live-runtime re-render does not wipe the stage (stage subtree is morph-ignored)

  Scenario: replay-skeleton-authoring
    # Intent: A skeleton report becomes a replay with no hand-written windows or captions.
    # RIGOR: loose — builds on events_from_skeleton
    Given one or more `session-skeleton --json` reports
    When `auto_windows idle: 120` is used and reports are merged one lane per session
    Then windows split on idle gaps over 120 minutes with generated gap captions
