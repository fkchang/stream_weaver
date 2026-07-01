# StreamWeaver vs. Claude HTML Artifact Aesthetic — Capability Audit

**Author:** Forrest Chang  
**Date:** May 2026  
**Purpose:** Identify gaps between StreamWeaver's current component set and the "Claude HTML artifact" aesthetic that dominates AI-generated UI sharing on social media. Use this audit to prioritize what to build next.

---

## What Is the "Claude HTML Artifact" Aesthetic?

When Claude generates a self-contained HTML file and people screenshot/share it, there's a recognizable aesthetic:

- **Dark cosmic backgrounds**: `#0a0a1a`, `#0f0f23`, `#1a1a2e` — near-black with a blue/indigo tint
- **Purple → blue → cyan gradients** everywhere: headings, borders, progress fills, highlights
- **Glassmorphism cards**: `backdrop-filter: blur(20px)`, `background: rgba(255,255,255,0.05)`, subtle border `rgba(255,255,255,0.1)`
- **Gradient text headings**: `background: linear-gradient(135deg, #a78bfa, #60a5fa, #34d399)` + `background-clip: text; -webkit-text-fill-color: transparent`
- **Animated entrance effects**: `@keyframes fadeInUp` — elements slide up from 20px below with opacity 0→1 on page load
- **Smooth hover transitions**: `transition: all 0.3s ease` — cards lift, borders glow, buttons shimmer
- **Typography**: Inter or system-ui, generous padding (24–40px), rounded corners (12–16px radius)
- **Interactive sliders** (`<input type="range">`) updating visuals in real-time without page reload
- **KPI dashboards** with counters that animate up from 0 to the final value
- **Step-by-step progressions**: Next/Prev buttons, animated reveals, progress bars that fill as you advance
- **Canvas/SVG animations**: physics simulations, neural network visualizers, algorithm step-throughs
- **Parameter-reactive charts**: change a slider → chart re-renders instantly

This aesthetic has become the benchmark for "impressive AI output." StreamWeaver needs to be able to match or exceed it.

---

## StreamWeaver Strengths — What Already Matches

### ✅ Dark Theme Infrastructure
`theme_preset :technical` and `theme_toggle` provide dark mode. The `:terminal` preset goes full dark. Custom CSS via inline `style:` is supported on all components. **Foundation exists** — the colors just need to be dialed in.

### ✅ Glassmorphism — Achievable Today
`card` accepts `style:` overrides. You can do glassmorphism manually:
```ruby
card(style: "background: rgba(255,255,255,0.05); backdrop-filter: blur(20px); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px;") do
  # content
end
```
Not ergonomic, but it works. A `:glass` card variant would be the right fix.

### ✅ KPI Dashboard Component Exists
`kpi_dashboard` is present and working. However (see gaps below) it lacks the animated counter entrance effect.

### ✅ Tabs
`tabs` / `tab` with `:line` and `:pill` variants — matches a core artifact interactive pattern.

### ✅ Progress Bar (Animated)
`progress_bar` with animation exists. This covers the step-progression fill pattern.

### ✅ Charts (Chart.js)
`chart` supports bar, line, pie, doughnut, radar. Chart.js is the same library many Claude artifacts use.

### ✅ Slide Container
`slide_container` (swap/scroll_snap modes) + `keyboard_shortcuts` covers the step-through explainer pattern. This is actually **stronger** than typical Claude artifact step progressions.

### ✅ Pipeline Component
`pipeline` for flow visualization — covers data/process flow diagrams.

### ✅ Mermaid with Zoom
`mermaid` with zoom/elk support — architecture diagrams are fully covered, arguably better than a raw Claude SVG.

### ✅ Code Blocks with Syntax Highlighting
`code_block` with Prism.js — matches the code-display pattern in explainer artifacts.

### ✅ Callout / Alert Variants
`callout` (info/warning/success/error/tip) — the colored insight boxes that artifact layouts love.

### ✅ Comparison Component
`comparison` (before/after panels) — a pattern that shows up constantly in refactor-explainer artifacts.

### ✅ Hero Component
`hero` — the big splash header that anchors many artifact layouts.

---

## Gaps — What's Missing That Artifact World Loves

### 🔴 CRITICAL GAPS

#### 1. No Range/Slider Input (`<input type="range">`)
**Impact: High.** The slider → real-time reactive visual update is THE signature Claude artifact interactive pattern. Without a `slider` component, StreamWeaver cannot replicate parameter-reactive charts, physics demos, or any "drag this to see the effect" UX.

**What's needed:**
```ruby
slider(label: "Learning Rate", min: 0.001, max: 1.0, step: 0.001, default: 0.1, bind: :lr)
```
…and the chart/display should reactively update when `:lr` changes.

#### 2. No Animated Counter on `stat_display` / `kpi_dashboard`
**Impact: High.** The "number counts up from 0 to 42,891 over 1.2 seconds on load" effect is a crowd-pleaser in artifact KPI dashboards. `stat_display` renders the number statically.

**What's needed:** A `count_up: true` option (or default behavior) on `stat_display` and `kpi_dashboard` entries, using a lightweight JS counter animation.

#### 3. No Animated Canvas Wrapper Component
**Impact: High.** Physics sims, neural net visualizers, sorting algorithm animations — these all require a `<canvas>` element with a JavaScript animation loop. SW has no `canvas` or `animation_canvas` component.

**What's needed:**
```ruby
animation_canvas(height: 400, script: :bubble_sort) # built-in named animations
# OR
raw_canvas(height: 400, js: <<~JS)
  // user-supplied animation loop
JS
```

#### 4. No Gradient Text Heading — No `header` Style Variants
**Impact: Medium-High.** The purple→cyan gradient text on headings is the most visually distinctive artifact element. SW headers render as plain styled text.

**What's needed:** Either a `gradient: true` option on `header1`–`header6`, or a `gradient_header` component:
```ruby
header1("Neural Architecture", gradient: "135deg, #a78bfa, #60a5fa, #34d399")
```
**Workaround today:** Use `div` with inline `style:` containing the gradient CSS — verbose but functional.

#### 5. No Entrance Animations (fadeInUp on Load)
**Impact: Medium.** Artifact pages feel alive because elements cascade in on load. SW components render static.

**What's needed:** An `animate:` option on containers/cards: `card(animate: :fade_in_up, delay: 0.1)`. Could be implemented as CSS classes added by the DSL with a small animation stylesheet.

#### 6. No Glassmorphism Shorthand / `:glass` Card Variant
**Impact: Medium.** As noted above, it's doable manually but requires verbose inline CSS. A first-class `:glass` variant on `card` would make the aesthetic effortless.

### 🟡 MODERATE GAPS

#### 7. No Step Wizard Component
`slide_container` covers sequential content well, but a purpose-built `step_wizard` with:
- Numbered step indicators at top
- Next/Prev/Submit buttons
- Per-step validation state
- Progress bar integrated

…would match the "onboarding wizard" artifact pattern more cleanly.

#### 8. Parameter-Reactive Charts
Current `chart` component renders once. There's no binding mechanism to re-render a chart when a reactive state value changes (e.g., slider changes → chart dataset updates).

**What's needed:** A `reactive:` option or `bind:` param on `chart`, wired to SW's reactive state system.

#### 9. No Number Format Options on `stat_display`
Artifact KPI cards show `$1.2M`, `99.7%`, `+12.4%` with appropriate formatting and color-coded deltas (green up / red down). `stat_display` needs `format:`, `prefix:`, `suffix:`, and `delta_color:` options.

#### 10. No Tooltip Component
Artifact dashboards extensively use hover tooltips on data points and labels. SW has no `tooltip` wrapper component.

#### 11. No Color Swatch / Palette Display Component
Minor but noticeable in design-system artifacts.

### 🟢 MINOR / NICE-TO-HAVE

#### 12. No Sparkline
Inline mini-chart (a 5-value trend line inside a stat card). Would pair well with `kpi_dashboard`.

#### 13. No Tag Cloud / Word Cloud
Shows up in text-analysis artifacts.

#### 14. No Typing Animation Component
The "text types itself out" effect used in demo/explainer artifacts.

---

## The Design Aesthetic Gap

### Current SW Default Look
StreamWeaver's out-of-box appearance (no theme specified) is a **light, clean, editorial/technical look** — good for documentation and internal tools, but nothing like the dark-cosmos-gradient aesthetic.

| Dimension | Claude Artifact Default | SW Default |
|-----------|------------------------|------------|
| Background | `#0a0a1a` near-black | White / light gray |
| Headings | Gradient text | Plain bold, themed color |
| Cards | Glass morphism, blur | Solid bordered card |
| Accent color | Purple/violet/cyan | Blue or neutral |
| Entrance | Animated fadeInUp | Static render |
| Font | Inter, generous spacing | System-ui, moderate spacing |

### Bridging the Gap Today

**Option A: `theme_preset :technical` + custom overrides**
`:technical` gives a dark, dense, code-focused look. Then override with inline CSS:
```ruby
theme_preset :technical
hero(style: "background: linear-gradient(135deg, #0a0a1a, #1a1a2e); padding: 60px 40px;") do
  div(style: "font-size: 3rem; font-weight: 800; background: linear-gradient(135deg, #a78bfa, #60a5fa); -webkit-background-clip: text; -webkit-text-fill-color: transparent;") { "My Title" }
end
```

**Option B: `:terminal` preset** for fully dark background, then add gradient accents.

**Option C: Custom CSS injection** — SW supports raw CSS blocks. Create a reusable "artifact aesthetic" CSS snippet that sets the dark background, gradient variables, and entrance animation keyframes. Include it at the top of any canvas session.

### The Right Long-Term Fix
Add a `:artifact` or `:dark_gradient` theme preset that ships with:
- Dark cosmic background colors
- Purple→cyan gradient CSS custom properties
- Glassmorphism card defaults
- `fadeInUp` keyframe pre-defined
- Inter font import

This would make "looking like a Claude artifact" a one-liner: `theme_preset :dark_gradient`.

---

## Priority Matrix

| Gap | User Impact | Implementation Effort | Priority |
|-----|------------|----------------------|----------|
| Slider/range input | Very High | Medium | P0 |
| Animated counter on stat | High | Low | P0 |
| Parameter-reactive charts | High | Medium | P1 |
| `:dark_gradient` theme preset | High | Low-Medium | P1 |
| Gradient header option | Medium | Low | P1 |
| Entrance animations | Medium | Low | P1 |
| `:glass` card variant | Medium | Low | P2 |
| `animation_canvas` component | High | High | P2 |
| Step wizard | Medium | Medium | P2 |
| Tooltip | Medium | Medium | P2 |
| Animated sparkline | Low | Medium | P3 |
| Number formatting on stat | Low | Low | P2 |

---

## Summary

StreamWeaver has **strong structural foundations** for matching the Claude artifact aesthetic:
- The component variety is there (tabs, charts, mermaid, slides, comparison, kpi_dashboard)
- Dark theme exists
- Chart.js is already the same library

The **critical missing pieces** are:
1. **Slider input** (the most-loved artifact pattern)
2. **Animated counters** on stat displays
3. **Gradient text / `:dark_gradient` theme** (purely aesthetic but high-signal)
4. **Parameter-reactive chart binding**
5. **Canvas animation wrapper** for physics/algorithm demos

Filling P0 and P1 items would allow StreamWeaver to produce outputs indistinguishable from — and in many ways superior to — the Claude HTML artifact aesthetic, with the added advantage of being a live server-rendered reactive app rather than a static HTML file.
