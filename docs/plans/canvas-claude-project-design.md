# Claude Project Design: Dynamic Canvas Workflows

## Overview

A Claude Project that enables rich, interactive workflows via StreamWeaver canvas. The project combines:
1. A slash command to launch the canvas panel
2. Knowledge of StreamWeaver DSL for dynamic UI generation
3. Agentic script execution for data analysis
4. Multi-step flows that produce unique results each time

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Project                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ /canvas command │  │ StreamWeaver    │  │ Domain      │ │
│  │ (launches panel)│  │ DSL Knowledge   │  │ Scripts     │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬──────┘ │
│           │                    │                   │        │
│           ▼                    ▼                   ▼        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Agentic Workflow Engine                    ││
│  │  1. Analyze context (repo, data, user input)            ││
│  │  2. Generate custom UI via canvas DSL                   ││
│  │  3. Collect user choices                                ││
│  │  4. Execute domain-specific actions                     ││
│  │  5. Display results with charts/tables                  ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │   Browser Canvas Panel        │
              │  ┌─────────────────────────┐  │
              │  │ Dynamic UI Components   │  │
              │  │ - Charts (bar, line)    │  │
              │  │ - Tables (sortable)     │  │
              │  │ - Progress indicators   │  │
              │  │ - Code with highlighting│  │
              │  │ - Forms & selections    │  │
              │  └─────────────────────────┘  │
              └───────────────────────────────┘
```

## Slash Command: `/canvas`

```
/canvas [workflow-name]

Examples:
  /canvas              # Interactive menu of available workflows
  /canvas analyze      # Launch project analyzer
  /canvas review       # Launch code review assistant
  /canvas explore      # Launch data explorer
```

## Core Workflows

### 1. Project Health Analyzer

**Purpose:** Analyze a codebase and generate custom health dashboard

**Flow:**
1. **Discovery** - Scan project structure, detect languages/frameworks
2. **Selection** - User picks what to analyze (tests, complexity, deps, etc.)
3. **Analysis** - Run analysis with progress indicators
4. **Dashboard** - Generate custom charts and recommendations

**Dynamic Elements:**
- Charts based on what metrics are relevant to the project
- Recommendations tailored to detected issues
- Drill-down tables for specific problem areas

### 2. Interactive Code Review

**Purpose:** Review code changes with visual diff and actionable fixes

**Flow:**
1. **Input** - User provides PR link, commit, or staged changes
2. **Analysis** - Categorize issues by severity and type
3. **Selection** - User picks which issues to address
4. **Preview** - Show proposed fixes with syntax highlighting
5. **Apply** - Make changes with progress tracking
6. **Summary** - Results with before/after comparison

### 3. Data Explorer Wizard

**Purpose:** Explore and visualize data from various sources

**Flow:**
1. **Source** - User specifies data (CSV, JSON, API, database)
2. **Profile** - Auto-detect schema, show sample data
3. **Questions** - User selects what to explore
4. **Visualization** - Generate appropriate charts
5. **Insights** - Surface patterns and anomalies
6. **Export** - Save findings or generate report

### 4. Decision Tree Builder

**Purpose:** Guide complex decisions with branching logic

**Flow:**
1. **Domain** - User describes the decision space
2. **Generation** - Claude creates branching questions
3. **Journey** - User navigates tree, sees path taken
4. **Result** - Final recommendation with reasoning
5. **Sensitivity** - "What if" analysis on key choices

## StreamWeaver DSL Knowledge Base

The project includes comprehensive knowledge of StreamWeaver components:

```ruby
# Layout
columns, hstack, vstack, card, collapsible

# Input
checkbox, radio_group, text_field, select, button

# Display
header1-6, md, text, alert, badge, status_dot

# Data Visualization
bar_chart, line_chart, table (sortable), progress_bar

# Feedback
spinner, status_dot (with pulse), activity_item
```

## Example: Project Health Analyzer Script

```bash
#!/bin/bash
# project_health.sh - Launched by /canvas analyze

SESSION="project-health-$$"
streamweaver panel "$SESSION"

# Step 1: Discovery
streamweaver canvas-push "$SESSION" <<'RUBY'
header1 "Project Health Analyzer"
hstack spacing: :md, align: :center do
  spinner size: :md
  md "**Scanning project structure...**"
end
RUBY

# Analyze project (pseudo-code)
LANGUAGES=$(detect_languages)
TEST_COVERAGE=$(calculate_coverage)
COMPLEXITY=$(analyze_complexity)

# Step 2: Selection - dynamically built based on findings
streamweaver canvas-push "$SESSION" <<RUBY
header1 "Project Health Analyzer"
md "Found: **${LANGUAGES}** project with ${FILE_COUNT} files"

card do
  header3 "Select Analysis Areas"
  checkbox :tests, "Test Coverage (${TEST_COVERAGE}% current)"
  checkbox :complexity, "Code Complexity"
  checkbox :dependencies, "Dependency Health"
  checkbox :security, "Security Scan"
end

button "Analyze Selected", id: "btn_analyze"
RUBY

CHOICES=$(streamweaver canvas-wait "$SESSION")
# ... continue based on user choices
```

## Project Files Structure

```
canvas-workflows/
├── CLAUDE.md                    # Project instructions
├── commands/
│   └── canvas.md                # /canvas slash command
├── knowledge/
│   ├── streamweaver-dsl.md      # Component reference
│   └── workflow-patterns.md     # Common patterns
└── scripts/
    ├── project_health.sh        # Project analyzer
    ├── code_review.sh           # Code review assistant
    ├── data_explorer.sh         # Data exploration
    └── decision_tree.sh         # Decision guidance
```

## CLAUDE.md Content

```markdown
# Canvas Workflows Project

You have access to StreamWeaver canvas for rich interactive workflows.

## Launching Canvas

Use `/canvas` to start interactive workflows, or run scripts directly:
- `./scripts/project_health.sh` - Analyze project health
- `./scripts/code_review.sh` - Interactive code review

## Creating Dynamic UIs

Generate StreamWeaver DSL based on context. The UI should adapt to:
- What data is available
- What the user has selected
- What findings are discovered

## Key Patterns

1. **Progressive Disclosure** - Show complexity gradually
2. **Contextual Charts** - Only show relevant visualizations
3. **Actionable Results** - Every screen should have clear next steps
4. **Error Gracefully** - Show friendly messages, offer alternatives

## Available Components

[Include condensed DSL reference]
```

## Unique Results Each Time

The workflows produce different results because they:

1. **Analyze Real Data** - Project structure, code metrics, git history
2. **Adapt to Context** - Different charts for different findings
3. **User-Driven Branching** - Choices affect subsequent screens
4. **Time-Sensitive** - Recent commits, current test status, etc.

## Next Steps

1. Create the `/canvas` slash command skill
2. Build knowledge base documents for StreamWeaver DSL
3. Implement `project_health.sh` as first complete workflow
4. Test end-to-end with Claude Code
5. Document patterns for creating new workflows
