# StreamWeaver Canvas Roadmap

## What is Canvas?

**The Problem:** Agentic AI CLIs like Claude Code are powerful but constrained to text-based terminal interaction. Complex choices, data visualization, code review, and multi-step workflows become walls of text that are hard to parse and interact with.

**The Solution:** A persistent browser canvas that AI agents can push rich HTML/CSS/JS UI to, enabling:
- Visual data display (tables, charts, diffs)
- Interactive forms and wizards
- Clickable choices instead of typing responses
- Real-time progress visualization

**Why Ruby/Phlex?** Token efficiency. Instead of generating verbose HTML, the AI generates concise Ruby DSL:
```ruby
# 45 tokens of Ruby
table headers: ["File", "Size"], rows: data, striped: true
button "Apply Changes", variant: :primary

# vs 200+ tokens of equivalent HTML/CSS
```

### Primary Use Case

**Claude Code Companion** - Side-by-side experience:
- Terminal on left: Claude Code CLI running
- Canvas on right: Rich UI for interaction

When Claude needs user input, instead of:
```
Please choose:
1. PostgreSQL
2. SQLite
3. MySQL
Enter number:
```

It pushes a visual choice UI, user clicks, Claude receives JSON response.

### StreamWeaver Modes: When to Use What

StreamWeaver has multiple modes. Canvas (live sessions) is one of them:

| Mode | Command | Use When |
|------|---------|----------|
| **Standalone** | `streamweaver run app.rb` | Building a complete web app with predefined UI |
| **Server** | `streamweaver serve` | Hosting multiple apps, production deployment |
| **Agentic** | `streamweaver llm` | AI generates UI on-the-fly during conversation |
| **Canvas** | `streamweaver live SESSION` | AI pushes UI during external workflow (e.g., Claude Code) |

**Standalone** - You write the app, user interacts with fixed UI
```ruby
# my_app.rb - predefined screens and flow
text_field :name
button "Submit" do |state|
  # handle submission
end
```

**Agentic** - AI writes the app dynamically based on conversation
```bash
streamweaver llm  # AI generates UI based on chat
```

**Canvas** - External AI agent pushes UI as needed during its workflow
```bash
# Claude Code (or other agent) runs separately
# Pushes to canvas when it needs rich interaction
./exe/streamweaver template wizard mysession '{"steps":[...]}'
```

### When to Use Canvas vs Other Modes

| Scenario | Best Mode | Why |
|----------|-----------|-----|
| Building a dashboard app | Standalone | Fixed UI, known requirements |
| Deploying apps for team | Server | Multi-app hosting, production-ready |
| Chatbot builds custom UI | Agentic | AI controls the whole experience |
| Claude Code needs user input | **Canvas** | AI is running elsewhere, pushes when needed |
| CI/CD wants to show results | **Canvas** | External process pushes status |
| Debug session visualization | **Canvas** | Debugger pushes state as it runs |

### Canvas-Specific Use Cases

| Use Case | Description |
|----------|-------------|
| **Any agentic CLI** | Not Claude-specific - any AI agent can push to canvas |
| **Build dashboards** | Show test results, coverage, build status visually |
| **Code review UI** | Rich diff display with inline comments |
| **Onboarding wizards** | Guide users through project setup |
| **Debug visualizers** | Display data structures, call stacks graphically |
| **Documentation preview** | Live preview of generated docs |
| **Database explorers** | Query results in proper tables |
| **Log viewers** | Filterable, searchable log display |
| **Deployment dashboards** | Multi-environment status at a glance |
| **LLM prompt builders** | Visual prompt construction with previews |

### Design Principles

1. **Token efficient** - Ruby DSL, not verbose HTML
2. **Bidirectional** - Push UI, receive user actions as JSON
3. **Stateless templates** - Each interaction is self-contained
4. **Progressive enhancement** - Works with polling, can upgrade to WebSocket
5. **Browser-native** - No Electron needed, any browser works

## Current State (January 2025)

### Working
- Live sessions with 300ms polling
- 7 templates: wizard, choices, confirm, info, table, code, diff
- Native Phlex table component with styling options
- Smooth CSS transitions between content updates
- Theme support (dashboard, minimal, dark)
- Form submission capture and retrieval

### Limitations
- No real-time streaming (polling only)
- No terminal embedding yet
- Templates require user to have browser open
- No progress updates during long-running Claude tasks

## Future Directions

### 1. Terminal Integration

**Goal:** Side-by-side terminal + canvas experience

**Options explored:**
| Approach | Pros | Cons |
|----------|------|------|
| xterm.js | Full terminal emulator | Complex PTY setup, WebSocket needed |
| tmux capture | Simple, read pane buffer | Polling delay, not true integration |
| ttyd/gotty | Existing tools | External dependency, iframe embed |

**Recommendation:** Start with tmux capture for simplicity, evolve to xterm.js if needed.

### 2. Real-time Progress Updates

**Problem:** Claude can't push updates during thinking/tool execution.

**Explored solutions:**
| Approach | How | Status |
|----------|-----|--------|
| Incremental pushes | Claude pushes between steps | Works, but adds tool calls |
| Status file | Claude writes file, canvas polls | Not implemented |
| Hooks | Claude Code hooks for output events | Unknown feasibility |

**Recommendation:** For now, use incremental pushes. Status file approach is cleaner but requires infrastructure.

### 3. New Templates

**High value:**
- `progress` - Progress bar with status messages (for multi-step tasks)
- `log` - Scrolling log viewer (for build output, test results)
- `file-tree` - Interactive file browser
- `form` - Generic form builder (more flexible than wizard)

**Nice to have:**
- `chart` - Simple charts (bar, line)
- `timeline` - Event timeline display
- `kanban` - Task board view

### 4. WebSocket Support

**Current:** 300ms polling works but isn't true real-time.

**Trade-off:** WebSocket adds complexity (Sinatra needs extra gems like Faye or switching to a different server).

**Recommendation:** Polling is sufficient for current use cases. Revisit if latency becomes an issue.

### 5. Electron/Desktop App

**Idea:** Native app with terminal + canvas side-by-side.

**Benefits:**
- True terminal integration
- No browser tab needed
- Could hook into Claude Code process directly

**Complexity:** High - separate app to maintain.

**Recommendation:** Defer until web-based approach hits limitations.

### 6. VS Code Extension

**Idea:** Webview panel in VS Code alongside terminal.

**Benefits:**
- Developers already in VS Code
- Native integration with editor
- Could leverage VS Code's terminal API

**Complexity:** Medium - VS Code extension API learning curve.

### 7. Better Code Display

**Current:** Basic dark theme code block.

**Improvements:**
- Syntax highlighting (via Prism.js or highlight.js)
- Line number linking
- Diff with inline comments
- Copy button
- Expand/collapse for long code

### 8. Session Persistence

**Current:** Sessions are in-memory, lost on restart.

**Improvement:** Store session state to disk for:
- Resume after service restart
- History of interactions
- Audit trail

### 9. Multi-canvas Support

**Idea:** Multiple named canvases for different purposes:
- `main` - Primary interaction
- `logs` - Continuous log output
- `status` - Persistent status bar

**Implementation:** Already supported via session names, just needs patterns/conventions.

## Architecture Notes

### Why Polling vs WebSocket

Polling at 300ms provides:
- Simpler implementation (plain HTTP)
- Works through proxies/firewalls
- No connection management
- Good enough latency for human interaction

WebSocket would provide:
- True real-time updates
- Lower server load for many clients
- Better for streaming output

### Why Phlex

- Ruby-native templating
- Type-safe HTML generation
- Composable components
- No separate template files

### Template Design Principles

1. **Single command** - Full interaction in one bash call
2. **JSON in, JSON out** - Easy to parse programmatically
3. **Clear state** - Each run starts fresh
4. **Timeout** - Don't hang forever
5. **Sensible defaults** - Work out of the box

## Next Steps (Prioritized)

1. **Dogfood** - Use templates in real agentic workflows
2. **Progress template** - Most requested for long tasks
3. **Syntax highlighting** - Improve code/diff display
4. **Documentation** - More examples, best practices

## Non-Goals (For Now)

- Full IDE replacement
- Complex state management
- Multi-user collaboration
- Mobile support
