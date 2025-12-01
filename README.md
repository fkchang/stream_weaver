# StreamWeaver

**Declarative Ruby DSL for building interactive web UIs with minimal token overhead**

StreamWeaver enables GenAI agents (like Claude Code) and developers to rapidly build interactive web UIs using a declarative Ruby DSL. Perfect for agentic workflows, developer utilities, and rapid prototyping.

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
- **Zero Configuration** - Auto port detection, browser opening, graceful shutdown
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

See `examples/` directory for more:
- `hello_world.rb` - Basic form
- `todo_list.rb` - Full CRUD app
- `all_components.rb` - Component showcase
- `checkbox_group_demo.rb` - Batch selection with select all/none
- `markdown_demo.rb` - Full GFM markdown demo
- `agentic_form.rb` - Agentic mode demo

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

collapsible "Expanded Section", expanded: true do
  text "Visible initially"
end
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
