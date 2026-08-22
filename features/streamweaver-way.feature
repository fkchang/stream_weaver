Feature: The StreamWeaver Way — Hotwire-grade omakase layer
  StreamWeaver owns both sides of the wire (Ruby DSL backend + htmx/Alpine frontend,
  designed together) — the precondition Hotwire has and the rest of the htmx ecosystem
  lacks (verified: docs/research/2026-08-17-hotwire-alike-landscape.md — the niche is
  empty). This epic closes the capability gaps that block "4 complex features, zero
  custom JavaScript", verified chapter-by-chapter against the learnhotwire.com course
  (syllabus coverage matrix: docs/research/2026-08-22-learnhotwire-syllabus-coverage.md),
  then codifies the conventions as The StreamWeaver Way — a skill with progressive
  disclosure, with the trilaws as design filters. The verification vehicle is a
  StreamWeaver "My Todos" companion app mirroring the course's Rails app
  (github.com/learnhotwire/rails), so every parity claim reads: "Rails uses <mechanism>
  to do <feature>, key elements <X>; StreamWeaver does the equivalent via <Y>."
  This epic covers the Turbo Frames chapters (the study group's current position);
  Turbo Streams / Stimulus / Modal chapters are later epics, shaped as the study group
  reaches them.

  Background:
    Research grounding: docs/research/2026-08-17-hotwire-alike-landscape.md (niche
    verification), docs/research/2026-08-17-hotwire-concept-map.md (13-concept gap map;
    NOTE its §10 form_with claim is stale — form_for shipped at
    lib/stream_weaver/app.rb:598), docs/research/2026-08-22-learnhotwire-syllabus-coverage.md
    (full-syllabus matrix: HAVE 12 / PARTIAL 21 / MISSING 11 / N-A 21). Source spec for
    the benchmark features: alex_turbo_frames_transcript.txt. Prior scoping:
    gsd/analysis/00-analysis-and-plan.md (Phase 0 strict-ids).

  Scenario: my-todos-parity-spike
    # Intent: SDRD discovery instrument and parity vehicle — build the course's My Todos app in StreamWeaver as it exists today (Sinatra + DSL, zero custom JS), covering the four Turbo Frames chapter features: inline editing, frame-targeted search, hover cards, infinite scroll. Record exactly where each breaks; every working piece gets a parity note in the matrix's verification format.
    # RIGOR: loose — spike app + findings; value is discovery, browser-verified
    Given the learnhotwire My Todos app and its four Turbo Frames chapter features
    When a StreamWeaver companion app is built under examples/my_todos/ using only existing DSL primitives (resource, form_for, fragment updates:, route tabs) and zero custom JavaScript
    Then each feature either works or stops at a documented stumble, verified in a real browser (playwright-cli, main-thread rule)
    And docs/research/streamweaver-way-spike-findings.md records per feature: the Rails mechanism, key elements, the StreamWeaver equivalent used or the exact missing primitive
    And no framework changes are made in this story — gaps are recorded, not patched

  Scenario: document-form-for
    # Intent: cheap, load-bearing doc fix — form_for (app.rb:598, shipped 2026-07-10) already provides record-bound forms with create/update inference, validation re-render, and PRG, but is absent from resource-dsl.md and for_llms.md; the 13-concept map §10 calls it unimplemented. Inline-editing parity depends on agents knowing it exists.
    # RIGOR: trivial — documentation of shipped, tested capability
    Given form_for exists and is spec'd but undocumented
    When docs/resource-dsl.md, docs/for_llms.md, and llms.txt gain a form_for section with a worked inline-edit example
    Then an agent reading only the docs can build the course's inline-editing feature with form_for
    And the stale claim in docs/research/2026-08-17-hotwire-concept-map.md §10 is corrected in place

  Scenario: strict-ids-auto-keying
    # Intent: the dom_id equivalent — collision-proof, auto-derived component/fragment keys by construction, closing "the most dangerous bug in the catalog" (silent loop-ID collision) and encoding the transcript's rule: key by what is unique per position on the page, not by what the content is about.
    # RIGOR: strict — silent-collision logic; a plausible wrong implementation breaks apps invisibly
    Given a loop rendering interactive components that would historically collide on identical label plus source location
    When the DSL renders them with auto-disambiguation by render occurrence and an optional key: accepting stable scalars
    Then every interactive element receives a unique, stable id without author intervention
    And a strict_ids mode raises (dev) or warns (prod) on any residual collision
    And the keying convention is documented in docs/for_llms.md with the key-by-position-not-content rule

  Scenario: deferred-fragments-src
    # Intent: the eager-loading frame (Turbo src=) equivalent — the biggest MISSING in the concept map and the direct fix for the Streamlit scaling wall (root cause 1): render the shell now, let a slow region's work land when ready, without every(seconds) hand-rolling.
    # RIGOR: strict — new render-pipeline path; whole-rerun architecture makes deferral subtle
    Given a fragment declared with a deferred/src-style option and placeholder block content
    When the page first renders
    Then the shell responds without executing the deferred fragment's block, showing the placeholder
    And the fragment's content is fetched and swapped in automatically once ready, with no custom JavaScript in the app
    And a page with one slow fragment renders its fast content immediately (benchmarked, not asserted)

  Scenario: visibility-lazy-fragments
    # Intent: loading=lazy visibility semantics (fires when visible, whatever made it visible — CSS hover included), fetch-once — the primitive behind the course's Hovercards and Infinite Scroll chapters, AND the designed replacement for the click-lazy tabs mode that the shipped route-tabs epic deprecated (its named-but-undesigned "lazy route tabs" successor should be this same primitive applied to tab panels).
    # RIGOR: strict — IntersectionObserver wiring in the adapter plus fetch-once semantics
    Given a deferred fragment additionally marked lazy
    When the fragment becomes visible in the viewport, regardless of what made it visible
    Then its content is fetched exactly once and cached in the DOM (no refetch on re-visibility)
    And a fragment hidden via CSS never triggers a fetch
    And the design note records how route tabs adopt this primitive as the deprecated click-lazy mode's replacement

  Scenario: dev-loud-failure-overlay
    # Intent: explicit design ruling — keep prod's self-heal full-swap fallback, but make dev mode fail loud (Hotwire's "content missing" is its single best debugging aid, per the course's Debugging Turbo Frames lesson); today broken wiring silently self-heals and the author learns nothing.
    # RIGOR: loose — presentation-layer overlay on an existing, already-tested fallback path
    Given an interaction whose target fragment is missing or whose action token is stale
    When StreamWeaver falls back to a full-container swap in development mode
    Then a visible, styleable overlay names the missing target and the likely cause
    And production behavior is unchanged (silent self-heal)
    And the ruling (dev loud, prod self-heal) is documented as a deliberate inversion of Hotwire's philosophy

  Scenario: my-todos-zero-js
    # Intent: the acceptance benchmark made literal — complete the My Todos companion app on the new primitives; all four Turbo Frames chapter features working with zero custom JavaScript, each with a parity writeup in the matrix's verification format.
    # RIGOR: loose — verification story, gated on main-thread browser evidence with screenshots
    Given the primitives shipped by the preceding stories
    When the examples/my_todos/ app is completed: inline editing, search, hover cards, infinite scroll
    Then all four features work end to end with zero custom JavaScript in the app code
    And each is verified in a real browser with screenshots (server-shape-true is not user-true)
    And docs/research/2026-08-22-learnhotwire-syllabus-coverage.md is updated: each Turbo Frames chapter row gains its verified StreamWeaver parity entry
    And the spike findings doc shows each recorded stumble resolved or explicitly re-filed

  Scenario: streamweaver-way-skill
    # Intent: codify the conventions as The StreamWeaver Way — the "extract a how-to guide for our AIs with progressive disclosure" goal from the transcript, applied to our own framework where we control both the conventions and the teaching.
    # RIGOR: loose — docs plus skill authoring, riding the existing for_llms/skill discipline
    Given the conventions proven by the preceding stories
    When docs/for_llms.md and llms.txt are updated and a streamweaver-way skill is authored with progressive disclosure
    Then the skill states the laws of the Way (key by position not content, deferred-over-hand-rolled-timers, dev-loud/prod-self-heal, trilaws as design filters)
    And an agent following only the skill can build the four benchmark features without touching raw adapter internals
    And the skill is installable via the existing streamweaver setup / install-skill path
