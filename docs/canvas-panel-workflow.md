# Canvas Panel Workflow

Two-way IPC for Claude Code integration. Open a side panel, push content, wait for user interaction, repeat.

## Quick Start

```bash
# Open panel (creates iTerm2 split with browser)
streamweaver panel myapp --fresh

# Push content
streamweaver canvas-push myapp <<'RUBY'
  header1 "Pick an option"
  radio_group :choice, ["A", "B", "C"]
  button "Submit"
RUBY

# Wait for user interaction (returns JSON)
streamweaver canvas-wait myapp
# => {"choice": "B"}

# Close panel (also closes browser pane)
streamweaver canvas-close myapp
```

## Commands

| Command | Description |
|---------|-------------|
| `panel <name> [--fresh]` | Open split pane with browser. `--fresh` closes existing session first |
| `canvas-push <name>` | Push DSL content from stdin |
| `canvas-wait <name>` | Block until user clicks a button, returns form state as JSON |
| `canvas-toast <name> <msg>` | Show toast notification overlay |
| `canvas-close <name>` | Close session and browser pane |
| `canvas-raise <name>` | Surface an already-open session without opening a second pane: activates its tracked iTerm pane, or opens its URL in the default browser if there is none to reuse |
| `canvas-reset <name>` | Reset session state (keep connections) |
| `canvas-list` | List all canvas sessions |

## Upgrading StreamWeaver under a running bridge

The canvas bridge is a long-lived process holding its classes in memory, so a `gem update` or `rake install` underneath it leaves it serving the old code -- pushed canvas source calling a brand-new method used to fail with a bare `NameError`. It now heals itself: the bridge stamps the StreamWeaver version and a fingerprint of the code it loaded into `~/.streamweaver/canvas.pid` at boot, every canvas command compares that stamp against its own before talking to the bridge, and on a mismatch it restarts the bridge in place -- snapshot, stop, start, restore -- so open sessions keep their content, then carries on with the command you actually ran. You see one line on stderr (stdout stays clean for `canvas-wait`'s JSON): `StreamWeaver: canvas bridge was running older code — restarting it (sessions preserved)…`. It speaks up again, on the same stream, if anything about that claim needs qualifying: a session it could not read before stopping the old bridge, a restore that failed, or a restarted bridge that landed on a different port -- which means the tab you have open is pointing at a dead one and wants a reload.

Two things it deliberately will not do. It never restarts twice within a minute: a second mismatch that soon means two callers disagree about which code is current -- a dev checkout and the installed gem, typically -- and restarting again would just hand the bridge back and forth, taking your sessions with it each time. And it does not notice a single edited file deep in a dev checkout, because the fingerprint tracks `stream_weaver.rb`, which an install rewrites and a targeted edit does not. Both cases print a warning naming `streamweaver canvas-restart`, which is the answer.

Set `SW_NO_AUTO_RESTART=1` to be warned instead of healed everywhere; the command then continues against the old bridge.

## Multi-Step Workflows

Use `canvas_continue` to show a spinner after submit instead of "You can close this window":

```bash
streamweaver canvas-push myapp <<'RUBY'
  card do
    header1 "Step 1"
    text_field :name, label: "Name"
    button "Next"
  end
  canvas_continue message: "Processing..."
RUBY
```

After user clicks "Next", they see "Processing..." spinner until you push the next page.

**Final page** (no `canvas_continue`): Shows "Submitted - You can close this window"

## Panel Features

### Automatic Pane Tracking

When you open a panel, StreamWeaver tracks the iTerm2 pane ID. When you call `canvas-close`, it automatically closes the browser pane. `panel` always opens a NEW pane -- calling it a second time on a session that already has one duplicates it. To bring an existing session's pane back to the front instead (a push you made after the user's attention moved elsewhere, for example), use `canvas-raise <name>`.

### URL Fallback

If the browser doesn't auto-open, the panel command shows a URL you can paste manually:

```
Canvas 'myapp' ready
Browser opened in split pane

URL (if browser didn't open): http://localhost:4570/canvas/myapp
```

## DSL Components

All standard StreamWeaver DSL components work in canvas mode:

- `header1`, `header2`, `header3` - Headings
- `md "text"` - Markdown content
- `text_field :key, label: "...", placeholder: "..."` - Text input
- `radio_group :key, ["opt1", "opt2"]` - Radio buttons
- `select :key, ["opt1", "opt2"]` - Dropdown
- `checkbox :key, label: "..."` - Checkbox
- `button "Label", id: "btn_id", style: :primary` - Submit button
- `card { ... }` - Card container
- `status_dot status: :green, pulse: true, label: "OK"` - Status indicator
- `badge "TEXT", variant: :success` - Badge/tag
- `table headers: [...], rows: [...]` - Data table

## Example: Verification Flow

See `examples/claude_code/verification_flow/` for a complete multi-step workflow:

1. Sign-up form with `canvas_continue`
2. Verification page with toast notification
3. Welcome page (final, no `canvas_continue`)

## Claude Code Integration

### Permissions

Add to `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": ["Bash(streamweaver *)"]
  }
}
```

### Slash Command Pattern

Create `.claude/commands/myflow.md`:

```markdown
# My Flow

## Instructions

### Phase 1: Open Panel
\`\`\`bash
streamweaver panel myflow --fresh
\`\`\`

### Phase 2: First Page
\`\`\`bash
streamweaver canvas-push myflow <<'RUBY'
  # DSL content here
  canvas_continue message: "Loading..."
RUBY
\`\`\`

Wait for input:
\`\`\`bash
streamweaver canvas-wait myflow
\`\`\`

### Phase 3: Final Page
\`\`\`bash
streamweaver canvas-push myflow <<'RUBY'
  # Final page - no canvas_continue
RUBY
\`\`\`

### Cleanup
\`\`\`bash
streamweaver canvas-close myflow
\`\`\`
```

## Architecture

```
Claude Code CLI
      │
      ▼
┌─────────────────┐
│ Unix Socket IPC │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     WebSocket      ┌─────────────┐
│  Canvas Bridge  │◄──────────────────►│   Browser   │
│  (background)   │                    │  (iTerm2)   │
└─────────────────┘                    └─────────────┘
```

- **Unix Socket**: CLI ↔ Bridge communication
- **WebSocket**: Bridge ↔ Browser real-time updates
- **Bridge**: Renders DSL to HTML, manages sessions, routes events
