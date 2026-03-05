# PLAN: shadcn Polish for StreamWeaver

**Goal:** Get shadcn/ui-level visual polish in StreamWeaver components, with optional Tailwind mode for full fidelity.

**Reference:** `docs/ruby-ui-comparison.md` for full gap analysis.
**RubyUI source:** `~/work/ruby_ui/` (gem), `~/work/ruby_ui_web/` (docs/CSS)

---

## Phase 1: shadcn Token Layer + Dark Mode

**Outcome:** All existing components gain consistent colors, dark mode, and visual polish. Zero breaking changes.

### 1.1 Create `shadcn_tokens.css`

Add to StreamWeaver's base CSS output. This defines the semantic color system that both pure CSS and Tailwind modes will share.

**Location:** `lib/stream_weaver/assets/shadcn_tokens.css`

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --destructive-foreground: #fff;
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --radius: 0.5rem;
  --warning: hsl(38 92% 50%);
  --warning-foreground: #fff;
  --success: hsl(87 100% 37%);
  --success-foreground: #fff;
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.205 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.205 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.922 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --secondary: oklch(0.269 0 0);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.269 0 0);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.704 0.191 22.216);
  --destructive-foreground: oklch(0.637 0.237 25.331);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.556 0 0);
}
```

**Integration with existing Theme system:**

Update `Theme::VARIABLE_SCHEMA` to map existing `--sw-` vars to shadcn tokens. When a StreamWeaver theme sets `color_primary`, it should also update `--primary`. This can be done in the CSS output:

```css
:root {
  --primary: var(--sw-color-primary, oklch(0.205 0 0));
  --background: var(--sw-color-bg, oklch(1 0 0));
  /* etc — shadcn tokens fall back to SW vars if set, else default */
}
```

### 1.2 Create `shadcn_base.css`

Global base styles that give everything the shadcn feel.

**Location:** `lib/stream_weaver/assets/shadcn_base.css`

```css
/* Base reset for shadcn consistency */
*, *::before, *::after {
  border-color: var(--border);
}

body {
  background-color: var(--background);
  color: var(--foreground);
}

/* Shared interactive states */
.sw-interactive {
  transition: color 0.15s ease, background-color 0.15s ease,
              border-color 0.15s ease, box-shadow 0.15s ease;
}

.sw-interactive:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px var(--background), 0 0 0 4px var(--ring);
}

.sw-interactive:disabled,
.sw-interactive[aria-disabled="true"] {
  opacity: 0.5;
  pointer-events: none;
  cursor: not-allowed;
}
```

### 1.3 Update Component CSS

Migrate existing component styles from hardcoded colors to semantic tokens. Example diffs:

**Button (before):**
```css
.sw-button { background: var(--sw-color-primary); color: #fff; border-radius: var(--sw-radius-md); }
.sw-button:hover { background: var(--sw-color-primary-hover); }
```

**Button (after):**
```css
.sw-button {
  display: inline-flex; align-items: center; justify-content: center;
  border-radius: var(--radius);
  font-weight: 500; font-size: 0.875rem;
  height: 2.25rem; padding: 0.5rem 1rem;
  transition: color 0.15s, background-color 0.15s;
}
.sw-button:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px var(--background), 0 0 0 4px var(--ring);
}
.sw-button:disabled { opacity: 0.5; pointer-events: none; }

.sw-button--primary { background: var(--primary); color: var(--primary-foreground); }
.sw-button--primary:hover { filter: brightness(1.1); }

.sw-button--secondary { background: var(--secondary); color: var(--secondary-foreground); }
.sw-button--secondary:hover { filter: brightness(0.95); }

.sw-button--destructive { background: var(--destructive); color: var(--destructive-foreground); }
.sw-button--destructive:hover { filter: brightness(1.1); }

.sw-button--outline {
  background: var(--background); color: var(--foreground);
  border: 1px solid var(--input); box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}
.sw-button--outline:hover { background: var(--accent); color: var(--accent-foreground); }

.sw-button--ghost { background: transparent; color: var(--foreground); }
.sw-button--ghost:hover { background: var(--accent); color: var(--accent-foreground); }

.sw-button--link { background: transparent; color: var(--primary); text-decoration-line: underline; text-underline-offset: 4px; }
```

**Card (before):**
```css
.card { background: var(--sw-color-bg-card); border: 1px solid var(--sw-color-border); border-radius: var(--sw-radius-lg); }
```

**Card (after):**
```css
.sw-card {
  background: var(--card); color: var(--card-foreground);
  border: 1px solid var(--border);
  border-radius: calc(var(--radius) + 4px);
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}
.sw-card-header { padding: 1.5rem 1.5rem 0; display: flex; flex-direction: column; gap: 0.375rem; }
.sw-card-content { padding: 1.5rem; padding-top: 0; }
.sw-card-footer { padding: 0 1.5rem 1.5rem; display: flex; align-items: center; }
```

**Apply this pattern to all components:**
- Alert → `var(--destructive)`, `var(--warning)`, `var(--success)`
- Badge → variant colors from tokens
- Input/TextArea → `var(--input)` border, `var(--ring)` focus
- Select/Dropdown → `var(--popover)` background
- Modal/Dialog → `var(--popover)` with backdrop
- Table → `var(--muted)` for header, `var(--border)` for rows
- Tabs → `var(--muted)` for inactive, `var(--background)` for active
- Sidebar → `var(--card)` or dedicated sidebar tokens

### 1.4 Dark Mode Toggle

Update `ThemeSwitcher` component to support dark mode:

```ruby
class ThemeSwitcher < Base
  def render(view, state)
    # Emit a button that toggles .dark class on <html> and persists to localStorage
    view.adapter.render_theme_switcher(view, self, state)
  end
end
```

Add JS to the adapter output:
```javascript
function toggleDarkMode() {
  const html = document.documentElement;
  html.classList.toggle('dark');
  localStorage.setItem('theme', html.classList.contains('dark') ? 'dark' : 'light');
}

// On load: respect saved preference or system preference
(function() {
  if (localStorage.theme === 'dark' ||
      (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.classList.add('dark');
  }
})();
```

### 1.5 Verify with Existing Apps

Run existing StreamWeaver examples/apps and confirm:
- Colors look correct with new tokens
- Dark mode works
- No visual regressions
- Existing `register_theme` still works (SW vars feed into shadcn tokens)

---

## Phase 2: Extract Adapter Pattern

**Outcome:** Clean separation between component logic (DSL) and rendering (adapter).

### 2.1 Formalize BaseAdapter

Ensure all component rendering goes through adapter methods:

```ruby
module StreamWeaver
  class BaseAdapter
    def render_button(view, component, state); end
    def render_card(view, component, state); end
    def render_input(view, component, state); end
    # ... one method per component
  end
end
```

### 2.2 Rename Current Adapter → PureCSSAdapter

The existing AlpineJS adapter becomes `PureCSSAdapter` (or `AlpineJSAdapter` stays but internally uses pure CSS classes).

### 2.3 Configuration

```ruby
StreamWeaver.configure do |config|
  config.adapter = :alpine_js  # default, uses pure CSS classes
  # or
  config.adapter = :tailwind   # uses Tailwind utility classes
end
```

---

## Phase 3: Tailwind Adapter

**Outcome:** Full shadcn fidelity when Tailwind is available.

### 3.1 Add `tailwind_merge` Gem (Optional Dependency)

```ruby
# stream_weaver.gemspec
spec.add_development_dependency 'tailwind_merge', '~> 1.0'
```

### 3.2 Build TailwindAdapter

Port RubyUI's class strings directly. The classes are already defined in `~/work/ruby_ui/lib/ruby_ui/button/button.rb`, etc.

```ruby
module StreamWeaver
  class TailwindAdapter < BaseAdapter
    MERGER = TailwindMerge::Merger.new.freeze

    BUTTON_BASE = "inline-flex items-center justify-center rounded-md font-medium transition-colors " \
                  "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring " \
                  "disabled:pointer-events-none disabled:opacity-50"

    BUTTON_VARIANTS = {
      primary: "bg-primary text-primary-foreground shadow hover:bg-primary/90",
      secondary: "bg-secondary text-secondary-foreground hover:bg-opacity-80",
      destructive: "bg-destructive text-white shadow-sm hover:bg-destructive/90",
      outline: "border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground",
      ghost: "hover:bg-accent hover:text-accent-foreground",
      link: "text-primary underline-offset-4 hover:underline"
    }.freeze

    BUTTON_SIZES = {
      sm: "px-3 py-1.5 h-8 text-xs",
      md: "px-4 py-2 h-9 text-sm",
      lg: "px-4 py-2 h-10 text-base",
      xl: "px-6 py-3 h-12 text-base"
    }.freeze

    def render_button(view, component, state)
      classes = MERGER.merge([
        BUTTON_BASE,
        BUTTON_VARIANTS[component.variant] || BUTTON_VARIANTS[:primary],
        BUTTON_SIZES[component.size] || BUTTON_SIZES[:md],
        component.options[:class]
      ].compact.join(" "))

      view.button(class: classes, type: "button", **data_attrs(component)) do
        yield if block_given?
      end
    end

    # ... similar for Card, Input, Alert, etc.
    # Port class strings from ~/work/ruby_ui/lib/ruby_ui/*/
  end
end
```

### 3.3 Tailwind CSS Requirement

When using the Tailwind adapter, the output HTML needs Tailwind CSS loaded. Options:
- CDN link (easiest for development)
- Bundled Tailwind (for production)
- User provides their own Tailwind setup

The adapter should inject the appropriate `<link>` or `<script>` in the HTML head.

Tailwind v4 config needed for shadcn tokens:
```css
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  /* ... */
}
```

---

## Phase 4: Port High-Value Components

Port these from RubyUI, adapting for StreamWeaver's DSL pattern:

### Priority 1 (most impact):
| Component | RubyUI Source | DSL Example |
|-----------|--------------|-------------|
| **Sheet** | `ruby_ui/sheet/` | `sheet(:right) { text "Details..." }` |
| **Skeleton** | `ruby_ui/skeleton/` | `skeleton width: "100%", height: "20px"` |
| **Command** | `ruby_ui/command/` | `command_palette { item "Search...", shortcut: "⌘K" }` |
| **Clipboard** | `ruby_ui/clipboard/` | `clipboard "code to copy"` |

### Priority 2 (nice to have):
| Component | RubyUI Source | DSL Example |
|-----------|--------------|-------------|
| **Combobox** | `ruby_ui/combobox/` | `combobox :user, choices, searchable: true` |
| **Calendar** | `ruby_ui/calendar/` | `calendar :date, range: true` |
| **AlertDialog** | `ruby_ui/alert_dialog/` | `alert_dialog "Are you sure?", confirm: "Delete"` |
| **HoverCard** | `ruby_ui/hover_card/` | `hover_card { text "Preview content" }` |

### Implementation Pattern

For each component:
1. Read RubyUI's Phlex component for structure
2. Define StreamWeaver DSL method (in `components.rb` or new file)
3. Add `render_*` method to PureCSSAdapter with CSS-variable styling
4. Add `render_*` method to TailwindAdapter with RubyUI's exact class strings
5. Add CSS for the pure CSS version to `shadcn_components.css`

---

## File Summary

```
lib/stream_weaver/
├── assets/
│   ├── shadcn_tokens.css          # Phase 1: semantic color tokens + dark mode
│   ├── shadcn_base.css            # Phase 1: global base styles
│   └── shadcn_components.css      # Phase 1: component styles using tokens
├── adapters/
│   ├── base_adapter.rb            # Phase 2: abstract adapter interface
│   ├── alpine_js_adapter.rb       # Phase 2: existing adapter (pure CSS classes)
│   └── tailwind_adapter.rb        # Phase 3: Tailwind utility classes
├── components.rb                  # Existing + Phase 4 new components
└── theme.rb                       # Updated to bridge --sw-* → shadcn tokens
```

---

## Quick Start (for Claude Code session)

```bash
cd ~/work/rstreamlit/stream_weaver

# Reference material:
# - RubyUI gem source: ~/work/ruby_ui/lib/ruby_ui/
# - RubyUI CSS tokens: ~/work/ruby_ui_web/app/assets/stylesheets/application.tailwind.css
# - Current SW theme: lib/stream_weaver/theme.rb
# - Current SW components: lib/stream_weaver/components.rb
# - Current SW adapter: lib/stream_weaver/adapter/
# - Full comparison: docs/ruby-ui-comparison.md

# Start with Phase 1:
# 1. Create lib/stream_weaver/assets/shadcn_tokens.css
# 2. Create lib/stream_weaver/assets/shadcn_base.css
# 3. Update component CSS to use var(--primary) etc.
# 4. Add dark mode toggle JS
# 5. Test with existing examples
```
