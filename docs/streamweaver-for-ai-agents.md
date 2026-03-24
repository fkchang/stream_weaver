# StreamWeaver for AI Agents

A guide to building visual UI for AI agent workflows with minimal token overhead.

## The Problem

AI agents need visual UI, but the options are frustrating:

**Terminal output** is hard to parse. Complex choices become walls of text. Multi-step workflows turn into scrolling nightmares. Users lose context.

**HTML/React** is verbose. A simple form is 50+ lines. AI generation is slow and expensive. Token costs matter—slower, more expensive, less context available for the actual problem.

**What agents actually need:**
- Quick visual feedback for complex choices
- Forms that don't require parsing natural language
- Progress indicators and status displays
- Charts and data visualization
- All without burning context on boilerplate

## The Solution: Concise DSL

StreamWeaver is a Ruby DSL that renders to HTML. Many components, clear syntax, fast to build real apps.

### Token Comparison

A form with 3 fields and a button:

**StreamWeaver DSL** (~45 tokens):
```ruby
card do
  header1 "Sign Up"
  text_field :email, placeholder: "you@example.com", label: "Email"
  text_field :name, placeholder: "Your Name", label: "Name"
  text_field :company, label: "Company"
  button "Submit", id: "btn_submit", style: :primary
end
```

**HTML** (~200+ tokens):
```html
<div class="card">
  <h1>Sign Up</h1>
  <div class="form-group">
    <label for="email">Email</label>
    <input type="text" id="email" name="email" placeholder="you@example.com" class="form-control">
  </div>
  <div class="form-group">
    <label for="name">Name</label>
    <input type="text" id="name" name="name" placeholder="Your Name" class="form-control">
  </div>
  <div class="form-group">
    <label for="company">Company</label>
    <input type="text" id="company" name="company" class="form-control">
  </div>
  <button type="submit" class="btn btn-primary">Submit</button>
</div>
```

**React** (~300+ tokens):
```jsx
function SignUpForm() {
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [company, setCompany] = useState('');

  return (
    <div className="card">
      <h1>Sign Up</h1>
      <div className="form-group">
        <label htmlFor="email">Email</label>
        <input
          type="text"
          id="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com"
        />
      </div>
      {/* ... more fields ... */}
      <button type="submit" className="btn btn-primary">Submit</button>
    </div>
  );
}
```

That's **5-7x fewer tokens** for the same UI. For AI generation, this means:
- Faster responses
- Lower cost
- More context available for actual work

### Component Variety

StreamWeaver includes components for common agent needs:

| Category | Components |
|----------|------------|
| Layout | `card`, `columns`, `hstack`, `vstack`, `collapsible` |
| Text | `header1`-`header4`, `text`, `md` (markdown) |
| Forms | `text_field`, `radio_group`, `checkbox`, `select`, `button` |
| Data | `table`, `bar_chart`, `pie_chart`, `stat_display` |
| Status | `status_dot`, `progress_bar`, `spinner`, `badge`, `alert` |
| Media | `image`, `video`, `audio` |

### CRITICAL: Never Put Markdown Inside `text`

`text` is a literal renderer — markdown syntax appears as raw characters on screen.

```ruby
# WRONG — renders as: **Select the article PDF:**  (asterisks visible to user)
text "**Select the article PDF:**"

# CORRECT — use md for markdown formatting
md "**Select the article PDF:**"

# BETTER — use semantic headers for labels and section titles
header3 "Select the article PDF:"
header4 "What do you want to know?"
```

Use `text` only for plain prose. Use `md` when you need inline markdown (bold, italic, links, code). Use `header1`–`header6` for structural headings and form-section labels.

## The Modes Gamut

StreamWeaver supports multiple modes, from full standalone apps to persistent canvas sessions with Claude Code.

| Mode | Use Case | Process Model | Example |
|------|----------|---------------|---------|
| **Standalone** | Full applications | `streamweaver app.rb` | Rivet, tutorial.rb, theme_tweaker |
| **Agentic** (`run_once!`) | Mid-task UI from scripts | Generate → wait → parse JSON | Quick prompts, confirmations |
| **Service** | Multi-app hosting | Long-running server, reuse apps | Dashboard with multiple widgets |
| **Canvas/Panel** | Claude Code companion | Persistent session, push/wait | codebreaker, verification_flow |

### Standalone Mode

Full applications that run independently.

```bash
streamweaver my_app.rb
```

Good for:
- Reusable tools and utilities
- Self-documenting tutorials
- Applications that run outside agent workflows

Example: `examples/advanced/tutorial.rb` teaches StreamWeaver using StreamWeaver itself.

### Agentic Mode (`run_once!`)

Quick UI mid-script. Generate DSL, render, wait for input, parse JSON response.

```ruby
require 'stream_weaver'

result = StreamWeaver.run_once! do
  card do
    header1 "Quick Question"
    radio_group :choice, ["Option A", "Option B", "Option C"]
    button "Continue", id: "btn_continue", style: :primary
  end
end

puts "User chose: #{result['choice']}"
```

Good for:
- Confirmation dialogs
- Quick selections
- Mid-workflow decisions

### Service Mode

Long-running server that hosts multiple apps. Avoids startup overhead when switching between apps.

```bash
streamweaver service start
streamweaver service add my_app.rb
streamweaver service status
```

Good for:
- Dashboard with multiple widgets
- Frequently-used utilities
- Development workflows

### Canvas/Panel Mode

Persistent session with Claude Code. The agent opens a panel, pushes updates, waits for input, and continues the conversation.

```bash
# Open a panel (browser in iTerm split pane)
streamweaver panel my_session

# Push DSL content (via stdin)
streamweaver canvas-push my_session <<'DSL'
card do
  header1 "Working..."
  spinner label: "Processing files..."
end
DSL

# Wait for user interaction (returns JSON)
streamweaver canvas-wait my_session

# Show toast notification
streamweaver canvas-toast my_session "Check terminal for input"

# Close when done
streamweaver canvas-close my_session
```

Good for:
- Multi-phase Claude Code workflows
- Real-time status updates
- Interactive analysis tools

## Remote & Mobile Access

StreamWeaver apps aren't limited to localhost. With Tailscale or LAN access, the same app you build for local use becomes a mobile dashboard:

```bash
# Access from your phone via Tailscale
STREAMWEAVER_HOST=0.0.0.0 STREAMWEAVER_PORT=4580 ruby dashboard.rb
# → http://your-machine:4580 from any Tailscale device
```

Or in code:
```ruby
app "Ops Dashboard", theme: :dark do
  # ... status displays, charts, priority items
end.run!(host: '0.0.0.0', port: 4580)
```

This opens up use cases like:
- **Mobile monitoring** — check build status, deployment health from your phone
- **Team dashboards** — share a StreamWeaver app across Tailscale for team visibility
- **Remote agentic UI** — trigger agent workflows from a tablet while away from your desk

The fixed port ensures bookmarks and home screen shortcuts stay stable across restarts.

## When to Use What

```
                                    ┌─────────────────────┐
                                    │  What are you       │
                                    │  building?          │
                                    └──────────┬──────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
           ┌────────────────┐        ┌────────────────┐        ┌────────────────┐
           │  Reusable app  │        │  Quick UI in   │        │  Claude Code   │
           │  or tool?      │        │  a script?     │        │  integration?  │
           └───────┬────────┘        └───────┬────────┘        └───────┬────────┘
                   │                         │                         │
                   ▼                         ▼                         │
           ┌────────────────┐        ┌────────────────┐                │
           │  STANDALONE    │        │  AGENTIC       │                │
           │  streamweaver  │        │  run_once!     │                │
           │  app.rb        │        │                │                │
           └────────────────┘        └────────────────┘                │
                                                                       │
                                               ┌───────────────────────┴───────────────────────┐
                                               │                                               │
                                               ▼                                               ▼
                                      ┌────────────────┐                              ┌────────────────┐
                                      │  Single        │                              │  Multi-app     │
                                      │  workflow?     │                              │  dashboard?    │
                                      └───────┬────────┘                              └───────┬────────┘
                                              │                                               │
                                              ▼                                               ▼
                                      ┌────────────────┐                              ┌────────────────┐
                                      │  CANVAS/PANEL  │                              │  SERVICE       │
                                      │  slash command │                              │  multi-app     │
                                      │  + heredocs    │                              │  hosting       │
                                      └────────────────┘                              └────────────────┘
```

## Canvas/Panel Patterns

The canvas/panel mode is the most common for Claude Code integration. Key patterns:

### Pattern A: Progress While Working

Show a spinner while Claude does actual work:

```bash
# Push spinner (with canvas_continue)
streamweaver canvas-push session <<'DSL'
canvas_continue message: "Analyzing..."
card do
  header1 "Working"
  spinner label: "Processing files..."
end
DSL

# DO THE ACTUAL WORK (Glob, Grep, Read, etc.)
# ...

# Push results (NO canvas_continue)
streamweaver canvas-push session <<'DSL'
card do
  header1 "Results"
  table headers: ["File", "Lines"], rows: [["main.rb", "150"]]
  button "Continue", id: "btn_continue", style: :primary
end
DSL

# Wait for user
streamweaver canvas-wait session
```

### Pattern B: Form Interaction

Show a form and wait for user input:

```bash
# Push form (NO canvas_continue)
streamweaver canvas-push session <<'DSL'
card do
  header1 "Choose Options"
  radio_group :choice, ["Option A", "Option B"]
  button "Submit", id: "btn_submit", style: :primary
end
DSL

# Wait for user
streamweaver canvas-wait session
```

**Critical:** Never combine `canvas_continue` with `canvas-wait`. That's contradictory:
- `canvas_continue` says "I'm working, here's a spinner"
- `canvas-wait` says "I'm done, waiting for you"

### Toast for Terminal Prompts

When Claude needs permission for tools, toast alerts the user:

```bash
streamweaver canvas-toast session "Check terminal for authorization" --variant warning
```

## Real Examples

### codebreaker

Spy-themed code analysis tool. Demonstrates:
- Multi-phase workflow (briefing → reconnaissance → report → deep analysis)
- Component variety (charts, tables, status dots, progress bars)
- Dynamic DSL generation based on analysis results
- `canvas_continue` for progress, `canvas-wait` for interaction

### verification_flow

Realistic 2FA-style account verification. Demonstrates:
- Form collection across multiple steps
- Status page updates during provisioning
- Toast usage for terminal prompts
- Clean phase transitions

### tutorial (Claude Code)

Conversational canvas tutorial. Demonstrates:
- Freeform exploration (no fixed order)
- Dynamic DSL generation based on questions
- Code + rendered output in same view
- Iterative refinement ("make it blue")

## Creating Your Own

1. Create directory with `.claude/commands/yourcommand.md`
2. Write instructions with canvas-push heredocs and canvas-wait
3. Add `.claude/settings.local.json` for permissions:

```json
{
  "permissions": {
    "allow": [
      "Bash(streamweaver panel:*)",
      "Bash(streamweaver canvas-push:*)",
      "Bash(streamweaver canvas-wait:*)",
      "Bash(streamweaver canvas-toast:*)",
      "Bash(streamweaver canvas-close:*)"
    ]
  }
}
```

4. Run with `/yourcommand` in Claude Code

## Summary

StreamWeaver makes AI agent UI practical:

- **Concise DSL**: 5-7x fewer tokens than HTML/React
- **Rich components**: Forms, charts, tables, status indicators
- **Multiple modes**: Standalone apps to Claude Code canvases
- **Simple patterns**: Push DSL, wait for JSON, repeat

Build what you need to show, not the infrastructure to show it.
