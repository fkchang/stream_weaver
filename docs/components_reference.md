# StreamWeaver Components Reference

Complete reference for all StreamWeaver components. For quick usage, see the main `llms.txt`.

## Text Display

```ruby
text "Plain paragraph"           # Literal text - what you type is what you get
text "Value: #{state[:value]}"   # String interpolation works
```

## Headers

```ruby
header "Section Title"    # <h2> - default header level
header1 "Page Title"      # <h1>
header2 "Section"         # <h2>
header3 "Subsection"      # <h3>
header4 "Minor Section"   # <h4>
header5 "Sub-subsection"  # <h5>
header6 "Smallest"        # <h6>
```

## Markdown Content

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

## Text Input

```ruby
text_field :key, placeholder: "Hint text"
text_area :key, placeholder: "Multi-line", rows: 5

# Disable auto-submit (for display-only or manual submission)
text_field :key, placeholder: "Edit me", submit: false
```

## Selection

```ruby
# Dropdown
select :color, ["Red", "Green", "Blue"]

# Dropdown with default value
select :priority, ["Low", "Medium", "High"], default: "Medium"

# Radio buttons (all options visible)
radio_group :answer, ["Option A", "Option B", "Option C"]

# Disable auto-submit
select :role, ["Admin", "User"], submit: false
```

## Boolean

```ruby
checkbox :agree, "I accept the terms"
# state[:agree] will be true/false

# Disable auto-submit
checkbox :preview_flag, "Show preview", submit: false
```

## Checkbox Group (Multi-Select with Select All/None)

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

## Buttons

```ruby
button "Primary" do |state|
  # Action when clicked
  state[:clicked] = true
end

button "Secondary", style: :secondary do |state|
  # Secondary styling
end

# Display-only button (no server request, for previews)
button "Preview Button", submit: false
button "Cancel", style: :secondary, submit: false
```

## Layout Containers

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

# Structured card with header, body, footer
card do
  card_header "Card Title"
  card_body do
    text "Main content goes here"
    text_field :field
  end
  card_footer do
    button "Cancel", style: :secondary
    button "Save"
  end
end
```

## Stacking Layouts (VStack / HStack)

```ruby
# Vertical stack with spacing
vstack spacing: :lg do
  text "Item 1"
  text "Item 2"
  text "Item 3"
end

# VStack with dividers between items
vstack spacing: :md, divider: true do
  text "Item with divider below"
  text "Another item"
end

# Horizontal stack
hstack spacing: :md, align: :center do
  button "Action 1"
  button "Action 2", style: :secondary
end

# HStack with justify (spread content)
hstack justify: :between do
  text "Left"
  text "Right"
end
```

Spacing options: `:xs`, `:sm`, `:md`, `:lg`, `:xl`
Align options: `:start`, `:center`, `:end`
Justify options (hstack only): `:start`, `:center`, `:end`, `:between`, `:around`

## Grid Layouts

```ruby
# Fixed 3-column grid
grid columns: 3, gap: :md do
  card { text "Item 1" }
  card { text "Item 2" }
  card { text "Item 3" }
end

# Responsive grid: 1 col mobile, 2 tablet, 3 desktop
grid columns: [1, 2, 3], gap: :lg do
  items.each do |item|
    card { text item.name }
  end
end
```

## Columns (Multi-Column Layout)

```ruby
# Equal-width columns (default)
columns do
  column do
    text "Left column"
  end
  column do
    text "Right column"
  end
end

# Custom widths (sidebar + main content)
columns widths: ['30%', '70%'] do
  column do
    header4 "Sidebar"
    text "Navigation here"
  end
  column do
    header4 "Main Content"
    text "Primary content here"
  end
end

# Custom gap between columns
columns gap: "2rem" do
  column { text "More space" }
  column { text "Between columns" }
end
```

Columns stack vertically on mobile (< 768px) for responsive design.

## Collapsible Sections

```ruby
# Collapsed by default
collapsible "Show Details" do
  text "Hidden content revealed on click"
  text "Can contain any components"
end

# Start expanded
collapsible "View Context", expanded: true do
  text "This content is visible initially"
end
```

## Form Blocks (Deferred Submission)

Group multiple form elements for batch editing. Fields use client-side only state until submit.

```ruby
form :edit_person do
  text_field :name, placeholder: 'Name'
  select :status, %w[active paused archived]
  text_area :notes, placeholder: 'Notes...', rows: 3

  submit 'Save' do |form_values|
    # form_values = { name: "...", status: "...", notes: "..." }
    # state[:edit_person] already updated at this point
    api.save_person(form_values)  # optional side effects
  end

  cancel 'Cancel'  # resets to original values, no server request
end
```

**Key behaviors:**
- State stored as nested hash: `state[:edit_person][:name]` (Rails-style)
- Form reads initial values from `state[:form_name]`
- On submit: state auto-updates, THEN submit block runs
- On cancel: Alpine.js resets to original values (client-side)

## Tabs

```ruby
tabs :settings_tabs do
  tab "General" do
    text_field :app_name
    checkbox :dark_mode, "Enable dark mode"
  end

  tab "Notifications" do
    checkbox :email_notifications, "Email notifications"
  end
end
# state[:settings_tabs] = 0 (active tab index)
```

Tab variants:
```ruby
tabs :demo, variant: :line do ... end        # Underline (default)
tabs :demo, variant: :enclosed do ... end    # Boxed tabs
tabs :demo, variant: :"soft-rounded" do ... end  # Pill-style
```

## Breadcrumbs

```ruby
breadcrumbs do
  crumb "Home", href: "/"
  crumb "Products", href: "/products"
  crumb "Current"  # No href = current page
end

# Custom separator
breadcrumbs separator: ">" do
  crumb "Dashboard", href: "/dashboard"
  crumb "Settings"
end
```

## Dropdown Menu

```ruby
dropdown do
  trigger do
    button "Actions"
  end

  menu do
    menu_item "Edit" do |s|
      s[:editing] = true
    end
    menu_item "Duplicate" do |s|
      s[:items] << s[:items].last.dup
    end
    menu_divider
    menu_item "Delete", style: :destructive do |s|
      s[:items].pop
    end
  end
end
```

## Modal Dialogs

```ruby
# Open modal via button
button "Open Settings" do |s|
  s[:settings_open] = true
end

# Define modal (state key is :{name}_open)
modal :settings, title: "Settings", size: :md do
  text_field :setting_value
  text "Configure your preferences here."

  modal_footer do
    button "Cancel", style: :secondary do |s|
      s[:settings_open] = false
    end
    button "Save" do |s|
      # save logic
      s[:settings_open] = false
    end
  end
end
```

Modal sizes: `:sm` (400px), `:md` (560px default), `:lg` (800px), `:xl` (1140px)

Close methods: click backdrop, press Escape, or button action setting `s[:modal_key_open] = false`

## Status Badge

```ruby
status_badge :strong, "Perfect match"
status_badge :maybe, "Good fit, but..."
status_badge :skip, "Not recommended"
```

Renders visual indicators:
- Strong = green background
- Maybe = yellow background
- Skip = red background

## Tag Buttons

```ruby
# Default style
tag_buttons :category, ["Fiction", "Non-fiction", "Mystery"]

# Destructive style
tag_buttons :eliminate_reason, ["Too dark", "Wrong genre"], style: :destructive
# state[:eliminate_reason] = "too_dark" (normalized)
```

Single-select: clicking a tag selects it and deselects others.

## External Link Button

```ruby
# Just open link
external_link_button "View on Amazon", url: "https://amazon.com/dp/B0XXX"

# Submit form AND open link (for agentic mode)
external_link_button "Get it!", url: book[:amazon_url], submit: true
```

## Table

Display tabular data with smart data inference, formatters, and interactive features.

### Basic Usage

```ruby
# Original API - explicit headers and rows
table headers: ["Name", "Size"], rows: [["app.rb", "12kb"], ["cli.rb", "8kb"]]

# Array of hashes - headers auto-inferred from keys
table [
  { name: "Alice", age: 30, role: "Engineer" },
  { name: "Bob", age: 25, role: "Designer" }
]
# Headers become: "Name", "Age", "Role" (titleized keys)

# Hash of arrays - keys become columns
table({ name: ["Alice", "Bob"], age: [30, 25] })
```

### Data Sources

```ruby
# State binding - reads from state[:users]
table data: :users

# File loading (YAML or JSON)
table file: "data/users.yaml"
table file: "data.json", path: "results.users"

# Transform block for file data
table file: "raw.yaml" do |data|
  data.map { |r| { name: r[:n], value: r[:v] } }
end
```

### Column DSL with Formatters

```ruby
table users do
  column :name
  column :email, header: "E-mail"
  column :balance, format: :currency, align: :right
  column :joined, format: :date
  column(:active) { |u| u.active ? "Yes" : "No" }  # Computed column
end
```

**Built-in formatters:**

| Format | Example Input | Output |
|--------|---------------|--------|
| `:date` | `Date.today` | "Jan 20, 2026" |
| `:datetime` | `Time.now` | "Jan 20, 2026 3:30 PM" |
| `:currency` | `1234.56` | "$1,234.56" |
| `:number` | `1234567` | "1,234,567" |
| `:percent` | `0.42` | "42%" |

Custom formatter with Proc:
```ruby
column :balance, format: ->(v) { v > 1000 ? "#{(v/1000.0).round(1)}k" : v.to_s }
```

### Interactive Features

```ruby
# Sortable - click headers to sort (handles text and numbers)
table data, sortable: true

# Sticky header - header stays visible when scrolling
table data, sticky_header: true

# Combined
table data, sortable: true, sticky_header: true, striped: true
```

### Styling Options

```ruby
table data,
      striped: true,        # Alternate row colors
      bordered: true,       # Cell borders
      hoverable: true,      # Highlight rows on hover (default: true)
      compact: true,        # Reduced padding
      sortable: true,       # Client-side sorting
      sticky_header: true,  # Header stays visible on scroll
      caption: "Title"      # Table caption above
```

## Score Table

```ruby
score_table scores: [
  { label: "Novelty", value: 8, max: 10 },
  { label: "Quality", value: 5, max: 10 },
  { label: "Impact", value: 3, max: 10 }
]
```

Color coding: Green (>=70%), Yellow (40-69%), Red (<40%)

## Charts

Data visualization using Chart.js (loaded via CDN only when charts are present):

```ruby
# Bar charts
bar_chart data: { calendar: 45, news: 120, tasks: 30 }
hbar_chart data: { "Phase A" => 25, "Phase B" => 45 }  # horizontal

# Line charts
line_chart data: [12, 19, 8, 15, 22]  # array = sequential x-axis
line_chart data: { Mon: 5, Tue: 12, Wed: 8 }, fill: true

# Sparklines (minimal, inline trend indicators)
sparkline data: [45, 52, 48, 61, 55, 67, 72]

# File-based data
bar_chart file: "~/metrics/timing.yaml", path: "entries.-1.phases"

# State-bound
bar_chart data: :metrics
```

**Bar chart options:** `horizontal:`, `show_values:`

**Line chart options:** `fill:`, `smooth:`, `points:`, `begin_at_zero:`

**Pie/Doughnut:**
```ruby
pie_chart data: { sales: 100, costs: 60, profit: 40 }
doughnut_chart data: { frontend: 40, backend: 35, devops: 25 }
```

**Stacked bar:**
```ruby
stacked_bar_chart data: [
  { label: "Mon", sales: 100, costs: 60 },
  { label: "Tue", sales: 120, costs: 70 }
]
```

**Common options:** `data:`, `file:`, `path:`, `title:`, `height:`, `colors:`, `show_legend:`

## Educational Content (Glossary/Tooltips)

```ruby
glossary = {
  "term" => {
    simple: "Short definition on hover",
    detailed: "Longer explanation on click"
  }
}

# String syntax - terms in {braces}
lesson_text "This has a {term}.", glossary: glossary
```

## Alerts

```ruby
alert(variant: :info) do
  text "Informational message."
end

alert(variant: :success, title: "Success!") do
  text "Your changes have been saved."
end

alert(variant: :warning, title: "Warning") do
  text "Your session will expire soon."
end

alert(variant: :error, title: "Error") do
  text "Unable to connect to server."
end

# Dismissible
alert(variant: :info, dismissible: true) do
  text "Click X to dismiss."
end
```

Variants: `:info`, `:success`, `:warning`, `:error`

## Toast Notifications

```ruby
# Add toast container
toast_container position: :top_right, duration: 5000

# Trigger toasts from button actions
button "Save" do |s|
  show_toast("Saved successfully!", variant: :success)
end

# Clear all toasts
button "Clear" do |s|
  clear_toasts
end
```

Positions: `:top_right`, `:top_left`, `:bottom_right`, `:bottom_left`
Variants: `:info`, `:success`, `:warning`, `:error`
Duration: milliseconds (0 = no auto-dismiss)

## Progress Bar

```ruby
progress_bar value: 75
progress_bar value: 65, show_label: true
progress_bar value: 100, variant: :success
progress_bar value: 80, animated: true
```

Variants: `:default`, `:success`, `:warning`, `:error`

## Spinner

```ruby
spinner
spinner size: :sm
spinner size: :md  # default
spinner size: :lg
spinner size: :md, label: "Loading data..."
```

Sizes: `:sm`, `:md`, `:lg`
