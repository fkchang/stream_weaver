# Weaving Web UIs with Ruby: A StreamWeaver Introduction

*Build reactive web interfaces with pure Ruby—no JavaScript required.*

![StreamWeaver Hero](/images/heros/streamweaver-hero.png)
<!-- Hero image: Terminal showing StreamWeaver app code on left, browser with running app on right -->

## A Personal Confession

I've spent more hours than I care to admit building internal tools. Dashboards for monitoring. Forms for data entry. Quick interfaces to wrap API calls. Every time, the same friction: set up a JavaScript build pipeline, configure a frontend framework, wire up API endpoints, manage state synchronization between client and server.

For a "simple" tool.

Python developers had Streamlit. They could write a script, sprinkle in some UI components, and have a working web app in minutes. Meanwhile, Ruby developers—blessed with one of the most expressive languages ever created—were still configuring Webpack.

StreamWeaver changes that. It's Streamlit's ease of use, brought to Ruby with a DSL that feels like it belongs in the language.

## What is StreamWeaver?

StreamWeaver is a Ruby DSL for building reactive web UIs with minimal code. Write your interface in pure Ruby. Run the script. A browser opens with your working application.

```ruby
require 'stream_weaver'

app "Hello World" do
  text_field :name, placeholder: "What's your name?"

  if state[:name].to_s.strip != ""
    text "Hello, #{state[:name]}!"
  end
end.run!
```

![Hello World Example](/images/streamweaver/hello-world.png)
<!-- Screenshot: Browser showing text input and greeting -->

That's it. No HTML templates. No JavaScript. No build step. No webpack. No npm. Just Ruby.

## The Key Insight

Here's the magic that makes StreamWeaver tick:

**Your Ruby block re-executes on every user interaction.**

When a user types in a text field, clicks a button, or changes a selection, your entire block runs again with the updated state. This creates reactive UI without you writing any event handling code.

```ruby
app "Counter" do
  state[:count] ||= 0

  text "Count: #{state[:count]}"

  button "+" do |s|
    s[:count] += 1
  end

  button "-" do |s|
    s[:count] -= 1
  end
end.run!
```

![Counter Example](/images/streamweaver/counter.png)
<!-- Screenshot: Counter UI with + and - buttons -->

Click the "+" button:
1. The callback runs: `s[:count] += 1`
2. Your entire block re-executes
3. `text "Count: #{state[:count]}"` now shows the new value
4. The browser updates automatically

No manual DOM manipulation. No state synchronization. No WebSocket configuration. StreamWeaver handles all of it.

## Why Ruby Needs This

Ruby's philosophy has always been developer happiness. We optimize for expressiveness, readability, and joy. Rails brought this philosophy to web applications. Hotwire brought it to interactive features.

But there's a gap. When you need a quick internal tool, a prototype, or a simple UI for a script—Rails is overkill. You don't need models, migrations, and a full MVC stack for a form that calls an API.

StreamWeaver fills that gap:

| Need | Traditional Approach | StreamWeaver |
|------|---------------------|--------------|
| Quick form UI | Rails scaffold + views + JS | 10 lines of Ruby |
| Data dashboard | React app + API | Single Ruby file |
| Script with UI | CLI flags or Tk | Declarative DSL |
| Prototype | Full stack setup | Immediate iteration |

### The GenAI Advantage

We're in an era where AI assistants write significant portions of our code. Token efficiency matters. The more concise your DSL, the more the AI can accomplish in a single context window.

StreamWeaver's declarative approach is token-efficient by design. Instead of describing separate model, view, controller, and JavaScript layers, you describe the UI once. The AI (and you) can iterate faster.

## The Component Library

StreamWeaver provides all the building blocks you need for real applications.

### Input Components

```ruby
app "Form Demo" do
  text_field :name, placeholder: "Your name"
  text_area :bio, rows: 4, placeholder: "Tell us about yourself"
  checkbox :newsletter, "Subscribe to newsletter"
  select :role, ["Developer", "Designer", "Manager"]
  radio_group :priority, ["Low", "Medium", "High"]
end.run!
```

![Form Components](/images/streamweaver/form-components.png)
<!-- Screenshot: Form with all input types displayed -->

Each component automatically binds to `state[:key]`. When the user types in `text_field :name`, the value is available as `state[:name]`.

### Display Components

```ruby
app "Display Demo" do
  header1 "Page Title"
  header "Section Header"
  header3 "Subsection"

  text "Plain text with interpolation: #{Time.now}"
  md "**Markdown** support with *formatting* and `code`"
end.run!
```

![Display Components](/images/streamweaver/display-components.png)
<!-- Screenshot: Various header sizes and text styles -->

### Buttons & Actions

```ruby
app "Actions" do
  state[:message] ||= "Click a button"

  text state[:message]

  button "Primary Action" do |s|
    s[:message] = "Primary clicked!"
  end

  button "Secondary", style: :secondary do |s|
    s[:message] = "Secondary clicked!"
  end

  button "Danger", style: :danger do |s|
    s[:message] = "Danger clicked!"
  end
end.run!
```

![Button Styles](/images/streamweaver/buttons.png)
<!-- Screenshot: Three button styles in a row -->

### Layout Components

StreamWeaver provides flexible layout primitives:

```ruby
app "Layout Demo" do
  columns widths: ['30%', '70%'] do
    column do
      card do
        header3 "Sidebar"
        text "Navigation goes here"
      end
    end

    column do
      vstack spacing: :md do
        card do
          header3 "Main Content"
          text "Your primary content area"
        end

        hstack spacing: :sm do
          button "Save"
          button "Cancel", style: :secondary
        end
      end
    end
  end
end.run!
```

![Layout Example](/images/streamweaver/layout.png)
<!-- Screenshot: Two-column layout with sidebar and main content -->

**Layout primitives:**
- `columns` - Multi-column layouts with custom widths
- `vstack` - Vertical stacking with spacing
- `hstack` - Horizontal stacking with spacing
- `card` - Bordered container with padding

### Modals & Dialogs

```ruby
app "Modal Demo" do
  button "Open Settings" do |s|
    s[:settings_open] = true
  end

  modal :settings, title: "Settings", size: :lg do
    text_field :api_key, placeholder: "Enter API key"
    checkbox :dark_mode, "Enable dark mode"

    modal_footer do
      button "Save" do |s|
        s[:settings_open] = false
        # Save logic here
      end
      button "Cancel", style: :secondary do |s|
        s[:settings_open] = false
      end
    end
  end
end.run!
```

![Modal Example](/images/streamweaver/modal.png)
<!-- Screenshot: Open modal dialog over main content -->

### Feedback Components

```ruby
app "Feedback Demo" do
  state[:status] ||= nil

  button "Submit" do |s|
    # Simulate operation
    s[:status] = rand > 0.5 ? :success : :error
  end

  case state[:status]
  when :success
    alert(variant: :success) { text "Operation completed successfully!" }
  when :error
    alert(variant: :error) { text "Something went wrong. Please try again." }
  end
end.run!
```

![Alert Variants](/images/streamweaver/alerts.png)
<!-- Screenshot: Success and error alerts -->

**Alert variants:** `:info`, `:success`, `:warning`, `:error`

## Common Patterns

### Conditional Display

Show different UI based on state—a pattern that feels natural in Ruby:

```ruby
app "Login Flow" do
  if state[:authenticated]
    text "Welcome back, #{state[:username]}!"

    button "Logout" do |s|
      s[:authenticated] = false
      s[:username] = nil
    end
  else
    text_field :username, placeholder: "Username"
    text_field :password, placeholder: "Password"

    button "Login" do |s|
      # Validate credentials
      s[:authenticated] = true
    end
  end
end.run!
```

![Login Flow](/images/streamweaver/login-flow.png)
<!-- Screenshot: Side-by-side of logged out and logged in states -->

### Dynamic Lists

Build, modify, and display lists with standard Ruby iteration:

```ruby
app "Todo List" do
  state[:todos] ||= []

  text_field :new_todo, placeholder: "What needs doing?"

  button "Add" do |s|
    if s[:new_todo].to_s.strip != ""
      s[:todos] << { text: s[:new_todo], done: false }
      s[:new_todo] = ""
    end
  end

  state[:todos].each_with_index do |todo, i|
    hstack do
      checkbox :"done_#{i}", "" do |s, checked|
        s[:todos][i][:done] = checked
      end

      text todo[:text],
        style: todo[:done] ? "text-decoration: line-through; opacity: 0.6" : ""

      button "X", style: :danger, size: :sm do |s|
        s[:todos].delete_at(i)
      end
    end
  end

  if state[:todos].any?
    text "#{state[:todos].count { |t| t[:done] }} of #{state[:todos].size} completed"
  end
end.run!
```

![Todo List](/images/streamweaver/todo-list.png)
<!-- Screenshot: Todo list with items in various states -->

### Multi-Step Wizards

Guide users through complex flows:

```ruby
app "Setup Wizard" do
  state[:step] ||= 1

  case state[:step]
  when 1
    header "Step 1: Account"
    text_field :email, placeholder: "Email"
    text_field :name, placeholder: "Full name"

    button "Next" do |s|
      s[:step] = 2
    end

  when 2
    header "Step 2: Preferences"
    select :theme, ["Light", "Dark", "System"]
    checkbox :notifications, "Enable notifications"

    hstack do
      button "Back", style: :secondary do |s|
        s[:step] = 1
      end
      button "Next" do |s|
        s[:step] = 3
      end
    end

  when 3
    header "Step 3: Confirm"
    text "Email: #{state[:email]}"
    text "Name: #{state[:name]}"
    text "Theme: #{state[:theme]}"
    text "Notifications: #{state[:notifications] ? 'Yes' : 'No'}"

    hstack do
      button "Back", style: :secondary do |s|
        s[:step] = 2
      end
      button "Complete Setup" do |s|
        s[:complete] = true
      end
    end
  end

  if state[:complete]
    alert(variant: :success) { text "Setup complete! Welcome aboard." }
  end
end.run!
```

![Wizard Flow](/images/streamweaver/wizard.png)
<!-- Screenshot: Multi-step wizard showing step 2 -->

## Agentic Mode: One-Shot UIs

StreamWeaver isn't just for persistent applications. It excels at one-shot UIs where you need user input mid-script:

```ruby
# Script that needs user input
result = app "Quick Survey" do
  header "Before we continue..."

  text_field :project_name, placeholder: "Project name"
  select :priority, ["Low", "Medium", "High", "Critical"]
  text_area :notes, placeholder: "Any additional notes?"
end.run_once!(auto_close_window: true)

# Script continues with the data
puts "Creating project: #{result['project_name']}"
puts "Priority: #{result['priority']}"
```

![Agentic Mode](/images/streamweaver/agentic.png)
<!-- Screenshot: One-shot form in browser -->

The browser opens, the user fills the form, submits, and the window closes. Your script receives a hash of the form values and continues execution.

This is particularly powerful for AI agents that need human input mid-task—configuration, confirmation, or parameter selection.

## App Configuration

Customize your app's appearance:

```ruby
app "Dashboard",
  layout: :wide,           # :default, :wide, :full, :fluid
  theme: :dashboard        # :default, :dashboard, :document
do
  # Wide layout for data-heavy interfaces
  # ...
end.run!
```

![Layout Options](/images/streamweaver/layouts.png)
<!-- Screenshot: Side-by-side of default and wide layouts -->

## Under the Hood

StreamWeaver's architecture is intentionally simple:

- **Backend:** Sinatra server handles requests
- **Rendering:** Phlex generates HTML
- **Reactivity:** Alpine.js manages client-side state
- **Updates:** HTMX swaps content on state changes
- **State:** Server-side, persisted in session cookies

When a user interacts with the UI:
1. HTMX sends a request with the new state
2. Sinatra receives and stores the state
3. Your Ruby block re-executes with updated state
4. Phlex renders new HTML
5. HTMX swaps the content in the browser

No WebSocket complexity. No client-side state management. Just HTTP and HTML—the technologies that have powered the web for 30 years.

## Installation

Add to your Gemfile:

```ruby
gem 'stream_weaver'
```

Or install directly:

```bash
gem install stream_weaver
```

**Requirements:** Ruby 3.1+

## Source Code

StreamWeaver is open source and available on GitHub:

| Resource | Link |
|----------|------|
| GitHub | [github.com/fkchang/stream_weaver](https://github.com/fkchang/stream_weaver) |
| Documentation | `docs/` directory |
| Examples | `examples/` directory |

## What's Next

StreamWeaver is actively developed. On the roadmap:

- **Charts integration** - Data visualization components
- **Table component** - Sortable, filterable data tables
- **File upload** - Drag-and-drop file handling
- **Service mode** - Run multiple apps from a single server
- **Theming system** - Custom CSS and color schemes

## Let's Build Together

I built StreamWeaver because I wanted the joy of Ruby for every interface I create—not just the ones worth setting up a full stack for.

If you share that vision, I'd love your input:

- **Try it** - Build something, however small
- **Break it** - File issues when things don't work
- **Extend it** - PRs welcome for new components
- **Share it** - Show what you've built

The best DSLs emerge from real use. Every dashboard you build, every tool you create, every experiment you run helps shape what StreamWeaver becomes.

## A Renaissance in Ruby Tooling

StreamWeaver joins a wave of projects making Ruby development more delightful:

- **Hotwire** - Interactive features without JavaScript
- **Phlex** - Type-safe HTML generation
- **Charm Ruby** - Beautiful terminal UIs
- **Prism** - Modern Ruby parser

Ruby isn't just surviving—it's thriving. We're building the tools we've always wanted, with the expressiveness we've always loved.

StreamWeaver is my contribution to that renaissance. I hope it saves you the hours I've spent on internal tools, and lets you focus on what matters: the problems you're solving, not the frameworks you're configuring.

Now go build something beautiful.

---

*StreamWeaver: Reactive Ruby UIs. No JavaScript required.*

```ruby
require 'stream_weaver'

app "Your App" do
  # Your beautiful UI here
end.run!
```
