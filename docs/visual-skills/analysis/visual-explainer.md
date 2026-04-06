# Visual Explainer - Comprehensive Analysis for StreamWeaver Port

**Source:** https://github.com/nicobailon/visual-explainer
**Version:** 0.6.3
**Author:** nicobailon
**License:** MIT
**Date of analysis:** 2026-03-12

---

## 1. Core Intent

### Problem
Developers working with AI coding agents (Claude Code, Pi, Codex) receive complex technical information as raw text -- ASCII tables, textual architecture descriptions, plain diff output. This is hard to parse, impossible to share, and loses context. Visual Explainer transforms that information into magazine-quality, self-contained HTML pages that open in a browser.

### User
Developers using AI agents for code review, planning, architecture understanding, and project management. The agent itself is the primary "author" -- it generates the HTML pages as part of its workflow.

### Workflow
1. User invokes a slash command (e.g., `/diff-review main`) or the agent proactively decides to generate HTML (for complex tables)
2. The agent reads reference materials (SKILL.md, templates, CSS patterns)
3. The agent gathers data from the codebase (git commands, file reads, etc.)
4. The agent generates a complete self-contained HTML file with inline CSS, optional JS
5. The file is written to `~/.agent/diagrams/` and opened in the browser
6. Optionally, the user can `/share` to deploy to Vercel for a live URL

### Key Design Philosophy
- **Never fall back to ASCII art** -- everything visual goes to the browser
- **Proactive table rendering** -- tables with 4+ rows or 3+ columns auto-generate HTML
- **Self-contained** -- single HTML file, no external assets except CDN links (fonts, Mermaid, Chart.js)
- **Both themes** -- every page must work in both light and dark mode via `prefers-color-scheme`
- **Anti-slop** -- extensive forbidden patterns to prevent generic AI-looking output

---

## 2. Feature Inventory

### Slash Commands

#### /generate-web-diagram
- **Purpose:** Generate an HTML diagram for any topic
- **Input:** Free-form topic description (`$@`)
- **Output:** Self-contained HTML page
- **Behavior:** Picks aesthetic, reads reference template, generates diagram, writes to `~/.agent/diagrams/`, opens in browser. Optional surf-cli image generation.

#### /generate-visual-plan
- **Purpose:** Visual implementation plan for a feature specification
- **Input:** Feature description (`$@`)
- **Data gathering:** Parse feature request, read relevant codebase, understand extension points, check prior art
- **Design phase:** State design, API design, integration design, edge cases
- **Output sections (10):**
  1. Header (feature name, description, scope)
  2. The Problem (before/after comparison panels)
  3. State Machine (Mermaid flowchart/stateDiagram)
  4. State Variables (card grid)
  5. Modified Functions (code snippets with explanations)
  6. Commands/API (table)
  7. Edge Cases (table)
  8. Test Requirements (table/cards)
  9. File References (table)
  10. Implementation Notes (callout boxes with colored borders)
- **Verification checkpoint** before HTML generation

#### /generate-slides
- **Purpose:** Magazine-quality slide deck presentation
- **Input:** Topic description (`$@`)
- **Output:** Scroll-snap based slide deck, 100dvh per slide
- **Slide types (10):** Title, Section Divider, Content, Split, Diagram, Dashboard, Table, Code, Quote, Full-Bleed
- **Features:** Keyboard/touch/wheel navigation, progress bar, nav dots, slide counter, hints, staggered child reveals, per-slide background variation
- **Presets (4):** Midnight Editorial, Warm Signal, Terminal Mono, Swiss Clean
- **Key constraint:** Content completeness -- every section of source must appear in deck; add more slides rather than cutting content

#### /diff-review
- **Purpose:** Visual diff review with architecture comparison and code review
- **Input:** Branch name, commit hash, HEAD, PR number, range, or no argument (defaults to main)
- **Data gathering:** git diff --stat, git diff --name-status, line counts, new API surface, feature inventory, read all changed files, check CHANGELOG/README, reconstruct decision rationale
- **Verification checkpoint** before HTML generation
- **Output sections (10):**
  1. Executive summary (hero depth, "aha moment" clarity)
  2. KPI dashboard (lines added/removed, files changed, housekeeping indicators)
  3. Module architecture (Mermaid dependency graph with zoom controls)
  4. Major feature comparisons (side-by-side before/after panels)
  5. Flow diagrams (Mermaid for new lifecycle/pipeline patterns)
  6. File map (color-coded new/modified/deleted, collapsible)
  7. Test coverage (before/after)
  8. Code review (Good/Bad/Ugly/Questions with colored accent cards)
  9. Decision log (decision, rationale, alternatives, confidence level)
  10. Re-entry context (invariants, coupling, gotchas, follow-ups)

#### /plan-review
- **Purpose:** Compare proposed implementation plan against current codebase
- **Input:** Plan file path (`$1`), optional codebase path (`$2`)
- **Data gathering:** Read plan file, read every referenced file, map blast radius, cross-reference plan vs code
- **Output sections (9):**
  1. Plan summary (hero depth)
  2. Impact dashboard (files to modify/create/delete, completeness indicator)
  3. Current architecture (Mermaid diagram)
  4. Planned architecture (Mermaid diagram, same node names for visual diff)
  5. Change-by-change breakdown (side-by-side panels with rationale)
  6. Dependency and ripple analysis (collapsible)
  7. Risk assessment (edge cases, assumptions, ordering, rollback, cognitive complexity)
  8. Plan review (Good/Bad/Ugly/Questions)
  9. Understanding gaps (decision-rationale gaps dashboard)

#### /project-recap
- **Purpose:** Rebuild mental model of a project for context-switching
- **Input:** Time window (`$1` -- e.g., `2w`, `30d`, `3m`; default `2w`)
- **Data gathering:** Project identity, recent git activity, current state, decision context, architecture scan
- **Output sections (8):**
  1. Project identity (current-state summary, not README blurb)
  2. Architecture snapshot (Mermaid diagram of system as-is)
  3. Recent activity (human-readable narrative grouped by theme)
  4. Decision log (extracted from commits/conversations/docs)
  5. State of things (KPI dashboard: working/in-progress/broken/blocked)
  6. Mental model essentials (invariants, coupling, gotchas, naming conventions)
  7. Cognitive debt hotspots (amber cards with severity indicators)
  8. Next steps (inferred from recent activity)

#### /fact-check
- **Purpose:** Verify factual accuracy of a document against actual code
- **Input:** File path (`$1`) or defaults to most recent HTML in `~/.agent/diagrams/`
- **Phases:**
  1. Extract claims (quantitative, naming, behavioral, structural, temporal)
  2. Verify against source (re-read files, re-run git commands)
  3. Correct in place (surgical text replacements)
  4. Add verification summary (banner or section)
  5. Report results
- **Key principle:** Not a re-review -- only verifies factual claims, doesn't change opinions or structure

#### /share
- **Purpose:** Deploy HTML page to Vercel for a live URL
- **Input:** File path to HTML file
- **Implementation:** Shell script (`share.sh`) that copies to temp dir as index.html, deploys via vercel-deploy skill
- **Output:** Live URL + claim URL (for transferring to Vercel account)
- **Requirements:** vercel-deploy skill
- **Retention:** Default 30 days, public access

### Auto-Trigger Behavior
- **Threshold:** Tables with 4+ rows OR 3+ columns
- **Behavior:** Agent generates HTML page instead of ASCII box-drawing table
- **Scope:** Comparisons, audits, feature matrices, status reports, configuration matrices, test results, dependency lists, permission tables, API inventories
- **UX:** Agent can include a brief text summary in chat, but the table itself is HTML in browser

### Page Types
1. **Architecture diagrams** -- CSS Grid cards + flow arrows (text-heavy) or Mermaid (topology-focused) or hybrid (15+ elements)
2. **Flowcharts/Pipelines** -- Mermaid with `graph TD` preferred
3. **Sequence diagrams** -- Mermaid `sequenceDiagram`
4. **Data flow diagrams** -- Mermaid with edge labels
5. **Schema/ER diagrams** -- Mermaid `erDiagram`
6. **State machines** -- Mermaid `stateDiagram-v2` (simple labels) or `flowchart TD` (complex labels)
7. **Mind maps** -- Mermaid `mindmap`
8. **Class diagrams** -- Mermaid `classDiagram`
9. **C4 architecture** -- Mermaid `graph TD` + `subgraph` (NOT native C4Context)
10. **Data tables** -- HTML `<table>` with sticky headers, alternating rows, status badges
11. **Timelines** -- CSS central line + cards
12. **Dashboards** -- CSS Grid + Chart.js
13. **Implementation plans** -- Structured multi-section with state machines and code snippets
14. **Slide decks** -- Scroll-snap 100dvh slides with 10 slide types
15. **Prose/documentation** -- Card grids, numbered flows, tables, callout boxes

### Mermaid Integration
- CDN: `mermaid@11` ESM module
- Optional ELK layout: `@mermaid-js/layout-elk` (separate CDN import)
- Always `theme: 'base'` with custom `themeVariables`
- Dark mode detection at load time via `matchMedia`
- CSS overrides for node/edge labels, colors
- Full zoom/pan engine (~200 lines JS): +/- buttons, Ctrl/Cmd+scroll zoom, click-and-drag pan, touch pinch zoom, double-click to fit, click-to-expand in new tab
- Smart fit algorithm: contain, width-priority, height-priority based on diagram aspect ratio
- Adaptive container height based on SVG dimensions
- Max 10-12 nodes per Mermaid diagram; hybrid pattern for 15+ elements
- Preferred direction: `flowchart TD` (top-down) over LR for complex diagrams

### Chart.js Integration
- CDN: `chart.js@4` UMD bundle
- Dark mode aware: reads `prefers-color-scheme` for text/grid colors
- Reads CSS custom properties for font family
- Used for bar, line, pie/doughnut, radar charts in dashboard pages

### Theme Support
- **Auto (default):** Uses `prefers-color-scheme` media query
- **Light-first:** `:root` = light, `@media (prefers-color-scheme: dark)` = dark
- **Dark-first:** `:root` = dark, `@media (prefers-color-scheme: light)` = light
- **Manual toggle:** `data-theme` attribute with JS toggle function
- Both themes must look intentional, not broken

### Responsive Navigation / Sticky TOC
- For pages with 4+ sections
- Desktop: Sticky sidebar TOC (170px column) with scroll spy via IntersectionObserver
- Mobile (<1000px): Horizontal scrollable sticky bar at top
- Active section highlighting with smooth scroll-into-view on mobile
- Smooth scroll on click with URL hash update

### Optional AI Image Generation
- Via `surf-cli` (Gemini-powered)
- Check availability with `which surf`
- Generate images, base64 encode, embed as data URIs
- Use cases: hero banners, conceptual illustrations, slide backgrounds
- Graceful degradation when not available

---

## 3. Architecture and Implementation

### Plugin Structure
```
visual-explainer/
  .claude-plugin/
    plugin.json            # Top-level: marketplace distribution metadata
    marketplace.json       # Marketplace listing metadata
  plugins/visual-explainer/
    .claude-plugin/
      plugin.json          # Inner: skill metadata (name, version, author, repo)
    SKILL.md               # The main brain -- teaches the agent everything
    commands/
      diff-review.md       # Slash command prompt template
      fact-check.md
      generate-slides.md
      generate-visual-plan.md
      generate-web-diagram.md
      plan-review.md
      project-recap.md
      share.md
    references/
      css-patterns.md      # ~1700 lines of CSS patterns, layout, theming
      libraries.md         # CDN library usage (Mermaid, Chart.js, anime.js, fonts)
      responsive-nav.md    # Sticky sidebar TOC + mobile horizontal bar
      slide-patterns.md    # ~1300 lines of slide deck patterns
    templates/
      architecture.html    # Reference: CSS Grid architecture layout
      data-table.html      # Reference: data tables with KPIs and status badges
      mermaid-flowchart.html  # Reference: Mermaid with full zoom/pan engine
      slide-deck.html      # Reference: all 10 slide types in one deck
    scripts/
      share.sh             # Vercel deployment script
  package.json             # NPM package metadata (for claude-code-plugin distribution)
  install-pi.sh            # Pi-specific installation script
```

### How SKILL.md Teaches the Agent
SKILL.md is the central document (~475 lines) that the agent reads at the start of every command. It provides:

1. **Workflow (4 steps):** Think > Structure > Style > Deliver
2. **Think phase:** Choose aesthetic direction, audience, content type. Constrained aesthetics preferred (Blueprint, Editorial, Paper/ink, Terminal). Forbidden patterns (neon dashboard, gradient mesh, Inter font + violet accents).
3. **Structure phase:** Read the right reference template for the content type. Routing table maps content types to rendering approaches (Mermaid, CSS Grid, HTML table, etc.). Detailed Mermaid configuration rules.
4. **Style phase:** Typography (font pairings with forbidden defaults), color palettes (forbidden accent colors), surface depth hierarchy, background atmosphere, animation choreography.
5. **Deliver phase:** Write to `~/.agent/diagrams/`, open in browser, tell user the file path.
6. **Diagram types:** Detailed guidance for each of ~15 diagram types.
7. **Slide deck mode:** Opt-in only, separate medium with different rules.
8. **Quality checks:** Squint test, swap test, both themes, information completeness, overflow, Mermaid zoom controls.
9. **Anti-patterns:** Exhaustive list of "AI slop" signals to avoid.

### How the Agent Generates HTML
The agent does NOT use traditional templates with variable substitution. Instead:
1. Agent reads SKILL.md to understand the workflow
2. Agent reads relevant reference files (css-patterns.md, libraries.md, etc.)
3. Agent reads relevant template HTML for structural patterns
4. Agent gathers data from the codebase (git commands, file reads)
5. Agent generates the ENTIRE HTML file from scratch, incorporating patterns from references
6. The HTML is a complete `<!DOCTYPE html>` document with inline `<style>` and optional `<script>`
7. Every generation is unique -- different fonts, palettes, layouts per the variety requirements

### Cross-Tool Compatibility
- **Pi:** Commands are slash commands (`/diff-review`). Installed to `~/.pi/agent/skills/`. Uses `{{skill_dir}}` placeholder replaced at install time.
- **Claude Code:** Namespaced commands (`/visual-explainer:diff-review`). Installed via `npm` (package.json has `claude-code-plugin` keyword).
- **Codex:** Uses `$visual-explainer` with description, or `/prompts:diff-review` if installed to `~/.codex/prompts/`.

### Output Location
- All diagrams written to `~/.agent/diagrams/`
- Descriptive filenames: `modem-architecture.html`, `pipeline-flow.html`
- Directory persists across sessions
- Opened via `open` (macOS) or `xdg-open` (Linux)

---

## 4. UI/UX Patterns

### Typography
- **Font pairings** (13 recommended, rotate each generation):
  - DM Sans + Fira Code (technical, precise)
  - Instrument Serif + JetBrains Mono (editorial, refined)
  - IBM Plex Sans + IBM Plex Mono (reliable, readable)
  - Bricolage Grotesque + Fragment Mono (bold, characterful)
  - Plus Jakarta Sans + Azeret Mono (rounded, approachable)
  - Outfit + Space Mono (clean geometric)
  - Sora + IBM Plex Mono (technical)
  - Crimson Pro + Noto Sans Mono (scholarly)
  - Fraunces + Source Code Pro (warm, distinctive)
  - Geist + Geist Mono (sharp, modern)
  - Red Hat Display + Red Hat Mono (cohesive)
  - Libre Franklin + Inconsolata (classic)
  - Playfair Display + Roboto Mono (elegant contrast)
- **Forbidden body fonts:** Inter, Roboto, Arial, Helvetica, system-ui alone
- **Prose typography by voice:** Literary (Literata, Lora), Technical (IBM Plex), Bold (Bricolage Grotesque), Minimal (Source Serif 4)
- All loaded via Google Fonts CDN with `display=swap`
- System font fallback in font-family stack

### Color Palettes
- **Required CSS custom properties:** `--bg`, `--surface`, `--border`, `--text`, `--text-dim`, 3-5 accent colors with dim variants
- **Recommended palettes:**
  - Terracotta + sage (`#c2410c`, `#65a30d`)
  - Teal + slate (`#0891b2`, `#0369a1`)
  - Rose + cranberry (`#be123c`, `#881337`)
  - Amber + emerald (`#d97706`, `#059669`)
  - Deep blue + gold (`#1e3a5f`, `#d4a73a`)
- **Forbidden colors:** `#8b5cf6`, `#7c3aed`, `#a78bfa` (indigo/violet), `#d946ef` (fuchsia), cyan+magenta+pink combination
- **Forbidden effects:** Gradient text on headings, animated glowing box-shadows, neon haze

### Layout System
- **Max width:** Typically 1000-1400px centered
- **Surface depth tiers (4):**
  - Hero: accent-tinted background, elevated shadow, demanding attention
  - Elevated: subtle shadow, for KPIs and key sections
  - Default: flat card with border
  - Recessed: inset shadow, for code blocks and secondary content
- **Background atmosphere:** Never flat solid -- use subtle gradients, dot grids, diagonal lines, or gradient mesh
- **Card component:** `.ve-card` (not `.node` -- Mermaid collision)
- **Grid layouts:** Architecture (2-column sidebar), Pipeline (horizontal flex), Card grid (auto-fit), Data tables (HTML `<table>`)

### Responsive Design
- Single breakpoint at 768px
- Grids collapse to single column
- Pipeline arrows hidden on mobile
- Body padding reduces from 40px to 16px
- TOC switches from sidebar to horizontal bar at 1000px
- Slide decks have height-based breakpoints (700px, 600px, 500px)

### Navigation Patterns
- **Sticky sidebar TOC:** 170px column, scroll spy via IntersectionObserver, active state with accent border
- **Mobile horizontal bar:** Sticky top, horizontal scroll, auto-scroll active tab to center
- **Slide navigation:** Keyboard (arrows, space, page up/down, home/end), touch swipe, scroll snap, progress bar, nav dots, slide counter, keyboard hints

### Animations
- **Staggered fade-in:** `fadeUp` keyframe with `--i` CSS variable for delay (0.04-0.06s per element)
- **Scale-fade:** `fadeScale` for KPI cards and badges
- **SVG draw-in:** `drawIn` for connectors using stroke-dashoffset
- **CSS counter:** `@property --count` for animating numbers without JS
- **Hover lift:** translateY(-2px) with subtle shadow
- **Slide transitions:** fade + translateY(40px) + scale(0.98), staggered child reveals (0.1s increment)
- **Forbidden:** Animated glowing shadows, pulsing/breathing effects, continuous animations after page load
- **Always:** `@media (prefers-reduced-motion: reduce)` to disable animations

### Interactive Elements
- **Mermaid zoom controls:** +/- buttons, reset, 1:1, expand (new tab)
- **Mermaid pan:** Click-and-drag with cursor change, Ctrl/Cmd+scroll zoom, touch pinch zoom
- **Mermaid click-to-expand:** Click without dragging opens full-size in new tab
- **Collapsible sections:** Native `<details>/<summary>` with styled disclosure chevron
- **Table row hover:** Background highlight for scanability
- **Theme toggle:** Optional button with sun/moon SVG icons

---

## 5. Gherkin/Cucumber Scenarios

### Generate Web Diagram

```gherkin
Feature: Generate Web Diagram
  As a developer using an AI agent
  I want to generate visual HTML diagrams
  So that I can understand complex systems better than ASCII art

  Scenario: Basic diagram generation
    Given the visual-explainer skill is loaded
    When the user invokes "/generate-web-diagram WebSocket message flow"
    Then the agent reads SKILL.md for workflow guidance
    And the agent reads the appropriate reference template
    And the agent picks a distinctive aesthetic direction
    And the agent generates a self-contained HTML file
    And the file is written to "~/.agent/diagrams/" with a descriptive filename
    And the file is opened in the default browser
    And the agent tells the user the file path

  Scenario: Diagram has light and dark themes
    Given a diagram has been generated
    When the OS is set to light mode
    Then the page renders with light palette colors
    When the OS is switched to dark mode
    Then the page renders with dark palette colors via prefers-color-scheme
    And both themes look intentional, not broken

  Scenario: Diagram uses distinctive typography
    Given a diagram is being generated
    Then the body font is NOT Inter, Roboto, Arial, Helvetica, or system-ui alone
    And the font pairing is loaded from Google Fonts CDN
    And a system font fallback is included in the font-family stack

  Scenario: Diagram avoids AI slop patterns
    Given a diagram is being generated
    Then the accent colors do NOT include #8b5cf6, #7c3aed, or #a78bfa
    And headings do NOT use gradient text with background-clip
    And section headers do NOT use emoji icons
    And cards do NOT have animated glowing box-shadows
    And the layout is NOT perfectly uniform with identical card styling

  Scenario: Diagram with surf-cli available
    Given surf-cli is installed (which surf returns a path)
    When generating a diagram where an image would enhance the page
    Then the agent generates an image via "surf gemini --generate-image"
    And base64-encodes it as a data URI
    And embeds it in the HTML
    And cleans up the temporary file

  Scenario: Diagram without surf-cli
    Given surf-cli is NOT installed
    When generating a diagram
    Then the agent skips image generation without erroring
    And the page stands on its own with CSS and typography alone
```

### Auto-Trigger on Complex Tables

```gherkin
Feature: Proactive Table Rendering
  As a developer
  I want complex data automatically rendered as HTML
  So that I don't have to ask for visual treatment of tabular data

  Scenario: Table with 4+ rows triggers HTML generation
    Given the agent is about to present tabular data
    And the table has 4 or more rows
    Then the agent generates an HTML page instead of ASCII art
    And opens it in the browser
    And tells the user the file path
    And may include a brief text summary in chat

  Scenario: Table with 3+ columns triggers HTML generation
    Given the agent is about to present tabular data
    And the table has 3 or more columns
    Then the agent generates an HTML page instead of ASCII art

  Scenario: Small table does not trigger
    Given the agent is about to present tabular data
    And the table has fewer than 4 rows AND fewer than 3 columns
    Then the agent renders it as normal text in the terminal

  Scenario: Auto-generated table has proper styling
    Given an HTML table is auto-generated
    Then the table has a sticky header
    And alternating row backgrounds via tr:nth-child(even)
    And row hover highlighting
    And status indicators use styled spans, never emoji
    And the table wraps in a scrollable container for wide content
```

### Diff Review

```gherkin
Feature: Diff Review
  As a developer
  I want a visual HTML diff review
  So that I can understand code changes with architecture context

  Scenario: Diff review against main branch
    Given the visual-explainer skill is loaded
    When the user invokes "/diff-review" with no argument
    Then the agent diffs working tree against main branch
    And gathers data: git diff --stat, --name-status, line counts, API surface
    And reads all changed files in full
    And checks CHANGELOG.md and README.md for updates needed
    And generates a verification fact sheet before HTML
    And generates an HTML page with all 10 sections
    And opens it in the browser

  Scenario: Diff review of a specific PR
    Given the user invokes "/diff-review #42"
    Then the agent runs "gh pr diff 42" for the diff data
    And proceeds with the standard review process

  Scenario: Diff review of a commit hash
    Given the user invokes "/diff-review abc123"
    Then the agent runs "git show abc123" for the diff data

  Scenario: Diff review of uncommitted changes
    Given the user invokes "/diff-review HEAD"
    Then the agent runs "git diff" and "git diff --staged"
    And reviews only uncommitted changes

  Scenario: Executive summary provides "aha moment"
    Given a diff review has been generated
    Then the executive summary section uses hero depth styling
    And it leads with WHY the changes exist
    And provides the core insight
    And a reader of only this section understands the essence of the change

  Scenario: Code review has Good/Bad/Ugly structure
    Given a diff review has been generated
    Then the code review section has 4 categories: Good, Bad, Ugly, Questions
    And each uses colored left-border cards (green, red, amber, blue)
    And each item references specific files and line ranges
    And empty categories say "None found" rather than being omitted

  Scenario: Decision log captures rationale
    Given a diff review has been generated
    Then each decision card has: decision, rationale, alternatives, confidence
    And confidence levels have visual treatment: green (high), blue (medium), amber (low)
    And low-confidence items warn "document before committing"

  Scenario: Mermaid diagram has zoom controls
    Given a diff review contains a Mermaid dependency graph
    Then the diagram is wrapped in .mermaid-wrap container
    And has zoom controls: +, -, reset, 1:1, expand
    And supports Ctrl/Cmd+scroll zoom
    And supports click-and-drag panning
    And clicking without dragging opens full-size in new tab
```

### Plan Review

```gherkin
Feature: Plan Review
  As a developer
  I want to compare a plan against the actual codebase
  So that I can identify gaps, risks, and incorrect assumptions before implementation

  Scenario: Plan review with plan file path
    Given the user invokes "/plan-review docs/plan.md"
    Then the agent reads the plan file in full
    And reads every file the plan references
    And reads files that import/depend on referenced files
    And maps the blast radius
    And cross-references plan claims against actual code
    And generates a verification fact sheet
    And generates an HTML page with all 9 sections

  Scenario: Current vs planned architecture diagrams
    Given a plan review has been generated
    Then the current architecture Mermaid diagram uses the same node names as the planned diagram
    And the layout direction matches between both diagrams
    And new nodes in the planned diagram are highlighted with accent borders
    And removed nodes have reduced opacity or strikethrough

  Scenario: Risk assessment includes cognitive complexity
    Given a plan review has been generated
    Then the risk assessment section includes cognitive complexity flags
    And each flag has a severity indicator (high/medium/low)
    And each has a concrete mitigation suggestion
    And cognitive complexity is distinct from bug risk

  Scenario: Understanding gaps dashboard
    Given a plan review has been generated
    Then the closing section rolls up rationale gaps and complexity flags
    And includes a visual bar chart of clear vs missing rationale
    And provides explicit recommendations for pre-implementation documentation
```

### Project Recap

```gherkin
Feature: Project Recap
  As a developer returning to a project after time away
  I want a visual mental model snapshot
  So that I can quickly re-orient and resume productive work

  Scenario: Default 2-week recap
    Given the user invokes "/project-recap" with no argument
    Then the agent uses a 2-week time window
    And reads README.md, CHANGELOG.md, package.json
    And runs git log --since="2 weeks ago"
    And checks for uncommitted changes and stale branches
    And reads recent commit messages for decision context
    And generates an 8-section HTML page

  Scenario: Custom time window
    Given the user invokes "/project-recap 3m"
    Then the agent uses a 3-month time window
    And adjusts git log --since="3 months ago"

  Scenario: Cognitive debt hotspots are surfaced
    Given a project recap has been generated
    Then the cognitive debt section uses amber-tinted cards
    And each hotspot has a severity indicator (red/amber/blue left border)
    And each has a concrete suggestion for remediation
    And areas include: undocumented changes, untested complex modules, overlapping modifications

  Scenario: Architecture snapshot is the visual anchor
    Given a project recap has been generated
    Then the architecture Mermaid diagram uses hero depth styling
    And labels nodes with what they DO, not just file names
    And the rest of the page conceptually hangs off this diagram
```

### Slide Deck Mode

```gherkin
Feature: Slide Deck Mode
  As a presenter
  I want to convert technical content into a presentation
  So that I can present findings to a team

  Scenario: Slide deck is opt-in only
    Given the visual-explainer skill is loaded
    When the agent encounters complex content
    Then it NEVER auto-selects slide format
    And slides are only generated via /generate-slides, --slides flag, or explicit request

  Scenario: Generate slides command
    Given the user invokes "/generate-slides API Gateway Redesign"
    Then the agent reads slide-patterns.md and slide-deck.html template
    And picks one of the 4 slide presets or adapts an existing aesthetic
    And plans the slide sequence with compositions before writing HTML
    And generates a scroll-snap deck with 100dvh slides
    And writes to ~/.agent/diagrams/ and opens in browser

  Scenario: --slides flag on diff-review
    Given the user invokes "/diff-review main --slides"
    Then the agent gathers data using diff-review's normal process
    But presents content as a slide deck instead of scrollable page
    And coverage matches what the scrollable version would have included

  Scenario: Content completeness in slides
    Given a source document has 7 sections and 6 decisions
    Then the slide deck covers all 7 sections
    And presents all 6 decisions
    And collapsible details from the source become their own slides
    And a 22-slide complete deck beats a 13-slide polished but incomplete deck

  Scenario: Slide navigation works
    Given a slide deck is displayed
    When the user presses ArrowRight or ArrowDown
    Then the next slide scrolls into view smoothly
    When the user presses ArrowLeft or ArrowUp
    Then the previous slide scrolls into view
    And Space, PageDown, PageUp, Home, End keys also work
    And touch swipe (>50px) navigates between slides
    And a progress bar shows current position
    And nav dots on the right indicate all slides with clickable navigation
    And a slide counter shows "X / Y"

  Scenario: Keyboard navigation skips interactive elements
    Given a slide deck has a Mermaid diagram or scrollable table
    When keyboard focus is inside .mermaid-wrap, .table-scroll, or .code-scroll
    Then arrow keys do NOT trigger slide navigation
    And are handled by the interactive element instead

  Scenario: Slide transitions are cinematic
    Given a slide scrolls into view
    Then it fades in from opacity 0 with translateY(40px) and scale(0.98)
    And child elements with .reveal class stagger in at 0.1s intervals
    And transitions use cubic-bezier(0.16, 1, 0.3, 1) easing
    And @media (prefers-reduced-motion: reduce) disables all transitions

  Scenario: Compositional variety
    Given a slide deck is being generated
    Then consecutive slides vary their spatial approach
    And the deck alternates between centered, left-heavy, right-heavy, split, edge-aligned, and full-bleed
    And three centered slides in a row means at least one gets pushed off-axis
```

### Fact Check

```gherkin
Feature: Fact Check
  As a developer
  I want to verify that generated documents match the actual code
  So that I can trust the information in reviews and plans

  Scenario: Fact check the most recent diagram
    Given the user invokes "/fact-check" with no argument
    Then the agent finds the most recently modified HTML in ~/.agent/diagrams/
    And extracts every verifiable claim
    And verifies each against the actual codebase
    And corrects inaccuracies in place
    And adds a verification summary section
    And reports results

  Scenario: Fact check a specific file
    Given the user invokes "/fact-check ~/.agent/diagrams/diff-review.html"
    Then the agent reads that specific file
    And proceeds with the standard verification process

  Scenario: Claims are classified
    Given a fact check is in progress
    Then each claim is classified as Confirmed, Corrected, or Unverifiable
    And the verification summary includes counts for each category
    And corrections list what was fixed with specific details

  Scenario: Corrections preserve page structure
    Given corrections are being applied to an HTML file
    Then layout, CSS, animations, and Mermaid diagrams are preserved
    And only factual content is changed
    And subjective analysis is never modified
```

### Share/Deploy

```gherkin
Feature: Share via Vercel
  As a developer
  I want to share generated pages with a live URL
  So that teammates can view them without local file access

  Scenario: Share a diagram
    Given the user invokes "/share ~/.agent/diagrams/my-diagram.html"
    And vercel-deploy skill is installed
    Then the script copies the HTML to a temp directory as index.html
    And deploys via vercel-deploy
    And returns a live URL immediately
    And returns a claim URL for account transfer
    And the deployment is public

  Scenario: Share without vercel-deploy
    Given the user invokes "/share"
    But vercel-deploy skill is NOT installed
    Then the script errors with "vercel-deploy skill not found"
    And suggests "pi install npm:vercel-deploy"

  Scenario: Share with invalid file
    Given the user invokes "/share nonexistent.html"
    Then the script errors with "File not found"
```

### Theme Switching

```gherkin
Feature: Theme Support
  As a user
  I want pages to respect my OS color scheme
  So that the visual output matches my environment

  Scenario: Automatic theme detection
    Given a page is generated with CSS custom properties
    And :root defines light values
    And @media (prefers-color-scheme: dark) defines dark values
    When the OS is in light mode
    Then the page renders with light palette
    When the OS switches to dark mode
    Then the page renders with dark palette
    And no page reload is required for CSS-only elements

  Scenario: Mermaid uses static theme
    Given a page contains a Mermaid diagram
    Then the Mermaid theme is determined once at load time via matchMedia
    And does NOT reactively switch when OS theme changes
    And CSS overrides on the container still respond to prefers-color-scheme

  Scenario: Optional manual theme toggle
    Given a page includes the theme toggle pattern
    Then a toggle button appears in the top-right corner
    And clicking switches between data-theme="light" and data-theme="dark"
    And the toggle has sun/moon SVG icons
```

---

## 6. Design System / CSS Patterns

### Design Tokens (CSS Custom Properties)

**Required minimum set:**
```
--font-body        Body text font family
--font-mono        Monospace font family
--bg               Page background
--surface          Card/container background
--surface-elevated Elevated card background (optional)
--surface2         Secondary surface (optional)
--border           Low-opacity border (rgba, ~0.06-0.08 alpha)
--border-bright    Visible border (rgba, ~0.12-0.15 alpha)
--text             Primary text color
--text-dim         Dimmed/secondary text color
--accent           Primary accent color
--accent-dim       Accent at ~0.08-0.12 alpha
--node-a/b/c       Semantic accent colors for diagram elements (with -dim variants)
--green/red/orange Status colors (with -dim variants)
--code-bg          Code block background (optional, for slides)
--code-text        Code block text color (optional)
```

### Surface Depth Tiers
| Tier | Use | Background | Shadow |
|------|-----|-----------|--------|
| Hero | Executive summary, focal elements | accent-tinted via color-mix | 4px 20px spread |
| Elevated | KPIs, key sections | --surface-elevated | 2px 8px spread |
| Default | Standard cards | --surface | 1px border only |
| Recessed | Code blocks, secondary content | mixed bg/surface | Inset shadow |
| Glass | Special overlays (rare) | 60% surface + backdrop-filter: blur | Transparent border |

### Component Inventory

| Component | CSS Class | Usage |
|-----------|----------|-------|
| Card | `.ve-card` | Base container (NOT `.node` -- Mermaid collision) |
| Card variants | `.ve-card--elevated`, `--recessed`, `--hero`, `--glass` | Depth tiers |
| Card accent | `.ve-card--accent-a/b/c` | Colored left border |
| Card label | `.ve-card__label` | Monospace uppercase label with dot |
| Section label | `.section-label` + `.dot` | Section header with colored dot |
| Flow arrow | `.flow-arrow` | Vertical arrow with SVG icon and label |
| Pipeline | `.pipeline`, `.pipeline-step`, `.pipeline-arrow` | Horizontal step flow |
| Inner grid | `.inner-grid`, `.inner-card` | 2-column grid within a section card |
| Data table | `.data-table` in `.table-wrap` > `.table-scroll` | Styled HTML table |
| Status badge | `.status--match/gap/partial/info` | Colored status indicators with dots |
| Status dot | `.status-dot--match/gap/warn` | Compact dot indicators |
| KPI card | `.kpi-card`, `.kpi-card__value`, `.kpi-card__label` | Metric display |
| KPI row | `.kpi-row` | Auto-fit grid for KPI cards |
| Code block | `.code-block`, `.code-block--scroll` | Styled code with pre-wrap |
| Code file | `.code-file`, `.code-file__header`, `.code-file__body` | Code with file header |
| Directory tree | `.dir-tree` | Pre-formatted file tree |
| Diff panels | `.diff-panels`, `.diff-panel__header--before/after` | Before/after comparison |
| Collapsible | `details.collapsible` | Native details/summary with styled chevron |
| Callout | `.callout`, `.callout--info/warning/success` | Warning/tip/note boxes |
| Legend | `.legend`, `.legend-item`, `.legend-swatch` | Color legend |
| Tags | `.tag` | Small inline labels |
| Node list | `.node-list` | List with chevron markers |
| Responsive nav | `.toc`, `.wrap`, `.main` | Sidebar/horizontal TOC |
| Mermaid container | `.diagram-shell` > `.mermaid-wrap` > `.mermaid-viewport` > `.mermaid-canvas` | Full zoom/pan diagram |
| Zoom controls | `.zoom-controls` | +/-/reset/1:1/expand buttons |
| Prose | `.prose`, `.prose--narrow`, `.prose--wide` | Reading-optimized text |
| Lead paragraph | `.lead`, `.lead--dropcap` | Opening paragraph |
| Pull quote | `.pullquote`, `.pullquote--centered` | Highlighted quotes |
| Article hero | `.hero--centered`, `.hero--editorial` | Page headers |
| Theme toggle | `.theme-toggle` | Light/dark switch button |
| Sparkline | Inline SVG `<polyline>` | Simple inline charts |
| Progress bar | Inline div with CSS gradient | Simple progress |

### Slide-Specific Components

| Component | CSS Class | Usage |
|-----------|----------|-------|
| Deck container | `.deck` | Scroll-snap container |
| Slide base | `.slide` | 100dvh viewport slide |
| Slide types | `.slide--title/divider/content/split/diagram/dashboard/table/code/quote/bleed` | Layout variants |
| Display text | `.slide__display` | 48-120px hero text |
| Heading | `.slide__heading` | 28-48px heading |
| Body | `.slide__body` | 16-24px body text |
| Label | `.slide__label` | 10-14px mono uppercase |
| Subtitle | `.slide__subtitle` | 12-18px mono subtitle |
| Reveal | `.reveal` | Staggered child animation |
| Decorative SVG | `.slide__decor` | Absolute positioned accents |
| Section number | `.slide__number` | Giant decorative number |
| KPI value | `.slide__kpi-val` | 36-64px metric |
| Code block | `.slide__code-block`, `.slide__code-filename` | Code with floating filename |
| Quote mark | `.slide__quote-mark` | Giant decorative quotation mark |
| Background | `.slide__bg`, `.slide__bg--gradient` | Full-bleed backgrounds |
| Scrim | `.slide__scrim` | Gradient overlay for text readability |
| Panels | `.slide__panels`, `.slide__panel--primary/secondary` | Split layout panels |
| Bullets | `.slide__bullets` | Styled bullet list |
| CSS Pipeline | `.pipeline`, `.pipeline__step`, `.pipeline__arrow` | Step flow for slides |
| Progress bar | `.deck-progress` | Fixed top progress bar |
| Nav dots | `.deck-dots`, `.deck-dot` | Fixed right nav dots |
| Slide counter | `.deck-counter` | Fixed bottom-right counter |
| Hints | `.deck-hints` | Auto-fading keyboard hints |

### Animation Library

| Animation | Keyframe | Use for | Stagger |
|-----------|----------|---------|---------|
| fadeUp | opacity 0->1, translateY 12->0 | Cards, sections | `--i * 0.05s` |
| fadeScale | opacity 0->1, scale 0.92->1 | KPIs, badges | `--i * 0.06s` |
| drawIn | stroke-dashoffset to 0 | SVG connectors | `--i * 0.1s` |
| countUp | @property --count integer | Hero numbers | Single, 1.2s |
| Slide entrance | opacity, translateY(40px), scale(0.98) | Slides | 0.6s |
| Reveal | opacity, translateY(20px) | Slide children | nth-child * 0.1s |

---

## 7. Token Cost Analysis

### Current Approach: Full HTML Generation

Every invocation generates a complete HTML document from scratch. Typical token costs:

| Page Type | Estimated Output Tokens | Notes |
|-----------|------------------------|-------|
| Simple diagram | 3,000-5,000 | CSS + HTML, no JS |
| Mermaid diagram | 5,000-8,000 | CSS + HTML + ~200 lines zoom JS + Mermaid init |
| Data table | 4,000-7,000 | CSS + HTML table rows |
| Diff review | 12,000-20,000 | 10 sections, Mermaid, tables, KPIs, all inline CSS |
| Plan review | 10,000-18,000 | 9 sections, 2 Mermaid diagrams, tables |
| Project recap | 8,000-15,000 | 8 sections, Mermaid, KPIs |
| Slide deck | 15,000-25,000 | 15-25 slides, SlideEngine JS, Mermaid, all CSS |

**Input tokens per invocation** (reference material the agent reads):
| File | Lines | Estimated Tokens |
|------|-------|-----------------|
| SKILL.md | 475 | ~3,500 |
| css-patterns.md | ~1,700 | ~12,000 |
| libraries.md | ~612 | ~4,500 |
| responsive-nav.md | ~213 | ~1,500 |
| slide-patterns.md | ~1,300 | ~9,500 |
| Template HTML (1 of 4) | 300-900 | ~2,500-6,000 |
| **Total input per invocation** | | **~24,000-37,000** |

**Total cost per generation:**
- Simple: ~27,000-42,000 tokens (input + output)
- Complex: ~49,000-62,000 tokens (input + output)

### StreamWeaver DSL Approach (Estimated)

With a DSL, the agent would emit DSL calls instead of raw HTML. The reference material stays on the server side, not in the prompt.

**Input token savings:**
- No need to read css-patterns.md, libraries.md, etc. in the prompt
- SKILL.md equivalent would be much shorter (just DSL API reference)
- Estimated input: ~3,000-5,000 tokens (DSL API docs + command template)

**Output token savings:**
- DSL calls instead of full HTML: ~70-85% reduction
- A diff review that generates 15,000 tokens of HTML might need ~2,000-4,000 tokens of DSL calls
- No inline CSS duplication
- No boilerplate HTML structure
- Mermaid zoom/pan JS lives in the framework, not regenerated each time

**Estimated DSL costs:**

| Page Type | Estimated Output Tokens | Savings vs Current |
|-----------|------------------------|-------------------|
| Simple diagram | 500-1,000 | ~80% |
| Mermaid diagram | 800-1,500 | ~80% |
| Data table | 600-1,200 | ~80% |
| Diff review | 2,000-4,000 | ~80% |
| Plan review | 2,000-3,500 | ~80% |
| Project recap | 1,500-3,000 | ~80% |
| Slide deck | 3,000-6,000 | ~75% |

**Total DSL cost per generation:**
- Simple: ~3,500-6,000 tokens (vs 27,000-42,000) -- **~85% reduction**
- Complex: ~7,000-11,000 tokens (vs 49,000-62,000) -- **~82% reduction**

### Key Insight for the Port

The massive token cost is split between:
1. **Reference material in the prompt (~24,000-37,000 input tokens)** -- This is the design system, CSS patterns, Mermaid configuration, etc. In StreamWeaver, this lives in the framework as Ruby code and CSS files, costing 0 prompt tokens.
2. **Generated HTML/CSS/JS output (~3,000-25,000 output tokens)** -- This is the actual page content duplicated with inline styles every time. In StreamWeaver, the agent emits DSL calls like `mermaid_diagram(title: "...", code: "graph TD\n...")` and the framework handles rendering.

The design system itself (typography, color palettes, depth tiers, animation patterns, layout components, Mermaid zoom engine) is reusable infrastructure that belongs in the framework, not in every agent conversation.

---

## 8. Key Findings for StreamWeaver Port

### What Must Be Preserved
1. **Visual quality** -- The extensive anti-slop rules, font pairings, color palettes, and depth tiers are critical to the output quality
2. **Self-contained output** -- Single HTML file that works offline (except CDN fonts)
3. **Both themes** -- Every component must work in light and dark mode
4. **Mermaid zoom/pan** -- The ~200-line zoom engine is essential for usability
5. **Responsive nav** -- Sidebar TOC on desktop, horizontal bar on mobile
6. **Animation choreography** -- Staggered reveals guide the eye through hierarchy
7. **Data gathering workflows** -- Each command has specific git commands and codebase reads
8. **Verification checkpoints** -- Fact sheets before HTML generation prevent hallucinated data

### What StreamWeaver Adds
1. **Token efficiency** -- 80-85% reduction in per-generation token cost
2. **Consistent quality** -- Design system is enforced by framework, not agent memory
3. **Reactive updates** -- StreamWeaver's reactive model enables live-updating pages
4. **Component reuse** -- Mermaid zoom engine, slide engine, nav written once
5. **Ruby DSL** -- More concise than raw HTML, more expressive than templates

### Architecture Recommendation
The visual-explainer design system should map to StreamWeaver components:

| Visual Explainer Pattern | StreamWeaver Component |
|-------------------------|----------------------|
| `.ve-card` with depth tiers | `card(depth: :hero\|:elevated\|:default\|:recessed)` |
| `.data-table` with sticky headers | `data_table(headers: [...], rows: [...])` |
| `.mermaid-wrap` with zoom engine | `mermaid_diagram(code: "...")` |
| `.kpi-row` + `.kpi-card` | `kpi_dashboard(metrics: [...])` |
| `.diff-panels` | `comparison(before: ..., after: ...)` |
| `.pipeline` | `pipeline(steps: [...])` |
| `details.collapsible` | `collapsible(title: "...") { ... }` |
| Responsive TOC | `page_with_nav(sections: [...])` |
| Slide deck | `slide_deck { slide(:title) { ... } }` |
| Theme tokens | Framework-level CSS with preset selection |
| Staggered animations | Automatic based on render order |
| Font pairing selection | `theme(preset: :editorial)` or auto-rotation |
