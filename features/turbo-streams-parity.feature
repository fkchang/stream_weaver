Feature: Turbo Streams Parity — push updates from anywhere
  Match the learnhotwire Turbo Streams chapters: surgical multi-region updates pushed
  from anywhere in the stack (model callbacks, background work), not just from every()
  timer blocks — StreamWeaver's equivalent of broadcasts_to / broadcasts_refreshes /
  custom stream actions. Syllabus rows owned by this epic are marked in
  docs/research/2026-08-22-learnhotwire-syllabus-coverage.md (Epic ownership roadmap).
  DEPENDS_ON: streamweaver-way (conventions + parity app this epic extends) and the
  now-view-support session-scoped-broadcast fix (broadcast-from-anywhere widens that
  leak's blast radius, so it must land first).
  UNLOCKS: modal-dialogs-parity (dialog insertion via stream actions).

  Background:
    Study-group cadence: Alex presents the Turbo Streams chapters next; the preso
    transcript becomes shaping input, like alex_turbo_frames_transcript.txt was for
    streamweaver-way. Current StreamWeaver state: Streamer (lib/stream_weaver/streamer.rb)
    has the full action vocabulary (replace/append/prepend/remove/class toggles) but is
    reachable only from every() timer blocks, and Streamer::ACTIONS is a closed list.

  Scenario: shape-epic
    # Intent: assessment-first story — flesh out this epic from real inputs before any build: the Streams preso transcript, the syllabus matrix rows this epic owns, the shipped streamweaver-way conventions, and the landed session-scoped-broadcast fix. Output is a fully-criteria'd epic, not code.
    # RIGOR: loose — shaping/assessment story; deliverable is the epic itself plus updated core docs
    Given the streamweaver-way epic is complete and the now-view session-scoped-broadcast fix has landed
    When the Streams preso transcript and the matrix rows owned by this epic are assessed against current Streamer capabilities via /tyrion-shape
    Then every placeholder scenario below gains real Given/When/Then criteria or is explicitly dropped with a reason
    And docs/research/2026-08-22-learnhotwire-syllabus-coverage.md rows owned by this epic are re-verified and updated
    And the epic context records the parity-demo plan extending examples/my_todos/

  Scenario: broadcast-from-anywhere
    # Intent: Streamer reachable from any server-side code (store callbacks, background work), not just every() blocks — the broadcasts_to equivalent and the biggest recurring PARTIAL in the matrix.
    # RIGOR: strict — concurrency + session-scoping correctness
    # TODO: criteria — fill during shape-epic

  Scenario: refresh-fragment-action
    # Intent: bare "refetch yourself" push with no server-side HTML diffing — the broadcasts_refreshes equivalent; today Streamer always computes and pushes HTML.
    # RIGOR: strict
    # TODO: criteria — fill during shape-epic

  Scenario: extensible-stream-actions
    # Intent: registration mechanism opening the closed Streamer::ACTIONS list — the Custom Turbo Stream Actions lesson equivalent.
    # RIGOR: loose
    # TODO: criteria — fill during shape-epic

  Scenario: morph-scroll-preservation
    # Intent: verify and document Idiomorph-backed morph + scroll preservation parity (Morph And Scroll Preservation lesson) — StreamWeaver already ships Idiomorph; this may be verification + docs rather than a build.
    # RIGOR: loose
    # TODO: criteria — fill during shape-epic
