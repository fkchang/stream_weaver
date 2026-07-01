# Skill Specification: `streamweaver-claude-code-companion`

**Author:** Forrest Chang  
**Date:** May 2026  
**Status:** Specification — Not Yet Implemented as SKILL.md  
**Purpose:** Define the behavior, templates, and guidance for a Hermes skill that enables Claude Code to use StreamWeaver's canvas as a live visual companion during coding sessions.

> **Note:** This document is the spec. The actual `SKILL.md` for the `streamweaver-claude-code-companion` skill gets written after this spec is validated through real use.

---

## Overview

When developers use Claude Code for complex work — explaining architectures, refactoring code, visualizing data flows, building step-by-step tutorials — a live visual pane alongside the terminal makes the experience dramatically richer. This skill teaches Claude Code to use StreamWeaver's canvas as that visual companion, pushing DSL-based renderings in real time.

The result feels like a Claude HTML artifact, but it's live, reactive, and persistent across the entire coding session.

---

## How the Setup Works

### The iTerm2 Split Panel

StreamWeaver's `iterm.rb` uses the `iterm2_ruby` gem to:
1. Split the current iTerm2 pane vertically
2. Open a browser (or `webview` pane) pointing at the canvas URL
3. Keep that pane persistent across the session

**Command:**
```bash
streamweaver panel <session_name>
```

This splits iTerm, opens the browser in the new pane, and the canvas is ready to receive pushes.

### Pushing Updates

```bash
streamweaver canvas-push <session_name> path/to/canvas.rb
# OR via inline DSL:
streamweaver canvas-push <session_name> --dsl "$(cat << 'EOF'
header1 "Hello World"
md "This is **live** content"
EOF
)"
```

Every push replaces the canvas content — no page refresh, morphdom-patched in place.

### Session Flow

```
1. User starts session:   streamweaver panel my-session
2. Browser pane opens:    http://localhost:4567/canvas/my-session
3. Claude Code works:     writes code, explains concepts
4. Claude Code pushes:    streamweaver canvas-push my-session <dsl>
5. Browser updates live:  user sees visual companion update
```

---

## When to Activate

Claude Code should proactively use the canvas companion (once a panel session is established) when:

### Automatic Triggers
- User asks to **explain something complex** — algorithm, architecture pattern, data flow
- User asks to **compare approaches** — "what's better, X or Y?"
- User asks to **show architecture** — system design, module dependencies, call flows
- User asks to **visualize data** — metrics, datasets, before/after comparisons
- User asks to **walk through step by step** — tutorial, onboarding, migration guide
- Any time a **diagram or mockup** would communicate better than text alone
- When **refactoring** — show the before/after side by side
- When **explaining a data model** — table schemas, relationship diagrams

### Passive Triggers
- When an explanation runs longer than ~4 paragraphs of text — "let me show you this visually"
- When the user seems confused and is asking follow-up questions
- When comparing more than 2 options (a comparison visual helps)
- When explaining something with multiple sequential steps

### Do NOT Activate For
- Simple one-line answers
- File editing operations
- Git commands
- Package installs
- Anything where a visual would be gratuitous

---

## Setup Steps (First Time in a Session)

### Step 1: Start the Panel
```bash
streamweaver panel <session_name>
# Suggested naming: use the project or topic, e.g.:
streamweaver panel auth-refactor
streamweaver panel neural-net-explainer
streamweaver panel api-design-review
```

### Step 2: Verify the Canvas is Live
```bash
# The panel command outputs the URL — export it:
export SW_CANVAS_URL="http://localhost:4567/canvas/<session_name>"
export SW_CANVAS_SESSION="<session_name>"
```

### Step 3: Push an Orientation Header
```bash
streamweaver canvas-push $SW_CANVAS_SESSION --dsl "$(cat << 'EOF'
theme_preset :technical
hero do
  header1 "Session: Auth Refactor"
  md "Visual companion for this coding session"
end
EOF
)"
```

### Step 4: Use canvas-push for Every Visual
From here, every explanation, diagram, or dashboard gets pushed to this persistent pane.

---

## The "Explain" Pattern

The canonical composite template for rich explanations. Chains components in this order:

```
callout (the key insight, what to remember)
  ↓
code_block (the implementation, the "how")
  ↓
comparison OR pipeline (before/after OR the flow)
  ↓
mermaid (architecture, if relevant)
```

This mirrors what people love about Claude HTML artifacts — layered context with visual rhythm — but in the StreamWeaver DSL, which means it's live and reactive, not static HTML.

### Why This Order
1. **Callout first** — leads with the "aha" moment. User immediately knows the key takeaway.
2. **Code second** — shows the concrete implementation after the concept is framed.
3. **Comparison/pipeline** — shows where this fits (before/after or in a flow).
4. **Mermaid last** — architecture diagrams make more sense after you've seen the code.

---

## Aesthetic Guidance: The "Premium Dark Artifact" Look

### Recommended Theme
```ruby
theme_preset :technical
```
`:technical` gives a dark, dense look. Pair with targeted inline styles for the full gradient aesthetic.

### Gradient Text Headings
No native gradient heading component yet (it's on the roadmap). Do it with an inline-styled `div`:
```ruby
div(style: "font-size: 2.5rem; font-weight: 800; background: linear-gradient(135deg, #a78bfa, #60a5fa, #34d399); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 1rem;") do
  text "Your Heading"
end
```

### Glassmorphism Card
```ruby
card(style: "background: rgba(255,255,255,0.05); backdrop-filter: blur(20px); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 24px;") do
  # content
end
```

### Dark Background Container
```ruby
div(style: "background: #0f0f23; min-height: 100vh; padding: 40px;") do
  # all content here
end
```

### Accent Borders
```ruby
div(style: "border-left: 3px solid #a78bfa; padding-left: 16px; margin: 16px 0;") do
  md "Key insight highlighted with a purple accent bar"
end
```

### Full "Artifact" Wrapper (Combine It All)
```ruby
theme_preset :technical
div(style: "background: linear-gradient(135deg, #0a0a1a 0%, #1a1a2e 50%, #0f0f23 100%); min-height: 100vh; padding: 40px; font-family: 'Inter', system-ui, sans-serif;") do
  # your content — cards, headers, code, charts
end
```

---

## Quick-Copy DSL Templates

### 1. Concept Explainer
```ruby
theme_preset :technical

div(style: "background: #0f0f23; padding: 40px; min-height: 100vh;") do
  div(style: "font-size: 2rem; font-weight: 800; background: linear-gradient(135deg, #a78bfa, #60a5fa); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 24px;") do
    text "Concept: [NAME]"
  end

  callout(:tip) do
    md "**Key insight:** [One sentence that captures the core idea]"
  end

  div(style: "height: 16px;")  # spacer — no spacer component yet

  code_block(language: :ruby) do
    <<~RUBY
      # The implementation
      def example
        "put real code here"
      end
    RUBY
  end

  div(style: "height: 16px;")

  comparison do
    slot(:before) do
      header4 "Before"
      code_block(language: :ruby) { "old_approach()" }
    end
    slot(:after) do
      header4 "After"
      code_block(language: :ruby) { "new_approach()" }
    end
  end
end
```

### 2. Architecture Diagram
```ruby
theme_preset :technical

div(style: "background: #0f0f23; padding: 40px;") do
  div(style: "font-size: 2rem; font-weight: 800; background: linear-gradient(135deg, #a78bfa, #60a5fa); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 24px;") do
    text "Architecture: [SYSTEM NAME]"
  end

  callout(:info) do
    md "**Design principle:** [Why this architecture makes sense]"
  end

  div(style: "height: 16px;")

  mermaid(zoom: true) do
    <<~MERMAID
      graph TB
        A[Client] --> B[API Gateway]
        B --> C[Auth Service]
        B --> D[Core Service]
        D --> E[(Database)]
        C --> E
    MERMAID
  end

  div(style: "height: 16px;")

  callout(:warning) do
    md "**Watch out for:** [Tradeoffs or gotchas]"
  end
end
```

### 3. Step-by-Step Tutorial
```ruby
theme_preset :technical

div(style: "background: #0f0f23; padding: 40px;") do
  header2 "Tutorial: [TOPIC]"

  div(style: "height: 16px;")

  progress_bar(value: 33, label: "Step 1 of 3", animated: true,
               style: "accent-color: #a78bfa;")

  div(style: "height: 16px;")

  slide_container(mode: :swap) do
    slide do
      card(style: "background: rgba(255,255,255,0.05); border-radius: 12px; padding: 24px; border: 1px solid rgba(167,139,250,0.3);") do
        header3 "Step 1: [Title]"
        md "[Explanation of step 1]"
        code_block(language: :ruby) { "# step 1 code" }
      end
    end

    slide do
      card(style: "background: rgba(255,255,255,0.05); border-radius: 12px; padding: 24px; border: 1px solid rgba(96,165,250,0.3);") do
        header3 "Step 2: [Title]"
        md "[Explanation of step 2]"
        code_block(language: :ruby) { "# step 2 code" }
      end
    end

    slide do
      card(style: "background: rgba(255,255,255,0.05); border-radius: 12px; padding: 24px; border: 1px solid rgba(52,211,153,0.3);") do
        header3 "Step 3: [Title]"
        md "[Explanation of step 3]"
        code_block(language: :ruby) { "# step 3 code" }
      end
    end
  end

  keyboard_shortcuts  # enables left/right arrow navigation
end
```

### 4. Dashboard / Metrics
```ruby
theme_preset :technical

div(style: "background: #0f0f23; padding: 40px;") do
  header2 "Metrics: [SYSTEM NAME]"
  div(style: "height: 16px;")

  kpi_dashboard(metrics: [
    { label: "Total Requests", value: "1.2M", trend: "+12%", trend_direction: :up },
    { label: "Error Rate", value: "0.03%", trend: "-0.01%", trend_direction: :down },
    { label: "Avg Latency", value: "42ms", trend: "+2ms", trend_direction: :neutral },
    { label: "Uptime", value: "99.97%", trend: "30d", trend_direction: :up }
  ])

  div(style: "height: 24px;")

  hstack do
    chart(type: :line, data: {
      labels: ["Jan", "Feb", "Mar", "Apr", "May"],
      datasets: [{ label: "Requests", data: [800, 950, 1100, 1050, 1200] }]
    }, style: "flex: 1;")

    div(style: "width: 24px;")  # gap

    chart(type: :doughnut, data: {
      labels: ["2xx", "4xx", "5xx"],
      datasets: [{ data: [94, 5, 1] }]
    }, style: "flex: 1; max-width: 300px;")
  end

  div(style: "height: 24px;")

  table(headers: ["Endpoint", "Calls", "P99 Latency", "Errors"],
        rows: [
          ["/api/users", "420K", "38ms", "0.02%"],
          ["/api/orders", "380K", "55ms", "0.04%"],
          ["/api/search", "400K", "120ms", "0.01%"]
        ])
end
```

### 5. Before/After Refactor
```ruby
theme_preset :technical

div(style: "background: #0f0f23; padding: 40px;") do
  div(style: "font-size: 2rem; font-weight: 800; background: linear-gradient(135deg, #f87171, #a78bfa); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 8px;") do
    text "Refactor: [WHAT CHANGED]"
  end

  callout(:tip) do
    md "**Why this change:** [The motivation — performance, readability, correctness]"
  end

  div(style: "height: 24px;")

  comparison do
    slot(:before) do
      card(style: "background: rgba(248,113,113,0.05); border: 1px solid rgba(248,113,113,0.2); border-radius: 12px; padding: 20px;") do
        header4 "❌ Before"
        code_block(language: :ruby) do
          <<~RUBY
            # The old way
            # problems: [list them]
            def old_method
              "old implementation"
            end
          RUBY
        end
      end
    end

    slot(:after) do
      card(style: "background: rgba(52,211,153,0.05); border: 1px solid rgba(52,211,153,0.2); border-radius: 12px; padding: 20px;") do
        header4 "✅ After"
        code_block(language: :ruby) do
          <<~RUBY
            # The new way
            # benefits: [list them]
            def new_method
              "new implementation"
            end
          RUBY
        end
      end
    end
  end

  div(style: "height: 16px;")

  callout(:success) do
    md "**Result:** [Measurable improvement — faster, cleaner, safer]"
  end
end
```

---

## Gotchas and Rules

These are hard-won lessons — follow them or things break:

### ⚠️ No `spacer` or `divider` Component
They don't exist. For vertical spacing, use:
```ruby
div(style: "height: 16px;")   # or 8px, 24px, 32px
```
For horizontal rules / dividers:
```ruby
div(style: "border-top: 1px solid rgba(255,255,255,0.1); margin: 24px 0;")
```

### ⚠️ Use `md` Not `text` for Markdown Content
`text` renders plain text. `md` (or `markdown`) renders Markdown with bold, italic, links, lists, etc.
```ruby
# WRONG:
text "This has **bold** that won't render"

# RIGHT:
md "This has **bold** that renders correctly"
```

### ⚠️ Never Launch a Standalone Server
Don't generate DSL that includes:
- `StreamWeaver::Server.start`
- `Sinatra::Application.run!`
- Any `require 'webrick'` or direct server-start code

The canvas server is already running. Use `canvas-push` to update it.

### ⚠️ `canvas-push` Only — No File-Based Serving
Always push to the persistent canvas session:
```bash
streamweaver canvas-push <session> <dsl_file>
```
Don't try to open new browser windows, don't serve files directly, don't assume the user wants to navigate away from the panel pane.

### ⚠️ `theme_preset` Must Be at the Top
```ruby
# RIGHT — theme_preset is the first thing:
theme_preset :technical
div do
  # content
end

# WRONG — theme_preset after content may not apply correctly:
div do
  theme_preset :technical  # too late
  # content
end
```

### ⚠️ Inline `style:` Strings Must Be Valid CSS
The `style:` param on any component passes through directly to the HTML `style` attribute. A syntax error will silently fail to apply. Double-check property names and semicolons.

### ⚠️ `comparison` Slots Are Named `:before` / `:after`
```ruby
comparison do
  slot(:before) { ... }   # correct
  slot(:after)  { ... }   # correct
  # NOT: slot(:left), slot(:right), slot(:one), slot(:two)
end
```

### ⚠️ `slide_container` Needs `keyboard_shortcuts` for Arrow Nav
```ruby
slide_container(mode: :swap) do
  slide { ... }
  slide { ... }
end
keyboard_shortcuts   # add this! otherwise no keyboard navigation
```

---

## Example: Full Session Script

Here's what a Claude Code session might look like when the skill is active:

```
User: "Explain how our auth middleware chain works"

Claude Code:
1. Reads the middleware files
2. Pushes this to canvas:
```

```ruby
theme_preset :technical
div(style: "background: #0f0f23; padding: 40px;") do
  div(style: "font-size: 2rem; font-weight: 800; background: linear-gradient(135deg, #a78bfa, #60a5fa); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 24px;") do
    text "Auth Middleware Chain"
  end

  callout(:info) do
    md "**How it works:** Each request passes through 3 middleware layers before hitting your controller. Each layer can halt the chain by returning early."
  end

  div(style: "height: 16px;")

  mermaid(zoom: true) do
    <<~MERMAID
      sequenceDiagram
        participant C as Client
        participant T as TokenValidator
        participant P as PermissionCheck
        participant R as RateLimiter
        participant Ctrl as Controller

        C->>T: Request + Bearer token
        T-->>C: 401 if invalid
        T->>P: Validated identity
        P-->>C: 403 if insufficient role
        P->>R: Authorized user
        R-->>C: 429 if rate exceeded
        R->>Ctrl: Clean request
        Ctrl-->>C: Response
    MERMAID
  end

  div(style: "height: 16px;")

  code_block(language: :ruby) do
    <<~RUBY
      # config/middleware.rb
      use TokenValidator      # Layer 1: Is this token real?
      use PermissionCheck     # Layer 2: Can this user do this?
      use RateLimiter         # Layer 3: Are they hitting us too fast?
    RUBY
  end
end
```

```
3. Continues the text explanation in the terminal, pointing to the visual
```

---

## Skill Identity (For Future SKILL.md)

When this spec is validated and ready to be formalized:

- **Skill name:** `streamweaver-claude-code-companion`
- **Trigger phrases:** "explain", "show me", "visualize", "diagram", "architecture", "compare", "step by step", "walk me through"
- **Required context:** `SW_CANVAS_SESSION` env var set, `streamweaver panel` running
- **Primary tool:** `streamweaver canvas-push`
- **Templates to include:** All five quick-copy templates from this spec
- **Aesthetic default:** `theme_preset :technical` + dark gradient wrapper

The SKILL.md will be written by converting this specification into the Hermes skill format, with the templates as literal snippet blocks Claude Code can emit directly.
