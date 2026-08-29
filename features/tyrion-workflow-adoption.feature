Feature: Tyrion Workflow Adoption
  Make Tyrion the authoritative ledger for all new StreamWeaver work while preserving Beads as a legacy backlog that can still be inspected and resolved.

  Scenario: tyrion-primary-guidance
    # Intent: Every new agent session should orient through Tyrion and understand that Beads is no longer allowed to create or prioritize new work.
    Given the repository's tracked AGENTS.md and CLAUDE.md guidance
    When a Claude, Codex, or other coding agent starts work in StreamWeaver
    Then the guidance names Tyrion as the authoritative source for new stories, discoveries, gates, and completion evidence
    And it documents Beads only as a legacy backlog whose existing entries may be searched, updated, or closed

  Scenario: tyrion-hook-cutover
    # Intent: Session and Git hooks should reinforce Tyrion without continuing to execute Beads lifecycle automation.
    Given Claude hooks currently run bd prime and Git uses .beads/hooks
    When the repository workflow is migrated
    Then Claude SessionStart and PreCompact run tyrion prime through the versioned Tyrion shim
    And Claude PreToolUse uses Tyrion's claim gate
    And Git uses a repository-owned hook directory that preserves the StreamWeaver hygiene gate without invoking Beads
    And bin/setup installs the repository hook path and runs Tyrion setup when Tyrion is available

  Scenario: legacy-beads-awareness
    # Intent: The migration must not strand unresolved historical Beads content or allow it to remain a competing source for new work.
    Given unresolved historical issues remain in the Beads database
    When an agent needs historical context or resolves one of those issues
    Then it may use bd list, search, show, update, or close for that existing issue
    But it never creates new Beads issues, claims new work from Beads, or uses bv to choose new work
    And any newly discovered work is recorded in Tyrion instead
