Feature: Presentation genre spike
  Prove that StreamWeaver can reproduce a polished consulting-style slide deck
  with a thin Ruby DSL presentation shell rather than a new rendering system.

  Scenario: consulting-presentation-spike
    # Intent: Recreate four representative slides from the supplied kickoff deck and measure the actual framework work required.
    # RIGOR: loose - visual component plumbing with focused rendering checks
    Given the supplied 16:9 reference deck
    When the spike example renders its title, section divider, card grid, and milestone slides
    Then each slide appears within a 16:9 presentation stage with recurring footer and slide number chrome
    And existing StreamWeaver navigation moves through all four slides
    And standalone HTML export contains all four slides without requiring a new export engine
    And Org Writer and Reader preserve the presentation DSL through the existing raw Ruby escape hatch
    And the spike adds no native Org dialect, PDF engine, presenter mode, animation system, or phone-specific layout system

  Scenario: full-consulting-deck
    # Intent: Build the complete 20-slide deck from low-level primitives, then extract only patterns proven by the finished consumer.
    # RIGOR: loose - visual composition followed by evidence-based refactoring
    Given the supplied 20-page reference deck and the existing presentation spike
    When a sanitized full-deck example is rendered with low-level StreamWeaver primitives
    Then the standalone export contains exactly 20 ordered presentation stages matching the reference slide sequence
    And browser navigation reaches every slide from 1 through 20
    And every visible stage measures 16:9 with no horizontal or vertical overflow at the review viewport
    And the first-pass implementation records repeated layout patterns and their occurrence counts
    When patterns repeated at least three times or proven materially error-prone are extracted
    Then the refactored deck preserves the same 20 slide IDs, headings, navigation, aspect ratio, and overflow results
    And no client names, confidential source text, session-local paths, native Org dialect, PDF engine, presenter mode, animation system, or phone-specific layout system are added
