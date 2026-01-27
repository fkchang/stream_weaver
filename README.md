# StreamWeaver

**Rich UI for Claude Code. Express intention, get interface.**

```ruby
app "Meeting Notes" do
  header "1:1 with #{manager}"
  md notes_markdown
end.run!
```

That's it. No HTML. No CSS. No JavaScript. No webpack. Just Ruby expressing what you want.

---

## The Problem StreamWeaver Solves

> "I would like to give Claude a way of popping up its results on my desktop in rich text. Basically because if I have it generate something like 1:1 meeting notes, I need that to pop up and stay available instead of scrolling out of the current terminal context."

Sound familiar? Claude Code generates great content, but it scrolls away in the terminal. You're left copying text, opening editors, losing context.

**StreamWeaver gives Claude Code a canvas** - a persistent browser display for rich output that doesn't disappear.

---

## Three Ways to Use StreamWeaver

| Mode | Use Case | How It Works |
|------|----------|--------------|
| **Canvas** | Claude Code output that persists | Browser tab Claude pushes content to |
| **Agentic** | Claude needs user input | Popup form → collect answer → return JSON |
| **Standalone** | Quick Ruby apps | Single file → full UI |

### Canvas Mode: Persistent Rich Output

Keep a browser tab open. Claude Code pushes rich content that *stays*.

```bash
# Terminal 1: Start canvas
streamweaver live mynotes

# Terminal 2: Claude Code pushes content
streamweaver push mynotes --dsl 'md "# Meeting Notes\n\n## Action Items\n- ..."'
```

The canvas updates. Content persists. No scrolling away.

**Pro tip:** iTerm2 has a [built-in browser](https://iterm2.com/documentation-web.html) that fits into split panes - run Claude Code on the left, canvas on the right, same window.

### Agentic Mode: Rich Input Collection

When Claude Code needs a complex answer, don't suffer through terminal menus:

```ruby
result = app "Project Setup" do
  header "Configure New Project"
  text_field :name, placeholder: "Project name"
  select :database, ["PostgreSQL", "SQLite", "MySQL"]
  select :framework, ["Rails", "Sinatra", "Hanami"]
  checkbox :docker, "Include Docker setup"
end.run_once!

# Returns: { "name" => "myapp", "database" => "PostgreSQL", ... }
```

Browser opens, user fills form, JSON returns to Claude Code. Done.

### Standalone Mode: The Joy of Ruby

Quick utilities without ceremony:

```ruby
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

`ruby todo.rb` → browser opens → working app. That's the joy of Ruby: express intention, get result.

---

## Token Efficiency: Why This Matters for GenAI

When Claude Code generates UI, tokens = time + money.

```ruby
# StreamWeaver: ~50 tokens
table users do
  column :name
  column :balance, format: :currency
end
button "Export CSV"
```

```html
<!-- Equivalent HTML/React: ~300+ tokens -->
<div className="overflow-x-auto">
  <table className="min-w-full divide-y divide-gray-200">
    <thead className="bg-gray-50">
      <tr>
        <th scope="col" className="px-6 py-3 text-left text-xs...
<!-- ... 50 more lines ... -->
```

**5-10x fewer tokens** means faster responses and lower costs. For complex UIs, the difference is dramatic.

Even better: pre-build your StreamWeaver app, have Claude generate just the *data*:

```ruby
# Claude generates only this (~20 tokens):
meetings = [{ title: "1:1 with Sarah", notes: "..." }, ...]

# Pre-built app renders it:
MeetingNotesApp.new(meetings: meetings).run!
```

---

## Installation

```bash
gem install stream_weaver
```

Or in your Gemfile:

```ruby
gem 'stream_weaver'
```

---

## Quick Start

```bash
# Interactive tutorial
streamweaver tutorial

# Browse examples
streamweaver showcase

# Run any example
ruby examples/basic/hello_world.rb
```

---

## Running Modes Explained

### `ruby app.rb` vs `streamweaver app.rb`

| Command | What Happens | When to Use |
|---------|--------------|-------------|
| `ruby app.rb` | Standalone server on auto-detected port | Quick scripts, one-off apps |
| `streamweaver app.rb` | Managed by background service | Multiple apps, development |

The service mode (`streamweaver`) runs one Sinatra server for all apps instead of one per app - cleaner process management.

### Canvas Commands

```bash
streamweaver live SESSION      # Start persistent canvas
streamweaver push SESSION      # Push content to canvas
streamweaver wait SESSION      # Wait for user submission
streamweaver template TYPE SESSION '{...}'  # Use pre-built template
```

### Templates for Common Patterns

```bash
# Quick selection
streamweaver template choices mysession '{"title": "Pick DB", "options": ["PostgreSQL", "SQLite"]}'

# Yes/No confirmation
streamweaver template confirm mysession '{"title": "Delete?", "message": "This cannot be undone"}'

# Multi-step wizard
streamweaver template wizard mysession '{"steps": [...]}'

# Data table
streamweaver template table mysession '{"headers": ["Name", "Size"], "rows": [...]}'
```

---

## Components

### The Basics

```ruby
text "Plain text"
md "**Markdown** with *formatting*"
header "Section Title"
header1 "H1" # through header6
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
  column { text "Main content" }
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
  header3 "Card Title"
  text "Content"
end
```

### Tables

```ruby
# Simple
table headers: ["Name", "Age"], rows: [["Alice", 30], ["Bob", 25]]

# From array of hashes (headers inferred)
table [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }]

# With formatters
table users do
  column :name
  column :balance, format: :currency
  column :joined, format: :date
end

# Interactive
table data, sortable: true, sticky_header: true, striped: true
```

### Charts

```ruby
bar_chart data: { sales: 100, costs: 60, profit: 40 }
line_chart data: [12, 19, 8, 15, 22], fill: true
pie_chart data: { frontend: 40, backend: 35, devops: 25 }
sparkline data: [45, 52, 48, 61, 55, 67, 72]  # Compact inline
```

### Navigation & Feedback

```ruby
tabs :settings do
  tab("General") { text_field :name }
  tab("Advanced") { checkbox :debug, "Debug mode" }
end

modal :confirm, title: "Are you sure?" do
  text "This action cannot be undone."
  modal_footer do
    button "Cancel", style: :secondary do |s| s[:confirm_open] = false end
    button "Delete" do |s| delete_item; s[:confirm_open] = false end
  end
end

alert(variant: :success) { text "Saved!" }
progress_bar value: 75, variant: :success
spinner label: "Loading..."
```

### Dashboard Components

For operations dashboards (best with `theme: :dark`):

```ruby
status_dot status: :green, pulse: true
badge "5", variant: :danger
stat_display value: 42, label: "TASKS"
priority_item priority: :critical, title: "Server down"
activity_item time: "15:00", title: "Deploy complete"

app_shell sidebar_width: "320px" do
  main { header "Dashboard" }
  sidebar(header: "Alerts") { priority_item priority: :high, title: "CPU 90%" }
end
```

---

## Theming

```ruby
app "My App", theme: :dark do      # Dark mode
  # ...
end

app "Report", theme: :document do  # Reading-optimized
  # ...
end
```

**Built-in themes:** `:default`, `:dashboard`, `:document`, `:dark`

---

## Evolution & Philosophy

StreamWeaver evolved through real needs:

1. **Standalone** - "I want a quick UI without HTML/CSS/JS ceremony"
2. **Agentic** - "Claude Code needs to collect structured input from me"
3. **Canvas** - "Claude's output needs to persist, not scroll away"
4. **Service** - "I don't want 30 Sinatra processes for 30 apps"

The constant: **Ruby's joy of expressing intention**. You say what you want, StreamWeaver figures out the how.

---

## iTerm2 + Claude Code Setup

iTerm2's [built-in browser](https://iterm2.com/documentation-web.html) enables a powerful workflow:

1. Split iTerm pane vertically
2. Left: Claude Code terminal
3. Right: StreamWeaver canvas (browser tab)

Claude Code generates content → pushes to canvas → you see rich output without leaving your terminal.

*Coming soon: `/streamweaver-pane` command to set this up automatically.*

---

## More Resources

- [Canvas Mode Documentation](docs/canvas-roadmap.md)
- [Templates Reference](docs/templates.md)
- [Components Reference](docs/components_reference.md)
- [Service Mode](docs/SERVICE_MODE.md)

---

## Contributing

Contributions welcome! See [GitHub repository](https://github.com/fkchang/stream_weaver).

## License

MIT License - see [LICENSE.txt](LICENSE.txt)

---

## Sources

- [iTerm2 Web Browser Documentation](https://iterm2.com/documentation-web.html)
