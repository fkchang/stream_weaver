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

## Reaching the bridge from your phone (tailnet)

The bridge listens on `127.0.0.1:4700` and answers only loopback `Host` headers, so a proxy such as `tailscale serve` gets `403 Host not permitted` until you name the hosts it will present. Name them in `STREAMWEAVER_CANVAS_ALLOWED_HOSTS` (comma separated, host part only, no port) in the environment the bridge starts in, or, better because it survives an automatic bridge restart from a shell without the variable, one host per line in `~/.streamweaver/canvas_allowed_hosts` (`#` comments allowed; both are unioned). Then restart the bridge with `streamweaver canvas-restart` (snapshot, stop, start, restore: sessions keep their content):

```bash
export STREAMWEAVER_CANVAS_ALLOWED_HOSTS=mac.tailnet-name.ts.net,mac,100.64.0.7
tailscale serve --bg --https=8445 http://127.0.0.1:4700   # tailnet only, not funnel
# phone: https://mac.tailnet-name.ts.net:8445/canvas/<session>
```

Default (unset or empty) is loopback only, exactly as before. Matching is exact on the host (case-insensitive, port ignored); an empty `Host` and wildcard entries are ignored, never allowed. The same setting governs the reader (`canvas-read`), so both servers agree. The decision uses the raw `Host` header, not `X-Forwarded-Host`. The browser `Sec-Fetch-Site` check stays on the reader and now also guards the bridge's POST routes (events, save-doc, shutdown): the https proxy is same-origin to the page, so it passes, while a page from another site cannot post to the bridge. Edits to the file take effect on the next request; the env var needs a bridge restart. An entry is a bare host (no wildcard, no leading-dot subdomain syntax). Canvas pages use relative URLs for polling and events, so they work under whatever origin served them.

**Security:** the bridge accepts pushed content and relays canvas actions (button clicks) to the agent sessions listening for them. Exposing it means every device on that tailnet can do both. Only add hosts on a tailnet you fully trust, and never proxy it through a public funnel. The setting also opens the reader, whose `/open` evaluates the `.rb` file it is given, so do not proxy the reader onto the tailnet unless you accept that every tailnet device can run code on this machine.

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

`canvas_continue` goes at the top level, after the closing `end` of a `tabs` block, never inside it (inside `tabs` it raises `undefined method label`).

## Many clicks: `canvas-wait` is one event, a listener is every event

A canvas used as a working form (a coordinator page with several cards, each with its own button) gets more than one click. `canvas-wait` is the wrong tool for that:

- It returns the **first** `action` event and closes its socket. A click that lands while the agent is not blocked in `canvas-wait` is lost, and the default timeout is 300 s (`-t SECONDS`; `-a` waits for any event type, `-e TYPE` for one type).
- It returns the **whole form state** (every field), not only the button's own card. A radio selected in card B arrives with the button of card A; the button pressed is the answer, and a field alone is not a submit.
- The page after a click is the `canvas_continue` spinner, or "Submitted" without it. Until the next push, a spinner page **swallows every later click** (the adapter sets `_swFeedbackActive`). So every click must be followed by a re-push, even when nothing on the page changed.

For many clicks use `StreamWeaver::Canvas::Client.each_event(session)`: it holds **one** connection open and yields every event for that session (events are filtered by session name because the bridge broadcasts all sessions' events). Handle each click (write to your store, then re-push the page) and reconnect when `each_event` returns, which it does when the bridge closes the socket (`canvas-restart` does that routinely). Reference implementations: `lib/stream_weaver/university/listener.rb` (a click becomes a ledger write plus a re-push) and, outside this repo, `bin/scrum-canvas-listen` in cultiv-ai (a click becomes a durable log entry, a re-push, and a nudge to the agent that owns the canvas).

Event shape: `{type: 'event', name: <session>, data: {type: 'action', button: 'btn_<label-slug>_<n>', state: {...}}}`.

If the listener process loads only `stream_weaver/canvas/client`, the staleness guard may try to restart an older bridge from inside it and fail with `NameError ... CLI::Service`. Set `SW_NO_AUTO_RESTART=1` for the listener (it then warns and carries on against the running bridge) and run `streamweaver canvas-restart` yourself when you choose.

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
