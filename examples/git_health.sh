#!/bin/bash
# Git Project Health Analyzer
#
# A dynamic canvas workflow that analyzes a git repository and generates
# a custom health dashboard. Each run produces different results based on
# the actual project state.
#
# Features demonstrated:
#   - Real data analysis (git commands)
#   - Dynamic UI generation based on findings
#   - Charts, tables, progress indicators
#   - Multi-step interactive workflow
#
# Usage: ./examples/git_health.sh [path-to-repo]

set -e

REPO_PATH="${1:-.}"
SESSION="git-health-$$"

# Validate it's a git repo
if ! git -C "$REPO_PATH" rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: $REPO_PATH is not a git repository"
  exit 1
fi

cd "$REPO_PATH"
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

echo "=== Git Project Health Analyzer ==="
echo "Repository: $REPO_NAME"
echo ""

# Start the panel
streamweaver panel "$SESSION" 2>/dev/null
sleep 1

# ============================================================================
# STEP 1: Discovery - Scan the repository
# ============================================================================
echo "Step 1: Scanning repository..."
echo "  Features: spinner, progress feedback"

streamweaver canvas-push "$SESSION" <<RUBY
header1 "Git Project Health"
md "Analyzing **${REPO_NAME}**..."

hstack spacing: :md, align: :center do
  spinner size: :md
  md "Scanning repository structure..."
end

progress_bar value: 10, show_label: true, animated: true
RUBY

sleep 0.5

# Gather repository metrics
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
TOTAL_FILES=$(git ls-files | wc -l | tr -d ' ')
TOTAL_AUTHORS=$(git shortlog -sn --all | wc -l | tr -d ' ')
TOTAL_BRANCHES=$(git branch -a | wc -l | tr -d ' ')
REPO_AGE_DAYS=$(( ($(date +%s) - $(git log --reverse --format=%ct | head -1)) / 86400 ))

# Recent activity
COMMITS_LAST_30=$(git rev-list --count --since="30 days ago" HEAD 2>/dev/null || echo "0")
COMMITS_LAST_7=$(git rev-list --count --since="7 days ago" HEAD 2>/dev/null || echo "0")

# File types
TOP_EXTENSIONS=$(git ls-files | grep -E '\.[a-zA-Z0-9]+$' | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -5)

streamweaver canvas-push "$SESSION" <<RUBY
header1 "Git Project Health"
md "Analyzing **${REPO_NAME}**..."

hstack spacing: :md, align: :center do
  spinner size: :md
  md "Analyzing commit history..."
end

progress_bar value: 40, show_label: true, animated: true
RUBY

sleep 0.5

# ============================================================================
# STEP 2: Selection - Choose what to analyze
# ============================================================================
echo ""
echo "Step 2: Showing discovery results, getting user selection..."
echo "  Features: cards, badges, stats, checkboxes, radio_group"

# Determine health indicators
if [ "$COMMITS_LAST_7" -gt 5 ]; then
  ACTIVITY_STATUS="green"
  ACTIVITY_LABEL="Active"
elif [ "$COMMITS_LAST_30" -gt 0 ]; then
  ACTIVITY_STATUS="yellow"
  ACTIVITY_LABEL="Moderate"
else
  ACTIVITY_STATUS="red"
  ACTIVITY_LABEL="Stale"
fi

streamweaver canvas-push "$SESSION" <<RUBY
header1 "Git Project Health"
md "Repository: **${REPO_NAME}** (${REPO_AGE_DAYS} days old)"

# Quick stats
hstack spacing: :lg do
  card do
    hstack spacing: :sm, align: :center do
      badge "${TOTAL_COMMITS}", variant: :info
      md "**Commits**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "${TOTAL_FILES}", variant: :info
      md "**Files**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "${TOTAL_AUTHORS}", variant: :info
      md "**Authors**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      status_dot status: :${ACTIVITY_STATUS}, label: "${ACTIVITY_LABEL}"
    end
  end
end

md "---"

# Analysis options
header3 "Select Analysis Areas"
card do
  checkbox :commits, "**Commit Activity** - Commits over time, busiest days"
  checkbox :authors, "**Author Contributions** - Who contributes most"
  checkbox :files, "**File Analysis** - Largest files, most changed"
  checkbox :branches, "**Branch Health** - Stale branches, merge status"
end

md "---"

header3 "Report Detail"
radio_group :detail, ["Summary only", "Detailed with charts", "Full analysis"]

md "---"

hstack spacing: :md do
  button "Cancel", id: "btn_cancel", style: :secondary
  button "Generate Report", id: "btn_generate", variant: "primary"
end
RUBY

SELECTION=$(streamweaver canvas-wait "$SESSION" 2>/dev/null)
echo "User selection: $SELECTION"

# Check if cancelled
if echo "$SELECTION" | grep -q "btn_cancel"; then
  echo "User cancelled."
  streamweaver canvas-close "$SESSION" 2>/dev/null
  exit 0
fi

# ============================================================================
# STEP 3: Analysis - Generate the report
# ============================================================================
echo ""
echo "Step 3: Generating analysis with progress..."
echo "  Features: progress_bar, status_dot, activity_item"

# Parse selections (simplified - check if keys are true)
ANALYZE_COMMITS=$(echo "$SELECTION" | python3 -c "import sys,json; d=json.load(sys.stdin); print('1' if d.get('state',{}).get('commits') else '0')" 2>/dev/null || echo "1")
ANALYZE_AUTHORS=$(echo "$SELECTION" | python3 -c "import sys,json; d=json.load(sys.stdin); print('1' if d.get('state',{}).get('authors') else '0')" 2>/dev/null || echo "1")

# Show progress
streamweaver canvas-push "$SESSION" <<RUBY
header1 "Generating Report"

hstack spacing: :md, align: :center do
  spinner size: :md
  md "**Analyzing commit patterns...**"
end

progress_bar value: 20, show_label: true, animated: true, variant: :success

hstack spacing: :lg, align: :center do
  status_dot status: :green, pulse: true, label: "Commits"
  status_dot status: :gray, label: "Authors"
  status_dot status: :gray, label: "Files"
end
RUBY

sleep 0.3

# Gather detailed metrics
# Commits by day of week
COMMITS_BY_DAY=$(git log --format='%ad' --date=format:'%A' | sort | uniq -c | sort -rn)
MON=$(echo "$COMMITS_BY_DAY" | grep Monday | awk '{print $1}' || echo "0")
TUE=$(echo "$COMMITS_BY_DAY" | grep Tuesday | awk '{print $1}' || echo "0")
WED=$(echo "$COMMITS_BY_DAY" | grep Wednesday | awk '{print $1}' || echo "0")
THU=$(echo "$COMMITS_BY_DAY" | grep Thursday | awk '{print $1}' || echo "0")
FRI=$(echo "$COMMITS_BY_DAY" | grep Friday | awk '{print $1}' || echo "0")

# Top authors
TOP_AUTHORS=$(git shortlog -sn --all | head -5)

streamweaver canvas-push "$SESSION" <<RUBY
header1 "Generating Report"

hstack spacing: :md, align: :center do
  spinner size: :md
  md "**Analyzing author contributions...**"
end

progress_bar value: 60, show_label: true, animated: true, variant: :success

hstack spacing: :lg, align: :center do
  status_dot status: :green, label: "Commits"
  status_dot status: :green, pulse: true, label: "Authors"
  status_dot status: :gray, label: "Files"
end
RUBY

sleep 0.3

# Recent files changed
RECENT_FILES=$(git diff --stat HEAD~10 HEAD 2>/dev/null | head -10 || echo "No recent changes")

streamweaver canvas-push "$SESSION" <<RUBY
header1 "Generating Report"

hstack spacing: :md, align: :center do
  spinner size: :md
  md "**Finalizing report...**"
end

progress_bar value: 90, show_label: true, animated: true, variant: :success

hstack spacing: :lg, align: :center do
  status_dot status: :green, label: "Commits"
  status_dot status: :green, label: "Authors"
  status_dot status: :green, pulse: true, label: "Files"
end
RUBY

sleep 0.3

# ============================================================================
# STEP 4: Results - Display the dashboard
# ============================================================================
echo ""
echo "Step 4: Displaying results dashboard..."
echo "  Features: charts, tables, collapsible sections"

# Build author table data
AUTHOR_TABLE=""
while IFS= read -r line; do
  if [ -n "$line" ]; then
    COUNT=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
    AUTHOR_TABLE="${AUTHOR_TABLE}{ author: \"${NAME}\", commits: ${COUNT} },"
  fi
done <<< "$TOP_AUTHORS"
AUTHOR_TABLE="[${AUTHOR_TABLE%,}]"

streamweaver canvas-push "$SESSION" <<RUBY
header1 "Project Health Report"
md "**${REPO_NAME}** - Generated $(date '+%Y-%m-%d %H:%M')"

# Summary stats
hstack spacing: :lg do
  card do
    hstack spacing: :sm, align: :center do
      badge "${TOTAL_COMMITS}", variant: :success
      md "**Total Commits**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "${COMMITS_LAST_30}", variant: :info
      md "**Last 30 Days**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "${TOTAL_AUTHORS}", variant: :info
      md "**Contributors**"
    end
  end
end

md "---"

# Commit activity chart
header3 "Commit Activity by Day"
bar_chart data: {
  "Mon" => ${MON:-0},
  "Tue" => ${TUE:-0},
  "Wed" => ${WED:-0},
  "Thu" => ${THU:-0},
  "Fri" => ${FRI:-0}
}, title: "Commits by Day of Week", height: "200px"

md "---"

# Top contributors
header3 "Top Contributors"
table ${AUTHOR_TABLE}, striped: true, sortable: true

md "---"

# Recommendations
header3 "Recommendations"
RUBY

# Add dynamic recommendations based on findings
RECS=""
if [ "$COMMITS_LAST_7" -eq 0 ]; then
  RECS="${RECS}alert variant: :warning, title: \"Low Recent Activity\" do\n  md \"No commits in the last 7 days. Consider reviewing project status.\"\nend\n"
fi

if [ "$TOTAL_BRANCHES" -gt 20 ]; then
  RECS="${RECS}alert variant: :info, title: \"Many Branches\" do\n  md \"${TOTAL_BRANCHES} branches detected. Consider cleaning up stale branches.\"\nend\n"
fi

if [ -z "$RECS" ]; then
  RECS="alert variant: :success, title: \"Looking Good!\" do\n  md \"No major issues detected. Keep up the good work!\"\nend\n"
fi

streamweaver canvas-push "$SESSION" <<RUBY
header1 "Project Health Report"
md "**${REPO_NAME}** - Generated $(date '+%Y-%m-%d %H:%M')"

hstack spacing: :lg do
  card do
    hstack spacing: :sm, align: :center do
      badge "${TOTAL_COMMITS}", variant: :success
      md "**Total Commits**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "${COMMITS_LAST_30}", variant: :info
      md "**Last 30 Days**"
    end
  end
  card do
    hstack spacing: :sm, align: :center do
      badge "${TOTAL_AUTHORS}", variant: :info
      md "**Contributors**"
    end
  end
end

md "---"

header3 "Commit Activity by Day"
bar_chart data: {
  "Mon" => ${MON:-0},
  "Tue" => ${TUE:-0},
  "Wed" => ${WED:-0},
  "Thu" => ${THU:-0},
  "Fri" => ${FRI:-0}
}, title: "Commits by Day of Week", height: "200px"

md "---"

header3 "Top Contributors"
table ${AUTHOR_TABLE}, striped: true, sortable: true

md "---"

header3 "Recommendations"
${RECS}

md "---"

button "Done", id: "btn_done", variant: "primary"
RUBY

streamweaver canvas-wait "$SESSION" 2>/dev/null

# Cleanup
streamweaver canvas-close "$SESSION" 2>/dev/null

echo ""
echo "=============================================="
echo "Report complete!"
echo ""
echo "This workflow demonstrated:"
echo "  - Real git data analysis (${TOTAL_COMMITS} commits analyzed)"
echo "  - Dynamic charts based on actual commit patterns"
echo "  - Contextual recommendations based on findings"
echo "  - Different results each time based on repo state"
echo ""
