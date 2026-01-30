# Operation: CODEBREAKER v2

> Infiltrate any codebase. Extract actionable intelligence.

An interactive spy/hacker-themed code intelligence tool built with a **Claude-native approach**. Claude Code IS the intelligence - it uses its own tools (Glob, Grep, Read) to perform real code analysis, generating dynamic findings and recommendations.

## Quick Start

From this directory, run Claude Code and use the slash command:

```bash
cd examples/claude_code/codebreaker
claude
# Then type: /infiltrate
```

Claude Code will orchestrate the full interactive experience using StreamWeaver panels.

## Architecture: Claude-Native

**Key insight**: Claude Code IS the intelligence. Don't delegate to external scripts.

### Only 4 External Commands

```bash
streamweaver panel <session>        # Open panel (1x at start)
streamweaver canvas-push <session>  # Push DSL via heredoc
streamweaver canvas-wait <session>  # Wait for user input
streamweaver canvas-close <session> # Cleanup (1x at end)
```

### Claude Does Everything Else

- **Generates DSL inline** as heredocs (no Ruby templates)
- **Analyzes code** using Glob, Grep, Read (no Bash scripts)
- **Interprets results** and generates findings (Claude's strength)
- **Creates recommendations** dynamically based on what it finds

## Requirements

- StreamWeaver gem (`gem install stream_weaver`)
- iTerm2 (for panel mode) or any browser
- Claude Code CLI

## Pre-configured Permissions

The `.claude/settings.local.json` pre-allows the 4 streamweaver commands so Claude can run without prompting:

```json
{
  "permissions": {
    "allow": [
      "Bash(streamweaver panel:*)",
      "Bash(streamweaver canvas-push:*)",
      "Bash(streamweaver canvas-wait:*)",
      "Bash(streamweaver canvas-close:*)"
    ]
  }
}
```

## The Experience

### Phase 1: Mission Briefing
Dark theme intro with target selection and analysis parameters.

```
┌──────────────────────────────────────────────┐
│  OPERATION: CODEBREAKER     [CLASSIFIED]     │
│──────────────────────────────────────────────│
│  ● SYSTEM ONLINE  ○ AWAITING TARGET          │
│──────────────────────────────────────────────│
│  TARGET SELECTION: [___________________]     │
│  ANALYSIS: ○ Full  ○ Security  ○ Complexity  │
│                                              │
│           [ ACCEPT MISSION ]                 │
└──────────────────────────────────────────────┘
```

### Phase 2: Reconnaissance
Claude uses Glob, Grep, and Read to scan the target codebase:

- **Structure**: Find all code files, count lines, identify large directories
- **Security**: Search for SQL injection, hardcoded secrets, eval, command injection
- **Complexity**: Find long methods, deep nesting, large files

### Phase 3: Intelligence Report
Dashboard with REAL findings from Claude's analysis.

```
┌──────────────────────────────────────────────┐
│  INTELLIGENCE REPORT         [8 FINDINGS]    │
│──────────────────────────────────────────────│
│  CRITICAL: 2    WARNING: 3    INFO: 3        │
│──────────────────────────────────────────────│
│  ████████ Security (3)                       │
│  ██████ Complexity (3)                       │
│  ████ Structure (2)                          │
│──────────────────────────────────────────────│
│  [CRITICAL] SQL injection in auth.rb         │
│  [CRITICAL] Hardcoded secret in config.rb    │
│  [WARNING] Method too long in processor.rb   │
└──────────────────────────────────────────────┘
```

### Phase 4: Deep Analysis
Code investigation with before/after fixes - Claude generates recommendations based on what it found.

```
┌──────────────────────────────────────────────┐
│  DEEP ANALYSIS               [S001] [CRIT]   │
│──────────────────────────────────────────────│
│  CURRENT CODE        │  RECOMMENDED FIX      │
│  [VULNERABLE]        │  [SECURE]             │
│  User.where(         │  User.where(          │
│    "name='#{x}'"     │    name: x            │
│  )                   │  )                    │
│──────────────────────────────────────────────│
│  Use Parameterized Queries                   │
│  Replace interpolation with safe bindings    │
│──────────────────────────────────────────────│
│  [APPLY FIX]  [SKIP]  [INVESTIGATE MORE]     │
└──────────────────────────────────────────────┘
```

### Phase 5: Extraction
Mission summary with action breakdown.

```
┌──────────────────────────────────────────────┐
│  MISSION COMPLETE            [SECURE]        │
│──────────────────────────────────────────────│
│  TOTAL: 8    FIXED: 5    SKIPPED: 2    ?: 1  │
│──────────────────────────────────────────────│
│       ┌───┐                                  │
│       │███│ Fixed (5)                        │
│       │░░░│ Skipped (2)                      │
│       │   │ Pending (1)                      │
│       └───┘                                  │
│──────────────────────────────────────────────│
│  [GENERATE REPORT]  [NEW MISSION]  [EXIT]    │
└──────────────────────────────────────────────┘
```

## Analysis Capabilities

Claude performs real analysis using its native tools:

| Tool | What Claude Finds |
|------|-------------------|
| `Grep` | SQL injection, hardcoded secrets, eval, command injection patterns |
| `Glob` | File structure, file counts by type |
| `Read` | Long methods, deep nesting, actual code context |

No external analyzers needed - Claude IS the analyzer.

## Directory Structure

```
codebreaker/
├── .claude/
│   ├── commands/
│   │   └── infiltrate.md        # Slash command with full instructions
│   ├── settings.json            # Committed permission template
│   └── settings.local.json      # Local permissions (same as above)
└── README.md
```

That's it. No templates/, no analyzers/, no generators/.

## Benefits of Claude-Native Approach

| Old Approach | New Approach |
|--------------|--------------|
| Ruby templates (5 files) | Heredocs in command file |
| Bash analyzers (3 files) | Claude's Glob/Grep/Read |
| Many subprocesses | Just 4 streamweaver calls |
| Many permission prompts | Pre-allowed in settings |
| Scripted/mock findings | Claude's real analysis |
| Slow transitions | Fast (no subprocess spawn) |

## Components Showcase

This demo uses these StreamWeaver components:

| Component | Where Used |
|-----------|------------|
| `header1-4` | All phases |
| `badge` | CLASSIFIED, severity indicators |
| `status_dot` | System status with pulse animation |
| `progress_bar` | Scanning animation |
| `stat_display` | Metrics dashboard |
| `bar_chart` | Findings by category |
| `pie_chart` | Action breakdown |
| `table` | Findings log |
| `collapsible` | Expandable sections |
| `columns` | Before/after code view |
| `card` | Content containers |
| `button` | Actions with callbacks |
| `radio_group` | Analysis type selection |
| `alert` | Recommendations |

## Tips for Demos

1. **Set the scene**: Let the CLASSIFIED badge and dark theme speak for themselves
2. **Show real value**: Use it on a real codebase (StreamWeaver itself works great)
3. **Claude's intelligence**: Point out that findings are from real code analysis
4. **Interactive**: Let the audience pick which finding to investigate
5. **The payoff**: The extraction summary with charts is satisfying

## License

Part of the StreamWeaver examples. MIT License.
