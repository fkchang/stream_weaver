# Claude Code Integration Examples

Interactive canvas workflows powered by Claude Code slash commands.

## Examples

### [codebreaker/](codebreaker/)
**Operation: CODEBREAKER** - Spy/hacker-themed code intelligence tool.

Claude Code analyzes codebases using its native tools (Glob, Grep, Read) and presents findings through an interactive dark-themed dashboard. Demonstrates Claude-native approach where Claude IS the intelligence.

```bash
cd codebreaker && claude
# /infiltrate
```

### [verification_flow/](verification_flow/)
**Account Verification Flow** - Multi-step form workflow.

Realistic 2FA-style flow demonstrating forms, status pages, toasts, and canvas_continue for spinner feedback. Shows canvas + terminal interplay.

```bash
cd verification_flow && claude
# /verify
```

## Architecture

All examples follow the same pattern:

```
example/
├── .claude/
│   ├── commands/
│   │   └── command.md    # Slash command instructions
│   └── settings.local.json  # Pre-allowed streamweaver permissions
└── README.md
```

## Key Concepts

### Claude-Native Approach
Claude Code IS the intelligence. Don't delegate to external scripts.

- **4 external commands**: `panel`, `canvas-push`, `canvas-wait`, `canvas-close`
- **Claude does the rest**: Generates DSL, analyzes code, interprets results

### Canvas Commands

| Command | Purpose |
|---------|---------|
| `streamweaver panel <name> [--fresh]` | Open browser in iTerm split pane |
| `streamweaver canvas-push <name>` | Push DSL content (stdin) |
| `streamweaver canvas-wait <name>` | Wait for user input, returns JSON |
| `streamweaver canvas-toast <name> <msg>` | Show notification overlay |
| `streamweaver canvas-close <name>` | Close session and browser pane |

### Pre-configured Permissions

Each example includes `.claude/settings.local.json` with pre-allowed streamweaver commands so Claude can run without prompting:

```json
{
  "permissions": {
    "allow": ["Bash(streamweaver *)"]
  }
}
```

## Creating Your Own

1. Create directory with `.claude/commands/yourcommand.md`
2. Write instructions with canvas-push heredocs and canvas-wait
3. Add `.claude/settings.local.json` for permissions
4. Run with `/yourcommand` in Claude Code
