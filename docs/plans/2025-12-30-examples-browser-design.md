# Examples Browser Design

## Overview

An interactive Examples Browser app that showcases StreamWeaver examples, built with StreamWeaver itself. Features directory navigation, syntax-highlighted code display, and ability to run examples.

## Goals

1. **Phase 1 (MVP):** Browse and run examples with read-only code display
2. **Phase 2:** Edit code and run modified versions

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Examples Browser                      │
├──────────────┬──────────────────────────────────────────┤
│   Sidebar    │              Main Area                    │
│              │  ┌────────────────────────────────────┐  │
│  📁 basic/   │  │  Code Panel (CodeMirror 5)         │  │
│    hello_wo  │  │  ┌──────────────────────────────┐  │  │
│    todo_lis  │  │  │ require 'stream_weaver'      │  │  │
│  📁 agentic/ │  │  │                              │  │  │
│    ...       │  │  │ app "Hello" do               │  │  │
│              │  │  │   text_field :name           │  │  │
│              │  │  └──────────────────────────────┘  │  │
│              │  │  [▶ Run]  [✓ Check Syntax]         │  │
│              │  └────────────────────────────────────┘  │
└──────────────┴──────────────────────────────────────────┘
```

## State Structure

```ruby
state[:selected_dir]      # Currently expanded directory
state[:selected_file]     # Full path to selected file
state[:code_content]      # File content (or edited content in phase 2)
state[:error_message]     # Syntax error from ruby -c
state[:error_modal_open]  # Show/hide error modal
state[:running_pid]       # Track spawned process for cleanup
```

## New Component: `code_editor`

Added to core StreamWeaver for reusability.

### Usage

```ruby
# Read-only (phase 1)
code_editor :code_content, language: :ruby, readonly: true, height: "500px"

# Editable (phase 2)
code_editor :code_content, language: :ruby, readonly: false
```

### Implementation Details

- Renders `<div>` with `hx-preserve="true"` to survive HTMX swaps
- Contains hidden `<textarea>` bound to state key
- Emits initialization JS for CodeMirror instance
- Single instance pattern: `window.cmEditor` persists across navigation

### CDN Dependencies (CodeMirror 5)

```ruby
stylesheets: [
  "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css"
]
scripts: [
  "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js",
  "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/ruby/ruby.min.js"
]
```

### HTMX Integration Strategy

**Challenge:** CodeMirror creates complex DOM that HTMX can orphan/duplicate.

**Solution:**
1. Use `hx-preserve="true"` on editor container
2. Update content via JS: `window.cmEditor.setValue(newContent)`
3. Initialize once on DOMContentLoaded, not on HTMX swaps

## Interactions

### Run Flow

1. User clicks "Run"
2. System runs `ruby -c` on content for syntax check
3. If error: Parse message, show error modal
4. If OK: Write temp file to `/tmp/sw_example_*.rb`
5. Spawn process: `ruby /tmp/sw_example_*.rb`
6. Track PID for cleanup
7. Show success toast

### Error Modal

```
┌─────────────────────────────────────┐
│  ❌ Syntax Error                    │
├─────────────────────────────────────┤
│  Line 5: syntax error, unexpected   │
│  end-of-input, expecting `end'      │
│                          [Close]    │
└─────────────────────────────────────┘
```

### Cleanup

`at_exit` hook kills spawned PIDs (matches tutorial.rb pattern).

## File Structure

```
lib/stream_weaver/
├── components.rb          # Add CodeEditor class
├── adapter/
│   └── alpinejs.rb        # Add render_code_editor method
└── views.rb               # Add CodeMirror CSS

examples/
└── advanced/
    └── examples_browser.rb
```

## Implementation Plan

### Phase 1: Core Component + MVP Browser

1. Add `CodeEditor` component to `components.rb`
2. Add `render_code_editor` to AlpineJS adapter
3. Add CodeMirror initialization JS
4. Build `examples_browser.rb`:
   - Directory discovery
   - Sidebar navigation
   - Code display (read-only)
   - Run button with syntax check
   - Error modal

### Phase 2: Editing Support

1. Enable `readonly: false` mode
2. Sync edited content back to state
3. Track "modified" state
4. "Run Modified" writes temp file
5. "Reset" button restores original

## Inspiration

- [Glimmer meta_example.rb](https://github.com/AndyObtiva/glimmer-dsl-libui/blob/master/examples/meta_example.rb) - Example discovery, categorization, launch pattern
- StreamWeaver tutorial.rb - Process spawning, PID tracking, temp file approach
