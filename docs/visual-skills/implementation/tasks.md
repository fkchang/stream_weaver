# Visual Skills Implementation Tasks

*GSD Ralph-Loop Task Breakdown*
*Created: 2026-03-12*

---

## Task Index

| ID | Title | Phase | Deps | Est. Context |
|----|-------|-------|------|-------------|
| T1 | Generate-More Spike | 3 (spike) | none | ~40% |
| T2 | Theme Enhancement + CSS Foundation | 1 | none | ~35% |
| T3 | Mermaid Component | 1 | T2 | ~30% |
| T4 | CodeBlock + ImageBlock Components | 1 | T2 | ~30% |
| T5 | KeyboardShortcuts + SlideContainer | 1 | T2 | ~40% |
| T6 | Card Depth + Table Enhancement | 1 | T2 | ~30% |
| T7 | Design Deck Shell (DesignDeck + DeckSlide + DeckOption) | 2a | T5, T6 | ~45% |
| T8 | Deck Selection State + File-Backed State | 2b | T7 | ~40% |
| T9 | DeckSummary + ProgressBar Enhancement | 2c | T8 | ~35% |
| T10 | Generate-More Full Implementation | 3 | T1, T8 | ~45% |
| T11 | Explainer Components: SidebarToc + Callout + Comparison | 4 | T2, T6 | ~35% |
| T12 | Explainer Components: Pipeline + KpiDashboard + Chart | 4 | T2, T6 | ~35% |
| T13 | CSS-Only Helpers + HtmlExporter | 5 | T2 | ~30% |
| T14 | Deck Polish: ModelSelector + ConfirmationBar + CloseOverlay | 5 | T10 | ~35% |
| T15 | Theme Presets + Typography + Animations | 5 | T2 | ~30% |

---

## T1: Generate-More Spike

**Phase:** 3 (spike first -- highest risk)
**Dependencies:** None (standalone spike)
**Estimated context:** ~40%

### Goal
Discover the generate-more state machine through implementation. This is the riskiest feature (agent-browser-agent loop with SSE push, polling, timeouts). Build the minimum viable version to learn what states and edge cases actually matter.

### Scope
Create a standalone spike app (not in the gem yet) that demonstrates:
1. Browser shows a "Generate More" button with prompt input
2. Clicking sends a request to the server (queues a generate request)
3. Server-side polling detects the request (simulating agent detection)
4. Skeleton placeholders appear while "generating"
5. New content pushes to state (push-to-state, not push-to-DOM)
6. Page re-renders with new content replacing skeletons
7. Timeout/cancellation path

### Input Files (subagent reads these)
- `docs/visual-skills/design/architecture.md` (sections 7-8 on generate-more)
- `docs/visual-skills/design/review-synthesis.md` (push-to-state decision)
- `docs/visual-skills/design/gemini-review.md` (push-to-state rationale)
- `docs/visual-skills/analysis/components.md` (section 2.5-2.6)
- `lib/stream_weaver/pushable.rb` (existing SSE infrastructure)
- `lib/stream_weaver/app.rb` (how apps work)
- `lib/stream_weaver/server.rb` (Sinatra routes)

### Output Files
- `examples/generate_more_spike/app.rb` -- standalone spike app
- `examples/generate_more_spike/README.md` -- findings document
- `docs/visual-skills/implementation/spike-findings.md` -- state machine discovered, edge cases found, decisions made

### Acceptance Criteria
- [ ] Can click "Generate More" and see skeleton placeholders
- [ ] Simulated agent responds within 5s, skeletons replaced with content
- [ ] Timeout after 15s shows error toast
- [ ] Cancel button aborts pending generation
- [ ] State machine documented with actual states found (not predicted)
- [ ] Push-to-state pattern validated (not push-to-DOM)
- [ ] Findings doc written for T10 to consume

### Notes
- Use `StreamWeaver::App` and `Pushable` as-is -- do not modify the gem
- Simulate agent behavior with a Thread.new that sleeps then pushes
- The spike is throwaway code -- T10 will do the real implementation
- Key question to answer: does `Pushable` SSE work for this, or do we need modifications?

---

## T2: Theme Enhancement + CSS Foundation

**Phase:** 1 (shared foundation)
**Dependencies:** None
**Estimated context:** ~35%

### Goal
Establish the CSS custom property vocabulary and `sw-` prefix convention that all subsequent components depend on. Enhance the Theme module with auto-mode and the variable set needed by visual skills components.

### Scope
- Extend existing Theme module with CSS custom properties: `--sw-bg`, `--sw-surface`, `--sw-surface-elevated`, `--sw-border`, `--sw-text`, `--sw-text-dim`, `--sw-accent`, semantic node colors (`--sw-node-a/b/c`), status colors
- Add auto-mode (follows OS `prefers-color-scheme`)
- Add `data-theme` attribute management on `<html>`
- Add `<meta name="theme-color">` management
- Add localStorage persistence for theme override
- Establish `sw-` CSS prefix convention in a shared stylesheet
- CDN helper for loading Google Fonts

### Input Files
- `docs/visual-skills/analysis/components.md` (section 4.11 -- Theme enhancement)
- `docs/visual-skills/design/architecture.md` (section on theme)
- `lib/stream_weaver/theme.rb` (existing theme module)
- `lib/stream_weaver/adapter/alpinejs.rb` (how CDN scripts are loaded)

### Output Files
- `lib/stream_weaver/theme.rb` -- enhanced
- `lib/stream_weaver/assets/css/sw-foundation.css` -- CSS custom properties, `sw-` prefixed base styles
- `lib/stream_weaver/assets/js/sw-theme.js` -- auto-mode, toggle, localStorage
- `spec/theme_spec.rb` -- tests for theme enhancements

### Acceptance Criteria
- [ ] `--sw-*` custom properties defined for dark and light modes
- [ ] Auto-mode follows OS preference via `prefers-color-scheme`
- [ ] `data-theme` toggleable via JS function
- [ ] Theme persists in localStorage across page reloads
- [ ] `sw-` CSS prefix convention documented in code comments
- [ ] Existing StreamWeaver apps still work unchanged (backward compat)
- [ ] Tests pass

---

## T3: Mermaid Component

**Phase:** 1 (shared foundation)
**Dependencies:** T2 (needs CSS custom properties for theming)
**Estimated context:** ~30%

### Goal
Implement the `mermaid` DSL method and component class. Both pi-design-deck and visual-explainer need Mermaid diagrams as a core building block.

### Scope
- `Components::Mermaid` class in `components/mermaid.rb`
- DSL method `mermaid(code, **options)` in `DisplayDSL`
- Adapter rendering in `AlpineJS` adapter
- CDN loading for Mermaid.js (ESM, mermaid@11)
- Zoom/pan support when `zoom: true`
- Compact mode for embedding in cards
- Theme-aware: reads `data-theme` for Mermaid themeVariables
- ELK layout support via CDN module

### Input Files
- `docs/visual-skills/analysis/components.md` (section 1.1)
- `docs/visual-skills/design/architecture.md` (component pattern)
- `lib/stream_weaver/components.rb` (existing component pattern)
- `lib/stream_weaver/display_dsl.rb` (existing DSL pattern)
- `lib/stream_weaver/adapter/alpinejs.rb` (adapter rendering pattern)

### Output Files
- `lib/stream_weaver/components/mermaid.rb`
- `lib/stream_weaver/assets/js/sw-mermaid-zoom.js` (~200 lines)
- Updates to `lib/stream_weaver/display_dsl.rb`
- Updates to `lib/stream_weaver/adapter/alpinejs.rb`
- `spec/components/mermaid_spec.rb`

### Acceptance Criteria
- [ ] `mermaid("graph LR; A-->B")` renders a Mermaid diagram
- [ ] `zoom: true` enables click-drag pan and Ctrl+scroll zoom
- [ ] `compact: true` renders minimal container for card embedding
- [ ] Dark/light theme switch updates Mermaid theme
- [ ] CDN loads lazily (only when mermaid component is used)
- [ ] Tests pass

---

## T4: CodeBlock + ImageBlock Components

**Phase:** 1 (shared foundation)
**Dependencies:** T2 (needs CSS custom properties)
**Estimated context:** ~30%

### Goal
Implement syntax-highlighted code blocks and image display with captions. Both are used heavily by deck and explainer.

### Scope
- `Components::CodeBlock` class with Prism.js highlighting
- `Components::ImageBlock` class with caption and base64 export support
- DSL methods: `code_block(code, **options)`, `image_block(src, **options)`
- CDN loading for Prism.js with autoloader
- File header display for code blocks
- Truncation mode for thumbnail previews

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 1.2, 1.9)
- `lib/stream_weaver/components.rb` (patterns)
- `lib/stream_weaver/display_dsl.rb` (DSL patterns)
- `lib/stream_weaver/adapter/alpinejs.rb` (adapter patterns)

### Output Files
- `lib/stream_weaver/components/code_block.rb`
- `lib/stream_weaver/components/image_block.rb`
- Updates to `lib/stream_weaver/display_dsl.rb`
- Updates to `lib/stream_weaver/adapter/alpinejs.rb`
- `spec/components/code_block_spec.rb`
- `spec/components/image_block_spec.rb`

### Acceptance Criteria
- [ ] `code_block("puts 'hi'", lang: "ruby")` renders highlighted code
- [ ] `code_block(code, file: "src/app.rb")` shows file path header
- [ ] `code_block(code, truncate: 10)` truncates to 10 lines
- [ ] `image_block("photo.png", caption: "Figure 1")` renders image with caption
- [ ] Prism.js CDN loads lazily
- [ ] Tests pass

---

## T5: KeyboardShortcuts + SlideContainer

**Phase:** 1 (shared foundation)
**Dependencies:** T2 (needs theme foundation)
**Estimated context:** ~40%

### Goal
Implement the keyboard shortcut registry and slide container (both swap and scroll-snap modes). These are core navigation infrastructure for both deck and explainer.

### Scope
- `Components::KeyboardShortcuts` -- centralized shortcut registry
- `Components::SlideContainer` -- container with `:swap` and `:scroll_snap` modes
- JS for keyboard handling with context awareness (suppress in inputs)
- JS for slide navigation (swap DOM, progress tracking)
- Arrow key / Space navigation
- Progress bar integration (fixed-position variant)

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 1.4, 1.6, 4.7)
- `docs/visual-skills/design/architecture.md`
- `lib/stream_weaver/components.rb`
- `lib/stream_weaver/display_dsl.rb`
- `lib/stream_weaver/adapter/alpinejs.rb`

### Output Files
- `lib/stream_weaver/components/keyboard_shortcuts.rb`
- `lib/stream_weaver/components/slide_container.rb`
- `lib/stream_weaver/assets/js/sw-keyboard.js`
- `lib/stream_weaver/assets/js/sw-slide-nav.js`
- Updates to `lib/stream_weaver/display_dsl.rb`
- Updates to `lib/stream_weaver/adapter/alpinejs.rb`
- `spec/components/keyboard_shortcuts_spec.rb`
- `spec/components/slide_container_spec.rb`

### Acceptance Criteria
- [ ] Keyboard shortcuts register and fire callbacks
- [ ] "mod" maps to Cmd on Mac, Ctrl elsewhere
- [ ] Shortcuts suppressed when focus is in text inputs
- [ ] SlideContainer `:swap` mode shows one slide at a time with Back/Next
- [ ] Arrow keys navigate between slides
- [ ] Fixed-position progress bar updates on navigation
- [ ] Tests pass

---

## T6: Card Depth + Table Enhancement

**Phase:** 1 (shared foundation)
**Dependencies:** T2 (needs CSS custom properties)
**Estimated context:** ~30%

### Goal
Enhance existing `Card` and `Table` components with the features needed by visual skills. This avoids creating duplicate components (VeCard, DataTable) per the review decision.

### Scope
- Add `depth:` option to `Card` (:hero, :elevated, :default, :recessed, :glass)
- Add `accent:` option to `Card` for colored left border
- Add `sticky_header:`, `alternating:`, `scrollable:`, `hover:` options to `Table`
- CSS for depth tiers (shadows, backgrounds, blur)
- CSS for table enhancements

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 4.1, 4.2)
- `docs/visual-skills/design/review-synthesis.md` (VeCard -> Card merge)
- `lib/stream_weaver/components.rb` (existing Card, Table classes)
- `lib/stream_weaver/adapter/alpinejs.rb`

### Output Files
- Updates to `lib/stream_weaver/components.rb` (Card, Table classes)
- Updates to `lib/stream_weaver/assets/css/sw-foundation.css` (depth + table CSS)
- Updates to `lib/stream_weaver/adapter/alpinejs.rb` (if rendering changes needed)
- `spec/components/card_depth_spec.rb`
- `spec/components/table_enhanced_spec.rb`

### Acceptance Criteria
- [ ] `card(depth: :hero)` renders hero-depth styling
- [ ] `card(depth: :glass)` renders glass morphism effect
- [ ] `card(accent: :a)` renders colored left border
- [ ] `table(headers: h, rows: r, sticky_header: true)` has sticky header
- [ ] `table(..., alternating: true)` has alternating row backgrounds
- [ ] `table(..., scrollable: true)` wraps in scrollable container
- [ ] Existing card/table usage unchanged (backward compat)
- [ ] Tests pass

---

## T7: Design Deck Shell (DesignDeck + DeckSlide + DeckOption)

**Phase:** 2a (slide navigation)
**Dependencies:** T5 (SlideContainer), T6 (Card depth)
**Estimated context:** ~45%

### Goal
Build the core deck structure: a `design_deck` that contains `deck_slide`s, each with `deck_option` cards. No selection state yet -- just the visual shell with navigation.

### Scope
- `Components::Deck::DesignDeck` -- orchestrator component
- `Components::Deck::DeckSlide` -- slide with option grid
- `Components::Deck::DeckOption` -- option card with preview content
- DSL methods: `design_deck`, `deck_slide`, `deck_option`
- Auto-detect grid columns from option count
- Integration with SlideContainer for navigation
- Notes textarea on each option (display only, no persistence yet)

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 2.1-2.3)
- `docs/visual-skills/design/architecture.md` (deck section)
- Output from T5 (SlideContainer)
- Output from T6 (Card depth)
- `lib/stream_weaver/components.rb`
- `lib/stream_weaver/display_dsl.rb`

### Output Files
- `lib/stream_weaver/components/deck/design_deck.rb`
- `lib/stream_weaver/components/deck/deck_slide.rb`
- `lib/stream_weaver/components/deck/deck_option.rb`
- `lib/stream_weaver/assets/css/sw-deck.css`
- `lib/stream_weaver/assets/js/sw-deck-selection.js`
- Updates to `lib/stream_weaver/display_dsl.rb` (or `app.rb` for interactive DSL)
- `spec/components/deck/design_deck_spec.rb`

### Acceptance Criteria
- [ ] `design_deck("Title") { deck_slide("s1", "Slide") { deck_option("A") { text "..." } } }` renders
- [ ] Multiple slides navigable via Back/Next buttons
- [ ] Option cards display in auto-detected grid (2 options -> 2 cols, 3+ -> 3 cols)
- [ ] Option cards show preview content from block
- [ ] Notes textarea renders on each option
- [ ] Tests pass

---

## T8: Deck Selection State + File-Backed State

**Phase:** 2b (selection + persistence)
**Dependencies:** T7 (deck shell)
**Estimated context:** ~40%

### Goal
Add selection behavior to deck options and persist state to files. This is the core interactivity: users click options, write notes, and the state survives page reloads.

### Scope
- Click-to-select behavior on `DeckOption` (radio semantics per slide)
- Visual selection indicators (accent border, checkmark badge)
- ARIA: `role="radiogroup"`, `role="radio"`, `aria-checked`
- Number key quick-select (1-9)
- File-backed state storage (`DeckState` class)
- JSON file per session in tmp directory
- Notes persistence (textarea content saved to state file)
- Session ID generation and cookie tracking

### Input Files
- `docs/visual-skills/design/review-synthesis.md` (file-backed state decision)
- `docs/visual-skills/analysis/components.md` (sections 2.3, 4.8)
- `docs/visual-skills/design/architecture.md` (state management section)
- Output from T7 (deck components)
- `lib/stream_weaver/server.rb` (route patterns)

### Output Files
- `lib/stream_weaver/components/deck/deck_state.rb`
- Updates to `lib/stream_weaver/components/deck/deck_option.rb` (selection behavior)
- Updates to `lib/stream_weaver/assets/js/sw-deck-selection.js`
- Updates to `lib/stream_weaver/server.rb` (state persistence routes)
- `spec/components/deck/deck_state_spec.rb`
- `spec/components/deck/deck_selection_spec.rb`

### Acceptance Criteria
- [ ] Clicking an option selects it (accent border, checkmark)
- [ ] Only one option selected per slide (radio semantics)
- [ ] Number keys 1-9 select options
- [ ] Selection state persists in JSON file
- [ ] Notes text persists in JSON file
- [ ] State survives page reload
- [ ] ARIA attributes correct (`aria-checked`, roles)
- [ ] Tests pass

---

## T9: DeckSummary + ProgressBar Enhancement

**Phase:** 2c (summary)
**Dependencies:** T8 (selection state)
**Estimated context:** ~35%

### Goal
Build the auto-generated summary slide and enhance the progress bar for deck navigation.

### Scope
- `Components::Deck::DeckSummary` -- auto-generated final slide
- Summary cards showing: selected option, preview thumbnail, notes
- Submit button gated on all selections complete
- "Still need: X, Y" message when incomplete
- Submit state (locks deck after submission)
- Enhanced `ProgressBar` with `position: :fixed` variant

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 2.4, 4.7)
- Output from T8 (DeckState)
- Output from T7 (deck shell)

### Output Files
- `lib/stream_weaver/components/deck/deck_summary.rb`
- Updates to `lib/stream_weaver/components.rb` (ProgressBar enhancement)
- `spec/components/deck/deck_summary_spec.rb`

### Acceptance Criteria
- [ ] Summary slide auto-generated as last slide
- [ ] Shows selected option per slide with label and truncated preview
- [ ] Shows user notes per slide
- [ ] Submit button disabled when selections incomplete
- [ ] "Still need: Slide X, Slide Y" shown when incomplete
- [ ] Submit locks the deck into submitted state
- [ ] Fixed-position progress bar tracks slide position
- [ ] Tests pass

---

## T10: Generate-More Full Implementation

**Phase:** 3 (full implementation)
**Dependencies:** T1 (spike findings), T8 (deck state)
**Estimated context:** ~45%

### Goal
Implement generate-more as a production-quality gem feature, using the state machine and edge cases discovered in the T1 spike.

### Scope
- `Components::Deck::GenerateMoreControls` -- prompt, count, generate button
- `Components::Deck::SkeletonPlaceholder` -- shimmer loading cards
- Push-to-state pattern (Gemini's insight): new options written to DeckState, re-render
- Polling endpoint for agent to detect generate requests
- Timeout handling (15s default)
- Server routes for generate request queue
- Integration with `Pushable` SSE for push notifications

### Input Files
- `docs/visual-skills/implementation/spike-findings.md` (T1 output -- critical)
- `docs/visual-skills/analysis/components.md` (sections 2.5, 2.6)
- `docs/visual-skills/design/review-synthesis.md` (push-to-state decision)
- Output from T8 (DeckState, file-backed state)
- `lib/stream_weaver/pushable.rb`
- `lib/stream_weaver/server.rb`

### Output Files
- `lib/stream_weaver/components/deck/generate_more_controls.rb`
- `lib/stream_weaver/components/deck/skeleton_placeholder.rb`
- Updates to `lib/stream_weaver/components/deck/deck_state.rb` (generate queue)
- Updates to `lib/stream_weaver/server.rb` (generate routes)
- `lib/stream_weaver/assets/js/sw-generate-more.js`
- `spec/components/deck/generate_more_spec.rb`

### Acceptance Criteria
- [ ] Generate button sends request with prompt and count
- [ ] Skeleton placeholders appear during generation
- [ ] New options arrive via push-to-state and render correctly
- [ ] Timeout after configured duration shows error
- [ ] Cancel button aborts pending generation
- [ ] Polling endpoint returns pending generate requests
- [ ] Agent can poll, "generate," and push results
- [ ] Edge cases from spike findings are handled
- [ ] Tests pass

---

## T11: Explainer Components: SidebarToc + Callout + Comparison

**Phase:** 4 (visual explainer)
**Dependencies:** T2 (theme), T6 (card depth)
**Estimated context:** ~35%

### Goal
Build the first batch of visual-explainer-specific components.

### Scope
- `Components::SidebarToc` -- sticky sidebar with scroll spy (IntersectionObserver)
- `Components::Callout` -- bordered info/warning/tip box (not dismissible, unlike Alert)
- `Components::Comparison` -- side-by-side diff panels (before/after)
- Mobile responsive: SidebarToc collapses to horizontal bar, Comparison stacks

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 3.6, 3.8, 3.5)
- `lib/stream_weaver/components.rb`
- `lib/stream_weaver/display_dsl.rb`
- `lib/stream_weaver/adapter/alpinejs.rb`

### Output Files
- `lib/stream_weaver/components/sidebar_toc.rb`
- `lib/stream_weaver/components/callout.rb`
- `lib/stream_weaver/components/comparison.rb`
- `lib/stream_weaver/assets/js/sw-scroll-spy.js`
- Updates to `lib/stream_weaver/display_dsl.rb`
- `spec/components/sidebar_toc_spec.rb`
- `spec/components/callout_spec.rb`
- `spec/components/comparison_spec.rb`

### Acceptance Criteria
- [ ] `sidebar_toc(sections: [...])` renders sticky sidebar with links
- [ ] Scroll spy highlights active section
- [ ] `callout(variant: :warning) { text "..." }` renders bordered box
- [ ] `comparison(before_label: "Old", after_label: "New") { ... }` renders side-by-side
- [ ] Comparison stacks vertically on narrow viewports
- [ ] Tests pass

---

## T12: Explainer Components: Pipeline + KpiDashboard + Chart

**Phase:** 4 (visual explainer)
**Dependencies:** T2 (theme), T6 (card depth)
**Estimated context:** ~35%

### Goal
Build the remaining visual-explainer-specific components.

### Scope
- `Components::Pipeline` -- horizontal step flow with arrow connectors
- `Components::KpiDashboard` -- auto-fit grid of stat cards with animation
- `Components::Chart` -- Chart.js wrapper (bar, line, pie, doughnut, radar)
- CDN loading for Chart.js
- Dark mode awareness for chart colors

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 3.4, 3.2, 3.7)
- `lib/stream_weaver/components.rb` (StatDisplay for KpiDashboard)
- `lib/stream_weaver/display_dsl.rb`
- `lib/stream_weaver/adapter/alpinejs.rb`

### Output Files
- `lib/stream_weaver/components/pipeline.rb`
- `lib/stream_weaver/components/kpi_dashboard.rb`
- `lib/stream_weaver/components/chart.rb`
- Updates to `lib/stream_weaver/display_dsl.rb`
- `spec/components/pipeline_spec.rb`
- `spec/components/kpi_dashboard_spec.rb`
- `spec/components/chart_spec.rb`

### Acceptance Criteria
- [ ] `pipeline(steps: [...])` renders horizontal flow with arrows
- [ ] Pipeline collapses to vertical on mobile
- [ ] `kpi_dashboard(metrics: [...])` renders auto-fit grid of stat cards
- [ ] KPI cards animate on appearance (fadeScale)
- [ ] `chart(type: :bar, data: {...})` renders Chart.js chart
- [ ] Charts respect dark/light theme
- [ ] Chart.js CDN loads lazily
- [ ] Tests pass

---

## T13: CSS-Only Helpers + HtmlExporter

**Phase:** 5 (polish)
**Dependencies:** T2 (CSS foundation)
**Estimated context:** ~30%

### Goal
Implement the CSS-only DSL helpers (no component classes, just `div` wrappers) and the HTML export pipeline.

### Scope
- DSL helpers: `hero`, `prose`, `pullquote`, `dir_tree`, `legend`, `flow_arrow`, `layout_toggle`
- Each is a thin DSL method that wraps content in a `div` with CSS classes
- `HtmlExporter` -- serializes StreamWeaver page to self-contained HTML
- Inlines CSS, preserves CDN links, optional base64 images

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 3.12-3.15, 3.10-3.11, 1.5)
- `lib/stream_weaver/display_dsl.rb`

### Output Files
- Updates to `lib/stream_weaver/display_dsl.rb` (helper methods)
- `lib/stream_weaver/assets/css/sw-helpers.css`
- `lib/stream_weaver/export/html_exporter.rb`
- `spec/export/html_exporter_spec.rb`
- `spec/css_helpers_spec.rb`

### Acceptance Criteria
- [ ] `hero { header1 "Title" }` wraps in hero-styled div
- [ ] `prose { md "Long form text..." }` wraps in reading-optimized container
- [ ] `pullquote("Quote text", attribution: "Author")` renders styled quote
- [ ] `dir_tree("src/\n  app.rb")` renders monospace file tree
- [ ] HtmlExporter produces valid self-contained HTML file
- [ ] Exported HTML opens correctly in browser without server
- [ ] Tests pass

---

## T14: Deck Polish: ModelSelector + ConfirmationBar + CloseOverlay

**Phase:** 5 (polish)
**Dependencies:** T10 (generate-more)
**Estimated context:** ~35%

### Goal
Complete the deck's secondary UI components.

### Scope
- `Components::Deck::ModelSelector` -- model picker with provider filter pills
- `Components::Deck::ConfirmationBar` -- fixed top bar with confirm/cancel
- `Components::Deck::CloseOverlay` -- full-screen status overlay
- Auto-close tab behavior

### Input Files
- `docs/visual-skills/analysis/components.md` (sections 2.7-2.9)
- Output from T10 (GenerateMoreControls)

### Output Files
- `lib/stream_weaver/components/deck/model_selector.rb`
- `lib/stream_weaver/components/deck/confirmation_bar.rb`
- `lib/stream_weaver/components/deck/close_overlay.rb`
- `spec/components/deck/model_selector_spec.rb`
- `spec/components/deck/confirmation_bar_spec.rb`
- `spec/components/deck/close_overlay_spec.rb`

### Acceptance Criteria
- [ ] ModelSelector shows provider pills and model list
- [ ] ModelSelector hidden when fewer than 2 models
- [ ] ConfirmationBar slides down with confirm/cancel buttons
- [ ] ConfirmationBar auto-hides after timeout
- [ ] CloseOverlay shows full-screen status with backdrop blur
- [ ] CloseOverlay auto-closes tab after 800ms
- [ ] Tests pass

---

## T15: Theme Presets + Typography + Animations

**Phase:** 5 (polish)
**Dependencies:** T2 (theme foundation)
**Estimated context:** ~30%

### Goal
Add the curated theme presets and animation choreography.

### Scope
- 2 theme presets: `:editorial` (Instrument Serif + Terracotta), `:technical` (DM Sans + Teal)
- `theme_preset(name:)` DSL method
- Google Fonts CDN loading per preset
- Animation utilities: fadeScale, stagger reveals, shimmer
- CSS transitions for slide swaps

### Input Files
- `docs/visual-skills/analysis/components.md` (section 3.19)
- Output from T2 (theme foundation)

### Output Files
- `lib/stream_weaver/theme/presets.rb`
- `lib/stream_weaver/assets/css/sw-presets.css`
- `lib/stream_weaver/assets/css/sw-animations.css`
- Updates to `lib/stream_weaver/display_dsl.rb`
- `spec/theme/presets_spec.rb`

### Acceptance Criteria
- [ ] `theme_preset(:editorial)` loads Instrument Serif + JetBrains Mono fonts
- [ ] `theme_preset(:technical)` loads DM Sans + Fira Code fonts
- [ ] Preset applies CSS custom properties for colors and typography
- [ ] fadeScale animation utility available via CSS class
- [ ] Stagger animation for KPI cards and grid items
- [ ] Tests pass

---

## Dependency Graph

```
T1 (spike) ─────────────────────────────────┐
                                             │
T2 (theme) ──┬── T3 (mermaid)               │
             ├── T4 (codeblock+image)        │
             ├── T5 (keyboard+slides) ──┐    │
             ├── T6 (card+table) ──────┤    │
             ├── T11 (explainer batch1) │    │
             ├── T12 (explainer batch2) │    │
             ├── T13 (css helpers)      │    │
             └── T15 (presets)          │    │
                                        │    │
                    T7 (deck shell) ────┘    │
                        │                    │
                    T8 (selection+state) ────┤
                        │                    │
                    T9 (summary) ────────┐   │
                                         │   │
                    T10 (generate-more) ──┘───┘
                        │
                    T14 (deck polish)
```

## Parallelization Opportunities

These tasks can run in parallel if multiple subagents are available:

- **Parallel group A** (after T2): T3, T4, T6, T11, T12, T13, T15
- **Parallel group B** (after T5+T6): T7 can start
- **T1 runs independently** from the start, in parallel with everything

## Total Estimated Effort

- 15 tasks
- ~525% cumulative context (across all tasks)
- ~32 component classes + ~7 CSS helpers
- Critical path: T2 -> T5 -> T7 -> T8 -> T10 (with T1 in parallel)
