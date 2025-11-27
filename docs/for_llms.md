# StreamWeaver - LLM Reference Guide

StreamWeaver is a Ruby DSL for building reactive web UIs with minimal code. Think "Streamlit for Ruby" - declarative, state-driven, and instantly runnable.

## Quick Start

```ruby
require 'stream_weaver'

app "My App" do
  text_field :name, placeholder: "Your name"

  if state[:name] && !state[:name].empty?
    text "Hello, #{state[:name]}!"
  end
end.run!
```

Run with `ruby my_app.rb` and open `http://localhost:4567`.

## Core Concepts

### 1. The `app` Block
Everything lives inside an `app` block. The block is re-evaluated on every state change, enabling reactive UI.

```ruby
app "Title" do
  # Components go here
  # Access state via state[:key]
end
```

### 2. State
State is a hash accessed via `state[:key]`. Components automatically bind to state keys. State persists across re-renders.

```ruby
app "Counter" do
  button "Increment" do |state|
    state[:count] ||= 0
    state[:count] += 1
  end

  text "Count: #{state[:count] || 0}"
end
```

### 3. Conditional Rendering
Since the block re-evaluates on state change, use normal Ruby conditionals:

```ruby
app "Login" do
  if state[:logged_in]
    text "Welcome back!"
    button "Logout" { |s| s[:logged_in] = false }
  else
    text_field :username
    button "Login" { |s| s[:logged_in] = true }
  end
end
```

## Components Reference

### Text Display

```ruby
text "Plain paragraph"           # Literal text - what you type is what you get
text "Value: #{state[:value]}"   # String interpolation works
```

### Headers

```ruby
header "Section Title"    # <h2> - default header level
header1 "Page Title"      # <h1>
header2 "Section"         # <h2>
header3 "Subsection"      # <h3>
header4 "Minor Section"   # <h4>
header5 "Sub-subsection"  # <h5>
header6 "Smallest"        # <h6>
```

### Markdown Content

```ruby
md "**Bold**, *italic*, and `code`"    # Full markdown parsing
md "## Headers work too"               # Headers within markdown blocks
markdown "Same as md"                  # Alias for md

# Supported markdown:
# - **bold** → <strong>
# - *italic* → <em>
# - `code` → <code>
# - [link](url) → <a href="url">link</a>
# - ## headers → <h2>
```

### Text Input

```ruby
text_field :key, placeholder: "Hint text"
text_area :key, placeholder: "Multi-line", rows: 5
```

### Selection

```ruby
# Dropdown
select :color, ["Red", "Green", "Blue"]

# Dropdown with default value
select :priority, ["Low", "Medium", "High"], default: "Medium"

# Radio buttons (all options visible)
radio_group :answer, ["Option A", "Option B", "Option C"]
```

### Boolean

```ruby
checkbox :agree, "I accept the terms"
# state[:agree] will be true/false
```

### Checkbox Group (Multi-Select with Select All/None)

```ruby
# For batch selection (e.g., emails, files, items)
checkbox_group :selected_items, select_all: "Select All", select_none: "Clear" do
  items.each do |item|
    item item.id do
      text item.name
      # Any components can be nested here
    end
  end
end
# state[:selected_items] = ["id1", "id3", ...] (array of selected values)
```

### Buttons

```ruby
button "Primary" do |state|
  # Action when clicked
  state[:clicked] = true
end

button "Secondary", style: :secondary do |state|
  # Secondary styling
end
```

### Layout Containers

```ruby
# Generic div
div class: "my-class" do
  text "Nested content"
  text_field :nested_field
end

# Card (styled container)
card do
  header3 "Card Title"
  text "Card content here"
end

card class: "custom-card" do
  # Additional CSS class
end
```

### Collapsible Sections

Expandable/collapsible content sections with click-to-toggle:

```ruby
# Collapsed by default
collapsible "Show Details" do
  text "Hidden content revealed on click"
  text "Can contain any components"
end

# Start expanded
collapsible "View Context (127 words)", expanded: true do
  text "This content is visible initially"
end
```

### Score Table

Display metrics with color-coded scores and interpretations:

```ruby
score_table scores: [
  { label: "Novelty", value: 8, max: 10 },
  { label: "Quality", value: 5, max: 10 },
  { label: "Impact", value: 3, max: 10 }
]
```

Renders a table with Metric | Score | Meaning columns:
- **Green** (score-high): ratio >= 70%
- **Yellow** (score-medium): ratio 40-69%
- **Red** (score-low): ratio < 40%

Interpretations: Excellent (>=80%), Strong (>=70%), Moderate (>=50%), Weak (<50%)

### Educational Content (Glossary/Tooltips)

For interactive educational content with hoverable term definitions:

```ruby
glossary = {
  "term" => {
    simple: "Short definition shown on hover",
    detailed: "Longer explanation shown on tap/click"
  },
  "another term" => { simple: "...", detailed: "..." }
}

# Block syntax - explicit phrase/term
lesson_text glossary: glossary do
  phrase "This sentence has a "
  term "term"
  phrase " that users can hover."
end

# String syntax - terms in {braces}
lesson_text "This has a {term} and {another term}.", glossary: glossary
```

## Running Modes

### Interactive Mode (Default)
Server runs continuously, UI updates reactively:

```ruby
app "My App" do
  # ...
end.run!
```

### Agentic Mode
For AI agents - collect form data and return as JSON:

```ruby
result = app "Survey" do
  text_field :name
  select :priority, ["Low", "Medium", "High"]
end.run_once!

# Blocks until user submits, then returns hash:
# { "name" => "Alice", "priority" => "High" }
puts result.inspect
```

With auto-close (browser tab closes after submit):

```ruby
result = app "Quick Form" do
  text_field :data
end.run_once!(auto_close_window: true)
```

## CSS Customization

### CSS Variables
Override theme via CSS custom properties:

```css
:root {
  --sw-color-primary: #10b981;      /* Change primary color */
  --sw-font-family: "My Font";       /* Change font */
  --sw-radius-md: 4px;               /* Less rounded corners */
}
```

Key variables:
- `--sw-color-primary`, `--sw-color-secondary` - Button/accent colors
- `--sw-color-text`, `--sw-color-text-muted` - Text colors
- `--sw-color-bg`, `--sw-color-bg-card` - Backgrounds
- `--sw-font-family`, `--sw-font-size-base` - Typography
- `--sw-spacing-sm/md/lg/xl` - Spacing scale
- `--sw-radius-sm/md/lg` - Border radius

### Embedded Mode
When embedding in existing app (Rails, Sinatra), add `sw-embedded` class to body to disable container styling.

## Patterns

### Form with Validation

```ruby
app "Contact Form" do
  text_field :email, placeholder: "Email"
  text_area :message, placeholder: "Your message"

  # Simple validation
  valid = state[:email]&.include?("@") && state[:message]&.length.to_i > 10

  if valid
    button "Send" do |s|
      # Send the message
      s[:sent] = true
    end
  else
    text "Please enter valid email and message (10+ chars)"
  end

  text "Message sent!" if state[:sent]
end
```

### Quiz/Assessment

```ruby
app "Quiz" do
  card do
    header3 "Question 1"
    radio_group :q1, ["Answer A", "Answer B", "Answer C"]
  end

  card do
    header3 "Question 2"
    radio_group :q2, ["True", "False"]
  end

  if state[:q1] && state[:q2]
    button "Submit" do |s|
      s[:score] = calculate_score(s)
    end

    text "Score: #{state[:score]}" if state[:score]
  end
end
```

### Dynamic Lists

```ruby
app "Todo List" do
  text_field :new_item, placeholder: "New todo"

  button "Add" do |s|
    s[:todos] ||= []
    s[:todos] << s[:new_item] if s[:new_item]&.strip != ""
    s[:new_item] = ""
  end

  state[:todos]&.each_with_index do |todo, i|
    div class: "todo-item" do
      text todo
      button "Delete", style: :secondary do |s|
        s[:todos].delete_at(i)
      end
    end
  end
end
```

## Architecture Notes

- **Backend**: Sinatra server, Phlex for HTML generation
- **Frontend**: Alpine.js for reactivity, HTMX for server communication
- **State**: Server-side, persisted in session
- **Updates**: HTMX swaps `#app-container` innerHTML on state changes

## File Structure

```
my_app.rb           # Your app code
lib/stream_weaver/
  app.rb            # DSL methods (text_field, button, etc.)
  components.rb     # Component classes
  adapter/
    alpinejs.rb     # Alpine.js/HTMX rendering
  views.rb          # Phlex views + CSS
  server.rb         # Sinatra routes
```

## Common Mistakes

1. **Forgetting state is a hash** - Access with `state[:key]`, not `state.key`
2. **Mutating state outside button blocks** - State changes should happen in button actions
3. **Missing run!** - App won't start without `.run!` or `.run_once!`
4. **Glossary key mismatch** - Term keys must match glossary keys exactly (case-sensitive)
