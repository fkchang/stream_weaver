Feature: Visual Plan Components
  Close the gap between StreamWeaver's live canvas and Builder.io's planning-phase
  component vocabulary. Port ImplementationMap, Decision, AnnotatedCode, Diff,
  Wireframe (with device chrome), and ApiEndpoint as first-class StreamWeaver DSL
  methods, then ship /visual-plan and /visual-recap companion skills.

  Background:
    Given a StreamWeaver project with the component adapter pattern established
    And existing components callout.rb and code_block.rb as reference implementations
    And Builder.io reference docs at ~/work/reference/builderio-skills/skills/visual-plan/references/

  Scenario: callout-decision-risk-tones
    # Intent: Add :decision and :risk tone variants to the existing Callout component so agents
    #         can mark settled architecture choices and risk callouts with semantic precision.
    # RIGOR: trivial — extend VARIANTS array, add icons and CSS, no new class or adapter method
    Given the existing Callout component with variants [:info, :warning, :success, :error, :tip]
    When a DSL author writes callout(:decision) or callout(:risk)
    Then the callout renders with a distinct icon (⚖️ for decision, ⚠️ + red for risk)
    And each variant has a named CSS class sw-callout--decision / sw-callout--risk
    And the existing variants are unaffected

  Scenario: implementation-map
    # Intent: File-path-to-rationale mapping component for pre-flight planning — shows what
    #         files will be touched and why before coding starts.
    # RIGOR: loose — new component class + adapter render method + DSL method; no novel logic
    Given a DSL author writes:
      """
      implementation_map files: [
        { path: "lib/auth/session.rb", note: "Add guest token issuer" },
        { path: "app/routes/checkout.rb", note: "Branch on guest vs auth user" }
      ]
      """
    When the canvas renders
    Then each entry renders as a file path with monospace styling and an inline rationale note
    And file paths use a distinct visual treatment (icon, color, or badge) to distinguish from note text
    And the component is scrollable for long file lists

  Scenario: decision-block
    # Intent: Structured architecture decision block with labeled options and a recommended flag,
    #         for capturing planning forks declaratively rather than via interactive buttons.
    # RIGOR: loose — new component class + adapter + DSL; render-only, no state logic
    Given a DSL author writes:
      """
      decision question: "How should guest sessions be stored?" do
        option id: "jwt", label: "JWT in cookie", detail: "Stateless, no DB lookup"
        option id: "opaque", label: "Opaque token in DB",
                detail: "Revocable, enables account merge later", recommended: true
      end
      """
    When the canvas renders
    Then the question appears as a heading
    And each option renders as a labeled card with its detail text
    And the recommended option has a visual "recommended" badge
    And non-recommended options are visually de-emphasized

  Scenario: wf-token-css-foundation
    # Intent: Define the --wf-* CSS custom properties scoped to .sw-wireframe-surface so wireframe
    #         components can use Builder's token vocabulary without polluting StreamWeaver's --sw-* system.
    # RIGOR: trivial — CSS variables only, no Ruby logic, just a scoped stylesheet block
    Given the need for --wf-ink, --wf-muted, --wf-line, --wf-paper, --wf-card,
          --wf-accent, --wf-accent-soft, --wf-warn, --wf-ok, --wf-radius
    When a .sw-wireframe-surface container is rendered
    Then all --wf-* tokens resolve to appropriate values in both light and dark themes
    And .wf-card, .wf-pill, .wf-chip, .wf-muted, button.primary helper classes are defined
    And these styles do not leak outside .sw-wireframe-surface

  Scenario: annotated-code
    # Intent: Code block with line-number-pinned annotation bubbles in a side panel,
    #         for code walkthroughs where margin notes anchor to specific lines.
    # RIGOR: loose — new component; layout is side-by-side flex; reuses Prism.js from code_block
    # BATCHING: component class (1-3), adapter render + CSS (4-6)
    Given a DSL author writes:
      """
      annotated_code language: :ruby, annotations: [
        { line: 3, note: "Guest tokens use 'guest' role to restrict API scopes" },
        { line: 7, note: "24h TTL matches cleanup job cadence" }
      ] do
        <<~RUBY
          def issue_guest_token(email)
            JWT.encode({ sub: email, role: 'guest' }, SECRET, exp: 24.hours.from_now)
          end
        RUBY
      end
      """
    When the canvas renders
    Then the code appears with Prism.js syntax highlighting
    And each annotation appears in a side panel aligned to its target line number
    And the line(s) referenced by an annotation are highlighted or marked
    And annotations do not overlap each other when multiple annotations are close in line number

  Scenario: diff-block
    # Intent: Line-level split diff with +/- syntax, line numbers, and syntax highlighting —
    #         the prerequisite for /visual-recap. Distinct from the panel-level comparison block.
    # RIGOR: loose — new component; uses diffy gem server-side; renders styled +/- lines
    Given the diffy gem is added to the gemspec
    And a DSL author writes:
      """
      diff language: :ruby do
        before { "def old_method\n  session.fetch(:user)\nend" }
        after  { "def current_user\n  JWT.decode(token)\nend" }
      end
      """
    When the canvas renders
    Then removed lines appear with red background and leading "-"
    And added lines appear with green background and leading "+"
    And unchanged context lines appear neutral with leading " "
    And line numbers appear in a gutter column
    And syntax highlighting applies to the language-specific tokens

  Scenario: wireframe-component
    # Intent: HTML mockup wrapped in device chrome (browser/phone/tablet/desktop/popover/card)
    #         using the --wf-* token system and wf-* helper classes. Clean mode only (no rough.js yet).
    # RIGOR: loose — new component + adapter; bulk is CSS for device chrome frames
    # BATCHING: Ruby component class + DSL (1-4), device chrome CSS per surface (5-8), adapter render (9-10)
    Given the wf-token-css-foundation story is complete
    And a DSL author writes:
      """
      wireframe surface: :browser do
        <<~HTML
          <div style="display:flex;flex-direction:column;gap:12px;padding:16px;height:100%">
            <h1>Contacts</h1>
            <span class="wf-pill accent">All 128</span>
            <div class="wf-card">...</div>
          </div>
        HTML
      end
      """
    When the canvas renders
    Then the HTML is wrapped in appropriate device chrome matching the surface
    And browser surface shows a minimal browser chrome (address bar strip, window dots)
    And mobile surface shows a phone bezel with status bar
    And desktop surface shows a desktop window chrome
    And popover and card surfaces show compact floating frames
    And --wf-* tokens apply correctly inside the frame
    And wf-card, wf-pill, button.primary helper classes render with correct styling

  Scenario: api-endpoint
    # Intent: Single API endpoint spec card showing method badge, path, params table,
    #         and response schema — cleaner than mermaid sequence for simple endpoint specs.
    # RIGOR: loose — new component, render-only, structured data → HTML table
    Given a DSL author writes:
      """
      api_endpoint method: :post, path: "/api/v1/guest-sessions",
        description: "Issue a guest session token",
        params: [{ name: "email", type: "string", required: true }],
        response: { token: "string", expires_at: "iso8601" }
      """
    When the canvas renders
    Then the HTTP method appears as a colored badge (POST=green, GET=blue, DELETE=red, etc.)
    And the path appears in monospace next to the method badge
    And params render as a table with name, type, required columns
    And the response schema renders as formatted JSON or a key/type table

  Scenario: sketch-mode
    # Intent: :sketch theme preset that applies rough.js outlines and Excalifont to wireframe
    #         containers, visually distinguishing planning canvases from production dashboards.
    # RIGOR: trivial — load rough.js CDN (like Prism.js), apply to .sw-wireframe-surface via JS init
    Given the wireframe-component story is complete
    And rough.js is loaded via the component_assets CDN pattern
    And a DSL author writes: theme_preset :sketch
    When the page renders
    Then all .sw-wireframe-surface elements get rough.js border treatment
    And Excalifont (or similar hand-drawn font) applies to all text within wireframe surfaces
    And non-wireframe canvas content (charts, tables, text) is unaffected

  Scenario: visual-plan-skill
    # Intent: /visual-plan companion skill that Claude Code invokes before a coding task to push
    #         a structured planning canvas: implementation_map + decision blocks + optional wireframes.
    # RIGOR: loose — skill file + documented DSL pattern; no new components needed (depends on P0 stories)
    Given implementation-map, decision-block, and callout-decision-risk-tones stories are complete
    And a skill file exists at lib/stream_weaver/skills/visual-plan/SKILL.md
    When a Claude Code agent invokes /visual-plan before starting a task
    Then the skill instructs the agent to: start a canvas session, push implementation_map showing
         planned file changes, push decision blocks for open architecture choices, and optionally
         push wireframes for UI work
    And the skill instructs the agent to use canvas-wait for decisions that need user sign-off
    And the skill documents the DSL methods available for planning (implementation_map, decision, callout(:decision), wireframe)

  Scenario: visual-recap-skill
    # Intent: /visual-recap companion skill that Claude Code invokes after completing a task to push
    #         a structured recap canvas: implementation_map of what changed + diff blocks + summary.
    # RIGOR: loose — skill file + shell command pattern for git diff integration; no new components
    Given diff-block and implementation-map stories are complete
    And a skill file exists at lib/stream_weaver/skills/visual-recap/SKILL.md
    When a Claude Code agent invokes /visual-recap after finishing a task
    Then the skill instructs the agent to: run git diff HEAD~1, parse changed files,
         push implementation_map showing what changed and why, push diff blocks for key file changes,
         and optionally push annotated_code for the most significant change
    And the recap canvas is incremental — it can be updated mid-task before the task is complete
    And the skill notes StreamWeaver's advantage: recap is live, not a one-shot static publish
