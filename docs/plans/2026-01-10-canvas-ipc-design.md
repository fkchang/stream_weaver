# Canvas IPC Design

Two-way interaction between Claude Code and StreamWeaver UI, inspired by [claude-canvas](https://github.com/BEARLY-HODLING/claude-canvas).

## Goal

A single browser window that Claude Code can:
- Push UI content to (forms, displays, etc.)
- Receive user interactions from (button clicks, form submissions)
- All in real-time via IPC, not HTTP polling

```
┌─────────────────────┐     ┌──────────────────────┐
│   Claude Code       │◄───►│   Single UI Window   │
│   (Terminal)        │     │   (Browser)          │
└─────────────────────┘     └──────────────────────┘
        │                            │
        └── Unix Socket ─────────────┘
            + WebSocket
```

## Architecture

```
┌─────────────┐                  ┌─────────────────────────────────┐                  ┌─────────────┐
│ Claude Code │◄─Unix Socket────►│        Canvas Bridge            │◄───WebSocket────►│   Browser   │
│             │                  │                                 │                  │             │
│ streamweaver│  ~/.streamweaver │  - Sinatra + WebSocket          │  ws://...:4568   │ StreamWeaver│
│ canvas ...  │  /canvas.sock    │  - Session management           │                  │     UI      │
└─────────────┘                  │  - DSL → HTML rendering         │                  └─────────────┘
                                 │  - Event routing                │
                                 └─────────────────────────────────┘
```

### Why This Architecture

- Browser can't use Unix sockets directly
- Unix socket for Claude ↔ Bridge (fast, local IPC)
- WebSocket for Bridge ↔ Browser (real-time, bidirectional)
- Bridge process auto-starts on first use, reuses thereafter (like existing Service)

## Process Lifecycle

**Files:**
```
~/.streamweaver/
├── server.pid          # Existing HTTP service
├── canvas.pid          # Canvas bridge process
├── canvas.sock         # Unix socket for IPC
└── server.log
```

**First invocation:**
1. Check if `canvas.pid` exists and process is alive
2. If not running → spawn bridge, write PID, create socket
3. Connect to socket, send "create session" message
4. Bridge opens browser to `http://localhost:4568/canvas/<name>`
5. Returns socket connection to Claude Code

**Subsequent invocations:** Reuse existing bridge, create new sessions as needed.

## IPC Protocol

Line-delimited JSON over Unix socket.

### Claude Code → Bridge

| Message | Purpose | Example |
|---------|---------|---------|
| `create` | Create session | `{"type":"create","name":"survey"}` |
| `push` | Push UI content | `{"type":"push","name":"survey","dsl":"header1 'Pick One'"}` |
| `close` | Close session | `{"type":"close","name":"survey"}` |
| `get_state` | Get current state | `{"type":"get_state","name":"survey"}` |

### Bridge → Claude Code

| Message | Purpose | Example |
|---------|---------|---------|
| `ready` | Session created | `{"type":"ready","name":"survey","url":"http://..."}` |
| `event` | User interaction | `{"type":"event","name":"survey","event":"submit","data":{...}}` |
| `state` | Response to get_state | `{"type":"state","name":"survey","data":{...}}` |
| `closed` | Session closed | `{"type":"closed","name":"survey"}` |

### Event Types

- `submit` - User clicked submit button
- `action` - User clicked a named button
- `change` - Field value changed (optional)
- `cancel` - User cancelled/closed

## Adapter Mode

Modify `Adapter::AlpineJS` to support WebSocket mode:

| Mode | Component Output | Backend |
|------|-----------------|---------|
| `http` (current) | HTMX `hx-post`, `hx-target` | Sinatra routes |
| `websocket` (canvas) | Alpine `@click` → WebSocket | Bridge process |

**Button example in WebSocket mode:**
```ruby
def button_attributes(button)
  if mode == :websocket
    { '@click' => "sendEvent('action', {button: '#{button.id}', state: formState()})" }
  else
    { 'hx-post' => "#{url_prefix}/action/#{button.id}", ... }
  end
end
```

## CLI Interface

### Low-level (on-the-fly)

```bash
# Create/connect to session
streamweaver canvas <name>

# Push DSL (from stdin)
streamweaver canvas-push <name> <<'RUBY'
  header1 "Pick an option"
  radio_group :choice, ["A", "B", "C"]
  button "Submit"
RUBY

# Wait for event (blocks)
streamweaver canvas-wait <name>
# => {"event":"submit","data":{"choice":"B"}}

# Close session
streamweaver canvas-close <name>

# Management
streamweaver canvas-list
streamweaver canvas-stop
```

### High-level helpers

```bash
# One-liners for common patterns
streamweaver pick "Pick approach" "Refactor" "Adapter" "Patch"
# => {"choice":"Adapter"}

streamweaver confirm "Delete 47 files?"
# => {"confirmed":true}

streamweaver form "Quick Survey" \
  --text "name:Your name" \
  --radio "priority:Low,Medium,High"
# => {"name":"Alice","priority":"High"}
```

## Ruby API

### High-level helpers

```ruby
require 'stream_weaver/canvas'

choice = StreamWeaver::Canvas.pick("Pick approach", ["Refactor", "Adapter", "Patch"])
# => "Adapter"

confirmed = StreamWeaver::Canvas.confirm("Delete 47 files?")
# => true

data = StreamWeaver::Canvas.form("Quick Survey") do
  text_field :name, placeholder: "Your name"
  radio_group :priority, ["Low", "Medium", "High"]
end
# => { name: "Alice", priority: "High" }
```

### Low-level session API

```ruby
session = StreamWeaver::Canvas.session("wizard")

session.push do
  header1 "Step 1"
  text_field :email
  button "Next"
end

result = session.wait  # => { event: "submit", data: { email: "..." } }

session.push do
  header1 "Step 2"
  # ... based on result
end

session.close
```

### Project-specific reusable canvases

```ruby
module MyProject::Canvases
  def self.code_review_picker(files)
    StreamWeaver::Canvas.form("Select files to review") do
      checkbox_group :files, select_all: "All" do
        files.each { |f| item f, f }
      end
      radio_group :depth, ["Quick scan", "Detailed review"]
    end
  end
end
```

## Implementation Structure

### New files

```
lib/stream_weaver/
├── canvas/
│   ├── bridge.rb          # Bridge process (Unix socket + WebSocket)
│   ├── session.rb         # Session management
│   ├── helpers.rb         # High-level helpers (pick, confirm, form)
│   └── protocol.rb        # Message types and serialization
├── adapter/
│   └── alpinejs.rb        # MODIFY: Add websocket mode
└── cli.rb                 # MODIFY: Add canvas commands
```

### Dependencies

```ruby
gem 'faye-websocket'       # WebSocket support
gem 'eventmachine'         # Required by faye-websocket
```

### Implementation phases

| Phase | What | Why |
|-------|------|-----|
| 1 | Protocol + Bridge skeleton | Core IPC working |
| 2 | CLI commands (canvas, push, wait) | Can test manually |
| 3 | WebSocket adapter mode | Browser ↔ Bridge communication |
| 4 | Session management | Multi-session support |
| 5 | High-level helpers | Ergonomic API |
| 6 | Terminal pane spawning (optional) | iTerm2/tmux split panes |

## References

- [claude-canvas](https://github.com/BEARLY-HODLING/claude-canvas) - Inspiration for IPC pattern
- Existing StreamWeaver live sessions (HTTP polling approach)
