# StreamWeaver Components Reference

Complete reference for all StreamWeaver components. For quick usage, see the main `llms.txt`.

## Text Display

```ruby
text "Plain paragraph"           # Literal text - what you type is what you get
text "Value: #{state[:value]}"   # String interpolation works
```

> **WARNING for LLMs:** `text` renders its argument as a literal string. Markdown syntax like `**bold**` or `## heading` will appear as raw characters on screen — not as formatted HTML. Use `md` for markdown, or `header*` for section labels.

```ruby
# WRONG — asterisks show up literally on screen
text "**Select the article PDF:**"

# CORRECT — use md for inline markdown formatting
md "**Select the article PDF:**"

# BETTER — use semantic headers for labels and section titles
header3 "Select the article PDF:"
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

## Dates

```ruby
date_field :due_on, label: "Due date"

# Constrain the selectable range (both are ISO 8601 strings)
date_field :due_on, min: "2026-01-01", max: "2027-12-31"

# Disable auto-submit
date_field :due_on, submit: false
```

Renders a native `<input type="date">` — no custom JS, no bundled calendar
widget. The browser supplies the calendar popup and, on mobile, its own
native date picker. Works the same as `text_field` inside `form`/`scope`
blocks.

State always holds an **ISO 8601 string** (`"YYYY-MM-DD"`), never a `Date`
object — coerce it yourself when you need one:

```ruby
if (parsed = StreamWeaver::Components::DateField.to_date(state[:due_on]))
  text "Parsed as a Date: #{parsed.iso8601}"
end
```

`DateField.to_date` returns `nil` for blank or unparsable input instead of
raising.

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

# Unique ID for buttons in loops (prevents callback collisions)
voices.each do |v|
  button "Test", id: v[:name] do |state|
    speak(v[:name])  # Each button triggers its own callback
  end
end
```

**Note:** When creating buttons inside a loop, use `id:` to give each button a unique identifier. Without this, all buttons share the same internal ID and only the last callback fires.

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

# Card header with badge + right-aligned meta (flex row: badge | title | meta)
card do
  card_header "C1 — Title", badge: "C1", meta: "scheduler secretary"
  card_body do
    text "Main content goes here"
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

# With a subtitle and badge in the header
collapsible "Activity Log", subtitle: "Last 30 days", badge_text: "12 new", badge_variant: :success do
  text "Recent activity details"
end
```

`collapsible` is client-side only — the server never learns the expanded state. If you need the server to know whether a section is expanded (e.g. to bind it to `state`), use `expandable_card` instead.

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

An out-of-range index (a stale session value, or a group that shrank) renders tab 0
rather than blanking every panel.

### Route tabs (`url: true`)

```ruby
tabs :view, url: true do
  tab("Overview") { text "..." }
  tab("Findings") { text "..." }
end
# active tab lives in ?view=<index> — bookmarkable, back/forward-aware
```

Switching tabs is client-side (History API `pushState`/`popstate`) — zero requests.
Multiple `url: true` groups compose, one param per key: `/?view=2&panel=1`.

**The URL is authoritative on a full GET.** Param present and valid → that index.
Absent or invalid → tab 0, *never* the session value. The same URL always renders the
same tabs.

Invalid values degrade instead of erroring — `?view=999`, `?view=abc`, and `?view[]=`
all return 200 with tab 0 active. Integer strings (`?view=2`) are valid deep links.
Build-time `ArgumentError`s: a reserved request param as the key (`app_id`, `splat`,
`captures`, `button_id`), two groups claiming the same key, or `url: true` with
`lazy: true`.

**Gotcha — read `state[:view]` *below* the declaration.** Above it, the key still holds
the raw pre-authority value (the param string, or a stale session index); the resolved
integer only exists once the group has applied URL authority:

```ruby
tabs :view, url: true do ... end
md "Active view: #{state[:view]}"   # resolved Integer
```

**Gotcha — a route-tab group cannot be server-side preset.** `state[:view] ||= 1` above
the declaration is overwritten by URL authority (tab 0 on a bare GET). That is the
authority rule working as designed; use a deep link (`/?view=1`) instead.

On canvas pages `url:` is ignored — the group renders as plain client-side tabs and one
warning is logged per render pass, since a canvas page has no app URL to carry the tab.

See `examples/layout/route_tabs_demo.rb` for a two-group demo that exercises both
gotchas.

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

## Navbar

Cross-app horizontal navigation bar. Active item renders as bold text; others as links.

```ruby
navbar do
  nav_item "Home",     href: "/", active: true   # current page — bold, non-clickable
  nav_item "Settings", href: "/settings"          # link
  nav_item "Help",     href: "/help"
end
```

## Link

Inline anchor element.

```ruby
link_to "Visit docs", href: "https://example.com"
link_to "Internal page", href: "/dashboard"
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

## Copy Button

Client-side clipboard-copy trigger for a fixed text payload -- no server round-trip.

```ruby
copy_button "Copy summary", text: report_text

# Custom label shown briefly after a successful copy
copy_button "Copy", text: api_key, copied_label: "Copied to clipboard!"
```

Uses `navigator.clipboard` on secure origins (HTTPS or localhost) and automatically
falls back to a hidden-textarea + `execCommand('copy')` approach otherwise -- this
matters when StreamWeaver is served over plain HTTP to a LAN IP, where
`navigator.clipboard` is unavailable because the page isn't a secure context.

## Code Block

Syntax-highlighted code display.

```ruby
code_block "def hello\n  puts 'hi'\nend", lang: "ruby"

# With a copy affordance in the header (off by default)
code_block source_code, lang: "ruby", copy: true

# With a filename shown in the header
code_block source_code, lang: "ruby", file: "app.rb"
```

`copy:` reuses the same clipboard mechanism as `copy_button` -- the header gains
a small Copy button that always copies the full code text, even if the block is
truncated for display via `truncate:`.

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

### Markdown Links in Cells

```ruby
# Enable markdown link parsing with markdown: true
table [
  { issue: "[JIRA-123](https://jira.example.com/browse/JIRA-123)", status: "Open" },
  { issue: "[JIRA-456](https://jira.example.com/browse/JIRA-456)", status: "Closed" }
], markdown: true

# Default (markdown: false) shows literal text: "[text](url)"
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
      markdown: true,       # Parse [text](url) as clickable links
      caption: "Title"      # Table caption above
```

### Cell Style Escape Hatches

By default, the first column renders in an accent monospace style (legacy behavior, unchanged). To control this per-cell:

```ruby
# Column DSL: style: accepts a static String or a per-row Proc
table users do
  column :name, style: "font-weight: 600;"
  column :balance, style: ->(u) { u.balance.negative? ? "color: red;" : nil }

  # id_style: overrides the default first-column accent styling, true/false, on any column
  column :id, id_style: false     # never accent this column
  column :sku, id_style: true     # always accent this column, regardless of position
end

# Raw headers:/rows: tables: id_column: picks which column (by index) gets the
# accent styling instead of the column-0 default, or disables it entirely
table headers: ["SKU", "Name"], rows: [...], id_column: 0   # explicit column 0
table headers: ["SKU", "Name"], rows: [...], id_column: false # no accent anywhere
```

`style:` is appended after any built-in styling (including the accent styling above), so it always wins on conflicting CSS properties without needing `!important`.

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

## Mermaid Diagrams

Renders Mermaid.js diagrams. Mermaid.js 11 (ESM) is loaded lazily from CDN — only injected when a `mermaid` component is present on the page.

```ruby
# Basic — any valid Mermaid diagram type
mermaid <<~MERMAID
  graph LR
    A[Start] --> B{Decision}
    B -- Yes --> C[Ship it]
    B -- No  --> D[Debug]
    D --> A
MERMAID

# zoom: true — adds +/−/reset buttons and Ctrl+scroll zoom
mermaid diagram_code, zoom: true

# compact: true — reduced padding for embedding inside a card
card do
  mermaid diagram_code, compact: true
end

# layout: :elk — ELK layout engine (better for dense graphs, loads separately from CDN)
mermaid diagram_code, layout: :elk

# theme_vars: — override Mermaid themeVariables per diagram
mermaid diagram_code, theme_vars: {
  primaryColor: "#6366f1",
  primaryTextColor: "#ffffff",
  primaryBorderColor: "#4f46e5",
  lineColor: "#6366f1"
}
```

**Options:**

| Option | Type | Default | Description |
|---|---|---|---|
| `zoom:` | Boolean | `false` | Adds in-place zoom/pan controls (+/−/reset) and Ctrl+scroll |
| `compact:` | Boolean | `false` | Reduces padding — use when embedding inside a card |
| `layout:` | Symbol | `:default` | Layout engine: `:default` (Dagre) or `:elk` (ELK) |
| `theme_vars:` | Hash | `nil` | Per-diagram Mermaid `themeVariables` overrides |

**Supported diagram types:** flowchart, sequence, pie, gantt, gitgraph, classDiagram, stateDiagram, erDiagram, and any other type supported by Mermaid.js 11.

**Expand to full screen.** Every diagram, regardless of `zoom:`, gets an ⛶-style expand button that opens it full-viewport with no width constraint — a doc column's max-width shrinks a wide diagram's fixed-px labels proportionally no matter how the layout is tuned, so this is the actual fix for an illegible complex diagram, not just a bigger version of `zoom: true`. Scroll (or drag) to pan, Ctrl+scroll to zoom further, Escape/click the backdrop/the close button to exit. No opt-in needed and no extra dependency — it's client-side only, so it works the same in the live canvas, `canvas-read`, and any exported doc (including an `--offline` one).

**Theme awareness:** Mermaid diagrams automatically re-render when the page theme changes (dark/light). Use `theme_vars:` for brand-specific color overrides.

**Examples:** `examples/components/mermaid_demo.rb` (all options), `examples/canvas/mermaid_canvas_demo.sh` (canvas-push).

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

## Dashboard Components

Dashboard-style components for operations dashboards, control panels, and status displays. Best used with `theme: :dark`.

### Status Dot

Colored indicator dots with optional glow effect, pulse animation, and labels:

```ruby
status_dot status: :red      # Red with glow
status_dot status: :yellow   # Yellow with glow
status_dot status: :green    # Green with glow
status_dot status: :gray     # Gray (inactive)

# Sizes
status_dot status: :green, size: :sm   # 6px
status_dot status: :green, size: :md   # 10px (default)
status_dot status: :green, size: :lg   # 14px

# Pulse animation
status_dot status: :green, pulse: true

# With label (displayed below the dot)
status_dot status: :green, label: "user.rb"
status_dot status: :green, pulse: true, label: "processing..."
```

### Badge

Count/label badges in various color variants:

```ruby
badge "5"                        # Default gray
badge "3", variant: :danger      # Red
badge "12", variant: :warning    # Yellow
badge "OK", variant: :success    # Green
badge "new", variant: :info      # Blue

# Sizes
badge "5", size: :sm             # Smaller
badge "5", size: :md             # Default
```

### Stat Display

Large metric numbers with labels:

```ruby
stat_display value: 42, label: "TASKS"
stat_display value: 7, label: "PENDING", color: :blue
stat_display value: 5, label: "BLOCKED", color: :red
stat_display value: 12, label: "DONE", color: :purple

# Sizes
stat_display value: 99, label: "TOTAL", size: :sm
stat_display value: 99, label: "TOTAL", size: :md   # Default
stat_display value: 99, label: "TOTAL", size: :lg
```

Colors: `:default`, `:blue`, `:purple`, `:red`

### Type Tag

Activity type badges:

```ruby
type_tag :research       # Blue
type_tag :task           # Purple
type_tag :escalation     # Red
type_tag :communication  # Green
type_tag :warning        # Yellow
type_tag :info           # Gray
```

### Pulse Indicator

Animated status indicator with label (for headers):

```ruby
pulse_indicator color: :green, label: "System Active"
pulse_indicator color: :red, label: "Alert"
pulse_indicator color: :yellow, label: "Degraded"
```

### Priority Item

Items with priority-colored left border and hover slide effect:

```ruby
priority_item priority: :critical, title: "Database at capacity",
              description: "Primary DB at 92% storage. Need immediate action.",
              meta_left: "ops", meta_right: "Expand storage"

priority_item priority: :urgent, title: "API rate limited",
              description: "Third-party integration hitting 429 errors."

priority_item priority: :high, title: "Security patch needed"
priority_item priority: :normal, title: "Documentation update"
```

Priorities: `:critical` (red), `:urgent` (orange), `:high` (yellow), `:normal` (gray)

### Activity Item

Activity feed items with time, title, summary, and type badge:

```ruby
activity_item time: "15:00", title: "Performance analysis",
              summary: "Identified 3 slow queries, recommended indexes",
              type: :research

activity_item time: "14:30", title: "Deployment complete",
              summary: "All services updated successfully",
              type: :task
```

Types: `:research`, `:task`, `:escalation`, `:communication`

## Dashboard Layouts

### App Shell

Two-column layout with main content and sidebar:

```ruby
app_shell sidebar_width: "320px" do
  main do
    header2 "Dashboard"
    # Main content here
  end

  sidebar header: "Alerts" do
    # Sidebar content here
  end
end
```

The sidebar is sticky and scrolls independently. Layout stacks on mobile.

### Expandable Card

Cards that expand/collapse on click with smooth transitions:

```ruby
expandable_card key: :team_details,
                title: "Engineering",
                subtitle: "Product Development",
                badge_text: "5 activities",
                status: :green,
                initially_expanded: true do
  # Expanded content here
  stat_display value: 3, label: "TASKS"
  activity_item time: "15:00", title: "Code review"
end
```

Options:
- `key:` - State key for expansion state (required)
- `title:` - Card header title
- `subtitle:` - Secondary text
- `badge_text:` - Text in top-right badge
- `status:` - Status dot color (`:red`, `:yellow`, `:green`)
- `initially_expanded:` - Start expanded (default: false)

## Live Streaming (SSE Timers)

Push live updates to the browser without polling. The `every` DSL registers periodic timers that fire server-side and push DOM updates via Server-Sent Events.

### `every(seconds)`

```ruby
app "Live", theme: :dark do
  div id: "clock" do
    text "..."
  end

  every(1) do |streamer|
    streamer.replace("#clock") do
      div id: "clock" do
        text Time.now.strftime("%H:%M:%S")
      end
    end
  end
end.run!
```

### Streamer Actions

The `streamer` object passed to `every` blocks supports:

```ruby
# Replace element content (block or string)
streamer.replace("#target") do
  div id: "target" do
    stat_display value: "42", label: "COUNT", color: :green
  end
end

# Append/prepend content
streamer.prepend("#feed") do
  div style: "padding:4px" do
    text "New entry at #{Time.now}"
  end
end

streamer.append("#log", "<p>Raw HTML also works</p>")

# CSS class manipulation
streamer.add_class("#card-cpu", "highlight")
streamer.remove_class("#card-cpu", "highlight")

# Remove element entirely
streamer.remove("#temporary-banner")
```

### CSS Injection Pattern

To inject custom CSS for class effects, use a hidden placeholder with `replace` (not `append("head")` which creates duplicates):

```ruby
div id: "custom-css", style: "display:none"

every(5) do |streamer|
  streamer.replace("#custom-css", "<style>.glow{box-shadow:0 0 12px red}</style>")
  streamer.add_class("#card-alert", "glow")
end
```

### Multiple Timers

Multiple `every` blocks run independently. Use closure variables to share state:

```ruby
latest = { cpu: 0.0 }

every(3) do |streamer|
  latest[:cpu] = read_cpu
  streamer.replace("#cpu-metric") { ... }
end

every(10) do |streamer|
  if latest[:cpu] > threshold
    streamer.prepend("#alerts") { ... }
  end
end
```

### Targeting `expandable_card`

`expandable_card key: :foo` generates `id="card-foo"` on the outer container. Target it with `#card-foo` for class manipulation:

```ruby
expandable_card key: :server, title: "Server", status: :green do
  div id: "server-stats" do
    stat_display value: "\u2014", label: "LOAD"
  end
end

every(5) do |streamer|
  streamer.replace("#server-stats") { ... }
  streamer.add_class("#card-server", "alert-ring") if overloaded
end
```

### Accessing `state` Inside Replace Blocks

`streamer.replace` blocks run in a `FeedBuilder` context, not the App context. `state` is a method on App — it is **not available** inside replace blocks unless you pass it explicitly via the `state:` keyword.

```ruby
# WRONG — raises NameError in timer thread at runtime
every(30) do |streamer|
  streamer.replace("#panel") do
    text "Mode: #{state[:mode]}"  # NameError: undefined method `state'
  end
end

# CORRECT
every(30) do |streamer|
  streamer.replace("#panel", state: state) do
    text "Mode: #{state[:mode]}"  # works
  end
end
```

This applies to `replace`, `append`, and `prepend`. The error appears in the server log as `[StreamWeaver] Timer error: NameError` — it will not raise on startup, only when the timer fires.

### Helper Methods and Replace Blocks

Top-level `def` helper methods are accessible inside replace blocks (they're global). If those helpers use `state`, pass `state:` to `replace` so it is available:

```ruby
def render_dashboard(metrics:, state:)
  columns do
    column do
      stat_display value: metrics[:count], label: "Total"
    end
    column do
      text "Filter: #{state[:filter]}"
    end
  end
end

app "Dashboard" do
  div id: "dash" do
    render_dashboard(metrics: load_metrics, state: state)
  end

  every(10) do |streamer|
    streamer.replace("#dash", state: state) do
      render_dashboard(metrics: load_metrics, state: state)
    end
  end
end.run!
```

## Dark Theme

Use `theme: :dark` for a dark color scheme optimized for dashboards:

```ruby
app "Operations Dashboard", theme: :dark do
  # components...
end
```

Dark theme provides:
- Deep dark backgrounds (`#0a0e14`, `#131820`)
- Soft borders and elevated surfaces
- Light text with proper contrast
- Glow effects on status indicators
- Hover lift and slide animations
