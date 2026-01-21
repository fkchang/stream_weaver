# Cabinet Control Components Plan

**Date:** 2026-01-19
**Status:** PHASE 2 COMPLETE
**Goal:** Add components and styling to StreamWeaver to enable building Cabinet Control dashboard

## Reference
- Cabinet Control HTML: `~/work/cultiv-ai/apps/cabinet-dashboard/index.html`
- Cabinet Control PDF: `~/Downloads/CabinetControl.pdf`

## Missing Components

### Priority 1: Core Components

| Component | Purpose | Props |
|-----------|---------|-------|
| `StatusDot` | Colored indicator dots with optional glow | `status:` (red/yellow/green/gray), `pulse:` (bool), `size:` (sm/md/lg) |
| `Badge` | Small count/label badges | `text:`, `variant:` (default/danger/warning/success), `size:` |
| `StatDisplay` | Large number + small label | `value:`, `label:`, `color:` |
| `TypeTag` | Colored type pills | `type:`, `text:` (RESEARCH, TASK, ESCALATION, etc.) |

### Priority 2: Layout Components

| Component | Purpose | Props |
|-----------|---------|-------|
| `AppShell` | Two-column layout with sidebar | `sidebar_width:`, `&block` for main + sidebar |
| `Sidebar` | Fixed sidebar container | `position:` (left/right), `width:` |

### Priority 3: Interactive Components

| Component | Purpose | Props |
|-----------|---------|-------|
| `ExpandableCard` | Card that expands on click | `expanded:`, `on_toggle:`, `&block` |
| `ActivityItem` | Time + title + summary + type badge | `time:`, `title:`, `summary:`, `type:` |
| `PriorityItem` | Item with priority-colored left border | `priority:` (critical/urgent/high/normal), `title:`, `description:` |

### Priority 4: Animation Components

| Component | Purpose | Props |
|-----------|---------|-------|
| `PulseIndicator` | Animated pulsing dot for live status | `color:`, `label:` |

## Missing CSS/Styling

### Dark Theme Variables
```css
:root[data-theme="dark"] {
  --sw-bg-deep: #0a0e14;
  --sw-bg-surface: #131820;
  --sw-bg-elevated: #1a2029;
  --sw-bg-hover: #242d3a;
  --sw-border: #2a3544;
  --sw-text-primary: #e6edf3;
  --sw-text-secondary: #8b949e;
  --sw-text-muted: #565d66;
  --sw-accent-blue: #58a6ff;
  --sw-accent-purple: #a371f7;
  --sw-status-red: #f85149;
  --sw-status-yellow: #d29922;
  --sw-status-green: #3fb950;
}
```

### Effects
- Glow effects for status indicators (`box-shadow` with color alpha)
- Gradient text for summary numbers
- Hover lift for cards (`transform: translateY(-2px)`)
- Hover slide for items (`transform: translateX(4px)`)
- Grid background overlay pattern

### Fonts
- JetBrains Mono for stats/timestamps (monospace)
- Outfit for UI text (already have Source Sans 3)

## Implementation Order

1. **StatusDot** - Most fundamental, used everywhere
2. **Badge** - Simple, high reuse
3. **StatDisplay** - Used in cards
4. **TypeTag** - Used in activity items
5. **Dark theme CSS** - Enable the aesthetic
6. **PulseIndicator** - Header status
7. **AppShell/Sidebar** - Layout structure
8. **ExpandableCard** - Interactive cards
9. **ActivityItem** - Compound component
10. **PriorityItem** - Escalation items

## Files to Modify

- `lib/stream_weaver/components.rb` - Add new component classes
- `lib/stream_weaver/views.rb` - Add dark theme CSS variables
- `lib/stream_weaver/css.rb` - Add animation/glow CSS
- `lib/stream_weaver/adapter/alpinejs.rb` - Add render methods

## Testing

Each component should be testable via:
```bash
./exe/streamweaver push test --dsl 'status_dot status: :red, pulse: true'
```

## Success Criteria

Can build a Cabinet Control-like dashboard using only StreamWeaver DSL:
```ruby
app_shell sidebar_width: 320 do
  main do
    header do
      pulse_indicator color: :green, label: "System Active"
    end
    grid cols: 2 do
      card do
        status_dot status: :red
        stat_display value: 5, label: "ACTIVITIES"
      end
    end
  end
  sidebar do
    badge text: "5", variant: :danger
    priority_item priority: :critical, title: "Needs attention"
  end
end
```

---

## Phase 1 Implementation (COMPLETE)

### Components Implemented

| Component | File | DSL Method |
|-----------|------|------------|
| `StatusDot` | components.rb:19-42 | `status_dot status: :green, pulse: true` |
| `Badge` | components.rb:44-66 | `badge "5", variant: :danger` |
| `StatDisplay` | components.rb:68-91 | `stat_display value: 42, label: "TASKS"` |
| `TypeTag` | components.rb:93-118 | `type_tag :research` |
| `PulseIndicator` | components.rb:120-138 | `pulse_indicator color: :green, label: "Active"` |
| `PriorityItem` | components.rb:140-170 | `priority_item priority: :critical, title: "..."` |
| `ActivityItem` | components.rb:172-192 | `activity_item time: "15:00", title: "..."` |

### CSS Added
- Dashboard component styles (StatusDot, Badge, StatDisplay, TypeTag, PulseIndicator, PriorityItem, ActivityItem)
- Dark theme (`sw-theme-dark`) with full color palette
- Glow effects for status indicators
- Pulse animation keyframes
- Hover effects (lift, slide)

### Theme Registration
- Added `:dark` to `BUILT_IN_THEMES` in app.rb

### Example App
- `examples/dashboard_components.rb` - Demonstrates all new components

## Phase 2 Implementation (COMPLETE)

### Components Implemented

| Component | File | DSL Method |
|-----------|------|------------|
| `AppShell` | components.rb | `app_shell sidebar_width: "320px" do ... end` |
| `Sidebar` | components.rb | `sidebar header: "Title" do ... end` |
| `MainContent` | components.rb | `main do ... end` |
| `ExpandableCard` | components.rb | `expandable_card key: :x, title: "..." do ... end` |

### CSS Added
- App shell grid layout with sidebar
- Sidebar with sticky positioning
- Expandable card with hover/transition effects
- Alpine.js transitions for expand/collapse
- Responsive breakpoint (stacks on mobile)
- Dark theme overrides for layout components

### Example App
- `examples/cabinet_control_demo.rb` - Full Cabinet Control-style dashboard

## Phase 3 (Future)

- Grid background overlay pattern
- Gradient text for large numbers
- Grid/List view toggle
