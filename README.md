# StreamWeaver

**Declarative Ruby DSL for building interactive web UIs with minimal token overhead**

StreamWeaver enables GenAI agents (like Claude Code) and developers to rapidly build interactive web UIs using a declarative Ruby DSL. Perfect for agentic workflows, developer utilities, and rapid prototyping.

## 🚀 Quick Start

```ruby
require 'stream_weaver'

app "Hello World" do
  text_field :name, placeholder: "Your name"
  
  button "Submit" do |state|
    puts "Hello, #{state[:name]}!"
  end
end.run!
```

Run with: `ruby my_app.rb`

The browser opens automatically at `http://localhost:4567` (or next available port).

## 💎 Installation

```bash
gem install stream_weaver
```

Or add to your Gemfile:

```ruby
gem 'stream_weaver'
```

## ✨ Features

- **🤖 Agentic Mode** - Built-in `run_once!` for AI agents to collect user input and return structured data
- **📦 Single-File Apps** - No separate HTML/CSS/JS files, no build step
- **🔄 Automatic State Management** - Session-based state with Alpine.js frontend sync
- **🎨 Zero Configuration** - Auto port detection, browser opening, graceful shutdown
- **⚡ Token Efficient** - 10-50x fewer tokens than HTML/React for GenAI generation
- **🧩 Component-Based** - 6 MVP components (TextField, Button, Text, Div, Checkbox, Select)
- **🌐 Cross-Platform** - Works on macOS, Linux, Windows

## 📖 Examples

```ruby
# Todo List App
app "Todo Manager" do
  text "## 📝 My Todos"
  
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
      button "✓", style: :secondary do |state|
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
- `agentic_form.rb` - Agentic mode demo

## 🤖 Agentic Mode

For AI agents to collect user input and return structured data:

```ruby
result = app "Survey" do
  text_field :name
  select :priority, ["Low", "High"]
  button "Submit"
end.run_once!

# Returns: { name: "Alice", priority: "High" }
```

Perfect for Claude Code integration - **10-50x fewer tokens than HTML!**

## 📚 Components

### Input Components
- `text_field(key, **options)` - Single-line text input
- `checkbox(key, label)` - Boolean checkbox
- `select(key, choices)` - Dropdown selection

### Action Components
- `button(label, style:, &block)` - Execute Ruby on click

### Display Components
- `text(content)` - Display text (supports interpolation)
- `div(class:, &block)` - Container with nested components

## 🔧 API Reference

### `run!(options)`

Start persistent server:

```ruby
App.run!                              # Auto port, auto-open browser
App.run!(port: 8080)                  # Custom port
App.run!(host: '0.0.0.0')            # Network access
App.run!(open_browser: false)         # Don't open browser
```

### `run_once!(options)` 🤖

Run once, collect data, return and quit:

```ruby
result = App.run_once!
result = App.run_once!(timeout: 120)
result = App.run_once!(output_file: "data.json")
```

## 🗺️ Roadmap

- **v0.1.0** (Current): Core DSL, 6 components, agentic mode
- **v0.2.0+**: Extended components (text_area, file_uploader, code highlighting)
- **v0.3.0+**: Rich display (dataframe, charts, markdown)
- **v1.0.0+**: Production features, custom styling, auto-reload

## 🤝 Contributing

Contributions welcome! See [GitHub repository](https://github.com/fkchang/stream_weaver).

## 📜 License

MIT License - see [LICENSE.txt](LICENSE.txt)

---

**Built with ❤️ for GenAI agents and Ruby developers**
