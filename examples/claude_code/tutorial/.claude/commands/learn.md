# StreamWeaver Canvas Tutorial

A freeform, conversational tutorial where users explore StreamWeaver at their own pace. No fixed order—they ask questions, you generate and render examples dynamically.

## Quick Reference

**StreamWeaver Commands:**
```bash
streamweaver panel <session>           # Open panel (1x at start)
streamweaver canvas-push <session>     # Push DSL via heredoc
streamweaver canvas-wait <session>     # Wait for user input
streamweaver canvas-close <session>    # Cleanup (1x at end)
```

Use `learn` as the session name for all commands.

## How This Tutorial Works

1. **User asks naturally** - "Show me forms", "What charts are available?", "Make a dashboard"
2. **You explain briefly** - 2-3 sentences in terminal
3. **You render to canvas** - Show BOTH the DSL code AND the rendered output
4. **User iterates** - "Make it red", "Add another field", "Try something else"

The canvas shows code + output so users learn the DSL by seeing real examples.

---

## Phase 1: Welcome

### 1.1 Open Panel

```bash
streamweaver panel learn --fresh
```

### 1.2 Push Welcome

```bash
streamweaver canvas-push learn <<'DSL'
card do
  header1 "StreamWeaver Tutorial"
  md "Welcome! This is an interactive, freeform tutorial."
end

md "---"

card do
  header2 "How This Works"
  md <<-CONTENT
1. **Ask anything** in the terminal - components, patterns, or "just show me something"
2. **See code + output** here in the canvas
3. **Iterate** - "make it blue", "add more fields", "try charts instead"
4. **No fixed order** - explore what interests you
  CONTENT
end

md "---"

card do
  header3 "Topics You Can Explore"

  hstack spacing: :md do
    vstack do
      badge "COMPONENTS", variant: :info
      text "Forms, charts, tables, status indicators"
    end
    vstack do
      badge "PATTERNS", variant: :success
      text "Multi-step flows, dashboards, status pages"
    end
    vstack do
      badge "EXAMPLES", variant: :warning
      text "\"Show me a login form\", \"Make a dashboard\""
    end
  end
end

md "---"

text "Type your first question or request in the terminal..."
DSL
```

### 1.3 Tell User to Start

In terminal, say:
> The canvas is ready. What would you like to explore? Some ideas:
> - "Show me how text_field works"
> - "What chart options are there?"
> - "Make a dashboard with 3 stats"
> - Or describe anything you want to see

Wait for user input in the terminal conversation (not canvas-wait—this is conversational).

---

## Phase 2: Respond to Requests

When the user asks about something, follow this pattern:

### 2.1 Brief Explanation (Terminal)

Give a 2-3 sentence explanation of the component or pattern.

### 2.2 Generate & Push (Canvas)

Push DSL that shows BOTH the code AND the rendered output. Use this layout:

```bash
streamweaver canvas-push learn <<'DSL'
card do
  hstack justify: :between, align: :center do
    header1 "Component: text_field"
    badge "FORMS", variant: :info
  end
end

md "---"

header2 "DSL Code"

md <<-CODE
```ruby
text_field :email, placeholder: "you@example.com", label: "Email"
text_field :name, placeholder: "Your Name", label: "Name"
text_field :password, label: "Password"
```
CODE

md "---"

header2 "Rendered Output"

card do
  text_field :email, placeholder: "you@example.com", label: "Email"
  text_field :name, placeholder: "Your Name", label: "Name"
  text_field :password, label: "Password"
end

md "---"

text "Ask a follow-up, request modifications, or pick something else."
DSL
```

### 2.3 Offer Next Steps (Terminal)

Say something like:
> That's the basic text_field. You can ask:
> - "Add validation styling"
> - "Show me radio_group next"
> - "Make a complete login form"
> - Or anything else

---

## Component Examples

Use these as starting points. **Always show code + rendered output.**

### Forms

**text_field:**
```ruby
text_field :email, placeholder: "you@example.com", label: "Email"
```

**radio_group:**
```ruby
radio_group :plan, ["Free", "Pro", "Enterprise"], label: "Select Plan"
```

**checkbox:**
```ruby
checkbox :terms, "I agree to the terms"
```

**select:**
```ruby
select :country, ["United States", "Canada", "UK", "Other"], label: "Country"
```

**button:**
```ruby
button "Submit", id: "btn_submit", style: :primary
button "Cancel", id: "btn_cancel", style: :secondary
```

### Data Display

**table:**
```ruby
table headers: ["Name", "Role", "Status"],
      rows: [
        ["Alice", "Engineer", "Active"],
        ["Bob", "Designer", "Away"],
        ["Carol", "PM", "Active"]
      ],
      striped: true, hoverable: true
```

**bar_chart:**
```ruby
bar_chart data: { "Jan": 120, "Feb": 150, "Mar": 180, "Apr": 210 }
```

**pie_chart:**
```ruby
pie_chart data: { "Desktop": 55, "Mobile": 35, "Tablet": 10 }
```

**stat_display:**
```ruby
hstack spacing: :lg do
  stat_display value: 1234, label: "Users", color: :blue
  stat_display value: 89, label: "Active", color: :green
  stat_display value: 12, label: "Issues", color: :red
end
```

### Status Indicators

**status_dot:**
```ruby
status_dot status: :green, pulse: true, label: "ONLINE"
status_dot status: :yellow, pulse: false, label: "WARNING"
status_dot status: :red, pulse: true, label: "ERROR"
```

**progress_bar:**
```ruby
progress_bar value: 65, max: 100
```

**spinner:**
```ruby
spinner size: :lg, label: "Loading..."
```

**badge:**
```ruby
hstack spacing: :sm do
  badge "NEW", variant: :info
  badge "BETA", variant: :warning
  badge "DEPRECATED", variant: :danger
end
```

**alert:**
```ruby
alert variant: :success do
  header4 "Success!"
  text "Your changes have been saved."
end
```

### Layout

**card:**
```ruby
card do
  header2 "Card Title"
  text "Card content goes here."
end
```

**hstack/vstack:**
```ruby
hstack spacing: :md, justify: :between do
  text "Left"
  text "Right"
end

vstack spacing: :sm do
  text "Top"
  text "Bottom"
end
```

**columns:**
```ruby
columns widths: ['50%', '50%'] do
  column do
    text "Left column"
  end
  column do
    text "Right column"
  end
end
```

**collapsible:**
```ruby
collapsible "Click to expand", expanded: false do
  text "Hidden content here"
end
```

---

## Pattern Examples

### Login Form

```ruby
card do
  header1 "Sign In"
  text_field :email, placeholder: "you@example.com", label: "Email"
  text_field :password, label: "Password"
  checkbox :remember, "Remember me"
  button "Sign In", id: "btn_login", style: :primary
end
```

### Dashboard with Stats

```ruby
header1 "Dashboard"

hstack spacing: :lg, justify: :around do
  stat_display value: 1234, label: "Total Users", color: :blue
  stat_display value: 89, label: "Active Now", color: :green
  stat_display value: 12, label: "Issues", color: :red
end

md "---"

columns widths: ['60%', '40%'] do
  column do
    header3 "Traffic This Week"
    bar_chart data: { "Mon": 120, "Tue": 150, "Wed": 180, "Thu": 140, "Fri": 200 }
  end
  column do
    header3 "Device Distribution"
    pie_chart data: { "Desktop": 55, "Mobile": 35, "Tablet": 10 }
  end
end
```

### Status Page

```ruby
card do
  hstack justify: :between, align: :center do
    header1 "System Status"
    badge "OPERATIONAL", variant: :success
  end
end

md "---"

vstack spacing: :md do
  hstack justify: :between do
    text "API Server"
    status_dot status: :green, label: "Healthy"
  end
  hstack justify: :between do
    text "Database"
    status_dot status: :green, label: "Healthy"
  end
  hstack justify: :between do
    text "Cache"
    status_dot status: :yellow, label: "Degraded"
  end
  hstack justify: :between do
    text "Search"
    status_dot status: :green, label: "Healthy"
  end
end
```

### Multi-Step Progress

```ruby
card do
  header1 "Setup Progress"
  progress_bar value: 2, max: 4

  hstack spacing: :lg, justify: :around do
    vstack align: :center do
      badge "1", variant: :success
      text "Account"
    end
    vstack align: :center do
      badge "2", variant: :success
      text "Profile"
    end
    vstack align: :center do
      badge "3", variant: :info
      text "Settings"
    end
    vstack align: :center do
      badge "4", variant: :default
      text "Done"
    end
  end
end
```

---

## Handling Modifications

When user asks to modify something ("make it blue", "add another field"):

1. Acknowledge the request in terminal
2. Regenerate the DSL with the changes
3. Push updated canvas showing new code + output

Example:
> User: "Add a phone number field"
> You: "Adding phone number field to the form."
> [Push updated DSL with phone field added]

---

## Ending the Tutorial

When user says they're done, or asks to finish:

1. Thank them in terminal
2. Push a closing message to canvas
3. Close the panel

```bash
streamweaver canvas-push learn <<'DSL'
card do
  header1 "Tutorial Complete"
  md "Thanks for exploring StreamWeaver!"
  md "**Next steps:**"
  md "- Check out the [examples](https://github.com/...) for more patterns"
  md "- Try building your own canvas workflow"
  md "- Read the full DSL reference"
end
DSL
```

Wait a moment, then close:

```bash
streamweaver canvas-close learn
```

---

## Key Principles

1. **Conversational** - User talks naturally, you respond dynamically
2. **Code + Output** - Always show both DSL and rendered result
3. **Brief explanations** - Terminal text is concise; let canvas do the showing
4. **No wrong questions** - Generate examples for whatever they ask
5. **Iterative** - Encourage modifications and follow-ups
6. **Real data** - Use realistic example data, not lorem ipsum
