Feature: Landing-page proof follow-up
  Turn the landing suite's strongest promise into inspectable proof: first ship one
  reusable code-and-render primitive, then adopt it in clearer audience-aware pages,
  then measure one fixed source-size case without overstating what the measurement proves.
  The three stories run in file order and do not create a registry, docs site, or publication flow.

  Scenario: reusable-code-preview
    # Intent: Make one trusted Ruby DSL snippet the visible and executable source of a reusable preview.
    # RIGOR: strict — source evaluation, identity isolation, and runtime boundaries can fail plausibly and silently.
    Given a public code_preview(source, id: nil, title: nil, file: nil, layout: :side_by_side) DSL with the source as the first positional argument
    When trusted self-contained display-only Ruby DSL source is evaluated
    Then that exact source is both displayed and rendered, with side_by_side as the default and stacked placing preview before code
    And omitted ids use a short source digest while repeated identical previews and explicit ids produce duplicate-safe DOM identity
    And a public headless evaluation entry point returns rendered HTML or raises, while visible failures honestly preserve the source and unsupported layouts raise
    And focused tests cover source identity, optional labels, layout order, identity isolation, error behavior, and the documented server, build, export, canvas, and Opal boundaries

  Scenario: adopt-real-proof-copy
    # Intent: Explain what StreamWeaver is, who it serves, and what it can make through real code-and-render proof.
    # RIGOR: loose — landing composition and copy using the completed code_preview contract.
    Given reusable-code-preview is complete and the six existing landing routes remain available
    When the overview and focused pages adopt real self-contained code_preview examples
    Then the overview leads with "ONE RUBY FILE. A REAL INTERFACE." and the category line "Ruby DSL for interfaces agents can write and people can use."
    And plain-language audience copy addresses the Ruby author, the agent author, and the reader without internal product jargon
    And verified breadth includes slide decks, charts, diagrams, and forms without unsupported counts or numerical savings claims
    And each category hero renders its own real example, all six routes and navigation links still resolve, and the review page displays an "Exploration" label

  Scenario: benchmark-source-token-workflow
    # Intent: Produce one reproducible source-size case for generation, full reading, and revision without claiming model performance.
    # RIGOR: loose — deterministic fixtures and counting, with methodological judgment but no novel product logic.
    Given adopt-real-proof-copy is complete and one fixed fixture specifies a title, three metrics, a four-row table, and a badge
    When equivalent reusable StreamWeaver, plain HTML and CSS, and React component versions are measured with a pinned tokenizer
    Then the reproducible output reports initial authored source, full-source reread, a fixed revision patch, and final source tokens for each version
    And the fixed revision adds a status column and changes the badge rule consistently across all three versions
    And app source, local CSS, setup code, reusable helpers, runtime dependencies, tokenizer identity and version, and counting commands are disclosed
    And the report labels token counts as source-size proxies, makes no model billing, comprehension, generation-speed, or live-run claims, and reserves broader conclusions for later study
