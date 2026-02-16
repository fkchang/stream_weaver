# RubyUI / shadcn Comparison & Adoption Plan

**Date:** 2026-02-14
**Context:** Evaluating RubyUI (shadcn/ui port for Phlex) to improve StreamWeaver's component polish.
**Repos:** `~/work/ruby_ui` (gem), `~/work/ruby_ui_web` (docs site)

---

## Component Gap Analysis

### High-Value Components StreamWeaver Is Missing

| RubyUI Component | What It Does | Priority |
|-----------------|-------------|----------|
| **Calendar** | Date picker calendar | HIGH |
| **Clipboard** | Copy-to-clipboard with visual feedback | HIGH |
| **Codeblock** | Syntax-highlighted code blocks | HIGH |
| **Combobox** | Searchable select/autocomplete | HIGH |
| **Command** | Command palette (⌘K style) | HIGH |
| **Sheet** | Slide-in panel (left/right/top/bottom) | HIGH |
| **Skeleton** | Loading placeholder animation | HIGH |
| **AlertDialog** | Modal confirmation with overlay | HIGH |
| **HoverCard** | Hover preview popover | Medium |
| **Popover** | Floating positioned content | Medium |
| **Switch** | Toggle switch | Medium |
| **ContextMenu** | Right-click menus | Medium |
| **ShortcutKey** | Keyboard shortcut badge display | Medium |
| **MaskedInput** | Input with format mask (phone, date) | Medium |
| **Avatar** | User image with fallback initials | Medium |
| **Typography** | Styled heading/paragraph components | Medium |
| **Carousel** | Content slider | Low |
| **AspectRatio** | Maintain aspect ratios | Low |

### StreamWeaver Has, RubyUI Doesn't

| StreamWeaver Component | Notes |
|----------------------|-------|
| **Charts** (Bar, Line, Pie, Stacked) | RubyUI has a basic Chart component |
| **AppShell** | Full app layout with sidebar + main |
| **ExpandableCard** | Click-to-expand card |
| **CodeEditor** | Editable code with syntax highlighting |
| **StatusDot / PulseIndicator** | Real-time status indicators |
| **StatDisplay** | Metric display with label |
| **TagButtons** | Tag/filter buttons |
| **Columns/Column** | Column layout DSL |
| **VStack/HStack/Grid** | Layout primitives |
| **Toast** | Notification toasts |
| **Spinner** | Loading spinner |

---

## Theming Comparison

### RubyUI (shadcn/ui pattern)

**How it works:**
- CSS custom properties on `:root` with semantic names
- `.dark` class on `<html>` overrides all variables
- Tailwind's `@theme inline` maps CSS vars → utility classes
- Components use Tailwind classes: `bg-primary text-primary-foreground`
- `TailwindMerge` gem resolves class conflicts
- `localStorage` persists theme preference
- Stimulus controller toggles `.dark` class

**Color tokens (the full set):**
```css
:root {
  --background       /* Page background */
  --foreground       /* Default text */
  --card             /* Card background */
  --card-foreground  /* Card text */
  --popover          /* Popover/dropdown background */
  --popover-foreground
  --primary          /* Primary action color */
  --primary-foreground
  --secondary        /* Secondary elements */
  --secondary-foreground
  --muted            /* Muted backgrounds */
  --muted-foreground /* Muted text */
  --accent           /* Hover/active states */
  --accent-foreground
  --destructive      /* Danger/delete actions */
  --destructive-foreground
  --border           /* Default border */
  --input            /* Input border */
  --ring             /* Focus ring */
  --chart-1 through --chart-5
  --radius           /* Base border radius */
  --sidebar, --sidebar-foreground, --sidebar-primary, etc.
  --warning, --warning-foreground     /* RubyUI additions */
  --success, --success-foreground
}

.dark {
  /* Same variables, different values */
}
```

**Color format:** oklch (perceptually uniform, modern)

**Key CSS:**
```css
@custom-variant dark (&:is(.dark *));

@theme inline {
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  /* ... maps CSS vars to Tailwind color names */
}

@layer base {
  * { @apply border-border outline-ring/50; }
  body { @apply bg-background text-foreground; }
}
```

### StreamWeaver (current)

**How it works:**
- CSS custom properties with `--sw-` prefix
- Ruby `Theme` class with `VARIABLE_SCHEMA` mapping
- Multiple named themes (not just light/dark)
- `register_theme` API for custom themes
- Components use inline styles referencing CSS vars
- No Tailwind — custom CSS classes

**Variable categories:**
- Typography: `--sw-font-family`, `--sw-font-size-base`, etc.
- Colors: `--sw-color-primary`, `--sw-color-bg`, `--sw-color-text`, etc.
- Spacing: `--sw-spacing-xs` through `--sw-spacing-2xl`
- Radius: `--sw-radius-sm` through `--sw-radius-xl`
- Shadows: `--sw-shadow-sm` through `--sw-shadow-xl`

**Strengths over RubyUI:**
- More granular control (spacing, shadows, radius as variables)
- Named theme system (not just light/dark)
- Ruby-native theme registration

**Weaknesses:**
- Components don't benefit from Tailwind utility classes
- More CSS to maintain per component
- No automatic dark mode
- Visual polish not at shadcn level

---

## Why RubyUI/shadcn Looks Better

1. **Consistent design tokens** — every component pulls from the same small set of semantic colors
2. **TailwindMerge** — prevents class conflicts, always clean output
3. **oklch colors** — perceptually uniform, look great at all lightness levels
4. **Transitions/animations** — `tw-animate-css` provides smooth enter/exit
5. **Focus states** — consistent `focus-visible:ring-1 focus-visible:ring-ring` everywhere
6. **Disabled states** — `disabled:pointer-events-none disabled:opacity-50` pattern
7. **Accessibility** — `aria-disabled` support built into base classes
8. **Minimal but precise spacing** — every component has exactly the right padding/margins

---

## Adoption Strategy

### Option A: Add shadcn CSS Variable Layer (Recommended)

Add the shadcn semantic tokens as an **additional layer** on top of existing `--sw-` variables. Map them so existing themes still work.

```css
/* Add to StreamWeaver's base CSS */
:root {
  /* Map shadcn tokens to existing SW variables */
  --primary: var(--sw-color-primary);
  --primary-foreground: #fff;
  --background: var(--sw-color-bg);
  --foreground: var(--sw-color-text);
  --card: var(--sw-color-bg-card);
  --card-foreground: var(--sw-color-text);
  --muted: var(--sw-color-bg-elevated);
  --muted-foreground: var(--sw-color-text-muted);
  --border: var(--sw-color-border);
  --input: var(--sw-color-border);
  --ring: var(--sw-color-border-focus);
  --destructive: #ef4444;
  --destructive-foreground: #fff;
  --accent: var(--sw-color-accent);
  --accent-foreground: var(--sw-color-text);
  --secondary: var(--sw-color-secondary);
  --secondary-foreground: var(--sw-color-text);
  --radius: var(--sw-radius-md);
}

.dark {
  /* Dark overrides — pull from dark theme values */
}
```

**Pros:** Non-breaking, incremental, existing themes keep working
**Cons:** Two variable systems in parallel temporarily

### Option B: Adopt Tailwind in the AlpineJS Adapter

StreamWeaver's adapter pattern means we can emit Tailwind classes from components without changing the DSL:

```ruby
# Current: adapter emits custom CSS classes
def render_button(view, component, state)
  view.button(class: "sw-button sw-button--primary") { ... }
end

# New: adapter emits Tailwind + shadcn classes
def render_button(view, component, state)
  view.button(class: "inline-flex items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90 h-9 px-4 py-2 text-sm font-medium") { ... }
end
```

**Pros:** Full shadcn polish, consistent with RubyUI
**Cons:** Requires Tailwind CSS in the output, bigger change

### Option C: Port RubyUI Components Directly

Since both use Phlex, RubyUI components can be adapted for StreamWeaver:

```ruby
# RubyUI's Button (Phlex component)
module RubyUI
  class Button < Base
    def view_template(&)
      button(**attrs, &)
    end
  end
end

# StreamWeaver equivalent would be in the adapter layer
# The DSL stays the same: `button "Click me", variant: :primary`
# But the rendered output matches RubyUI's polish
```

### Recommended Path

1. **Phase 1:** Add shadcn CSS variable layer (Option A) — immediate dark mode + consistent tokens
2. **Phase 2:** Update adapter to emit shadcn-style classes for existing components — visual polish
3. **Phase 3:** Port high-value missing components (Calendar, Command, Sheet, Skeleton, Combobox)
4. **Phase 4:** Consider full Tailwind adoption for new components

---

## Implementation: Phase 1 — shadcn Variable Layer + Dark Mode

### 1. Create `shadcn_compat.css`

A single CSS file that maps StreamWeaver themes to shadcn tokens and adds dark mode support:

```css
/* lib/stream_weaver/assets/shadcn_compat.css */

:root {
  /* Semantic tokens from shadcn */
  --background: var(--sw-color-bg, #ffffff);
  --foreground: var(--sw-color-text, #0a0a0a);
  --card: var(--sw-color-bg-card, #ffffff);
  --card-foreground: var(--sw-color-text, #0a0a0a);
  --primary: var(--sw-color-primary, #171717);
  --primary-foreground: #fafafa;
  --secondary: var(--sw-color-secondary, #f5f5f5);
  --secondary-foreground: #171717;
  --muted: var(--sw-color-bg-elevated, #f5f5f5);
  --muted-foreground: var(--sw-color-text-muted, #737373);
  --accent: var(--sw-color-accent, #f5f5f5);
  --accent-foreground: #171717;
  --destructive: #ef4444;
  --destructive-foreground: #ffffff;
  --border: var(--sw-color-border, #e5e5e5);
  --input: var(--sw-color-border, #e5e5e5);
  --ring: var(--sw-color-primary, #171717);
  --radius: var(--sw-radius-md, 0.5rem);
  --warning: #f59e0b;
  --warning-foreground: #ffffff;
  --success: #22c55e;
  --success-foreground: #ffffff;
}

.dark {
  --background: #0a0a0a;
  --foreground: #fafafa;
  --card: #171717;
  --card-foreground: #fafafa;
  --primary: #fafafa;
  --primary-foreground: #171717;
  --secondary: #262626;
  --secondary-foreground: #fafafa;
  --muted: #262626;
  --muted-foreground: #a3a3a3;
  --accent: #262626;
  --accent-foreground: #fafafa;
  --destructive: #dc2626;
  --destructive-foreground: #fafafa;
  --border: rgba(255,255,255,0.1);
  --input: rgba(255,255,255,0.15);
  --ring: #737373;
}
```

### 2. Add Dark Mode Toggle

Update `ThemeSwitcher` component to support `.dark` class toggle with localStorage persistence.

### 3. Update Component CSS

Gradually migrate component styles from hardcoded colors to `var(--primary)`, `var(--background)`, etc.

---

## References

- RubyUI docs: https://rubyui.com
- RubyUI gem source: `~/work/ruby_ui/`
- RubyUI web source: `~/work/ruby_ui_web/`
- shadcn/ui (React original): https://ui.shadcn.com
- Tailwind CSS v4: https://tailwindcss.com
- StreamWeaver theme system: `~/work/rstreamlit/stream_weaver/lib/stream_weaver/theme.rb`
- StreamWeaver components: `~/work/rstreamlit/stream_weaver/lib/stream_weaver/components.rb`
