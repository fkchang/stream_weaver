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
