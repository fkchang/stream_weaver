Feature: Modal Dialogs Parity — native dialog omakase
  Match the learnhotwire Modal Dialogs chapters: accessible modals via native
  <dialog>/showModal() (free focus-trap and ::backdrop), forms embedded in modal
  regions, clean open/close lifecycle, and "redirect out of the modal, update the
  page" flows — with zero custom JavaScript in app code. Syllabus rows owned by this
  epic are marked in docs/research/2026-08-22-learnhotwire-syllabus-coverage.md
  (Epic ownership roadmap).
  DEPENDS_ON: turbo-streams-parity (the course inserts/removes dialogs via stream
  actions; StreamWeaver's equivalent needs those primitives).
  UNLOCKS: stimulus-role-parity shaping (last parity epic in the arc).

  Background:
    StreamWeaver precedent: the mermaid fullscreen viewer already uses native
    <dialog>/showModal() internally — the recipe exists, it just is not what the
    general `modal` component uses. The course's dialog lifecycle (insert via stream,
    open modally, embed form in frame, close event cleanup, server-side redirect out)
    maps to fragment + streamer + form_for compositions to be designed at shape time.

  Scenario: shape-epic
    # Intent: assessment-first story — flesh out this epic from the Modal Dialogs preso/chapters, the matrix rows it owns, and the primitives landed by streamweaver-way + turbo-streams-parity. Output is a fully-criteria'd epic, not code.
    # RIGOR: loose — shaping/assessment story; deliverable is the epic itself plus updated core docs
    Given turbo-streams-parity is complete
    When the Modal Dialogs chapters and owned matrix rows are assessed against the modal component and the mermaid-viewer native-dialog precedent via /tyrion-shape
    Then every placeholder scenario below gains real Given/When/Then criteria or is explicitly dropped with a reason
    And docs/research/2026-08-22-learnhotwire-syllabus-coverage.md rows owned by this epic are re-verified and updated
    And the epic context records the parity-demo plan extending examples/my_todos/

  Scenario: native-dialog-modal
    # Intent: rebuild the modal component on native <dialog>/showModal() following the mermaid-viewer precedent — free focus-trap, ::backdrop, ESC handling.
    # RIGOR: strict
    # TODO: criteria — fill during shape-epic

  Scenario: modal-form-flows
    # Intent: form_for embedded in a modal region with validation re-render inside the modal and PRG redirect-out-and-update-page on success — the course's dialog form chapters.
    # RIGOR: strict
    # TODO: criteria — fill during shape-epic

  Scenario: dialog-lifecycle-cleanup
    # Intent: open/close events, close buttons, and cleanup-on-close semantics with zero custom JS in app code.
    # RIGOR: loose
    # TODO: criteria — fill during shape-epic
