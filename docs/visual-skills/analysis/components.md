# StreamWeaver Component Inventory for Visual Skills

*Date: 2026-03-12*
*Purpose: Every new component needed, organized by shared/deck/explainer*

---

## 1. Shared Components (Used by Both Projects)

### 1.1 `mermaid(code, **options)`
- **Props:** `code:` (string, required), `zoom:` (boolean, default false), `compact:` (boolean, default false), `layout:` (:default | :elk), `theme_vars:` (hash, optional per-block overrides)
- **Renders:** Mermaid diagram as inline SVG within a container. When `zoom: true`, wraps in zoom/pan container with +/- controls, Ctrl+scroll zoom, click-drag pan, click-to-expand. When `compact: true`, minimal container for card embedding.
- **Extends/Inspired by:** New component. JS asset (~200 lines) for zoom engine. Loads Mermaid.js from CDN (mermaid@11 ESM).
- **Notes:** Must detect dark/light theme at load time for Mermaid themeVariables. ELK layout loads separate CDN module.

### 1.2 `code_block(code, **options)`
- **Props:** `code:` (string, required), `lang:` (string, e.g. "ruby", "ts", "javascript"), `file:` (string, optional file path header), `truncate:` (integer, optional max lines), `scroll:` (boolean, default true for long code)
- **Renders:** Syntax-highlighted code block via Prism.js with autoloader. Optional file header bar above code. Scrollable container for long code. Truncation mode for thumbnails.
- **Extends/Inspired by:** New component. Could extend or wrap the existing `md` component's code fence rendering, but needs Prism.js for proper highlighting beyond what markdown processors offer.
- **Notes:** Loads Prism.js + autoloader from CDN. Uses theme's `--font-mono` custom property. Recessed depth styling when inside a card.

### 1.3 `theme_toggle(**options)`
- **Props:** `mode:` (:dark | :light | :auto, default :dark), `hotkey:` (string, e.g. "mod+shift+l"), `persist:` (boolean, default true)
- **Renders:** Optional toggle button with sun/moon SVG icons. Manages `data-theme` attribute on `<html>`. Updates `<meta name="theme-color">`.
- **Extends/Inspired by:** Enhances existing StreamWeaver Theme module. The module already has dark/light; this adds auto mode, keyboard toggle, localStorage persistence, and the toggle button UI.

### 1.4 `keyboard_shortcuts(&block)`
- **Props:** Block DSL for registering shortcuts: `shortcut("mod+s", context: :global) { |e| ... }`
- **Renders:** No visible UI. Registers keyboard event handlers with context awareness (suppresses when focus is in text inputs, textareas, or specified interactive containers).
- **Extends/Inspired by:** New component. AlpineJS adapter could handle `@keydown` directives, but a centralized registry is needed for conflict resolution and context suppression.
- **Notes:** "mod" maps to Cmd on Mac, Ctrl elsewhere. Must support modifier combinations. Context-aware suppression for `.mermaid-wrap`, `.table-scroll`, `.code-scroll`, `textarea`, `input[type=text]`.

### 1.5 `html_export(path:, inline_images:)`
- **Props:** `path:` (string, output file path), `inline_images:` (boolean, default false)
- **Renders:** Not a visual component. Pipeline that serializes current StreamWeaver page into a self-contained HTML file. Inlines all CSS from the theme and components. Preserves CDN links for Mermaid, Chart.js, fonts. Optionally base64-encodes images.
- **Extends/Inspired by:** New infrastructure. Works with the Phlex rendering pipeline to capture output as a string and wrap in HTML5 document structure.

### 1.6 `slide_container(**options, &block)`
- **Props:** `progress_bar:` (boolean, default true), `keyboard_nav:` (boolean, default true), `mode:` (:swap | :scroll_snap)
- **Renders:** Container for slides. In `:swap` mode (deck), shows one slide at a time with DOM-swap and Back/Next buttons. In `:scroll_snap` mode (explainer), uses CSS scroll-snap with 100dvh per slide. Both share: progress bar, keyboard navigation (arrows, space), focus management.
- **Extends/Inspired by:** New component. The two modes share a navigation state machine but differ in DOM structure and CSS.

### 1.7 `progress_bar(current:, total:)`
- **Props:** `current:` (integer), `total:` (integer), `animated:` (boolean, default true)
- **Renders:** Fixed-position progress bar at top of viewport showing completion percentage. Width transition animation.
- **Extends/Inspired by:** StreamWeaver already has `progress_bar(value:, max:, ...)` -- this is a presentation-specific variant that is fixed-position and auto-updates on navigation.

### 1.8 `toast(message, variant:, duration:)`
- **Props:** `message:` (string), `variant:` (:info | :success | :warning | :error), `duration:` (integer, milliseconds, default 3000)
- **Renders:** Temporary notification that slides up from bottom or down from top, then auto-dismisses. Used for save confirmations, generation timeouts, errors.
- **Extends/Inspired by:** New component. Could build on `alert` component but with auto-dismiss behavior and fixed positioning.

### 1.9 `image_block(src, **options)`
- **Props:** `src:` (string, file path or URL), `alt:` (string), `caption:` (string, optional), `base64:` (boolean, for export mode)
- **Renders:** Image with optional caption. Handles local file paths via asset serving endpoint. In export mode, inlines as base64 data URI.
- **Extends/Inspired by:** New component. StreamWeaver's Rack server can serve static assets; this wraps that with proper MIME types and export support.

---

## 2. Design Deck Components

### 2.1 `design_deck(title, &block)`
- **Props:** `title:` (string), block containing `slide` calls
- **Renders:** Top-level deck container. Initializes slide navigation in :swap mode. Creates session for selection tracking. Adds footer with layout toggle and theme shortcut label.
- **Notes:** Orchestrator component. Validates no duplicate slide IDs, no "summary" ID. Ensures only one active deck.

### 2.2 `deck_slide(id, title, **options, &block)`
- **Props:** `id:` (string, unique), `title:` (string), `context:` (string, optional), `columns:` (1|2|3|4, optional auto-detect)
- **Renders:** A single decision slide with title, optional context text, and a grid of option cards. Grid columns auto-detected from option count unless overridden.
- **Notes:** Child block contains `option` calls.

### 2.3 `deck_option(label, **options, &block)`
- **Props:** `label:` (string, required), `description:` (string, optional hover text), `aside:` (string, optional text below preview), `recommended:` (boolean, default false)
- **Renders:** Option card with: radio indicator, label header, preview content (from block), aside text, notes textarea. Click-to-select behavior. ARIA: `role="radio"`, `aria-checked`.
- **Notes:** Block contains mermaid, code_block, image_block, or raw HTML calls that stack vertically as the option's preview.

### 2.4 `deck_summary`
- **Props:** Auto-generated (no explicit props)
- **Renders:** Final slide showing grid of summary cards for each slide: selected option label, preview thumbnail (first block truncated), aside text (120 char max), user notes. Final notes textarea. Submit button gated on complete selections ("Still need: X, Y"). After submit: "Submitted" state.
- **Notes:** Automatically appended as last slide. Reads from deck selection state.

### 2.5 `generate_more_controls(**options)`
- **Props:** `on_generate:` (callback), `max_count:` (integer, default 3)
- **Renders:** Prompt input, count dropdown (1-3), "Generate" button, "Regenerate all" button. Loading states: button spinner, disabled inputs during generation.
- **Notes:** Triggers callback to agent. Works with SSE push (Pushable) for receiving new options.

### 2.6 `skeleton_placeholder(count:)`
- **Props:** `count:` (integer, how many placeholders)
- **Renders:** Placeholder cards with shimmer animation (linear-gradient background-position 1.5s infinite). Same dimensions as option cards. Removed and replaced when real options arrive via SSE.
- **Extends/Inspired by:** New component. Could extend `card` with a shimmer variant.

### 2.7 `model_selector(models:, **options)`
- **Props:** `models:` (array of model descriptors), `default_model:` (string, optional), `on_select:` (callback)
- **Renders:** Model bar below header: provider filter pills, model list, "Default" checkbox, thinking level pills (off/low/medium/high). Hidden when fewer than 2 models.
- **Notes:** Deck-specific UI. Selection affects generate-more requests.

### 2.8 `confirmation_bar(message, **options)`
- **Props:** `message:` (string), `confirm_label:` (string), `cancel_label:` (string), `auto_hide:` (integer, seconds, default 5)
- **Renders:** Fixed top bar that slides down with confirm/cancel buttons. Auto-hides after timeout. Used for cancel confirmation.

### 2.9 `close_overlay(status, message)`
- **Props:** `status:` (:submitted | :cancelled | :stale | :aborted), `message:` (string)
- **Renders:** Full-screen overlay with backdrop blur. Color-coded by status (green/amber/red). Auto-closes tab after 800ms.

### 2.10 `layout_toggle`
- **Props:** None (reads/writes to state)
- **Renders:** Footer buttons (1/2/3/4) for overriding grid column count. Persisted to state. Applied via `data-layout` attribute on the slide container.

---

## 3. Visual Explainer Components

### 3.1 `ve_card(**options, &block)`
- **Props:** `depth:` (:hero | :elevated | :default | :recessed | :glass), `accent:` (:a | :b | :c, for colored left border), `label:` (string, monospace uppercase with dot)
- **Renders:** Card container with depth-tier styling. Hero = accent-tinted background + elevated shadow. Elevated = subtle shadow. Default = flat with border. Recessed = inset shadow. Glass = transparent + backdrop blur.
- **Extends/Inspired by:** StreamWeaver `card` component. Adds depth tiers and accent variants.

### 3.2 `kpi_dashboard(metrics:)`
- **Props:** `metrics:` (array of `{ value:, label:, color:, trend: }`)
- **Renders:** Auto-fit grid row of KPI cards. Each card has large value text (animatable via CSS counter), label, optional trend indicator. fadeScale entry animation.
- **Extends/Inspired by:** StreamWeaver `stat_display` component. Wraps multiple stat_displays in a KPI grid layout with animation.

### 3.3 `data_table(headers:, rows:, **options)`
- **Props:** `headers:` (array of strings), `rows:` (array of arrays), `sticky_header:` (boolean, default true), `alternating:` (boolean, default true), `hover:` (boolean, default true), `scrollable:` (boolean, default true)
- **Renders:** Styled HTML table with sticky header, alternating row backgrounds, row hover highlighting. Wrapped in scrollable container for wide tables. Status badges rendered as styled spans.
- **Extends/Inspired by:** StreamWeaver `table` component already exists. Needs enhancement for sticky headers, alternating rows, hover highlighting, and scrollable container.

### 3.4 `pipeline(steps:)`
- **Props:** `steps:` (array of `{ label:, description:, status: }`)
- **Renders:** Horizontal step flow with arrow connectors between steps. Each step is a card. Responsive: arrows hidden on mobile, collapses to vertical.
- **Extends/Inspired by:** New component. No existing StreamWeaver equivalent.

### 3.5 `comparison(before:, after:, **options)`
- **Props:** `before:` (block or content), `after:` (block or content), `before_label:` (string), `after_label:` (string)
- **Renders:** Side-by-side diff panels with labeled headers (before=red tint, after=green tint). Responsive: stacks vertically on mobile.
- **Extends/Inspired by:** New component. `hstack` with 2 children could approximate but lacks the visual diff treatment.

### 3.6 `sidebar_toc(sections:)`
- **Props:** `sections:` (array of `{ id:, label: }`)
- **Renders:** Desktop: sticky 170px sidebar column with scroll spy via IntersectionObserver. Active section highlighted with accent border. Mobile (<1000px): horizontal scrollable sticky bar at top. Smooth scroll on click with URL hash update.
- **Extends/Inspired by:** StreamWeaver has `navbar` but not a scroll-spy sidebar. New component.

### 3.7 `chart(type:, data:, **options)`
- **Props:** `type:` (:bar | :line | :pie | :doughnut | :radar), `data:` (Chart.js data object), `options:` (Chart.js options), `height:` (integer)
- **Renders:** Chart.js chart. Dark mode aware (reads prefers-color-scheme for text/grid colors). Reads CSS custom properties for font family.
- **Extends/Inspired by:** New component. Loads Chart.js from CDN.

### 3.8 `callout(variant:, &block)`
- **Props:** `variant:` (:info | :warning | :success | :tip), `title:` (string, optional)
- **Renders:** Box with colored left border and optional icon. Info=blue, warning=amber, success=green, tip=purple.
- **Extends/Inspired by:** StreamWeaver `alert` component. Similar concept but `callout` is inline content (not dismissible banner). Could be a variant of alert or a separate component.

### 3.9 `code_file(file:, code:, lang:)`
- **Props:** `file:` (string, file path), `code:` (string), `lang:` (string)
- **Renders:** Code block with a distinct file header showing the path. Header has different background from code body. Scrollable body.
- **Extends/Inspired by:** Variant of shared `code_block` with `file:` option. May be just `code_block(code, file: "src/app.rb", lang: "ruby")`.

### 3.10 `dir_tree(tree:)`
- **Props:** `tree:` (string, pre-formatted directory tree text)
- **Renders:** Pre-formatted file tree in monospace font. Color-coded new/modified/deleted files.
- **Extends/Inspired by:** New component. Could use `code_block` with custom styling but the color-coding is file-tree-specific.

### 3.11 `flow_arrow(label:)`
- **Props:** `label:` (string, optional)
- **Renders:** Vertical arrow with SVG icon and optional label. Used between cards to show flow/sequence.
- **Extends/Inspired by:** New component.

### 3.12 `prose(**options, &block)`
- **Props:** `width:` (:narrow | :default | :wide), `dropcap:` (boolean, default false)
- **Renders:** Reading-optimized text container with appropriate max-width, line-height, and font sizing. Dropcap option for opening paragraph.
- **Extends/Inspired by:** StreamWeaver `text` and `md` components. This adds magazine-style typography treatment.

### 3.13 `pullquote(text, **options)`
- **Props:** `text:` (string), `attribution:` (string, optional), `centered:` (boolean, default false)
- **Renders:** Highlighted quote with large font, accent border or decorative quotation mark. Optional attribution line.
- **Extends/Inspired by:** New component.

### 3.14 `hero_section(**options, &block)`
- **Props:** `variant:` (:centered | :editorial), `depth:` (:hero, forced)
- **Renders:** Page header area with hero-depth styling. Centered variant for titles; editorial variant for asymmetric layout with large display text.
- **Extends/Inspired by:** StreamWeaver `app_header`. Needs enhancement for hero depth styling and editorial variant.

### 3.15 `legend(items:)`
- **Props:** `items:` (array of `{ color:, label: }`)
- **Renders:** Horizontal legend bar with color swatches and labels. For explaining color coding in diagrams or tables.
- **Extends/Inspired by:** New component.

### 3.16 `sparkline(data:)`
- **Props:** `data:` (array of numbers), `color:` (string, optional)
- **Renders:** Inline SVG `<polyline>` showing a mini trend line. For use within table cells or KPI cards.
- **Extends/Inspired by:** New component.

### 3.17 `status_indicator(status, **options)`
- **Props:** `status:` (:match | :gap | :partial | :info | :warn), `label:` (string, optional)
- **Renders:** Colored dot + optional label. Colors match semantic meaning.
- **Extends/Inspired by:** StreamWeaver `status_dot` and `status_badge` components. May need additional status values.

### 3.18 `inner_grid(columns:, &block)`
- **Props:** `columns:` (integer, default 2)
- **Renders:** 2-column (or N-column) grid within a section card. For sub-layouts within a card.
- **Extends/Inspired by:** StreamWeaver `grid` component used in a nested context. May not need a separate component if `grid` supports nesting well.

### 3.19 `theme_preset(name:)`
- **Props:** `name:` (symbol -- one of the curated presets)
- **Renders:** No visible output. Sets CSS custom properties for fonts, colors, and surface styling according to a named preset. Presets include font pairing + color palette combinations.
- **Extends/Inspired by:** New infrastructure component. Works with the theme system.
- **Presets to define (initial set):**
  - `:editorial` -- Instrument Serif + JetBrains Mono, Terracotta + sage
  - `:technical` -- DM Sans + Fira Code, Teal + slate
  - `:warm` -- Fraunces + Source Code Pro, Amber + emerald
  - `:minimal` -- Outfit + Space Mono, Deep blue + gold
  - `:terminal` -- IBM Plex Sans + IBM Plex Mono, Rose + cranberry
  - Plus slide-specific: Midnight Editorial, Warm Signal, Terminal Mono, Swiss Clean

---

## 4. Existing StreamWeaver Components That Need Enhancement

### 4.1 `card` -- Add Depth Tiers
- **Current:** Basic card with header/body/footer
- **Needs:** `depth:` option (:hero, :elevated, :default, :recessed, :glass). `accent:` option for colored left border. Integration with CSS custom properties for surface colors and shadows.

### 4.2 `table` -- Add Data Table Features
- **Current:** Basic table rendering from data/headers/rows
- **Needs:** Sticky header option. Alternating row backgrounds. Row hover highlighting. Scrollable container wrapper for wide tables. Status indicator rendering within cells (styled spans, not emoji).

### 4.3 `grid` -- Add Auto-Column Detection
- **Current:** `grid(columns:, gap:)` with explicit column count
- **Needs:** `auto_columns: true` mode that detects optimal column count from child count (1->1, 2|4->2, 3+->3). Responsive collapse breakpoints. `data-layout` override support for manual toggle.

### 4.4 `alert` -- Relate to Callout
- **Current:** Dismissible alert banner
- **Needs:** Consider whether `callout` (inline, not dismissible, colored left border) is a variant of alert or a separate component. If variant, add `inline: true` option.

### 4.5 `stat_display` -- Enhance for KPI Dashboard
- **Current:** Single metric card
- **Needs:** Integration with `kpi_dashboard` wrapper for auto-fit grid layout. CSS counter animation for numbers. fadeScale entry animation with stagger.

### 4.6 `collapsible` -- Add Styled Chevron
- **Current:** Basic expandable section
- **Needs:** Styled disclosure chevron (rotates on open/close). Integration with the visual-explainer's `.collapsible` CSS pattern.

### 4.7 `progress_bar` -- Add Presentation Variant
- **Current:** Inline progress bar with value/max
- **Needs:** Fixed-position variant for slide navigation. Auto-updates via state binding. Width transition animation.

### 4.8 `radio_group` -- Enhance for Deck Selection
- **Current:** Basic radio button group
- **Needs:** Card-based radio metaphor where entire card is clickable. Visual indicators: accent border on selection, checkmark badge with pop animation, radio dot fill. ARIA: `role="radiogroup"` on container, `role="radio"` + `aria-checked` on cards. Number key quick-select (1-9).

### 4.9 `app_header` -- Add Hero Variant
- **Current:** Page header with title, subtitle, variant
- **Needs:** Hero-depth variant with accent-tinted background and elevated shadow. Editorial variant for asymmetric layout.

### 4.10 `navbar` -- Relate to Sidebar TOC
- **Current:** Navigation bar with nav items
- **Needs:** Consider whether `sidebar_toc` (sticky sidebar, scroll spy, mobile horizontal bar) shares infrastructure with navbar or is a completely separate component. At minimum, the `nav_item(active:)` pattern is shared.

### 4.11 Theme Module -- Major Enhancement
- **Current:** Dark/light theme support
- **Needs:**
  - Auto mode (follows OS `prefers-color-scheme`)
  - Manual toggle with configurable keyboard shortcut
  - localStorage persistence of override
  - CSS custom property vocabulary: `--bg`, `--surface`, `--surface-elevated`, `--border`, `--border-bright`, `--text`, `--text-dim`, `--accent`, `--accent-dim`, semantic node colors (`--node-a/b/c`), status colors (`--green`, `--red`, `--orange`)
  - `<meta name="theme-color">` management
  - Preset system for curated font+color combinations
  - Anti-slop color validation (warn on forbidden colors in development)

### 4.12 AlpineJS Adapter -- SSE Integration
- **Current:** Client-side reactivity via AlpineJS
- **Needs:** Integration with SSE push for generate-more flow. When server pushes new options via Pushable/SSE, Alpine should reactively update the DOM (add option cards, remove skeletons). This may already work via StreamWeaver's existing reactivity model, but needs validation for the deck's specific push patterns.

---

## 5. Implementation Priority

### Phase 1: Shared Foundation (Highest Value)
1. `mermaid` component (both projects need this first)
2. `code_block` component (both projects need this)
3. Theme module enhancements (CSS custom properties, auto mode, presets)
4. `keyboard_shortcuts` system
5. `html_export` pipeline

### Phase 2: Design Deck Core
6. `design_deck` + `deck_slide` + `deck_option` (the deck shell)
7. `radio_group` enhancement for card-based selection
8. `deck_summary` auto-generated slide
9. `slide_container` in :swap mode
10. `generate_more_controls` + `skeleton_placeholder`
11. `confirmation_bar` + `close_overlay`

### Phase 3: Visual Explainer Core
12. `ve_card` with depth tiers (or enhance existing `card`)
13. `data_table` enhancements to existing `table`
14. `sidebar_toc` with scroll spy
15. `kpi_dashboard` wrapping enhanced `stat_display`
16. `comparison` (diff panels)
17. `pipeline` (step flow)
18. `chart` (Chart.js integration)

### Phase 4: Polish
19. `theme_preset` system with curated presets
20. `slide_container` in :scroll_snap mode
21. `prose`, `pullquote`, `hero_section`
22. `toast` notifications
23. `model_selector`
24. `save/load` deck snapshot system
25. Animation choreography (staggered reveals, fadeScale, etc.)
26. `dir_tree`, `flow_arrow`, `legend`, `sparkline`

### Phase 5: Agent Integration
27. Slash command framework for StreamWeaver skills
28. Data gathering workflow templates
29. Verification checkpoint system
30. Auto-trigger detection for complex tables
31. Share/deploy integration
