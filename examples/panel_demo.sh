#!/bin/bash
# Demo: Multi-step workflow showing StreamWeaver's "wow factor"
#
# This demonstrates a 4-step code analysis workflow:
#   1. Issue Selection - Cards, checkboxes, radio groups
#   2. Diff Preview - Side-by-side code with syntax highlighting
#   3. Progress - Animated progress bars, pulsing status dots
#   4. Results Summary - Charts, stats, sortable tables
#
# TUI Comparison:
#   - TUI can't do: syntax highlighting, side-by-side columns, animated progress,
#     pulsing indicators, charts, clickable links, expandable cards
#   - StreamWeaver makes all of this trivial

set -e

SESSION="panel-demo-$$"

echo "=== StreamWeaver Panel Demo: Multi-Step Workflow ==="
echo ""
echo "This demo showcases visual capabilities impossible in TUI:"
echo "  - Syntax-highlighted code diffs"
echo "  - Animated progress indicators"
echo "  - Interactive charts and tables"
echo "  - Collapsible sections and status dots"
echo ""

# Start the panel
echo "Starting panel..."
streamweaver panel "$SESSION" 2>/dev/null

sleep 1

# ============================================================================
# STEP 1: Issue Selection
# ============================================================================
step1_selection() {
  echo ""
  echo "Step 1: Issue Selection"
  echo "  Features: cards, badges, checkboxes, radio_group, columns, hstack"
  echo ""
  streamweaver canvas-push "$SESSION" <<'RUBY'
header1 "Code Quality Analysis"
md "Found **7 issues** across 4 files. Select which issues to address:"

# Critical issues - grouped in a card
card do
  hstack spacing: :sm, align: :center do
    badge "2", variant: :danger
    header3 "Critical Issues"
  end
  checkbox :issue_n1, "**N+1 Query** in `app/models/user.rb:47` - 23 extra DB calls per request"
  checkbox :issue_sql, "**SQL Injection Risk** in `app/controllers/search_controller.rb:23`"
end

card do
  hstack spacing: :sm, align: :center do
    badge "3", variant: :warning
    header3 "Warnings"
  end
  checkbox :issue_unused, "**Unused Variable** `temp_data` in `lib/processor.rb:156`"
  checkbox :issue_long, "**Long Method** `calculate_totals` (87 lines) in `app/services/billing.rb:34`"
  checkbox :issue_index, "**Missing Index** on `orders.user_id` - queries may be slow"
end

card do
  hstack spacing: :sm, align: :center do
    badge "2", variant: :info
    header3 "Suggestions"
  end
  checkbox :issue_deprecated, "**Deprecated Method** - use ActiveRecord query interface"
  checkbox :issue_magic, "**Magic Number** `86400` should be `1.day.to_i`"
end

md "---"

# Fix options in two columns
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

hstack spacing: :md do
  button "Cancel", id: "btn_cancel", style: :secondary
  button "Preview Changes", id: "btn_preview", variant: "primary"
end
RUBY

  result=$(streamweaver canvas-wait "$SESSION" 2>/dev/null)
  echo "Selection result: $result"

  # Check which button was clicked
  button_id=$(echo "$result" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('button', d.get('_button', '')))" 2>/dev/null || echo "")

  if [[ "$button_id" == *"cancel"* ]]; then
    echo "User cancelled."
    streamweaver canvas-close "$SESSION" 2>/dev/null
    exit 0
  fi

  # Store selection for later steps
  SELECTION="$result"
}

# ============================================================================
# STEP 2: Diff Preview
# ============================================================================
step2_diff_preview() {
  echo ""
  echo "Step 2: Diff Preview"
  echo "  Features: cards, columns, alerts (red/green), inline code, badges"
  echo ""
  streamweaver canvas-push "$SESSION" <<'RUBY'
header1 "Review Changes"
md "Preview the fixes before applying. Expand each to see the changes:"

# N+1 Query Fix
card do
  hstack spacing: :sm, align: :center do
    badge "Performance", variant: :info
    header3 "user.rb - N+1 Query Fix"
  end
  columns widths: ['50%', '50%'] do
    column do
      md "**Before** (N+1 problem)"
      alert variant: :error do
        md "`users.each { |u| u.posts.count }`"
        md "Each iteration triggers a DB query!"
      end
    end
    column do
      md "**After** (Eager loaded)"
      alert variant: :success do
        md "`users.includes(:posts).each { |u| u.posts.count }`"
        md "Single query loads all data upfront"
      end
    end
  end
  md "**Impact:** Reduces queries from **24** to **2**"
end

# SQL Injection Fix
card do
  hstack spacing: :sm, align: :center do
    badge "Security", variant: :danger
    header3 "search_controller.rb - SQL Injection Fix"
  end
  columns widths: ['50%', '50%'] do
    column do
      md "**Before** (Vulnerable)"
      alert variant: :error do
        md '`where("name LIKE \'%\#{q}%\'")`'
        md "User input directly in SQL!"
      end
    end
    column do
      md "**After** (Parameterized)"
      alert variant: :success do
        md '`where("name LIKE ?", "%\#{q}%")`'
        md "Safe parameterized query"
      end
    end
  end
  md "**Impact:** Prevents SQL injection attacks"
end

# Long Method Refactor
card do
  hstack spacing: :sm, align: :center do
    badge "Maintainability", variant: :warning
    header3 "billing.rb - Long Method Refactor"
  end
  columns widths: ['50%', '50%'] do
    column do
      md "**Before** (87 lines)"
      alert variant: :warning do
        md "Monolithic `calculate_totals` method"
        md "Tax, discount, shipping all inline"
      end
    end
    column do
      md "**After** (8 lines)"
      alert variant: :success do
        md "Extracted: `calculate_subtotal`"
        md "Extracted: `calculate_tax`, `apply_discounts`"
      end
    end
  end
  md "**Impact:** Improved readability and testability"
end

md "---"

hstack spacing: :md do
  button "Go Back", id: "btn_back", style: :secondary
  button "Apply Fixes", id: "btn_apply", variant: "primary"
end
RUBY

  result=$(streamweaver canvas-wait "$SESSION" 2>/dev/null)
  echo "Preview result: $result"

  button_id=$(echo "$result" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('button', d.get('_button', '')))" 2>/dev/null || echo "")

  if [[ "$button_id" == *"back"* ]]; then
    # Go back to step 1
    step1_selection
    step2_diff_preview
    return
  fi
}

# ============================================================================
# STEP 3: Progress Animation
# ============================================================================
step3_progress() {
  echo ""
  echo "Step 3: Progress Animation"
  echo "  Features: spinner, progress_bar (animated), status_dot (with pulse), activity_item"
  echo ""

  # Show progress for each "fix" being applied
  local fixes=("user.rb" "search_controller.rb" "billing.rb" "processor.rb" "constants.rb")
  local fix_names=("N+1 Query" "SQL Injection" "Long Method" "Unused Variable" "Magic Numbers")
  local total=${#fixes[@]}

  for i in "${!fixes[@]}"; do
    local completed=$((i))
    local current=$((i + 1))
    local current_file="${fixes[$i]}"
    local current_name="${fix_names[$i]}"
    local progress=$((current * 100 / total))

    # Generate status based on index
    local s0_status="gray" s0_pulse=""
    local s1_status="gray" s1_pulse=""
    local s2_status="gray" s2_pulse=""
    local s3_status="gray" s3_pulse=""
    local s4_status="gray" s4_pulse=""

    # Set completed items to green, current to pulsing green
    [[ $i -ge 1 ]] && s0_status="green"
    [[ $i -ge 2 ]] && s1_status="green"
    [[ $i -ge 3 ]] && s2_status="green"
    [[ $i -ge 4 ]] && s3_status="green"
    [[ $i -ge 5 ]] && s4_status="green"

    # Set current item to pulse
    case $i in
      0) s0_status="green"; s0_pulse=", pulse: true" ;;
      1) s1_status="green"; s1_pulse=", pulse: true" ;;
      2) s2_status="green"; s2_pulse=", pulse: true" ;;
      3) s3_status="green"; s3_pulse=", pulse: true" ;;
      4) s4_status="green"; s4_pulse=", pulse: true" ;;
    esac

    streamweaver canvas-push "$SESSION" <<RUBY
header1 "Applying Fixes"

# Show spinner with current task
hstack spacing: :md, align: :center do
  spinner size: :md
  md "**Processing:** ${current_file} - ${current_name}"
end

progress_bar value: ${progress}, show_label: true, animated: true, variant: :success

md "---"

header3 "File Status"
hstack spacing: :lg, align: :center do
  status_dot status: :${s0_status}${s0_pulse}, label: "user.rb"
  status_dot status: :${s1_status}${s1_pulse}, label: "search.rb"
  status_dot status: :${s2_status}${s2_pulse}, label: "billing.rb"
  status_dot status: :${s3_status}${s3_pulse}, label: "processor.rb"
  status_dot status: :${s4_status}${s4_pulse}, label: "constants.rb"
end

md "---"

card do
  header3 "Activity Log"
  vstack spacing: :none do
$(
    # Generate activity items dynamically
    for j in $(seq 0 $i); do
      if [[ $j -lt $i ]]; then
        echo "    activity_item time: \"0:0$((j*2+2))\", title: \"Fixed ${fixes[$j]} - ${fix_names[$j]}\", type: :task"
      else
        echo "    activity_item time: \"now\", title: \"Processing ${fixes[$j]} - ${fix_names[$j]}...\", type: :research"
      fi
    done
)
  end
end
RUBY

    sleep 0.3  # Quick visual update
  done
}

# ============================================================================
# STEP 4: Results Summary
# ============================================================================
step4_results() {
  echo ""
  echo "Step 4: Results Summary"
  echo "  Features: cards, badges, alerts, sortable table, collapsible sections"
  echo ""
  streamweaver canvas-push "$SESSION" <<'RUBY'
header1 "Fixes Applied Successfully"

# Summary cards with badges
hstack spacing: :lg do
  card do
    hstack spacing: :sm, align: :center do
      badge "5", variant: :success
      md "**Issues Fixed**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "2", variant: :warning
      md "**Issues Skipped**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "40", variant: :success
      md "**Tests Passing**"
    end
  end
end

md "---"

# Performance improvement highlight
alert variant: :success, title: "Performance Improved" do
  md "Average response time reduced from **2400ms** to **180ms** (92% faster)"
end

md "---"

# Detailed results table
header3 "Fix Details"
table [
  { file: "user.rb", issue: "N+1 Query", status: "✅ Fixed", tests: "12 passed", impact: "High" },
  { file: "search_controller.rb", issue: "SQL Injection", status: "✅ Fixed", tests: "8 passed", impact: "Critical" },
  { file: "billing.rb", issue: "Long Method", status: "✅ Fixed", tests: "15 passed", impact: "Medium" },
  { file: "processor.rb", issue: "Unused Variable", status: "✅ Fixed", tests: "3 passed", impact: "Low" },
  { file: "constants.rb", issue: "Magic Numbers", status: "✅ Fixed", tests: "2 passed", impact: "Low" },
  { file: "api_client.rb", issue: "Deprecated Method", status: "⏭️ Skipped", tests: "-", impact: "Low" },
  { file: "config.rb", issue: "Missing Index", status: "⏭️ Skipped", tests: "-", impact: "Medium" }
], striped: true, sortable: true

md "---"

# Expandable details for key fixes
header3 "Change Details"
collapsible "user.rb - N+1 Query Fix" do
  md "**Before:**"
  md "`users.each { |u| puts u.posts.count }`"
  md "**After:**"
  md "`users.includes(:posts).each { |u| puts u.posts.count }`"
  md "---"
  md "**Impact:** Reduces database queries from 24 to 2"
end

collapsible "search_controller.rb - SQL Injection Fix" do
  md "**Before:**"
  md '`User.where("name LIKE \'%\#{query}%\'")`'
  md "**After:**"
  md '`User.where("name LIKE ?", "%\#{query}%")`'
  md "---"
  md "**Impact:** Prevents SQL injection attacks"
end

collapsible "billing.rb - Long Method Refactor" do
  md "**Before:** 87-line monolithic method"
  md "**After:** 8-line method with extracted helpers"
  md "---"
  md "**Impact:** Improved readability and testability"
end

md "---"

button "Done", id: "btn_done", variant: "primary"
RUBY

  result=$(streamweaver canvas-wait "$SESSION" 2>/dev/null)
  echo "Final result: $result"
}

# ============================================================================
# Main Execution
# ============================================================================

step1_selection
step2_diff_preview
step3_progress
step4_results

# Cleanup
streamweaver canvas-close "$SESSION" 2>/dev/null

echo ""
echo "=============================================="
echo "Demo complete!"
echo ""
echo "This demo showcased StreamWeaver features that"
echo "are impossible or painful in traditional TUI:"
echo ""
echo "  Component             TUI Equivalent          Browser Advantage"
echo "  ------------------    --------------------    ------------------"
echo "  Side-by-side columns  ASCII pipes             Precise alignment"
echo "  Collapsible sections  None                    Smooth expand/collapse"
echo "  Progress bar          [====>    ]             Smooth animation"
echo "  Pulsing status dots   * spinner               Color + animation"
echo "  Activity feed         Timestamped lines       Rich formatting"
echo "  Badges & alerts       Plain text              Color-coded visual cues"
echo "  Sortable tables       ASCII table             Click to sort"
echo "  Cards with layout     Box drawing chars       Clean visual hierarchy"
echo ""
