# Operation: CODEBREAKER

You are running an interactive code analysis mission with spy/hacker aesthetic. This is a Claude-native implementation - YOU do the analysis using your own tools (Glob, Grep, Read), not external scripts.

## Quick Reference

**StreamWeaver Commands:**
```bash
streamweaver canvas-reset <session>    # Clear state for fresh start (safe if no session)
streamweaver panel <session>           # Open panel (1x at start)
streamweaver canvas-push <session>     # Push DSL via heredoc
streamweaver canvas-wait <session>     # Wait for user input
streamweaver canvas-toast <session> <msg>  # Show toast overlay (doesn't replace content)
streamweaver canvas-close <session>    # Cleanup (1x at end)
```

**Toast for permission prompts:** When you need to use tools that require permission (Glob, Grep, Read on new paths), show a toast first so the user knows to check the terminal:
```bash
streamweaver canvas-toast codebreaker "Check terminal for authorization" --variant warning
```

## How This Works

1. **Bash heredocs** (`<<'DSL' ... DSL`) pass the DSL string to streamweaver
2. **Ruby heredocs within DSL** (`<<-MARKDOWN ... MARKDOWN`) handle multi-line content inside the DSL
3. **YOU generate the DSL dynamically** - the examples are templates, fill in real values from your analysis
4. **State flows linearly** but user button clicks can jump between phases

**Note on Heredocs:** The DSL is pushed via Bash heredoc (`<<'DSL'`). Within the DSL, you can use Ruby heredocs (`<<-CONTENT`) for multi-line strings like markdown blocks. The outer heredoc is Bash, the inner heredocs are Ruby DSL syntax.

## CRITICAL: canvas_continue vs canvas-wait

**These are mutually exclusive patterns:**

### Pattern A: Showing progress while YOU work
```
canvas-push with canvas_continue message: "Working..."  → shows spinner
DO YOUR WORK with Glob/Grep/Read tools
canvas-push with results (NO canvas_continue)           → shows final UI
canvas-wait                                              → wait for user
```

### Pattern B: Presenting UI for user interaction
```
canvas-push with buttons/forms (NO canvas_continue)     → shows interactive UI
canvas-wait                                              → wait for user click
```

**NEVER combine `canvas_continue` with `canvas-wait`** - that's contradictory:
- `canvas_continue` says "I'm working, here's a spinner"
- `canvas-wait` says "I'm done, waiting for you to click"

If you push a spinner then immediately wait, the user sees a loading spinner but nothing is happening.

---

## PHASE 1: Session Setup & Mission Briefing

### 1.1 Reset & Open Panel

```bash
# Clear any previous state (safe to run even if session doesn't exist)
streamweaver canvas-reset codebreaker 2>/dev/null || true
# Open the panel (reuses browser if already open)
streamweaver panel codebreaker
```

Use `codebreaker` as the session name for all commands. The `canvas-reset` ensures a fresh start each time you run `/infiltrate`.

### 1.2 Push Mission Briefing

First, detect potential targets in the current directory using Glob to find directories and code files.

Then push this DSL (customize the badge targets based on what you found):

```bash
# NO canvas_continue here - we're showing a form and waiting for user input
streamweaver canvas-push codebreaker <<'DSL'
card do
  hstack justify: :between, align: :center do
    header1 "OPERATION: CODEBREAKER"
    badge "CLASSIFIED", variant: :danger
  end
end

md "---"

card do
  hstack spacing: :lg do
    vstack do
      status_dot status: :green, pulse: true, label: "SYSTEM ONLINE"
    end
    vstack do
      status_dot status: :yellow, pulse: false, label: "AWAITING TARGET"
    end
    vstack do
      status_dot status: :gray, pulse: false, label: "ANALYSIS PENDING"
    end
  end
end

md "---"

header2 "MISSION BRIEFING"

md <<-BRIEFING
Agent, your mission is to **infiltrate** the target codebase and extract
actionable intelligence. You will analyze code patterns, identify vulnerabilities,
and report findings for tactical response.

**Objectives:**
- Scan target filesystem
- Identify security vulnerabilities
- Assess code complexity
- Generate intelligence report
BRIEFING

md "---"

header3 "TARGET SELECTION"

text_field :target, placeholder: "Enter path to target directory or file...", value: ""

md ""
text "Quick targets detected:"

hstack spacing: :sm do
  badge ".", variant: :info
  badge "lib", variant: :info
  badge "app", variant: :info
  badge "src", variant: :info
end

md "---"

header3 "ANALYSIS PARAMETERS"

radio_group :analysis_type, ["Full Infiltration (all)", "Complexity Intel", "Security Scan", "Structure Map"]

md "---"

hstack justify: :center, spacing: :lg do
  button "ACCEPT MISSION", id: "btn_accept", style: :primary
  button "ABORT", id: "btn_abort", style: :secondary
end

md ""
text "Secure channel established. Awaiting orders."
DSL
```

### 1.3 Wait for User Response

```bash
streamweaver canvas-wait codebreaker --timeout 300
```

Parse the JSON response. Extract:
- `target`: The path to analyze
- `analysis_type`: What kind of analysis to run
- Check `buttons_clicked` for "btn_abort" to exit early

---

## PHASE 2: Reconnaissance (Claude Does the Analysis)

### 2.1 Push Scanning Animation (with canvas_continue)

```bash
# USE canvas_continue here - we're showing progress while Claude works
# DO NOT call canvas-wait after this - instead, do the actual work!
streamweaver canvas-push codebreaker <<'DSL'
canvas_continue message: "Scanning target..."

card do
  hstack justify: :between, align: :center do
    header1 "RECONNAISSANCE"
    badge "IN PROGRESS", variant: :warning
  end
end

md "---"

card do
  hstack spacing: :lg, justify: :center do
    status_dot status: :green, pulse: true, label: "SCANNING"
    status_dot status: :yellow, pulse: true, label: "ANALYZING"
    status_dot status: :gray, pulse: false, label: "REPORTING"
  end
end

md "---"

hstack justify: :center do
  spinner size: :lg, label: "Analyzing codebase..."
end

md ""

progress_bar value: 25, max: 100

md ""
text "Infiltrating target filesystem..."
text "Stand by for intelligence extraction..."
DSL
```

**IMMEDIATELY after pushing this, do the actual work with your tools (Glob, Grep, Read).
Do NOT call canvas-wait here - the spinner indicates YOU are working.**

### 2.2 Perform Analysis Using YOUR Tools

**This is the key difference from v1 - YOU analyze the code directly.**

Use these tools on the TARGET path:

1. **Structure Analysis (Glob)**:
   - `Glob("TARGET/**/*.rb")` - Find all Ruby files
   - `Glob("TARGET/**/*.py")` - Find all Python files
   - `Glob("TARGET/**/*.js")` - Find all JavaScript files
   - Count files, identify large directories

2. **Security Analysis (Grep)**:
   - `Grep(pattern: 'eval\s*\(', path: TARGET)` - Unsafe eval
   - `Grep(pattern: '\.where\(.*#\{', path: TARGET)` - SQL injection
   - `Grep(pattern: 'api_key|secret|password|token.*=.*["\']', path: TARGET, '-i': true)` - Hardcoded secrets
   - `Grep(pattern: 'system\(|exec\(|`.*#\{', path: TARGET)` - Command injection

3. **Complexity Analysis (Read + Analysis)**:
   - Read files and count lines
   - Look for methods over 50 lines
   - Look for deep nesting (4+ levels)
   - Identify files over 500 lines

### 2.3 Build Findings List

As you analyze, build a list of findings. Each finding should have:
- `id`: Unique identifier (F001, F002, etc.)
- `type`: "security", "complexity", or "structure"
- `severity`: "critical", "warning", or "info"
- `file`: File path
- `line`: Line number
- `message`: Description of the issue
- `code`: Snippet of problematic code

---

## PHASE 3: Intelligence Report

### 3.1 Generate Report DSL

Build the DSL dynamically based on YOUR findings. Here's the template structure:

```bash
# NO canvas_continue - this has buttons, we'll wait for user to click
streamweaver canvas-push codebreaker <<'DSL'
card do
  hstack justify: :between, align: :center do
    header1 "INTELLIGENCE REPORT"
    badge "N FINDINGS", variant: :info
  end
end

md "---"

header3 "THREAT ASSESSMENT"

hstack spacing: :lg do
  stat_display value: X, label: "CRITICAL", color: :red
  stat_display value: Y, label: "WARNING", color: :yellow
  stat_display value: Z, label: "INFO", color: :blue
end

md "---"

header3 "FINDINGS BY CATEGORY"

bar_chart data: { "Security": A, "Complexity": B, "Structure": C }

md "---"

header3 "PRIORITY FINDINGS"

vstack spacing: :md do
  # For each finding, generate a card like this:
  card do
    hstack justify: :between, align: :start do
      vstack do
        hstack spacing: :sm do
          badge "CRITICAL", variant: :danger
          badge "SECURITY", variant: :default
        end
        header4 "F001: Potential SQL injection vulnerability"
        text "app/models/user.rb:42"
      end
      button "INVESTIGATE", id: "investigate_F001"
    end
  end
  # ... more finding cards
end

md "---"

header3 "FULL FINDINGS TABLE"

collapsible "Show All N Findings", expanded: false do
  table headers: ["ID", "Type", "Severity", "File", "Line", "Message"], rows: [
    ["F001", "security", "critical", "app/auth.rb", "42", "SQL injection..."],
    # ... more rows
  ], striped: true, hoverable: true
end

md "---"

hstack justify: :center, spacing: :lg do
  button "EXTRACT REPORT", id: "btn_extract", style: :primary
  button "NEW TARGET", id: "btn_new_target", style: :secondary
end
DSL
```

**Important:** Fill in the actual values from your analysis!

**If no findings were discovered (clean code!):**

```bash
# NO canvas_continue - has buttons for user interaction
streamweaver canvas-push codebreaker <<'DSL'
card do
  hstack justify: :center do
    header1 "ALL CLEAR"
    badge "SECURE", variant: :success
  end
end

md "---"

alert variant: :success do
  header3 "No vulnerabilities detected"
  text "The target codebase passed all reconnaissance checks. Well maintained code!"
end

md "---"

hstack justify: :center, spacing: :lg do
  button "NEW TARGET", id: "btn_new_target", style: :primary
  button "EXIT", id: "btn_exit", style: :secondary
end
DSL
```

### 3.2 Wait for User Selection

```bash
streamweaver canvas-wait codebreaker --timeout 300
```

Check response for:
- `buttons_clicked` containing "investigate_FXXX" → Go to Phase 4 with that finding
- `buttons_clicked` containing "btn_extract" → Go to Phase 5
- `buttons_clicked` containing "btn_new_target" → Go back to Phase 1

---

## PHASE 4: Deep Analysis

When user clicks "INVESTIGATE" on a finding, show detailed analysis.

### 4.1 Read the Actual File

Use the Read tool to get the actual code around the finding's line number.

### 4.2 Generate Recommendation

Based on the finding type, generate an appropriate fix recommendation:

**For SQL Injection:**
- Before: `User.where("name = '#{params[:name]}'")`
- After: `User.where(name: params[:name])`

**For Hardcoded Secrets:**
- Before: `API_KEY = 'sk-1234567890'`
- After: `API_KEY = ENV.fetch('API_KEY')`

**For Long Methods:**
- Recommend extracting into smaller methods

**For Deep Nesting:**
- Recommend guard clauses and early returns

### 4.3 Push Deep Analysis View

```bash
# NO canvas_continue - has buttons for user interaction
streamweaver canvas-push codebreaker <<'DSL'
card do
  hstack justify: :between, align: :center do
    header1 "DEEP ANALYSIS"
    hstack spacing: :sm do
      badge "F001", variant: :default
      badge "CRITICAL", variant: :danger
    end
  end
end

md "---"

header3 "Potential SQL injection vulnerability"

card do
  hstack spacing: :md do
    vstack do
      text "**File:**"
      text "app/models/user.rb"
    end
    vstack do
      text "**Line:**"
      text "42"
    end
    vstack do
      text "**Type:**"
      text "Security"
    end
  end
end

md "---"

header3 "CODE ANALYSIS"

columns widths: ['50%', '50%'] do
  column do
    card do
      header4 "CURRENT CODE"
      badge "VULNERABLE", variant: :danger

      md <<-CODE
```ruby
User.where("name = '\#{params[:name]}'")
```
      CODE
    end
  end

  column do
    card do
      header4 "RECOMMENDED FIX"
      badge "SECURE", variant: :success

      md <<-CODE
```ruby
User.where(name: params[:name])
```
      CODE
    end
  end
end

md "---"

header3 "RECOMMENDATION"

alert variant: :info do
  header4 "Use Parameterized Queries"
  text "Replace string interpolation with parameterized queries to prevent SQL injection attacks."
end

md "---"

header3 "ACTION"

hstack justify: :center, spacing: :lg do
  button "APPLY FIX", id: "btn_fix", style: :primary
  button "SKIP", id: "btn_skip", style: :secondary
  button "INVESTIGATE MORE", id: "btn_more"
end

md ""

hstack justify: :center do
  button "BACK TO REPORT", id: "btn_back", style: :secondary
end
DSL
```

### 4.4 Handle User Action

```bash
streamweaver canvas-wait codebreaker --timeout 300
```

- "btn_fix" → Record action, return to report
- "btn_skip" → Record skip, return to report
- "btn_more" → Use your tools to investigate further, explain more
- "btn_back" → Return to Phase 3

---

## PHASE 5: Extraction (Mission Complete)

### 5.1 Generate Summary

Calculate totals from your session:
- Total findings discovered
- Actions taken (fixed/skipped/pending)
- Overall mission rating

### 5.2 Push Extraction View

```bash
# NO canvas_continue - has buttons for user interaction
streamweaver canvas-push codebreaker <<'DSL'
card do
  hstack justify: :between, align: :center do
    header1 "MISSION COMPLETE"
    badge "SECURE", variant: :success
  end
end

md "---"

header2 "EXTRACTION SUMMARY"

card do
  hstack spacing: :xl, justify: :around do
    stat_display value: 5, label: "TOTAL FINDINGS", color: :blue
    stat_display value: 2, label: "FIXED", color: :purple
    stat_display value: 1, label: "SKIPPED", color: :default
    stat_display value: 2, label: "PENDING", color: :red
  end
end

md "---"

header3 "ACTION BREAKDOWN"

columns widths: ['50%', '50%'] do
  column do
    pie_chart data: { "Fixed": 2, "Skipped": 1, "Pending": 2 }
  end

  column do
    card do
      header4 "SEVERITY BREAKDOWN"
      vstack spacing: :sm do
        hstack do
          badge "CRITICAL", variant: :danger
          text "1 finding"
        end
        hstack do
          badge "WARNING", variant: :warning
          text "2 findings"
        end
        hstack do
          badge "INFO", variant: :info
          text "2 findings"
        end
      end
    end
  end
end

md "---"

header3 "MISSION DEBRIEF"

card do
  md <<-DEBRIEF
**Operation Summary:**

The infiltration of the target codebase has been completed. A total of **5 intelligence items**
were extracted during reconnaissance.

**Key Observations:**
- 1 critical vulnerability requires immediate attention
- 2 warnings indicate areas for improvement
- 2 informational items noted for future reference

**Recommendation:** Further action recommended to secure the target.
  DEBRIEF
end

md "---"

hstack justify: :center, spacing: :lg do
  button "NEW MISSION", id: "btn_new_mission", style: :primary
  button "EXIT", id: "btn_exit", style: :secondary
end

md ""

text "Secure channel will close upon exit. All intelligence has been logged."
DSL
```

### 5.3 Handle Final Action

```bash
streamweaver canvas-wait codebreaker --timeout 300
```

- "btn_new_mission" → Go back to Phase 1
- "btn_exit" → Close panel and end

---

## PHASE 6: Cleanup

When the mission is complete:

```bash
streamweaver canvas-close codebreaker
```

---

## Key Principles

1. **YOU are the intelligence** - Use Glob, Grep, Read to analyze code directly
2. **Dynamic DSL generation** - Build DSL with real data from your analysis
3. **Smooth flow** - Only 4 streamweaver commands, all pre-approved
4. **Real findings** - Show actual issues from the codebase, not mock data
5. **Helpful recommendations** - Provide genuine fix suggestions based on what you find
6. **canvas_continue = Claude working** - Use with spinner, then DO work, NO canvas-wait after
7. **canvas-wait = waiting for user** - Push buttons/forms WITHOUT canvas_continue, then wait

## Error Handling

- If target path doesn't exist, ask user to provide a valid path
- If no findings are discovered, congratulate user on clean code
- If user aborts, close panel gracefully
- Keep track of session state to handle navigation correctly
