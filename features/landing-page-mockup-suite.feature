Feature: StreamWeaver landing-page mockup suite
  Show StreamWeaver's breadth through one homepage and five focused local landing-page
  mockups, using the existing Ruby DSL and a shared Baalda-inspired visual language.
  The suite should make the qualitative case that concise DSL source reduces both
  generation effort and the later reading and maintenance burden, without unsupported
  numerical claims or changes to StreamWeaver's framework and Org implementation.

  Scenario: build-six-page-landing-suite
    # Intent: Deliver a quick, coherent, reviewable demonstration of StreamWeaver across six linked pages.
    # RIGOR: loose — composition and responsive presentation using existing DSL primitives; no novel framework logic.
    Given a clean worktree at the current committed StreamWeaver HEAD
    And the implementation is confined to new files under examples/landing_pages
    When the builder creates a homepage and focused pages for agent communication, visual companions, living documents, applications, and plan and code review
    Then one local preview exposes all six pages through functional navigation
    And the homepage leads with "EXPRESS MORE. WRITE LESS." and a code-to-render stage
    And every page uses the same Baalda-inspired system of oversized uppercase editorial headlines, mono eyebrows, thin rules, pale neutral surfaces, restrained pills, and generous whitespace
    And the agent page leads with "GIVE AGENTS A SHARED SURFACE" and stages a structured decision storyboard
    And the visual page leads with "MAKE THE WORK VISIBLE" and stages a diagram and comparison
    And the document page leads with "DOCUMENTS YOU CAN EXPLORE" and stages a compact editorial document with a table of contents
    And the application page leads with "FROM SCRIPT TO USEFUL APP" and stages a small useful dashboard
    And the review page leads with "REVIEW THE DECISION AND THE DIFF" and stages a diff with an acceptance criterion
    And the six pages feel purpose-built rather than repeating one generic hero-card template
    And the homepage connects the five uses into one broad product story
    And the copy states qualitatively that concise DSL lowers generation plus subsequent reading and maintenance burden without unsupported numeric claims
    And shared styles and helpers are defined once and reused by all six page sources
    And the pages remain readable and navigable at desktop and narrow viewport sizes
    And source inspection links or equivalent visible affordances make the underlying DSL easy to review
    And the suite uses only existing public StreamWeaver capabilities and does not modify lib, spec, framework behavior, or Org reader and writer behavior
    And a representative page is checked against the existing Org export path and any expressiveness gap is recorded as a finding rather than fixed in this epic
    And the final handoff includes local preview instructions and the six inspectable DSL source paths
