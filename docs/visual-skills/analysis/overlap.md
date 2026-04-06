# Overlap Analysis: pi-design-deck + visual-explainer

*Date: 2026-03-12*
*Purpose: Identify shared infrastructure, unique features, and code savings for StreamWeaver unification*

---

## 1. Shared Infrastructure

### 1.1 Mermaid Diagram Rendering

**pi-design-deck:** Renders Mermaid blocks (`type: "mermaid"`) within option cards via Mermaid.js CDN. Supports per-block theme variable overrides. Renders inline within a card grid context. No zoom/pan controls -- diagrams are small previews within option cards.

**visual-explainer:** Extensive Mermaid integration with full zoom/pan engine (~200 lines JS). Supports +/- buttons, Ctrl/Cmd+scroll zoom, click-and-drag pan, touch pinch zoom, double-click to fit, click-to-expand in new tab. Smart fit algorithm with contain/width-priority/height-priority modes. Uses `theme: 'base'` with custom `themeVariables`. Dark mode detection at load time. Adaptive container height based on SVG dimensions. Max 10-12 nodes per diagram recommendation; hybrid CSS+Mermaid pattern for 15+ elements.

**StreamWeaver already has:** Nothing -- Mermaid rendering is listed as missing for both.

**StreamWeaver needs:** A `mermaid` component with two modes: (1) inline/compact for use within cards (deck use case), and (2) full-featured with zoom/pan/expand controls (explainer use case). Both need dark/light theme awareness. The zoom engine is ~200 lines of JS that can be packaged as a StreamWeaver JS asset.

**Estimated code savings from unification:** High. The Mermaid init, theme detection, and CDN loading are identical. The zoom engine is additive (explainer-only) but built on the same foundation. ~70% of the Mermaid code is shared.

---

### 1.2 Code Syntax Highlighting

**pi-design-deck:** Uses Prism.js with autoloader for language support. Code blocks (`type: "code"`) render within option cards with `lang` property. Part of the previewBlocks system.

**visual-explainer:** Uses Prism.js implicitly through code blocks in pages. `.code-block` and `.code-file` CSS components with pre-wrap styling, file headers, and scroll containers. Also has slide-specific code blocks (`.slide__code-block`) with floating filename labels.

**StreamWeaver already has:** Nothing specific to syntax highlighting. Has generic `text` and `md` (markdown) components.

**StreamWeaver needs:** A `code_block` component that wraps Prism.js: accepts code string and language, renders highlighted output. Variants: inline (within cards), standalone (with file header), and slide-mode (with floating filename). CDN loading of Prism.js + autoloader.

**Estimated code savings:** High. Prism.js loading, theme integration, and basic rendering are identical. ~80% shared.

---

### 1.3 Theme System (Dark/Light/Auto)

**pi-design-deck:** Three modes: dark (default), light, auto. CSS custom properties on `:root` and `[data-theme="light"]`. `data-theme` attribute on `<html>`. Configurable hotkey (parsed from "mod+shift+l"). Auto mode listens for `matchMedia` changes. Theme override stored in localStorage. `<meta name="theme-color">` updated. Also has preview palette themes (midnight-rose, slate-jade, warm-copper, ocean-cyan) and font themes for option previews.

**visual-explainer:** Auto mode by default via `prefers-color-scheme` media query. Light-first or dark-first variants. Optional manual toggle with data-theme attribute and sun/moon SVG button. CSS custom properties for all tokens (--bg, --surface, --border, --text, --text-dim, accents). Both themes must look intentional. Mermaid theme determined once at load time (static, not reactive).

**StreamWeaver already has:** Theme module with dark/light support. Theme-aware CSS styling (added for scroll_box).

**StreamWeaver needs:** Enhancement of existing theme module to support: (1) auto mode following OS preference, (2) manual toggle with keyboard shortcut, (3) localStorage persistence of override, (4) CSS custom property system matching the design token vocabulary (--bg, --surface, --border, --text, --text-dim, accent colors), (5) meta theme-color updates. The preview palette themes (deck-specific) and anti-slop color restrictions (explainer-specific) are additive.

**Estimated code savings:** Medium-high. Core theme switching logic is identical (~60% shared). Each project adds its own design tokens on top.

---

### 1.4 Browser Serving and Auto-Open

**pi-design-deck:** Node.js HTTP server on `127.0.0.1`, random port by default. Token-based auth via session query param. Auto-opens browser. Heartbeat watchdog. Server persists across tool re-invocations.

**visual-explainer:** No server -- writes static HTML files to `~/.agent/diagrams/` and opens via `open` (macOS) or `xdg-open` (Linux). Files served from filesystem.

**StreamWeaver already has:** Auto-port detection (scan from 4567). Auto-browser open. Puma server with Pushable streaming (SSE). Session state via cookies. Rack-based serving.

**StreamWeaver needs:** Minimal additions. The existing Puma server and auto-open cover the deck use case well. For explainer, StreamWeaver needs an HTML export mode that writes a self-contained file (see 1.6). The deck's persistent server pattern maps naturally to StreamWeaver's architecture.

**Estimated code savings:** Very high. StreamWeaver already has this. ~90% reuse.

---

### 1.5 Keyboard Shortcuts

**pi-design-deck:** Arrow keys (slide navigation + option focus), 1-9 (quick select), Space (select focused), Enter (select/advance/submit), Escape (cancel with confirmation), Cmd+S (save), Cmd+Shift+L (theme toggle). Context-aware: arrow keys behave differently when option cards have focus vs. no focus.

**visual-explainer:** Slide deck mode: arrows, space, page up/down, home/end for navigation. Touch swipe (>50px). Focus-aware: keyboard events suppressed when focus is inside .mermaid-wrap, .table-scroll, or .code-scroll.

**StreamWeaver already has:** Nothing specific to keyboard shortcuts.

**StreamWeaver needs:** A keyboard shortcut system/component that: (1) registers key handlers with context awareness (what element has focus), (2) supports modifier keys (Cmd/Ctrl abstraction), (3) handles conflicts between slide navigation and interactive element navigation, (4) is declarative (register shortcuts via DSL, not raw JS).

**Estimated code savings:** Medium. The underlying event listener pattern is shared, but the specific shortcuts diverge significantly. ~40% shared infrastructure, 60% app-specific bindings.

---

### 1.6 HTML Export (Self-Contained)

**pi-design-deck:** Export action generates standalone HTML with embedded CSS (all 4 CSS files), inlined base64 images, Mermaid CDN link, Google Fonts link. All slides visible simultaneously (no navigation). Meta chips showing deck metadata.

**visual-explainer:** Every output IS a self-contained HTML file. Inline `<style>`, optional `<script>`, CDN links for fonts/Mermaid/Chart.js. Written to `~/.agent/diagrams/`. This is the primary output format, not an export option.

**StreamWeaver already has:** Nothing -- this is a new capability. StreamWeaver currently serves live pages via Puma.

**StreamWeaver needs:** An export pipeline that serializes a StreamWeaver page into a single HTML file. Must inline all CSS, optionally inline images as base64 data URIs, preserve CDN links for external JS libraries. For deck: flatten slides into a single scrollable view. For explainer: the export IS the normal output.

**Estimated code savings:** Medium. The inlining/serialization logic is shared. Output format differs (deck flattens navigation; explainer is already flat). ~50% shared.

---

### 1.7 Slide/Presentation Navigation

**pi-design-deck:** Linear slide progression with Back/Next buttons. Progress bar showing position. Slides are "decision slides" (one per design dimension) plus auto-generated summary slide. Fade transitions (opacity + translateY). Slides are not scroll-snap -- they are DOM-swapped (only active slide visible).

**visual-explainer:** Scroll-snap based deck with 100dvh per slide. 10 distinct slide types (title, section divider, content, split, diagram, dashboard, table, code, quote, full-bleed). Keyboard/touch/wheel navigation. Progress bar, nav dots, slide counter. Cinematic transitions with staggered child reveals. 4 presets (Midnight Editorial, Warm Signal, Terminal Mono, Swiss Clean).

**StreamWeaver already has:** Nothing specific to slides/presentations.

**StreamWeaver needs:** Two slide systems that share a navigation abstraction: (1) Deck-style: DOM-swap with linear progression, Back/Next buttons, progress bar -- simpler, focused on decision-making. (2) Presentation-style: scroll-snap 100dvh, multiple slide types, nav dots, slide counter, cinematic transitions -- focused on content presentation. Common foundation: keyboard navigation (arrows, space), progress tracking, touch support.

**Estimated code savings:** Low-medium. The two slide paradigms are quite different (DOM-swap vs. scroll-snap). Navigation key handling shares ~30%. Progress bar is shared. ~35% overlap.

---

### 1.8 Responsive Layout

**pi-design-deck:** Grid columns auto-detection (1-4 based on option count). Responsive breakpoints at 1200px and 900px. CSS Grid subgrid for option card alignment. Layout toggle (1/2/3/4 columns in footer).

**visual-explainer:** Max width 1000-1400px centered. Single breakpoint at 768px. Grids collapse to single column. TOC switches from sidebar to horizontal bar at 1000px. Slides have height-based breakpoints (700px, 600px, 500px).

**StreamWeaver already has:** `grid(columns:, gap:)` component. `hstack` and `vstack` layout primitives. Card component.

**StreamWeaver needs:** Enhancement of grid component for auto-detection of column count based on child count. Responsive breakpoints. Layout toggle control. The sidebar TOC with responsive switching is explainer-specific but built on shared layout primitives.

**Estimated code savings:** Medium. Both need responsive CSS, but the specific breakpoints and layout patterns diverge. ~40% shared.

---

## 2. Unique to pi-design-deck

### 2.1 Multi-Slide Option Selection with Radio Metaphor
One selection per slide enforced via `role="radiogroup"` semantics. Visual radio indicators, accent borders, checkmark badges with pop animation. Number keys 1-9 for quick selection. Selection stored in `selections[slideId] = label` map. Click anywhere on card to select.

### 2.2 Generate-More Loop (SSE Push of New Options)
Complete agent-in-the-loop flow: user requests N more options, skeleton placeholders appear with shimmer animation, agent receives structured prompt, generates options, pushes via SSE `new-option`/`replace-options` events, client renders with entry animations. Includes regenerate-all variant. 90-second server timeout, 30-second per-option client timeout. Concurrent generation prevention.

### 2.3 Selection Tracking and Summary Slide
Auto-generated final slide (id: "summary") showing grid of summary cards with: slide title, selected option label, preview thumbnail (first block truncated), aside text (120 char truncation), user notes. Final notes textarea. Submit button gated on complete selections ("Still need: X, Y" message).

### 2.4 Save/Load/Export Snapshots
Snapshot system: manual save (Cmd+S), auto-save on submit (-submitted suffix), auto-save on cancel with selections (-cancelled suffix). Snapshot directory structure with deck.json + images/. List, open, and export actions. Dirty state tracking ("Unsaved changes" / "Saved at HH:MM").

### 2.5 Model Selector for Generation
Model bar with provider filter pills, model list, "Default" checkbox, thinking level pills (off/low/medium/high/xhigh). Model override flow spawns headless CLI with --provider and --model flags. Default model persistence in settings.json.

### 2.6 Notes per Option
Each option card has a "Your notes (optional)" textarea. Notes saved to localStorage and included in summary slide and submission payload. Per-option granularity, not per-slide.

### 2.7 Aside Text
Option-level explanatory text below the preview. Supports `\n` line breaks. Truncated to 120 chars in summary slide thumbnail.

### 2.8 Confirmation Dialogs
Cancel confirmation bar: fixed top, slide-down animation, "Cancel deck? Selections will be lost." with Cancel/Keep Going buttons, 5-second auto-hide, double-Escape pattern. Close overlay: full-screen blur backdrop, color-coded by status (green/amber/red), auto-closes tab after 800ms.

### 2.9 Preview Palette Themes
Per-option visual themes for previewHtml: midnight-rose, slate-jade, warm-copper, ocean-cyan. Font themes: albert, jakarta, grotesk. Applied via data attributes on preview elements.

### 2.10 Session/Connection Management
Token-based auth, heartbeat watchdog (5s interval, 60s grace), idle timer (5 min after generate-more), abort signal handling, `beforeunload` beacon, double-submit prevention, concurrent deck prevention.

---

## 3. Unique to visual-explainer

### 3.1 Auto-Trigger on Complex Tables
Proactive behavior: tables with 4+ rows OR 3+ columns automatically rendered as HTML instead of ASCII art. Agent decision-making, not user-triggered.

### 3.2 Eight Distinct Slash Commands with Different Data Gathering
Each command has a unique workflow: `/generate-web-diagram` (free-form), `/generate-visual-plan` (10 sections with state machine), `/diff-review` (10 sections with git data), `/plan-review` (9 sections comparing plan vs code), `/project-recap` (8 sections with time window), `/generate-slides` (scroll-snap deck), `/fact-check` (verification workflow), `/share` (Vercel deployment).

### 3.3 Verification/Fact-Check Workflow
Unique post-generation quality assurance: extract verifiable claims (quantitative, naming, behavioral, structural, temporal), verify against actual codebase, correct in place, add verification summary. Preserves page structure; only changes factual content.

### 3.4 Chart.js Integration
Bar, line, pie/doughnut, radar charts in dashboard pages. Dark mode aware (reads prefers-color-scheme for text/grid colors). Reads CSS custom properties for font family.

### 3.5 Responsive Sidebar TOC with Scroll Spy
Desktop: sticky 170px sidebar column with IntersectionObserver scroll spy. Mobile (<1000px): horizontal scrollable sticky bar at top with auto-scroll active tab to center. Smooth scroll with URL hash update.

### 3.6 Vercel Deployment/Sharing
Shell script (`share.sh`) that copies HTML to temp dir as index.html, deploys via vercel-deploy skill. Returns live URL + claim URL. 30-day retention, public access.

### 3.7 Anti-Slop Design Rules
Extensive forbidden patterns: specific hex colors (#8b5cf6, #7c3aed, etc.), gradient text on headings, animated glowing shadows, specific fonts (Inter, Roboto as body), neon dashboard aesthetic, emoji in section headers. Constrained aesthetic directions: Blueprint, Editorial, Paper/ink, Terminal.

### 3.8 Thirteen Font Pairings, Five Color Palettes
Curated design system with rotation requirement (different pairing each generation). Font pairings include body + mono combinations. Palettes defined with CSS custom properties. Prose typography by voice (Literary, Technical, Bold, Minimal).

### 3.9 Surface Depth Tiers
Four tiers: Hero (accent-tinted, elevated shadow), Elevated (subtle shadow), Default (flat card with border), Recessed (inset shadow). Plus Glass tier for special overlays. Background atmosphere rules (never flat solid).

### 3.10 Animation Choreography
Staggered fadeUp (cards, sections), fadeScale (KPIs, badges), SVG drawIn (connectors), CSS counter animation (@property --count), hover lift. Slide-specific: cinematic entrance with child reveal stagger. Always respects prefers-reduced-motion.

### 3.11 surf-cli Image Generation
Optional Gemini-powered image generation via surf-cli. Check availability, generate, base64 encode, embed as data URI. Graceful degradation when unavailable. Use cases: hero banners, conceptual illustrations, slide backgrounds.

### 3.12 Fifteen Page Types
Architecture diagrams, flowcharts, sequence diagrams, data flow, schema/ER, state machines, mind maps, class diagrams, C4 architecture, data tables, timelines, dashboards, implementation plans, slide decks, prose/documentation.

### 3.13 Forty+ CSS Components
Extensive component library (`.ve-card` variants, `.data-table`, `.kpi-card`, `.pipeline`, `.diff-panels`, `.callout`, `.code-file`, `.dir-tree`, `.legend`, `.prose`, `.pullquote`, etc.) plus slide-specific components (10 slide types, progress bar, nav dots, deck counter, hints).

---

## 4. Feature Overlap Matrix

| Feature | pi-design-deck | visual-explainer | Shared? |
|---------|:---:|:---:|:---:|
| **Rendering** | | | |
| Mermaid diagram rendering | Yes | Yes | SHARED |
| Mermaid zoom/pan controls | No | Yes | Explainer-only |
| Code syntax highlighting (Prism.js) | Yes | Yes | SHARED |
| Chart.js charts | No | Yes | Explainer-only |
| Markdown rendering | No | Yes (in prose) | Explainer-only |
| Image display/embedding | Yes (image blocks) | Yes (surf-cli, base64) | SHARED |
| Raw HTML injection | Yes (previewHtml) | Yes (full page) | SHARED |
| **Theming** | | | |
| Dark/light theme | Yes | Yes | SHARED |
| Auto theme (OS preference) | Yes | Yes | SHARED |
| Manual theme toggle | Yes (hotkey) | Yes (button) | SHARED |
| CSS custom property tokens | Yes | Yes | SHARED |
| Preview palette themes | Yes | No | Deck-only |
| Anti-slop color restrictions | No | Yes | Explainer-only |
| Font pairing rotation | No | Yes (13 pairings) | Explainer-only |
| Color palette selection | No | Yes (5 palettes) | Explainer-only |
| Surface depth tiers | No | Yes (4 tiers) | Explainer-only |
| **Navigation** | | | |
| Linear slide navigation | Yes (Back/Next) | Yes (scroll-snap) | SHARED (different impl) |
| Progress bar | Yes | Yes | SHARED |
| Nav dots | No | Yes | Explainer-only |
| Slide counter (X/Y) | No | Yes | Explainer-only |
| Sidebar TOC with scroll spy | No | Yes | Explainer-only |
| Touch/swipe navigation | No | Yes | Explainer-only |
| **Keyboard** | | | |
| Arrow key navigation | Yes | Yes | SHARED |
| Number key quick-select (1-9) | Yes | No | Deck-only |
| Space to select/advance | Yes | Yes | SHARED |
| Enter to advance/submit | Yes | No | Deck-only |
| Escape to cancel | Yes | No | Deck-only |
| Cmd+S to save | Yes | No | Deck-only |
| Theme toggle hotkey | Yes | No | Deck-only |
| Page Up/Down, Home/End | No | Yes | Explainer-only |
| Focus-aware key suppression | Yes | Yes | SHARED |
| **Interactive** | | | |
| Option selection (radio metaphor) | Yes | No | Deck-only |
| Generate-more loop (SSE) | Yes | No | Deck-only |
| Skeleton/shimmer placeholders | Yes | No | Deck-only |
| Notes per option | Yes | No | Deck-only |
| Summary slide | Yes | No | Deck-only |
| Submit selections to agent | Yes | No | Deck-only |
| Confirmation dialogs | Yes | No | Deck-only |
| Model selector | Yes | No | Deck-only |
| Collapsible sections | No | Yes | Explainer-only |
| Table row hover highlight | No | Yes | Explainer-only |
| **Persistence** | | | |
| Save/load snapshots | Yes | No | Deck-only |
| Auto-save on submit/cancel | Yes | No | Deck-only |
| localStorage state | Yes | No | Deck-only |
| Dirty state tracking | Yes | No | Deck-only |
| **Output** | | | |
| HTML export (self-contained) | Yes (export action) | Yes (primary output) | SHARED |
| Browser auto-open | Yes | Yes | SHARED |
| Vercel deployment/sharing | No | Yes | Explainer-only |
| Write to diagrams directory | No | Yes | Explainer-only |
| **Server** | | | |
| HTTP server with auth | Yes | No (static files) | Deck-only |
| SSE streaming | Yes | No | Deck-only |
| Heartbeat/keepalive | Yes | No | Deck-only |
| Asset serving | Yes | No | Deck-only |
| **Agent Integration** | | | |
| Slash commands | Yes (3) | Yes (8) | SHARED (concept) |
| Structured data gathering | No | Yes (per-command) | Explainer-only |
| Verification checkpoints | No | Yes | Explainer-only |
| Auto-trigger on complex tables | No | Yes | Explainer-only |
| Fact-check workflow | No | Yes | Explainer-only |
| **Layout** | | | |
| Grid auto-columns | Yes | Yes | SHARED |
| Responsive breakpoints | Yes | Yes | SHARED |
| Layout toggle (1/2/3/4 cols) | Yes | No | Deck-only |
| Max-width centered layout | No | Yes | Explainer-only |
| Card component | No | Yes (ve-card) | Explainer-only |
| KPI cards/dashboard | No | Yes | Explainer-only |
| Pipeline/flow visualization | No | Yes | Explainer-only |
| Diff panels (before/after) | No | Yes | Explainer-only |
| **Animations** | | | |
| Slide transition | Yes | Yes | SHARED |
| Entry animation for new elements | Yes | Yes | SHARED |
| Staggered reveal | No | Yes | Explainer-only |
| CSS counter animation | No | Yes | Explainer-only |
| SVG draw-in | No | Yes | Explainer-only |
| Skeleton shimmer | Yes | No | Deck-only |
| prefers-reduced-motion | Yes | Yes | SHARED |
| **Accessibility** | | | |
| ARIA roles (radiogroup, radio) | Yes | No | Deck-only |
| aria-checked, aria-pressed | Yes | No | Deck-only |
| aria-live regions | Yes | No | Deck-only |
| focus-visible outlines | Yes | Yes (implied) | SHARED |
| Focus management on navigation | Yes | Yes (implied) | SHARED |

---

## 5. Code Savings Estimate

### Methodology
Estimating by functional area: what percentage of total implementation effort is shared vs project-specific.

### Breakdown by Area

| Area | Shared | Deck-Specific | Explainer-Specific | Total Effort Weight |
|------|--------|---------------|--------------------|--------------------|
| Mermaid rendering | 70% | 10% | 20% | 12% |
| Code highlighting | 80% | 10% | 10% | 5% |
| Theme system | 60% | 15% | 25% | 8% |
| Keyboard shortcuts | 30% | 50% | 20% | 6% |
| HTML export | 50% | 20% | 30% | 8% |
| Slide navigation | 35% | 30% | 35% | 10% |
| Responsive layout | 40% | 25% | 35% | 8% |
| Browser/server infra | 90% | 10% | 0% | 5% |
| Selection/generate-more | 0% | 100% | 0% | 12% |
| Save/load/snapshots | 0% | 100% | 0% | 5% |
| Design system (CSS) | 20% | 10% | 70% | 10% |
| Data gathering/commands | 0% | 0% | 100% | 8% |
| Animation system | 30% | 20% | 50% | 3% |

### Weighted Average

Calculating the weighted shared percentage:

- Mermaid: 0.70 * 0.12 = 0.084
- Code: 0.80 * 0.05 = 0.040
- Theme: 0.60 * 0.08 = 0.048
- Keyboard: 0.30 * 0.06 = 0.018
- Export: 0.50 * 0.08 = 0.040
- Slide nav: 0.35 * 0.10 = 0.035
- Responsive: 0.40 * 0.08 = 0.032
- Browser/server: 0.90 * 0.05 = 0.045
- Selection/gen: 0.00 * 0.12 = 0.000
- Save/load: 0.00 * 0.05 = 0.000
- Design system: 0.20 * 0.10 = 0.020
- Data gathering: 0.00 * 0.08 = 0.000
- Animation: 0.30 * 0.03 = 0.009

**Total weighted shared: ~37%**

### Conclusion

The user's hypothesis of ~1/3 overlap is accurate. The analysis yields **~37% shared infrastructure**, with the remaining ~63% split roughly evenly between deck-specific (~30%) and explainer-specific (~33%) code.

The highest-value shared components are:
1. **Mermaid rendering** -- used heavily by both, complex enough to justify shared implementation
2. **Theme system** -- foundational to both, and StreamWeaver already has the beginnings
3. **Browser/server infrastructure** -- StreamWeaver already has this
4. **Code syntax highlighting** -- straightforward to share
5. **HTML export** -- needed by both, complex to implement well

The largest project-specific investments:
- **Deck:** Selection/generate-more loop (~12% of total), save/load system (~5%)
- **Explainer:** Design system/CSS components (~10%), data gathering workflows (~8%), 40+ CSS components

### Token Savings (Separate from Code Savings)

Beyond code reuse, the unification into StreamWeaver yields massive token savings:
- **Design deck:** ~30-45% token reduction per interaction (DSL vs JSON)
- **Visual explainer:** ~80-85% token reduction per generation (DSL vs full HTML + no more 24K-37K input tokens for reference material)

This is the strongest argument for unification -- the design system, CSS patterns, and rendering logic move from "context the agent reads every time" to "framework code that runs on the server."
