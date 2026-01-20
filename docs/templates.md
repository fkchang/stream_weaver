# StreamWeaver Templates

Templates provide pre-built UI patterns for common interactions. Each template is a single command that handles the full interaction flow and returns JSON.

## Quick Reference

| Template | Purpose | Returns |
|----------|---------|---------|
| `wizard` | Multi-step forms with branching | All collected fields |
| `choices` | Pick one from options | `{"choice": "Selected"}` |
| `confirm` | Yes/No decision | `{"confirmed": true/false}` |
| `info` | Show message + pick action | `{"action": "Clicked"}` |
| `table` | Display data, optional selection | `{"action": "OK"}` or `{"selected_row": N}` |
| `code` | Show code with line numbers | `{"action": "Apply/Cancel"}` |
| `diff` | Show changes with highlighting | `{"action": "Apply/Reject"}` |

## For LLMs

### Basic Usage Pattern

```bash
# All templates follow this pattern:
./exe/streamweaver template <name> <session> '<json-config>'

# Returns JSON on stdout when user completes interaction
```

### Wizard - Multi-step Forms

```bash
# Linear wizard (steps in order)
./exe/streamweaver template wizard test '{
  "title": "Project Setup",
  "steps": [
    {"title": "Info", "fields": [
      {"type": "text", "key": "name", "label": "Project name"},
      {"type": "select", "key": "type", "label": "Type", "options": ["Web", "CLI", "API"]}
    ]},
    {"title": "Options", "fields": [
      {"type": "checkbox", "key": "tests", "label": "Include tests"},
      {"type": "checkbox", "key": "ci", "label": "CI/CD"}
    ]}
  ]
}'
# Returns: {"name": "MyApp", "type": "Web", "tests": true, "ci": false}
```

```bash
# Branching wizard (different paths based on choices)
./exe/streamweaver template wizard test '{
  "title": "Setup",
  "steps": [
    {"id": "type", "title": "Type", "fields": [
      {"type": "select", "key": "project_type", "options": ["Web", "CLI"]}
    ], "next": {"branch_on": "project_type", "Web": "web_opts", "CLI": "cli_opts"}},
    {"id": "web_opts", "title": "Web Options", "fields": [
      {"type": "select", "key": "framework", "options": ["React", "Vue"]}
    ], "next": "done"},
    {"id": "cli_opts", "title": "CLI Options", "fields": [
      {"type": "select", "key": "cli_lib", "options": ["Thor", "Commander"]}
    ], "next": "done"}
  ]
}'
```

**Field types:**
- `text` - Text input
- `select` - Dropdown selection
- `checkbox` - Boolean toggle

### Choices - Quick Selection

```bash
./exe/streamweaver template choices test '{
  "title": "Select Database",
  "description": "Which database for this project?",
  "options": ["PostgreSQL", "SQLite", "MySQL"]
}'
# Returns: {"choice": "PostgreSQL"}
```

### Confirm - Yes/No

```bash
./exe/streamweaver template confirm test '{
  "title": "Delete files?",
  "message": "This will permanently remove 3 files.",
  "yes": "Delete",
  "no": "Cancel"
}'
# Returns: {"confirmed": true} or {"confirmed": false}
```

### Info - Message with Actions

```bash
./exe/streamweaver template info test '{
  "title": "Build Complete",
  "message": "All tests passed",
  "details": ["12 specs", "Coverage: 94%"],
  "actions": ["Deploy", "View Report", "Close"]
}'
# Returns: {"action": "Deploy"}
```

### Table - Data Display

```bash
./exe/streamweaver template table test '{
  "title": "Recent Files",
  "headers": ["File", "Size", "Modified"],
  "rows": [
    ["app.rb", "12kb", "2 hours ago"],
    ["cli.rb", "8kb", "yesterday"]
  ]
}'
# Returns: {"action": "OK"}

# With row selection:
./exe/streamweaver template table test '{
  "title": "Select File",
  "headers": ["File", "Size"],
  "rows": [["app.rb", "12kb"], ["cli.rb", "8kb"]],
  "selectable": true
}'
# Returns: {"selected_row": 0, "selected_data": ["app.rb", "12kb"]}
```

### Code - Code Display

```bash
./exe/streamweaver template code test '{
  "title": "Generated Code",
  "filename": "hello.rb",
  "code": "def hello\n  puts \"Hello\"\nend",
  "actions": ["Apply", "Edit", "Cancel"]
}'
# Returns: {"action": "Apply"}
```

### Diff - Change Display

```bash
./exe/streamweaver template diff test '{
  "title": "Proposed Changes",
  "filename": "app.rb",
  "diff": "- old line\n+ new line\n  context",
  "actions": ["Apply", "Reject"]
}'
# Returns: {"action": "Apply"}
```

## For Humans

### Architecture

Templates are Ruby classes in `lib/stream_weaver/templates/` that:
1. Push UI to a live session
2. Wait for user interaction
3. Return collected data as JSON

Each template clears stale submissions on start and uses unique field IDs to prevent browser autocomplete issues.

### Adding New Templates

1. Create `lib/stream_weaver/templates/your_template.rb`
2. Inherit common patterns from existing templates
3. Add to CLI in `lib/stream_weaver/cli.rb` (search for `when 'wizard'`)

### Native DSL Components

Templates can use StreamWeaver's DSL directly:

```ruby
# In template build_dsl method:
lines << "header2 \"Title\""
lines << "table headers: [\"A\", \"B\"], rows: [[\"1\", \"2\"]], striped: true"
lines << "button \"Submit\""
```

### Available Table Options

```ruby
table headers: [...], rows: [...],
  striped: true,    # Zebra stripes
  bordered: true,   # Cell borders
  hoverable: true,  # Highlight on hover
  compact: true,    # Reduced padding
  caption: "Title"  # Table caption
```

## Session Management

```bash
# Start a live session
./exe/streamweaver live mysession

# Push content
./exe/streamweaver push mysession --dsl 'text "Hello"'

# Wait for submission (blocks)
./exe/streamweaver wait mysession --timeout 60

# Run template (combines push + wait)
./exe/streamweaver template wizard mysession '{...}'
```

## Tips

1. **Single command = no permission prompts** - Templates handle the full flow in one bash call
2. **JSON escaping** - Use single quotes around JSON to avoid shell escaping issues
3. **Timeout** - Templates default to 300s timeout; user must interact within this window
4. **Browser** - User needs the live session open at `http://localhost:PORT/live/SESSION`
