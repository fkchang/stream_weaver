Feature: Canvas-Safe — fix the backend-less lies, then document what plays well
  Promoted from spike disc-093 (frontend-only compatibility matrix,
  docs/research/frontend-only-matrix.md). Two-thirds of the DSL is safe on
  every backend-less surface; the failures cluster in three mechanisms and
  several components actively lie (look interactive, do nothing — or report
  wrong data). Fixes ship BEFORE advice: docs that say "plays well" while
  five components deceive users would be false. Then the concerns doc, the
  progressive-disclosure reference skill, and an executable compatibility
  spec so the matrix cannot rot.

  Background:
    Given the compatibility matrix at docs/research/frontend-only-matrix.md (mechanisms M1-M9)
    And the three backend-less contexts: live canvas (bridge + sendEvent), canvas-read (render-only), exported HTML (static, possibly CSP-locked)

  Scenario: chart-export-allowlist
    # Intent: disc-094 — export ships no Chart.js for any shorthand chart; empty box, console-silent.
    # RIGOR: strict — the bug IS allowlist drift; the fix must be drift-proof
    Given an app using bar_chart, line_chart, pie_chart, sparkline, stacked_bar_chart, area_chart, hbar_chart, or doughnut_chart
    When streamweaver export runs
    Then the exported HTML includes the Chart.js library
    And the chart renders (guarded x-init actually executes Chart constructor)
    And the inclusion test keys on the ChartBase family, not a class allowlist that new chart types silently miss
    And a spec iterates every chart DSL method and asserts its export carries Chart.js

  Scenario: reader-dead-controls
    # Intent: disc-095 — canvas-read renders sendEvent controls that grey themselves out and die (sendEvent never defined).
    # RIGOR: strict — behavior semantics; the current state is worse than inert
    Given a doc containing button or radio_group opened in canvas-read
    When the reader renders it
    Then interactive controls are honestly non-interactive: visibly disabled with an explanatory title, or rendered inert without self-disabling click handlers
    And no control calls an undefined sendEvent (zero ReferenceErrors on click)
    And a control never mutates its own visual state in response to a click that did nothing
    And live-canvas rendering (real bridge, sendEvent defined) is byte-for-byte unchanged

  Scenario: checkbox-group-array
    # Intent: disc-098 — getFormState delivers the last checkbox's boolean instead of the selected array to canvas-wait.
    # RIGOR: strict — confidently-wrong data to the agent, worse than dead
    Given a canvas doc with a checkbox_group and an agent waiting on canvas-wait
    When the user selects multiple items and the form state is harvested
    Then the group's key carries the ARRAY of selected item values
    And single checkboxes (non-group) still deliver booleans
    And a spec locks the harvested payload shape for both cases

  Scenario: canvas-action-parity
    # Intent: disc-097 — only button/radio were ported to sendEvent; clickable(action:), menu_item blocks, form submit, tag_buttons, chip_group hx-post into bridge 404s, silently dead beside working buttons.
    # RIGOR: strict — the asymmetry is invisible in the DSL; every ported site needs behavior proof
    Given a canvas doc using clickable with an action, menu_item with a block, form submit, tag_buttons, or chip_group
    When rendered in websocket mode
    Then each either dispatches through sendEvent like button does, or renders honestly degraded (disabled + title), never an hx-post into a route the bridge lacks
    And the choice per component is recorded with rationale in the ledger
    And http-mode rendering for all five is byte-for-byte unchanged
    And specs cover every htmx_attrs call site's websocket-mode behavior so a future component cannot silently join the dead list

  Scenario: deck-honest-ui
    # Intent: disc-096 — swDeckSelect confirms selection (class + aria-checked) BEFORE an uncaught fetch that 404s on every backend-less surface.
    # RIGOR: strict — optimistic UI lying about recorded state, aria-announced
    Given a design_deck rendered anywhere /deck/* routes do not exist
    When the user selects an option, blurs a note, or uses the confirmation bar
    Then visual/aria confirmation applies only after the backing call succeeds, or the deck renders read-only where no backend serves /deck/*
    And failed deck fetches surface (console at minimum), never swallowed
    And standalone-mode deck behavior is unchanged

  Scenario: frontend-only-doc
    # Intent: the concerns doc — the three-context model and what survives where, pointing into the skill.
    # RIGOR: loose — writing from settled facts; clean-room acceptance gates it
    Given the matrix and the fixes above are in
    When docs/frontend-only.md is written
    Then it explains the three contexts and mechanisms (Alpine-owned state everywhere; sendEvent needs the bridge; round-trips need a host; CDN assets die under CSP with x-show content vanishing)
    And it carries the compatibility table derived from the matrix
    And it names the gotchas: silently-dead vs degrades, checkbox_group history, chart export history
    And docs/components_reference.md and llms.txt gain pointers to it
    And a clean-room agent given only this doc correctly predicts the behavior of five sampled components per context

  Scenario: canvas-safe-skill
    # Intent: the progressive-disclosure reference skill; visual-companion and doc-builder point into it.
    # RIGOR: loose — instruction deliverable; clean-room acceptance gates it
    Given the concerns doc exists
    When the in-repo skill is created
    Then SKILL.md carries the context model and the plays-well component list at a glance
    And per-component reference files carry advice + a minimal working example each, loaded on demand
    And at least one comprehensive example renders correctly in all three contexts
    And streamweaver-visual-companion and streamweaver-doc-builder reference it instead of duplicating it
    And a clean-room agent given only the skill produces a canvas doc that avoids every silently-dead component

  Scenario: compat-matrix-spec
    # Intent: the executable matrix — advice that cannot rot.
    # RIGOR: strict — it enforces every other story's claims
    Given the fixes are in
    When the compatibility spec suite runs
    Then it renders representative components per context and asserts the matrix verdicts mechanically (no hx-post in export; sendEvent only alongside bridge scripts; Chart.js present when any chart is; no self-disabling dead handlers in reader output)
    And a component whose backend-less behavior regresses fails the suite with a message naming the matrix
    And the suite runs in the normal rspec run, not a separate opt-in
