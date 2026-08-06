# frozen_string_literal: true

# UAT demo for three framework gaps closed in one session (2026-08-06):
#   1. Table cell style escape hatches (col.style, id_style:, id_column:)
#   2. collapsible subtitle:/badge_text:/badge_variant: parity with expandable_card
#   3. copy_button primitive + code_block copy: affordance
#
# Run: SW_NO_OPEN=1 ruby examples/components/uat_gaps_demo.rb
# Open: http://localhost:4567 (or whatever port the banner prints)

require_relative '../../lib/stream_weaver'

TEAM = [
  { assignee: "Priya Patel", tier: "P1", open_issues: 4 },
  { assignee: "Sam Okafor",  tier: "P2", open_issues: 1 },
  { assignee: "Jin Watanabe", tier: "P0", open_issues: 7 }
].freeze

app "UAT: Table / Collapsible / Copy gaps", layout: :wide do
  header "Three Gaps, One Session"
  text "Each card below is a UAT checkpoint for one specific fix. See docs/ideas/2026-08-06-table-collapsible-clipboard-gaps.md."

  vstack spacing: :lg do
    # ---------------------------------------------------------------
    card do
      header3 "1a. Table: legacy default UNCHANGED (regression guard)"
      text "Raw headers:/rows: table, no options. First column (Key) should still render accent-blue monospace, like every table before this session."
      table headers: ["Key", "Title", "Status"],
            rows: [
              ["PROJ-101", "Fix login bug", "Open"],
              ["PROJ-102", "Add dark mode", "In Progress"]
            ]
    end

    card do
      header3 "1b. Table: id_column escape hatch for raw tables"
      text "Same shape as Sprint Focus's Team table -- first column is an Assignee name, not an id. id_column: false turns OFF the accent-mono treatment table-wide."
      table headers: ["Assignee", "Tier", "Open Issues"],
            rows: TEAM.map { |r| [r[:assignee], r[:tier], r[:open_issues]] },
            id_column: false
    end

    card do
      header3 "1c. Table: id_column pointed at a different column"
      text "id_column: 1 -- only the Tier column (index 1) gets the identifier treatment."
      table headers: ["Assignee", "Tier", "Open Issues"],
            rows: TEAM.map { |r| [r[:assignee], r[:tier], r[:open_issues]] },
            id_column: 1
    end

    card do
      header3 "1d. Table: column DSL with style: Proc (per-row) + id_style: false"
      text "Open Issues column gets a Proc style (red when > 3); Assignee opts out of accent via id_style: false even though it's column 0."
      table TEAM do
        column :assignee, id_style: false
        column :tier
        column :open_issues, header: "Open Issues",
               style: ->(item) { item[:open_issues] > 3 ? "color: #c0392b; font-weight: 700;" : nil }
      end
    end

    # ---------------------------------------------------------------
    card do
      header3 "2a. Collapsible: plain (legacy look, unchanged)"
      collapsible "Show details" do
        text "No subtitle, no badge -- must look exactly like it did before this session."
      end
    end

    card do
      header3 "2b. Collapsible: subtitle + badge (the actual gap)"
      collapsible "Priority Alignment: cultiv-dashboard", subtitle: "12 issues, 83% aligned", badge_text: "P1", badge_variant: :danger do
        text "This is the pattern that used to force a switch to expandable_card just for a badge."
      end
    end

    card do
      header3 "2c. Collapsible: class:/style: forwarding (previously silently dropped)"
      collapsible "Custom-styled section", subtitle: "class:/style: now apply", badge_text: "NEW", badge_variant: :success,
                  class: "uat-custom-collapsible", style: "border-color: #2563eb;" do
        text "Inspect the outer div -- it should carry class=\"collapsible sw-collapsible uat-custom-collapsible\" and the inline border-color."
      end
    end

    # ---------------------------------------------------------------
    card do
      header3 "3a. copy_button: plain text"
      copy_button "Copy summary", text: "Sprint Focus: 3 gaps closed, 2613 tests green."
    end

    card do
      header3 "3b. copy_button: hostile payload (quotes, newline, backslash, <script>)"
      text "Click Copy, then paste somewhere to confirm the exact payload round-trips -- this is the safety-critical case."
      copy_button "Copy hostile text", text: "Line one \"quoted\"\nLine two with a backslash \\ and <script>alert(1)</script>"
    end

    card do
      header3 "3c. code_block: copy: true (opt-in, default off elsewhere)"
      code_block <<~RUBY, lang: "ruby", copy: true
        def hello(name)
          puts "Hello, \#{name}!"
        end
      RUBY
      text "Below: same code_block with copy: omitted -- must show NO copy affordance (regression guard)."
      code_block <<~RUBY, lang: "ruby"
        def goodbye(name)
          puts "Goodbye, \#{name}!"
        end
      RUBY
    end
  end
end.run!
