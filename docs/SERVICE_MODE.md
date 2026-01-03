# StreamWeaver Service Mode

StreamWeaver operates in two modes: **standalone scripts** and **service mode**. This document explains when to use each and how the service architecture works.

## Quick Start

```bash
gem install stream_weaver

# Interactive tutorial
streamweaver tutorial

# Browse all examples
streamweaver showcase
```

## Execution Modes

### 1. Standalone Scripts (`ruby app.rb`)

For simple, one-off scripts where you want a quick UI:

```ruby
# greeting.rb
require 'stream_weaver'

app "Greeting" do
  text_field :name, placeholder: "Your name"

  if state[:name].to_s.strip != ""
    text "Hello, #{state[:name]}!"
  end
end.run!
```

Run with: `ruby greeting.rb`

**Use when:**
- Quick utilities and scripts
- Single-purpose tools
- Learning StreamWeaver
- Prototyping

**Characteristics:**
- Each script runs its own Sinatra server
- Auto-detects free port (4567, 4568, etc.)
- Auto-opens browser
- Self-contained - no dependencies on service

### 2. Service Mode (`streamweaver <file>`)

A single background service renders multiple apps, each at a unique URL:

```bash
# Start service (auto-starts if not running)
streamweaver examples/basic/hello_world.rb

# Run another app (same service, new URL)
streamweaver examples/basic/todo_list.rb

# List all loaded apps
streamweaver list

# Admin dashboard
streamweaver admin
```

**Use when:**
- Running multiple apps side-by-side
- Tutorial and examples browser (loads playground apps)
- Comparing different implementations
- Long-running development sessions

**Characteristics:**
- Single server process on port 4575
- Apps at `/apps/:app_id` URLs
- Human-readable aliases like `/tutorial/philosophy`
- Hot-reload: change file, re-run command
- Persistent until `streamweaver stop`

## CLI Commands

| Command | Description |
|---------|-------------|
| `streamweaver <file.rb>` | Run app (auto-starts service) |
| `streamweaver run --name "My App" <file>` | Run with custom name |
| `streamweaver list` | List all loaded apps |
| `streamweaver remove <app_id>` | Remove specific app |
| `streamweaver clear` | Remove all apps |
| `streamweaver admin` | Open admin dashboard |
| `streamweaver showcase` | Open examples browser |
| `streamweaver tutorial` | Open interactive tutorial |
| `streamweaver status` | Show service status |
| `streamweaver stop` | Stop background service |
| `streamweaver llm` | Output LLM documentation |

## Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    StreamWeaver Service                      │
│                     (port 4575)                              │
├─────────────────────────────────────────────────────────────┤
│  /apps/a1b2c3d4  →  hello_world.rb                          │
│  /apps/e5f6g7h8  →  todo_list.rb                            │
│  /apps/i9j0k1l2  →  form_demo.rb                            │
│                                                              │
│  Aliases:                                                    │
│  /tutorial/philosophy  →  /apps/m3n4o5p6                    │
│  /examples/hello_world →  /apps/q7r8s9t0                    │
├─────────────────────────────────────────────────────────────┤
│  Admin Dashboard: /admin                                     │
└─────────────────────────────────────────────────────────────┘
```

### How Apps Are Loaded

1. **CLI calls `/load-app`** with file path and optional name/source
2. **Service evaluates** the Ruby file in isolation
3. **App gets unique ID** (8-char hash)
4. **Browser opens** to `/apps/:app_id` or aliased URL

### Aliased URLs

Apps can have human-readable URLs:

```ruby
# Internal: loads app with source="tutorial", name="tutorial/philosophy"
load_app_via_service(temp_file, source: "tutorial", name: "tutorial/philosophy")

# Results in alias: /tutorial/philosophy → /apps/a1b2c3d4
```

## Tutorial Integration

The interactive tutorial (`streamweaver tutorial`) demonstrates service integration:

```
┌────────────────────────────────────────────────────────────┐
│  Tutorial App (standalone on port 4567)                     │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────────┬─────────────────────────────────────┐│
│  │  Navigation      │  Code Editor                        ││
│  │  - Philosophy    │  ┌─────────────────────────────────┐││
│  │  - Hello World   │  │ header1 "Welcome!"              │││
│  │  - Getting Input │  │ text_field :name                │││
│  │  - ...           │  │ ...                             │││
│  │                  │  └─────────────────────────────────┘││
│  │                  │  [Check] [Reset] [Run] [Open] [Stop]││
│  └──────────────────┴─────────────────────────────────────┘│
└────────────────────────────────────────────────────────────┘
         │
         │ Click "Run" → Loads code into service
         ▼
┌────────────────────────────────────────────────────────────┐
│  StreamWeaver Service (port 4575)                           │
├────────────────────────────────────────────────────────────┤
│  /tutorial/philosophy → User's edited code running          │
│  /tutorial/hello_world → Another lesson's code              │
└────────────────────────────────────────────────────────────┘
```

**Flow:**
1. User edits code in tutorial's CodeMirror editor
2. Clicks "Run" → Tutorial writes temp file, calls service `/load-app`
3. Service loads app, returns URL
4. Tutorial opens browser to `/tutorial/philosophy`
5. User sees their code running live
6. Click "Stop" to unload from service

## Examples Browser Integration

The examples browser (`streamweaver showcase`) works similarly:

- Displays categorized examples with syntax-highlighted previews
- "Run" loads example into service
- "Stop" unloads from service
- Multiple examples can run simultaneously

## Use Cases

### Quick One-Off Script

```bash
# Just run it directly
ruby my_tool.rb
```

### Development Session

```bash
# Start working on an app
streamweaver my_app.rb

# Edit code, re-run to hot-reload
streamweaver my_app.rb

# Check what's loaded
streamweaver list

# Clean up when done
streamweaver stop
```

### Learning StreamWeaver

```bash
# Interactive tutorial
streamweaver tutorial

# Browse and run examples
streamweaver showcase
```

### Comparing Implementations

```bash
# Load multiple versions
streamweaver v1/dashboard.rb
streamweaver v2/dashboard.rb

# Open both in browser tabs
streamweaver list  # Shows URLs for both
```

## Session State

**Important:** Each app has isolated session state.

- Standalone scripts: Session in browser cookie per port
- Service mode: Session per app_id (apps don't share state)
- Tutorial/Examples: Playground apps are independent of the host app

## Agentic Mode with Service

For AI agent workflows, standalone mode is typically simpler:

```ruby
# Agent runs this, waits for response
result = app "Quick Survey" do
  text_field :feedback
  select :rating, ["1", "2", "3", "4", "5"]
end.run_once!

puts result.inspect
# => { "feedback" => "Great!", "rating" => "5" }
```

Service mode can be used for persistent agent UIs that need to run alongside other apps.

## Troubleshooting

### Service won't start

```bash
# Check if already running
streamweaver status

# Stop and restart
streamweaver stop
streamweaver serve  # Foreground mode for debugging
```

### App not updating after code change

```bash
# Re-run to hot-reload
streamweaver my_app.rb

# Or remove and re-add
streamweaver remove <app_id>
streamweaver my_app.rb
```

### Port conflict

```bash
# Service uses 4575 by default
# Standalone scripts auto-detect free ports starting at 4567
# If 4575 is in use, stop other service or change port:
streamweaver serve -p 4576
```

### Session state persists unexpectedly

Browser cookies persist across server restarts. To reset:
1. Clear browser cookies for localhost
2. Use incognito mode
3. Add reset button: `button "Reset" do |s| s.clear end`

## Future: Claude Code Integration

*Documentation for Claude Code integration patterns coming soon.*

Key areas:
- Using `run_once!` for form collection
- Building persistent agent UIs via service mode
- Patterns for multi-step agent workflows
