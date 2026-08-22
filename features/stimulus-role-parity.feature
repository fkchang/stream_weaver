Feature: Stimulus Role Parity — Alpine's half of the bargain
  Match what the learnhotwire Stimulus chapters give Rails, in StreamWeaver's chosen
  idiom (inline Alpine + registered components instead of Stimulus classes). Most
  Stimulus lessons are N-A-by-design (see matrix), but the course's concrete features
  are not: drag-and-drop todo reordering (sortable + acts_as_list), autogrow textarea,
  submits-with button label swap, and lifecycle guardrails (the leaked-listener bug
  class Stimulus prevents by construction and inline Alpine leaves to discipline).
  Syllabus rows owned by this epic are marked in
  docs/research/2026-08-22-learnhotwire-syllabus-coverage.md (Epic ownership roadmap).
  DEPENDS_ON: modal-dialogs-parity (completes the arc; also its shaping should absorb
  whatever lifecycle lessons the dialog work surfaces).

  Background:
    StreamWeaver's architectural bet (docs/streamweaver-frontend-vision.md): Alpine
    x-data declarations + StreamWeaver.register_component instead of Stimulus
    controllers. This epic is where that bet gets stress-tested against the course's
    real Stimulus-built features — each either gets a DSL-level primitive (zero app
    JS) or an honest N-A-by-design entry with the registered-component recipe.

  Scenario: shape-epic
    # Intent: assessment-first story — flesh out this epic from the Stimulus chapters, the matrix rows it owns, and everything learned across the three prior parity epics. Output is a fully-criteria'd epic, not code.
    # RIGOR: loose — shaping/assessment story; deliverable is the epic itself plus updated core docs
    Given modal-dialogs-parity is complete
    When the Stimulus chapters and owned matrix rows are assessed against Alpine-idiom equivalents via /tyrion-shape
    Then every placeholder scenario below gains real Given/When/Then criteria or is explicitly dropped with a reason
    And docs/research/2026-08-22-learnhotwire-syllabus-coverage.md rows owned by this epic are re-verified and updated
    And the epic context records which lessons are closed as N-A-by-design with their registered-component recipes

  Scenario: sortable-drag-drop
    # Intent: drag-and-drop reordering primitive (sortable: option) — core to the course's My Todos app (todo positions), the one Stimulus feature with no cheap Alpine-inline answer.
    # RIGOR: strict
    # TODO: criteria — fill during shape-epic

  Scenario: submits-with-label-swap
    # Intent: data-turbo-submits-with equivalent — button label swap during in-flight submission, additive to the existing hx-disabled-elt behavior.
    # RIGOR: loose
    # TODO: criteria — fill during shape-epic

  Scenario: autogrow-textarea
    # Intent: autogrow textarea as a DSL option — small, standalone course feature.
    # RIGOR: loose
    # TODO: criteria — fill during shape-epic

  Scenario: alpine-lifecycle-guardrails
    # Intent: the Stimulus value StreamWeaver's Alpine bet currently lacks by enforcement — listener cleanup / lifecycle discipline across morphs; decide guardrail vs documented convention.
    # RIGOR: loose
    # TODO: criteria — fill during shape-epic
