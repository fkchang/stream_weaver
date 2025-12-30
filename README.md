# StreamWeaver

**Declarative Ruby DSL for building interactive web UIs with minimal token overhead**

StreamWeaver enables GenAI agents (like Claude Code) and developers to rapidly build interactive web UIs using a declarative Ruby DSL. Perfect for agentic workflows, developer utilities, and rapid prototyping.

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

1. **Smaller generation = faster + cheaper** - The LLM generates a concise DSL instead of verbose HTML/React. Fewer tokens means faster responses and lower costs.

2. **Richer interactions** - Instead of walls of terminal text for complex decisions, spin up an actual UI. What would be 5 pages of back-and-forth becomes one well-designed form.

3. **Data-Only Generation** - Even better: pre-build your StreamWeaver app once, then have the LLM just generate the *data* to feed it. Minimal tokens, maximum speed.

```ruby
# Agent generates just this data:
books = [{ title: "...", author: "...", rating: 5 }, ...]

# Pre-built app renders it:
BookSelectorApp.new(books: books).run_once!
```

</details>

---

## Quick Start

```ruby
require 'stream_weaver'

app "Hello World" do
  header1 "Welcome!"
  text_field :name, placeholder: "Your name"

  button "Submit" do |state|
    puts "Hello, #{state[:name]}!"
  end
end.run!
```

Run with: `ruby my_app.rb`

The browser opens automatically at `http://localhost:4567` (or next available port).

> **Run Multiple Apps Simultaneously** - StreamWeaver automatically finds a free port and opens a browser tab for each app. Run `ruby app1.rb` in one terminal, `ruby app2.rb` in another — no port conflicts, no configuration. Each app gets its own port and browser tab automatically. The URL is printed to stdout so AI agents can read the port for testing.

## Installation

```bash
gem install stream_weaver
```

Or add to your Gemfile:

```ruby
gem 'stream_weaver'
```

## Features

- **Agentic Mode** - Built-in `run_once!` for AI agents to collect user input and return structured data
- **Single-File Apps** - No separate HTML/CSS/JS files, no build step
- **Automatic State Management** - Session-based state with Alpine.js frontend sync
- **Zero Configuration** - Auto port detection, auto browser opening, run multiple apps simultaneously without conflicts
- **Layout Modes** - Configurable container widths (`:default`, `:wide`, `:full`, `:fluid`)
- **Theming** - Built-in themes (`:default`, `:dashboard`, `:document`) + custom theme registration
- **Token Efficient** - 10-50x fewer tokens than HTML/React for GenAI generation
- **Full Markdown Support** - GitHub Flavored Markdown via Kramdown
- **Cross-Platform** - Works on macOS, Linux, Windows

## Examples

```ruby
# Todo List App
app "Todo Manager" do
  header "My Todos"

  text_field :new_todo, placeholder: "What needs to be done?"

  button "Add" do |state|
    state[:todos] ||= []
    state[:todos] << state[:new_todo] if state[:new_todo]
    state[:new_todo] = ""
  end

  state[:todos] ||= []
  state[:todos].each_with_index do |todo, idx|
    div class: "todo-item" do
      text todo
      button "Done", style: :secondary do |state|
        state[:todos].delete_at(idx)
      end
    end
  end
end.run!
```

### Interactive Tutorial

**Start here:** `ruby examples/advanced/tutorial.rb` — A self-documenting, interactive tutorial that teaches StreamWeaver using StreamWeaver itself. Features live demos, editable code panels, and "Run Standalone" to launch your experiments.

### Examples by Category

```
examples/
├── basic/              # Start here
│   ├── hello_world.rb    - Minimal form with conditional rendering
│   └── todo_list.rb      - Full CRUD app with state management
├── agentic/            # AI agent workflows
│   ├── agentic_form.rb   - Simple form collection for agents
│   ├── agentic_form_autoclose.rb - Auto-closing browser variant
│   └── cultivation_tracker.rb    - Real-world daily check-in form
├── components/         # Individual component demos
│   ├── form_demo.rb      - Form blocks with submit/cancel
│   ├── quiz_demo.rb      - Radio groups and validation
│   ├── checkbox_group_demo.rb - Batch selection with select all/none
│   ├── markdown_demo.rb  - GitHub Flavored Markdown
│   ├── lesson_demo.rb    - Educational content with glossary tooltips
│   ├── score_and_collapsible_demo.rb - Score tables, collapsibles
│   └── events_demo.rb    - on_change, on_blur callbacks
├── layout/             # Layout and navigation
│   ├── layout_components_demo.rb - Columns, VStack, HStack, Grid
│   ├── navigation_demo.rb - Tabs, Breadcrumbs, Dropdowns
│   └── modal_demo.rb     - Modal dialogs
├── styling/            # Themes and feedback
│   ├── theme_demo.rb     - Built-in theme switching
│   ├── style_showcase.rb - Component styling showcase
│   └── feedback_demo.rb  - Alerts, Toasts, Progress, Spinners
└── advanced/           # Full applications
    ├── tutorial.rb       - Interactive tutorial (start here!)
    ├── all_components.rb - Comprehensive component gallery
    ├── theme_tweaker.rb  - Visual theme editor with export
    └── teachables_browser.rb - Educational content browser
```

## Agentic Mode

For AI agents to collect user input and return structured data:

```ruby
result = app "Survey" do
  header "Quick Survey"
  text_field :name
  select :priority, ["Low", "Medium", "High"]
end.run_once!

# Returns: { "name" => "Alice", "priority" => "High" }
```

With auto-close (browser closes after submit):

```ruby
result = app "Quick Form" do
  text_field :data
end.run_once!(auto_close_window: true)
```

## Components

### Text Display

```ruby
text "Literal text - **asterisks** stay as asterisks"
md "**Bold**, *italic*, `code`, and [links](url) are parsed"
```

The `md` component supports full GitHub Flavored Markdown: bold, italic, strikethrough, lists, tables, code blocks, blockquotes, and more.

### Headers

```ruby
header "Section Title"    # <h2> - default
header1 "Page Title"      # <h1>
header2 "Section"         # <h2>
header3 "Subsection"      # <h3>
header4 "Minor"           # <h4>
header5 "Small"           # <h5>
header6 "Smallest"        # <h6>
```

### Form Inputs

```ruby
text_field :name, placeholder: "Enter name"
text_area :bio, placeholder: "Bio", rows: 5
checkbox :agree, "I accept the terms"
select :color, ["Red", "Green", "Blue"], default: "Green"
radio_group :size, ["Small", "Medium", "Large"]

# Checkbox group with select all/none (for batch operations)
checkbox_group :selected, select_all: "Select All", select_none: "Clear" do
  item "item_1" do
    text "First item"
  end
  item "item_2" do
    text "Second item"
  end
end
# state[:selected] = ["item_1", "item_2", ...] (array of selected values)
```

### Buttons

```ruby
button "Primary" do |state|
  state[:clicked] = true
end

button "Secondary", style: :secondary do |state|
  # secondary styling
end
```

### Layout

```ruby
div class: "my-class" do
  text "Nested content"
end

card do
  header3 "Card Title"
  text "Styled container"
end

collapsible "Show Details" do
  text "Hidden content revealed on click"
end

# Multi-column layouts
columns widths: ['30%', '70%'] do
  column do
    header4 "Sidebar"
    text "Narrow column"
  end
  column do
    text "Main content area"
  end
end

# Vertical/Horizontal stacking
vstack spacing: :md do
  text "Item 1"
  text "Item 2"
end

hstack spacing: :sm, justify: :between do
  button "Cancel", style: :secondary
  button "Save"
end

# Responsive grid (1 col mobile, 2 tablet, 3 desktop)
grid columns: [1, 2, 3], gap: :md do
  items.each { |item| card { text item.name } }
end

# Deferred submission forms
form :edit_user do
  text_field :name
  text_field :email
  submit "Save" do |form_values|
    save_user(form_values)
  end
  cancel "Cancel"
end
```

### Navigation

```ruby
# Tabs with persistent state
tabs :settings do
  tab "General" do
    text_field :name
  end
  tab "Advanced" do
    checkbox :debug, "Debug mode"
  end
end

# Breadcrumbs
breadcrumbs do
  crumb "Home", href: "/"
  crumb "Products", href: "/products"
  crumb "Details"  # Current page
end

# Dropdown menu
dropdown do
  trigger { button "Actions" }
  menu do
    menu_item "Edit" { |s| s[:editing] = true }
    menu_divider
    menu_item "Delete", style: :destructive { |s| s[:items].pop }
  end
end
```

### Modals

```ruby
button "Open Modal" do |s|
  s[:confirm_open] = true
end

modal :confirm, title: "Confirm Action", size: :sm do
  text "Are you sure?"
  modal_footer do
    button "Cancel", style: :secondary do |s|
      s[:confirm_open] = false
    end
    button "Confirm" do |s|
      # action
      s[:confirm_open] = false
    end
  end
end
```

### Feedback

```ruby
# Alerts
alert(variant: :success, title: "Saved!") { text "Changes saved." }
alert(variant: :warning, dismissible: true) { text "Session expiring." }

# Toast notifications
toast_container position: :top_right
button "Save" do |s|
  show_toast("Saved!", variant: :success)
end

# Progress bar
progress_bar value: 75, show_label: true, variant: :success

# Spinner
spinner size: :md, label: "Loading..."
```

### Advanced Components

```ruby
# Score table with color-coded metrics
score_table scores: [
  { label: "Quality", value: 8, max: 10 },
  { label: "Impact", value: 5, max: 10 }
]

# Educational content with glossary tooltips
lesson_text "Learn about {terms} here.", glossary: {
  "terms" => { simple: "Key concepts", detailed: "Longer explanation..." }
}

# Status badges for match indicators
status_badge :strong, "Perfect match for your preferences"
status_badge :maybe, "Good fit, but has some concerns"
status_badge :skip, "Not recommended"

# Tag buttons for quick selection (single-select)
tag_buttons :category, ["Fiction", "Non-fiction", "Mystery"]
tag_buttons :reason, ["Too dark", "Wrong genre"], style: :destructive

# External link button (opens URL, optionally submits form first)
external_link_button "View on Amazon", url: "https://amazon.com/dp/B0XXX"
external_link_button "Select & Open", url: "https://example.com", submit: true
```

## API Reference

### `app(title, layout:, &block)`

Create an application with optional layout mode:

```ruby
app "My App" do                       # Default 900px container
  # components...
end

app "Dashboard", layout: :wide do     # 1100px container
  # components...
end

# Layout options: :default (900px), :wide (1100px), :full (1400px), :fluid (100%)
```

### Theming

```ruby
# Use built-in themes
app "Dashboard", theme: :dashboard do    # Data-dense theme
  # components...
end

app "Document", theme: :document do      # Reading-optimized theme
  # components...
end

# Register custom themes
StreamWeaver.register_theme :corporate, {
  color_primary: "#0066cc",
  font_family: "'Inter', system-ui, sans-serif",
  spacing_md: "1rem"
}, base: :dashboard, label: "Corporate", description: "Brand theme"

app "My App", theme: :corporate do
  # components...
end

# Runtime theme switching
app "App" do
  theme_switcher  # Dropdown to switch themes live
end
```

**Built-in themes:**
- `:default` - Warm Industrial (Source Sans 3, 17px, generous spacing)
- `:dashboard` - Data Dense (15px font, tighter spacing, minimal accents)
- `:document` - Reading Mode (Crimson Pro serif, 19px, paper background)

### `run!(options)`

Start persistent server:

```ruby
App.run!                              # Auto port, auto-open browser
App.run!(port: 8080)                  # Custom port
App.run!(host: '0.0.0.0')             # Network access
App.run!(open_browser: false)         # Don't open browser
```

### `run_once!(options)`

Run once, collect data, return and quit:

```ruby
result = App.run_once!
result = App.run_once!(timeout: 120)
result = App.run_once!(auto_close_window: true)
```

## Contributing

Contributions welcome! See [GitHub repository](https://github.com/fkchang/stream_weaver).

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
