# StreamWeaver

**Express intention, get interface. The joy of Ruby applied to UI.**

```ruby
app "Meeting Notes" do
  header "1:1 with #{manager}"
  md notes
end.run!
```

That's it. No HTML. No CSS. No JavaScript. No webpack.

---

## Why StreamWeaver?

**TL;DR:** I want a quick UI. What do I need? Some text, a few inputs, a button. Why isn't *that* the interface? Instead: HTML, CSS, JavaScript, backend wiring... Streamlit showed me the interface *can* just be "text, inputs, button." StreamWeaver brings that to Ruby - and it turns out this minimal approach is perfect for AI agents too.

[Skip to Quick Start →](#quick-start)

<details>
<summary><b>The Longer Story</b></summary>

### The Interface Should Be What You Need

Think about what a simple UI actually requires: some text, a few inputs, maybe a dropdown, a button. That's it. That's what you're trying to build. But to get there you're dealing with HTML structure, CSS styling, JavaScript (or a backend framework), controllers, state management...

Streamlit's brilliance was recognizing that the DSL *can* just be the interface. You describe what you need - text, inputs, button - and you're done. StreamWeaver brings that philosophy to Ruby.

### Why This Matters for AI Agents

When you're building with Claude Code (or other AI coding assistants), this "what matters" approach pays off even more:

1. **Token efficiency** - The LLM generates a concise DSL instead of verbose HTML/React. **5-10x fewer tokens** means faster responses and lower costs.

2. **Rich interactions** - Instead of walls of terminal text for complex decisions, spin up an actual UI. What would be 5 pages of back-and-forth becomes one well-designed form.

3. **Persistent output** - Claude generates content (meeting notes, analysis, reports) but terminal output scrolls away. Canvas mode gives Claude a persistent display that stays visible.

4. **Data-only generation** - Pre-build your StreamWeaver app once, then have the LLM just generate the *data* to feed it. Minimal tokens, maximum speed.

```ruby
# Agent generates just this data:
meetings = [{ title: "1:1 with Sarah", notes: "..." }, ...]

# Pre-built app renders it:
MeetingNotesApp.new(meetings: meetings).run!
```

</details>

---

## The Modes

StreamWeaver evolved through real needs, resulting in four modes:

| Mode | Command | What It Does | Use Case |
|------|---------|--------------|----------|
| **Standalone** | `ruby app.rb` | Auto-port, auto-browser, persistent server | Quick apps, utilities, prototypes |
| **Agentic** | `app.run_once!` | Popup UI → collect input → return JSON → quit | Claude Code needs structured input |
| **Canvas** | `streamweaver live SESSION` | Persistent display that Claude updates | Output that doesn't scroll away |
| **Service** | `streamweaver app.rb` | Single server, multiple apps | Development, showcase, tutorial |

### `ruby app.rb` vs `streamweaver app.rb`

| Command | Process Model | When to Use |
|---------|---------------|-------------|
| `ruby app.rb` | You own the process, runs until you kill it | Quick one-off scripts, standalone apps |
| `streamweaver app.rb` | Managed by background service, multi-app routing | Multiple apps side-by-side, development |

The service mode runs one Sinatra server for all apps instead of one process per app.

### From Local Script to Mobile Dashboard

StreamWeaver apps cover a wide range — the same DSL works whether you're hacking a quick one-off or running a persistent dashboard you check from your phone:

| Scenario | Host | Port | How |
|----------|------|------|-----|
| **Quick one-off** | localhost | auto-detect | `ruby app.rb` — browser opens, use it, Ctrl+C |
| **Agentic popup** | localhost | auto-detect | `app.run_once!` — collect input, return JSON, exit |
| **Mobile/Tailscale** | `0.0.0.0` | fixed | `STREAMWEAVER_HOST=0.0.0.0 STREAMWEAVER_PORT=4580 ruby app.rb` |
| **LAN access** | `0.0.0.0` | fixed | Same — any device on your network can reach it |
| **Always-on dashboard** | `0.0.0.0` | fixed | Bookmark `http://your-machine:4580` on your phone |

**Environment variables** (overridden by code options if set):
- `STREAMWEAVER_HOST` — bind address (default: `127.0.0.1`)
- `STREAMWEAVER_PORT` — fixed port (default: auto-detect from 4567)

For quick local work, the defaults are perfect — auto-find a port, open the browser, done. For mobile or remote access (Tailscale, LAN), set a fixed host and port so your URL stays stable across restarts.

---

## Quick Start

```bash
gem install stream_weaver

# Interactive tutorial
streamweaver tutorial

# Browse examples
streamweaver showcase

# Run any example
ruby examples/basic/hello_world.rb
```

---

## Standalone Mode

The simplest path - one Ruby file, one command:

```ruby
# todo.rb
require 'stream_weaver'

app "Todo List" do
  text_field :new_todo, placeholder: "What needs doing?"

  button "Add" do |state|
    state[:todos] ||= []
    state[:todos] << state[:new_todo]
    state[:new_todo] = ""
  end

  state[:todos]&.each do |todo|
    div { text "• #{todo}" }
  end
end.run!
```

```bash
ruby todo.rb
# Browser opens at http://localhost:4567
```

---

## Agentic Mode

When Claude Code needs structured input, not terminal menus:

```ruby
result = app "Project Setup" do
  header "Configure New Project"
  text_field :name, placeholder: "Project name"
  select :database, ["PostgreSQL", "SQLite", "MySQL"]
  checkbox :docker, "Include Docker setup"
end.run_once!

# Browser opens, user fills form, returns:
# { "name" => "myapp", "database" => "PostgreSQL", "docker" => true }
```

The browser opens, user fills the form, JSON returns to the calling script. Perfect for AI workflows that need human input.

---

## Canvas Mode

A persistent browser display that Claude Code can update. Content stays visible instead of scrolling away in the terminal.

```bash
# Start the canvas (keeps running)
streamweaver live mynotes

# Claude Code pushes content as it works
streamweaver push mynotes --dsl 'md "# Analysis Results\n\n## Key Findings\n- ..."'

# Canvas updates in real-time
```

**Pro tip:** iTerm2 has a [built-in browser](https://iterm2.com/documentation-web.html) that fits into split panes - run Claude Code on the left, canvas on the right, same window.

### Templates for Common Patterns

```bash
# Quick selection
streamweaver template choices mysession '{"title": "Pick DB", "options": ["PostgreSQL", "SQLite"]}'
# Returns: {"choice": "PostgreSQL"}

# Yes/No confirmation
streamweaver template confirm mysession '{"title": "Delete?", "message": "Cannot be undone"}'
# Returns: {"confirmed": true}

# Multi-step wizard
streamweaver template wizard mysession '{"steps": [...]}'

# Data table with selection
streamweaver template table mysession '{"headers": ["File", "Size"], "rows": [...]}'
```

---

## Components

### Text & Headers

```ruby
text "Plain text"
md "**Markdown** with *formatting* and [links](url)"
header "Section"       # <h2> default
header1 "Page Title"   # through header6
```

### Form Inputs

```ruby
text_field :name, placeholder: "Name", default: "Alice"
text_area :bio, rows: 5
select :color, ["Red", "Green", "Blue"], default: "Green"
checkbox :agree, "I accept"
radio_group :size, ["S", "M", "L"]
```

### Buttons

```ruby
button "Primary" do |state|
  state[:clicked] = true
end

button "Secondary", style: :secondary do |state|
  # ...
end
```

### Layout

```ruby
columns widths: ['30%', '70%'] do
  column { text "Sidebar" }
  column { text "Main" }
end

vstack spacing: :md do
  text "Item 1"
  text "Item 2"
end

hstack justify: :between do
  button "Cancel", style: :secondary
  button "Save"
end

card do
  header3 "Title"
  text "Content"
end

collapsible "Show Details" do
  text "Hidden until clicked"
end
```

### Tables

```ruby
# Simple
table headers: ["Name", "Age"], rows: [["Alice", 30], ["Bob", 25]]

# From hashes (headers inferred)
table [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }]

# With formatters
table users do
  column :name
  column :balance, format: :currency
  column :joined, format: :date
end

# Interactive
table data, sortable: true, sticky_header: true, striped: true, markdown: true
```

### Charts

```ruby
bar_chart data: { sales: 100, costs: 60, profit: 40 }
line_chart data: [12, 19, 8, 15, 22], fill: true
pie_chart data: { frontend: 40, backend: 35, devops: 25 }
sparkline data: [45, 52, 48, 61, 55, 67, 72]
```

### Navigation & Modals

```ruby
tabs :settings do
  tab("General") { text_field :name }
  tab("Advanced") { checkbox :debug, "Debug" }
end

modal :confirm, title: "Are you sure?" do
  text "This cannot be undone."
  modal_footer do
    button "Cancel", style: :secondary do |s| s[:confirm_open] = false end
    button "Delete" do |s| do_delete; s[:confirm_open] = false end
  end
end
```

### Feedback

```ruby
alert(variant: :success) { text "Saved!" }
progress_bar value: 75, variant: :success
spinner label: "Loading..."
toast_container position: :top_right
```

### Dashboard Components

For operations dashboards (best with `theme: :dark`):

```ruby
status_dot status: :green, pulse: true
badge "5", variant: :danger
stat_display value: 42, label: "TASKS"
priority_item priority: :critical, title: "Server down"

app_shell sidebar_width: "320px" do
  main { header "Dashboard" }
  sidebar(header: "Alerts") { priority_item priority: :high, title: "CPU 90%" }
end
```

---

## Theming

```ruby
app "My App", theme: :dark do
  # Dark mode with glow effects
end

app "Report", theme: :document do
  # Reading-optimized (serif, paper background)
end
```

**Built-in themes:** `:default`, `:dashboard`, `:document`, `:dark`

---

## More Resources

- [Canvas Mode Documentation](docs/canvas-roadmap.md)
- [Templates Reference](docs/templates.md)
- [Components Reference](docs/components_reference.md)
- [Service Mode](docs/SERVICE_MODE.md)

---

## Contributing

Contributions welcome! [GitHub repository](https://github.com/fkchang/stream_weaver)

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
