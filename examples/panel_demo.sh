#!/bin/bash
# Demo: Side-by-side panel with rich UI
#
# This demonstrates using StreamWeaver panels to present interactive UI
# alongside a terminal session. Useful for:
#   - Presenting analysis results with checkboxes for selection
#   - Collecting structured input via forms
#   - Showing rich content that's hard to display in terminal
#
# The panel opens in a split pane (iTerm2) or separate browser window.

set -e

SESSION="panel-demo-$$"

echo "=== StreamWeaver Panel Demo ==="
echo ""
echo "This demonstrates a rich UI for collecting structured user input"
echo "that would be difficult to present in a terminal-only interface."
echo ""

# Start the panel
echo "Starting panel..."
streamweaver panel "$SESSION" 2>/dev/null

sleep 1

# Push the analysis report UI
echo "Pushing analysis report..."
streamweaver canvas-push "$SESSION" <<'RUBY'
header1 "Code Quality Analysis"
md "Found **7 issues** across 4 files. Select which issues to address:"

# Multi-select checkboxes for issues - grouped in cards
card do
  header3 "Critical Issues"
  checkbox :issue_1, "**N+1 Query** in `app/models/user.rb:47`"
  checkbox :issue_2, "**SQL Injection Risk** in `app/controllers/search_controller.rb:23`"
end

card do
  header3 "Warnings"
  checkbox :issue_3, "**Unused Variable** `temp_data` in `lib/processor.rb:156`"
  checkbox :issue_4, "**Long Method** `calculate_totals` (87 lines) in `app/services/billing.rb:34`"
  checkbox :issue_5, "**Missing Index** on `orders.user_id` - queries may be slow"
end

card do
  header3 "Suggestions"
  checkbox :issue_6, "**Deprecated Method** - use ActiveRecord query interface"
  checkbox :issue_7, "**Magic Number** `86400` should be `1.day.to_i`"
end

md "---"

# Additional options
header3 "Fix Options"
columns widths: ['50%', '50%'] do
  column do
    radio_group :approach, ["Fix in place", "Create separate PR per issue", "Generate TODO comments only"]
  end
  column do
    checkbox :run_tests, "Run tests after each fix"
    checkbox :auto_commit, "Auto-commit each fix"
  end
end

md "---"

button "Apply Selected Fixes", variant: "primary"
RUBY

echo ""
echo "Panel ready! The browser should show a rich code analysis report."
echo ""
echo "Features demonstrated:"
echo "  - Styled severity badges (error/warning/info)"
echo "  - Multi-select checkboxes for issues"
echo "  - Grouped cards for organization"
echo "  - Two-column layout for options"
echo "  - Radio group for approach selection"
echo ""
echo "Waiting for your selection..."
echo ""

# Wait for user interaction
result=$(streamweaver canvas-wait "$SESSION" 2>/dev/null)

echo "=== Your Selection ==="
echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"

# Cleanup
streamweaver canvas-close "$SESSION" 2>/dev/null

echo ""
echo "Demo complete! The script received structured JSON with:"
echo "  - Selected checkboxes (issues to fix)"
echo "  - Radio selection (approach)"
echo "  - Additional options (run_tests, auto_commit)"
echo ""
echo "This pattern enables rich interactive forms while keeping"
echo "the main workflow in the terminal."
