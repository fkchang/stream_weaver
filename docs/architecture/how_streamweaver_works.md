# How StreamWeaver Works: A Deep Dive

This document explains the internal architecture of StreamWeaver - how a Ruby DSL on the server handles frontend events and runs backend code.

## The Core Innovation

StreamWeaver's key insight: **Your Ruby code re-executes on every user interaction**. When a user types in a text field or clicks a button, the entire DSL block is re-evaluated with the new state. This creates a reactive programming model where your code runs on the server but responds to frontend events.

```ruby
app "Counter" do
  # This block runs EVERY TIME any input changes or button is clicked
  text "Count: #{state[:count] || 0}"

  button "Increment" do |s|
    s[:count] = (s[:count] || 0) + 1
  end
end
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           BROWSER                                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Alpine.js (x-model)     HTMX (hx-post)                       │   │
│  │  - Captures input values  - Sends POST requests               │   │
│  │  - Client-side state      - Swaps HTML responses              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼ HTTP POST                             │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           SERVER                                     │
│  ┌─────────────┐   ┌────────────────┐   ┌──────────────────────┐   │
│  │  SinatraApp │   │     App        │   │     Adapter          │   │
│  │  (Routes)   │──▶│ (DSL + State)  │──▶│ (HTML Generation)    │   │
│  │             │   │                │   │                      │   │
│  │ /update     │   │ rebuild_with_  │   │ render_text_field()  │   │
│  │ /action/:id │   │ state()        │   │ render_button()      │   │
│  │ /submit     │   │                │   │ render_*()           │   │
│  └─────────────┘   └────────────────┘   └──────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│                    ┌────────────────┐                               │
│                    │    Views       │                               │
│                    │ (Phlex HTML)   │                               │
│                    └────────────────┘                               │
└─────────────────────────────────────────────────────────────────────┘
```

## The Request-Response Cycle

### 1. Initial Page Load (GET /)

```
Browser ─────GET /─────▶ SinatraApp
                              │
                              ▼
                        App.rebuild_with_state({})
                              │
                              ▼
                        Execute DSL block (instance_eval)
                              │
                              ▼
                        Build component tree
                              │
                              ▼
                        Adapter renders HTML with HTMX/Alpine attributes
                              │
                              ▼
                        AppView generates full page
                              │
◀────────HTML────────────────┘
```

### 2. Input Change (typing in text field)

```
User types "hello"
      │
      ▼
Alpine.js x-model captures value
      │
      ▼
HTMX triggers POST /update (after debounce)
      │
      ▼
SinatraApp#post '/update'
      │
      ├─▶ state = session[:streamlit_state]
      ├─▶ sync_params_to_state(state)      # state[:name] = "hello"
      ├─▶ app.rebuild_with_state(state)    # Re-run DSL with new state
      └─▶ AppContentView renders HTML
             │
◀────────HTML partial─────────────────────┘
      │
      ▼
HTMX swaps #app-container innerHTML
```

### 3. Button Click (executing a callback)

```
User clicks "Submit"
      │
      ▼
HTMX POST /action/btn_submit_abc123
      │
      ▼
SinatraApp#post '/action/:button_id'
      │
      ├─▶ Find button by ID in component tree
      ├─▶ button.execute(state)  # Runs the Ruby block!
      │       │
      │       └─▶ Your code: puts state[:name]
      │
      ├─▶ app.rebuild_with_state(state)
      └─▶ AppContentView renders HTML
             │
◀────────HTML partial─────────────────────┘
```

## Core Classes Explained

### App (lib/stream_weaver/app.rb)

The `App` class is the heart of the DSL. It:

1. **Stores the DSL block** - The block you pass to `app` is saved and re-executed
2. **Manages state** - Tracks all form values in `@_state`
3. **Builds component tree** - DSL methods like `text_field`, `button` create Component instances
4. **Provides DSL methods** - All the UI building methods are defined here

```ruby
class App
  def initialize(title, &block)
    @block = block        # Your DSL code
    @_state = {}          # Current state
    @components = []      # Component tree
  end

  # This is the magic - re-runs your code with fresh state
  def rebuild_with_state(current_state)
    @_state = current_state
    @components = []      # Clear old components
    instance_eval(&@block)  # Execute YOUR code
  end

  # DSL methods create components
  def text_field(key, **options)
    @_state[key] ||= ""  # Initialize state
    @components << Components::TextField.new(key, **options)
  end

  def button(label, **options, &block)
    @components << Components::Button.new(label, &block)
  end
end
```

### SinatraApp (lib/stream_weaver/server.rb)

The generated Sinatra application that handles HTTP requests:

| Route | Purpose |
|-------|---------|
| `GET /` | Initial page load |
| `POST /update` | State sync from input changes |
| `POST /action/:button_id` | Button click handlers |
| `POST /submit` | Agentic mode final submission |
| `POST /event/:key` | on_change/on_blur callbacks |
| `POST /form/:form_name` | Deferred form submission |
| `POST /theme/:theme_name` | Runtime theme switching |

Key methods:

```ruby
# Sync form params to state hash
def sync_params_to_state(state, excluded_keys: [])
  params.each do |key, value|
    state[key.to_sym] = coerce_param_value(value, state[key.to_sym])
  end
end

# Find button in nested component tree
def self.find_button_recursive(components, button_id)
  components.each do |component|
    return component if component.is_a?(Components::Button) && component.id == button_id
    if component.respond_to?(:children) && component.children
      found = find_button_recursive(component.children, button_id)
      return found if found
    end
  end
  nil
end
```

### Adapter::AlpineJS (lib/stream_weaver/adapter/alpinejs.rb)

The adapter is responsible for rendering components with the right HTML attributes for the frontend framework (Alpine.js + HTMX).

```ruby
def render_text_field(view, key, options, state)
  view.input(
    type: "text",
    name: key.to_s,
    value: state[key] || "",
    "x-model" => key.to_s,           # Alpine.js 2-way binding
    "hx-post" => url("/update"),      # HTMX POST on change
    "hx-include" => "[x-model]",      # Include all bound inputs
    "hx-target" => "#app-container",  # Replace this element
    "hx-swap" => "innerHTML scroll:false",  # Swap method
    "hx-trigger" => "keyup changed delay:500ms"  # Debounced trigger
  )
end

def render_button(view, button_id, label, options, modal_context)
  view.button(
    "hx-post" => url("/action/#{button_id}"),
    "hx-include" => "[x-model]",
    "hx-target" => "#app-container",
    "hx-swap" => "innerHTML scroll:false"
  ) { label }
end
```

### Components (lib/stream_weaver/components.rb)

Each UI element is a component class. Components:
- Store their configuration
- Delegate rendering to the adapter
- Can have callbacks (on_change, on_blur)

```ruby
class TextField < Base
  include Callbacks
  attr_reader :key

  def initialize(key, on_change: nil, **options)
    @key = key
    @options = options
    init_callbacks(on_change: on_change)
  end

  def render(view, state)
    view.adapter.render_text_field(view, @key, @options, state)
  end
end

class Button < Base
  def initialize(label, stable_id, **options, &block)
    @label = label
    @action = block  # Your Ruby callback
    @button_id = "btn_#{label}_#{stable_id}"
  end

  def execute(state)
    @action.call(state) if @action  # Runs YOUR code!
  end
end
```

### Views (lib/stream_weaver/views.rb)

Phlex-based views render the final HTML:

- **AppView** - Full page with `<html>`, `<head>`, `<body>`, CSS, JS
- **AppContentView** - Partial for HTMX swaps (just the component HTML)

```ruby
class AppView < Phlex::HTML
  def view_template
    doctype
    html do
      head do
        @adapter.render_cdn_scripts(self)  # HTMX, Alpine.js
        style { raw(safe(CSS_CONTENT)) }   # Built-in CSS
      end
      body(class: body_classes) do
        h1 { @app.title }
        div(id: "app-container", **@adapter.container_attributes(@state)) do
          @app.components.each { |c| c.render(self, @state) }
        end
      end
    end
  end
end
```

## Service Mode (lib/stream_weaver/service.rb)

Service mode runs a persistent server that can host multiple apps:

```
┌─────────────────────────────────────────────────────────────────────┐
│                      StreamWeaver Service                           │
│                                                                     │
│  ┌───────────────────┐  ┌───────────────────┐                      │
│  │ App: abc123       │  │ App: def456       │                      │
│  │ hello_world.rb    │  │ todo_list.rb      │                      │
│  │ /apps/abc123      │  │ /apps/def456      │                      │
│  └───────────────────┘  └───────────────────┘                      │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    Live Sessions                               │ │
│  │                                                                │ │
│  │  claude_chat_1:                                                │ │
│  │    - Browser polls /live/claude_chat_1/poll                    │ │
│  │    - Claude pushes via /live/claude_chat_1/push                │ │
│  │    - User actions stored for Claude to retrieve                │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Service Features:

1. **Multi-app hosting** - Load apps dynamically via `/load-app`
2. **Live Sessions** - Polling-based update-in-place for agentic workflows
3. **Source-based routing** - Aliased URLs like `/examples/hello_world`
4. **Background launch** - `Service.launch_background` spawns a detached process

### Live Sessions Architecture

Live sessions enable Claude Code or other agents to push UI updates:

```ruby
# Claude pushes content
POST /live/my_session/push
  target: "#main"
  content: "<h1>Hello!</h1>"
  action: "replace"

# Browser polls for updates
GET /live/my_session/poll?since=1234567890
  # Returns any updates since timestamp

# User interaction creates submission
POST /live/my_session/submit
  # Form data stored for Claude to retrieve

# Claude retrieves user input
GET /live/my_session/submissions
  # Returns pending submissions
```

## State Management

State flows through the system:

```
                    ┌──────────────┐
                    │   Session    │
                    │ Cookie Store │
                    └──────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│                         State Hash                                │
│                                                                   │
│  {                                                                │
│    name: "hello",           # From text_field :name               │
│    active: true,            # From checkbox :active               │
│    settings: {              # From form :settings                 │
│      email: "x@y.com",                                           │
│      notify: true                                                │
│    },                                                            │
│    my_tabs: 0,              # From tabs :my_tabs (active index)  │
│    confirm_open: false,     # From modal :confirm (open state)   │
│    _toasts: [...]           # Internal toast queue               │
│  }                                                               │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
              App.rebuild_with_state(state)
                          │
                          ▼
              DSL accesses via state[:key]
```

### State Initialization

Components initialize their state keys when the DSL executes:

```ruby
def text_field(key, **options)
  # Initialize if not present
  @_state[key] ||= ""
  @components << Components::TextField.new(key, **options)
end

def checkbox(key, label, **options)
  @_state[key] ||= false
  @components << Components::Checkbox.new(key, label, **options)
end

def tabs(key, **options, &block)
  @_state[key] ||= 0  # Default to first tab
  # ...
end
```

## Frontend Integration

### Alpine.js Role

Alpine.js provides:
- **`x-data`** - Initializes reactive state on #app-container
- **`x-model`** - Two-way binding between inputs and state
- **`x-show`** - Conditional display (tabs, modals, tooltips)
- **`@click`** - Event handlers for client-only interactions

```html
<div id="app-container" x-data="{name: '', active: false, my_tabs: 0}">
  <input type="text" x-model="name" hx-post="/update" ...>
  <div x-show="my_tabs === 0">Tab 1 content</div>
</div>
```

### HTMX Role

HTMX handles server communication:
- **`hx-post`** - Where to send the request
- **`hx-include`** - What data to include (`[x-model]` = all bound inputs)
- **`hx-target`** - What to replace (`#app-container`)
- **`hx-swap`** - How to replace (`innerHTML scroll:false`)
- **`hx-trigger`** - When to fire (`keyup changed delay:500ms`)

### The Defer Mutations Pattern

A critical integration pattern prevents Alpine.js from overwriting HTMX updates:

```javascript
// Before swap: pause Alpine's mutation observer
document.addEventListener('htmx:beforeSwap', function(e) {
  Alpine.deferMutations();
});

// After settle: reinitialize Alpine with fresh state from server
document.addEventListener('htmx:afterSettle', function(e) {
  const stateEl = document.getElementById('sw-state-data');
  const container = document.getElementById('app-container');
  const newState = JSON.parse(stateEl.textContent);
  const alpineData = Alpine.$data(container);
  Object.keys(newState).forEach(key => {
    alpineData[key] = newState[key];
  });
  Alpine.flushAndStopDeferringMutations();
});
```

## Execution Modes

### 1. Standalone Mode (`App.run!`)

Traditional persistent server:

```ruby
app "My App" do
  # ...
end.run!
```

- Opens browser automatically
- Runs until Ctrl+C
- State persists in session

### 2. Agentic Mode (`App.run_once!`)

One-shot form collection for AI agents:

```ruby
result = app "Get User Info" do
  text_field :name
  text_field :email
end.run_once!(auto_close_window: true)

puts result  # => {name: "John", email: "john@example.com"}
```

- Shows a "Submit to Agent" button
- Returns data when submitted
- Auto-closes browser (optional)
- Timeout after 300s (configurable)

### 3. Service Mode (multi-app)

Run multiple apps on one server:

```bash
# Start service
streamweaver service start

# Load apps
streamweaver run hello.rb
streamweaver run todo.rb
```

Each app gets its own route (`/apps/{id}`) and isolated state.

## Form System

### Immediate Mode (default)

Every input change triggers a server round-trip:

```ruby
text_field :name  # POST /update on every keystroke (debounced)
```

### Deferred Mode (form blocks)

Group inputs and submit together:

```ruby
form :settings do
  text_field :email
  checkbox :notify, "Send notifications"

  submit "Save" do |values|
    # values = {email: "...", notify: true}
    save_settings(values)
  end
end
```

Form inputs use Alpine-only binding until submit, then POST to `/form/:name`.

## Callbacks and Events

### Button Callbacks

```ruby
button "Submit" do |state|
  # This Ruby code runs on the server when clicked
  puts state[:name]
  state[:submitted] = true
end
```

### Input Callbacks

```ruby
text_field :email, on_change: ->(state, value) {
  state[:valid] = value.include?("@")
}

text_field :search, on_blur: ->(state, value) {
  state[:results] = search_api(value)
}
```

Routes to `/event/:key` instead of `/update` when callbacks are present.

## Additional DSL Features

### App Configuration Options

```ruby
app "My App",
  layout: :wide,           # :default, :wide, :full, :fluid
  theme: :dashboard,       # :default, :dashboard, :document
  theme_overrides: { color_primary: "#0066cc" },
  scripts: ["custom.js"],
  stylesheets: ["custom.css"],
  components: [MyHelpers]  # Mixin modules
do
  # ...
end
```

### Dynamic Content with Procs

Text and markdown can accept procs for dynamic content:

```ruby
# Static
text "Hello"

# Dynamic - re-evaluated each render
text -> (s) { "Count: #{s[:count]}" }

# Also works with markdown
md -> (s) { "**Status:** #{s[:status]}" }
```

### Header Aliases

```ruby
header1 "Main Title"    # <h1>
header2 "Section"       # <h2>
header3 "Subsection"    # <h3>
header "Also h2"        # alias for header2
```

### Markdown Shorthand

```ruby
md "**Bold** and *italic*"
markdown "Same as md"  # alias
```

### Layout Components

```ruby
# Vertical/horizontal stacking
vstack spacing: :md do
  text "Item 1"
  text "Item 2"
end

hstack spacing: :sm, justify: :between do
  button "Left"
  button "Right"
end

# Multi-column layouts
columns widths: ['30%', '70%'] do
  column { text "Sidebar" }
  column { text "Main content" }
end

# Grid layouts
grid columns: 3, gap: :md do
  card { text "Card 1" }
  card { text "Card 2" }
  card { text "Card 3" }
end
```

### Container Components

```ruby
# Cards with sections
card do
  card_header "Title"
  card_body do
    text "Content"
  end
  card_footer do
    button "Action"
  end
end

# Collapsible sections
collapsible "More Details", expanded: false do
  text "Hidden content"
end
```

### Navigation Components

```ruby
# Tabs
tabs :my_tabs, variant: :line do  # :line, :enclosed, :soft-rounded
  tab "First" do
    text "Tab 1 content"
  end
  tab "Second" do
    text "Tab 2 content"
  end
end

# Breadcrumbs
breadcrumbs separator: ">" do
  crumb "Home", href: "/"
  crumb "Products", href: "/products"
  crumb "Current"  # No href = current page
end

# Dropdowns
dropdown do
  trigger { button "Menu" }
  menu do
    menu_item "Edit" do |s|
      s[:action] = "edit"
    end
    menu_divider
    menu_item "Delete", style: :destructive do |s|
      s[:action] = "delete"
    end
  end
end
```

### Modal Dialogs

```ruby
# Open modal via button
button "Show Dialog" do |s|
  s[:confirm_open] = true
end

# Modal definition
modal :confirm, title: "Confirm", size: :sm do
  text "Are you sure?"

  modal_footer do
    button "Yes" do |s|
      s[:confirmed] = true
      s[:confirm_open] = false
    end
    button "Cancel", style: :secondary do |s|
      s[:confirm_open] = false
    end
  end
end
```

### Feedback Components

```ruby
# Alerts
alert(variant: :success) { text "Saved!" }
alert(variant: :error, title: "Error") { text "Failed to save" }

# Progress
progress_bar value: 75, show_label: true

# Spinner
spinner size: :md, label: "Loading..."

# Toasts (notifications)
toast_container position: :top_right

button "Save" do |s|
  show_toast("Saved successfully!", variant: :success)
end
```

### Charts

```ruby
bar_chart data: { "A" => 10, "B" => 20 }, title: "Sales"
line_chart labels: ["Jan", "Feb"], values: [10, 20]
pie_chart data: :chart_data  # From state
```

### Helper Module Pattern

Extend the DSL with custom methods:

```ruby
module MyHelpers
  def user_card(user)
    card do
      header3 user[:name]
      text user[:email]
    end
  end
end

app "Users", components: [MyHelpers] do
  state[:users].each do |user|
    user_card(user)
  end
end
```

## Summary: The Magic in 7 Steps

1. **You write a DSL block** - Ruby code that builds UI
2. **Block is stored in App** - Not executed immediately
3. **User interacts in browser** - Alpine.js captures, HTMX sends
4. **Server receives request** - Sinatra route handles it
5. **State is updated** - From form params or button callback
6. **DSL block re-executes** - `instance_eval(&@block)` with new state
7. **Fresh HTML returned** - HTMX swaps it in, loop continues

Your Ruby code IS the UI definition AND the event handlers. The framework handles the plumbing to make this seamless.
