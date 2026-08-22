Feature: Way Teaching — the advanced tutorial
  Turn the sealed streamweaver-way epic's assets (proof app, skill recipes, laws,
  measured numbers, clean-room-caught gotchas) into teaching material for humans
  AND agents: an advanced tutorial that rebuilds the four benchmark features
  step-by-step, dogfooding StreamWeaver itself as the delivery medium. Doubles as
  study-group material and open-source launch content.

  Scenario: advanced-tutorial
    # Intent: "Build My Todos: the StreamWeaver Way" — a :doc-theme StreamWeaver doc-app plus a markdown twin, teaching the four features by rebuilding them, each step naming the law it obeys and the gotcha it avoids.
    # RIGOR: loose — docs/app authoring on proven assets; clean-room gate is the real acceptance
    Given the sealed streamweaver-way epic assets: examples/my_todos, the streamweaver-way skill, llms.txt sections, and the measured numbers
    When a tutorial is authored as a :doc-theme StreamWeaver app under examples/tutorials/ plus a markdown twin under docs/tutorials/
    Then it rebuilds inline editing, scoped search, lazy hover cards, and Russian-doll infinite scroll step-by-step, each step naming the law it obeys and the gotcha it avoids, with the real measured numbers
    And llms.txt links the tutorial and CHANGELOG records it
    And a clean-room agent following only the tutorial produces a working four-feature app with zero custom JavaScript
