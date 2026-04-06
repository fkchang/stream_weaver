# pi-design-deck Comprehensive Analysis

*Analysis date: 2026-03-12*
*Source: /Users/fkchang/work/rstreamlit/pi-design-deck/ (v0.3.2)*
*Purpose: Port feasibility analysis for StreamWeaver*

---

## 1. Core Intent

### Problem Solved
When an AI coding agent needs to present visual design/architecture decisions to a user, text descriptions are inadequate. The user needs to **see** the options side-by-side -- rendered UI mockups, architecture diagrams, syntax-highlighted code, images -- and make explicit selections that become an "implementation contract."

### Target User
A developer working with the Pi coding agent (analogous to Claude Code) who needs to make multi-dimensional design decisions before implementation begins.

### Workflow
1. User asks the agent about design/architecture options (or uses `/deck`, `/deck-plan`, `/deck-discover` slash commands)
2. Agent analyzes codebase, generates a JSON deck config with slides and options
3. Agent calls `design_deck` tool with the JSON -- a local HTTP server starts, browser opens
4. User navigates slides, selects one option per slide
5. Optionally requests more options via "Generate N options" button -- agent generates and pushes via SSE
6. User submits -- selections returned as `{ slideId: "selected label" }` map
7. Agent uses selections as implementation contract

---

## 2. Feature Inventory

### 2.1 Slide Types and Options

**DeckConfig structure:**
```
{
  title?: string,
  slides: DeckSlide[]
}
```

**DeckSlide:**
- `id: string` (unique, "summary" is reserved)
- `title: string`
- `context?: string` (displayed below title as framing text)
- `columns?: 1 | 2 | 3 | 4` (grid override; auto-detected if omitted)
- `options: DeckOption[]` (at least 1)

**DeckOption:**
- `label: string` (required, non-empty)
- `description?: string` (shown on hover as title attribute)
- `aside?: string` (explanatory text below preview, supports `\n` line breaks)
- `recommended?: boolean` (shows "Recommended" badge)
- Exactly one of:
  - `previewHtml: string` (raw HTML injected via innerHTML)
  - `previewBlocks: PreviewBlock[]` (typed block array, at least 1)

### 2.2 Preview Block Types

1. **HTML block**: `{ type: "html", content: "<div>...</div>" }` -- raw HTML snippet
2. **Mermaid block**: `{ type: "mermaid", content: "graph LR\n A-->B", theme?: { primaryColor: "#ff0000" } }` -- renders via Mermaid.js CDN, optional per-block theme variable overrides
3. **Code block**: `{ type: "code", code: "const x = 1;", lang: "ts" }` -- Prism.js syntax highlighting with autoloader for language support
4. **Image block**: `{ type: "image", src: "/absolute/path.png", alt: "description", caption?: "optional" }` -- served from temp directory via `/assets/` endpoint

### 2.3 The Generate-More Loop

**Trigger:** User clicks "Generate N options" button on any slide.

**Client-side flow:**
1. User optionally types instructions in prompt input, selects count (1-3) from dropdown
2. Click sends POST `/generate-more` with `{ slideId, prompt?, model?, thinking?, count }`
3. Client shows skeleton placeholder(s) with shimmer animation in the options grid
4. Button enters loading state ("Generating...")

**Server-side flow:**
1. Server validates request, sets `pendingGenerate` with 90-second timeout
2. Calls `callbacks.onGenerateMore(slideId, prompt, model, thinking, count)`
3. This resolves the Promise blocking the tool, returning structured prompt text to the agent

**Agent-side flow:**
1. Tool returns with `status: "generate-more"` and a text prompt instructing the agent:
   - Which slide needs options, how many
   - What options already exist (labels + descriptions)
   - Whether to use a specific model (via `deck_generate` tool)
   - The format hint (previewBlocks or previewHtml)
   - The exact tool call to make: `design_deck({ action: "add-options", slideId, options: "[...]" })`
2. Agent generates options and calls `design_deck({ action: "add-options", ... })`
3. Server pushes each option via SSE `new-option` event
4. Client receives, removes skeleton, renders new option card with entry animation
5. `add-options` call blocks until next user action

**Regenerate-all flow:**
- "Regenerate all" button replaces all options on a slide
- Uses `action: "replace-options"`
- Shows overlay with skeleton placeholders covering existing options
- SSE event: `replace-options` with full replacement array

**Single option (non-blocking):**
- `action: "add-option"` pushes one option and returns immediately (for parallel calls)

**Error handling:**
- 90-second generation timeout on server
- 30-second per-option timeout on client
- SSE events: `generate-failed`, `regenerate-failed`
- JSON parse errors return actionable messages
- Invalid option structure returns specific validation errors
- `cancelGenerate()` clears pending state and sends failure event

### 2.4 Selection/Submission Flow

**Selection:**
- Click option card or press number key (1-9)
- Stores in `selections[slideId] = label`
- Visual: radio button fills, checkmark appears (with pop animation), border highlights
- Persisted to localStorage keyed by sessionId
- Each option has a "Your notes (optional)" textarea

**Summary slide:**
- Auto-generated as last slide (id: "summary")
- Shows grid of summary cards with slide title, selected option label, preview thumbnail, aside text, and notes
- "Additional instructions" textarea for final notes
- Submit button enabled only when all slides have selections
- Shows "Still need: X, Y" message for incomplete selections

**Submit:**
- POST `/submit` with `{ selections, notes, finalNotes }`
- Auto-saves snapshot with `-submitted` suffix
- Clears localStorage
- Shows close overlay: "Selections sent to agent. You can close this tab."
- Auto-closes tab after 800ms
- Tool resolves with `{ status: "completed", selections, notes?, finalNotes? }`

### 2.5 Save/Load/Export Snapshots

**Manual save (Cmd+S):**
- POST `/save` with current selections and notes
- Saves to `~/.pi/deck-snapshots/{title}-{project}-{branch}-{date}-{time}/deck.json`
- Shows toast notification with path
- Tracks dirty state ("Unsaved changes" / "Saved at HH:MM")

**Auto-save on submit:** Enabled by default (`autoSaveOnSubmit: true`)

**Auto-save on cancel:** If selections exist when cancelling, saved with `-cancelled` suffix

**Snapshot structure:**
```
{title}-{project}-{branch}-{date}-{time}[-submitted|-cancelled]/
  deck.json     # { config, selections, savedAt, id, status, modifiedAt, notes, finalNotes, savedFrom }
  images/       # Copied image assets with relative paths
```

**List saved decks:** `design_deck({ action: "list" })` -- returns array of `{ id, title, savedAt, modifiedAt, status, cwd, branch, slideCount }`

**Open saved deck:** `design_deck({ action: "open", deckId: "..." })` -- reopens with selections and notes restored

**Export:** `design_deck({ action: "export", deckId: "...", format: "html" })` -- generates standalone HTML with:
- Embedded CSS (all 4 CSS files)
- Inlined base64 images
- Mermaid CDN for diagrams
- Google Fonts link
- All slides visible simultaneously (no navigation)
- Meta chips showing deck ID, status, timestamps, cwd, branch
- Selected options highlighted with "Selected" badge

### 2.6 Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Left/Right arrows | Navigate slides (or if focused on option, move between options) |
| Up/Down arrows | Move between options within a slide |
| 1-9 | Quick-select option by number |
| Space | Select focused option |
| Enter | Select focused option, or advance to next slide, or submit on summary |
| Escape | Cancel (shows confirmation bar if selections exist; second Escape confirms) |
| Cmd+S / Ctrl+S | Save snapshot |
| Cmd+Shift+L | Toggle theme (configurable hotkey) |

### 2.7 Theme Support

**Three modes:** `dark` (default), `light`, `auto` (follows OS `prefers-color-scheme`)

**Implementation:**
- CSS custom properties on `:root` and `[data-theme="light"]`
- `data-theme` attribute on `<html>`
- `colorScheme` CSS property set
- `<meta name="theme-color">` updated
- Theme override stored in localStorage (`pi-deck-theme-override`)
- Configurable hotkey parsed from string like `"mod+shift+l"` (mod = Cmd on Mac, Ctrl otherwise)
- Auto mode listens for `matchMedia` changes

**Preview palette themes (for previewHtml):**
- `midnight-rose`, `slate-jade`, `warm-copper`, `ocean-cyan`
- Font themes: `albert`, `jakarta`, `grotesk`
- Applied via `data-theme` and `data-fonts` attributes on `.preview` elements

### 2.8 Model Selector

**Visibility:** Shown when 2+ models available in the agent's model registry

**UI:** Model bar below header with:
- Provider filter pills (Current, anthropic, google, etc.)
- Model list with selectable items showing model name and "current" tag
- "Default" checkbox to save selection to settings
- Thinking level pills (off, low, medium, high, xhigh) -- only for reasoning models when using current model

**Model override flow:**
1. User selects a non-current model
2. Generate-more prompt includes instruction to use `deck_generate` tool
3. `deck_generate` spawns headless `pi` CLI with `--provider` and `--model` flags
4. Agent parses output as options JSON

**Persistence:** Default model saved to `~/.pi/agent/settings.json` under `designDeck.generateModel`

### 2.9 Accessibility Features

- `role="radiogroup"` on options container
- `role="radio"` + `aria-checked` on option cards
- `aria-label` on radiogroups, inputs, model list
- `aria-pressed` on layout toggle buttons
- `aria-live="polite"` on summary description and save status
- `focus-visible` outlines on interactive elements
- Heading focus on slide change (`h2.focus()`)
- `tabIndex` management (interactive elements inside previews set to -1)
- `prefers-reduced-motion` media query disables animations

### 2.10 Error Handling / Edge Cases

- **Single option per slide:** Valid (columns auto-set to 1)
- **Many options:** Grid rebalances; cols-4 supported
- **Cancel with selections:** Auto-saves with `-cancelled` suffix, confirmation bar shown
- **Browser disconnection:** Heartbeat watchdog (5s interval, 60s grace period) triggers stale cancel
- **Agent disconnection:** Idle timer (5 minutes) after generate-more closes deck
- **Abort signal:** Agent abort closes deck immediately
- **Duplicate slide IDs:** Rejected during validation
- **Reserved ID "summary":** Rejected during validation
- **Body size limit:** 15MB max (BodyTooLargeError)
- **Session token validation:** All endpoints require valid session token
- **JSON parse errors:** Descriptive error messages with snippet of bad input
- **Concurrent decks:** Only one active deck allowed
- **Path traversal:** `resolveDeckFilePath` validates deckId has no slashes or `..`
- **Tab close:** `beforeunload` sends cancel beacon via `navigator.sendBeacon`
- **Double submit:** `isSubmitting` flag prevents re-entry

---

## 3. Architecture & Implementation

### 3.1 Server Architecture

**HTTP server (Node.js `http`):**
- Binds to `127.0.0.1` on specified port (default: random/0)
- Token-based auth via `?session=UUID` query param (GET) or `token` body field (POST)
- No CORS (localhost only)

**Endpoints:**
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | Serve deck HTML (template with inlined data) |
| GET | `/deck.css` | Concatenated CSS (4 files) |
| GET | `/deck.js` | Concatenated JS (4 files) |
| GET | `/assets/{file}` | Serve image assets from temp dir |
| GET | `/events` | SSE stream |
| GET | `/health` | Health check |
| GET | `/models` | Available models |
| POST | `/heartbeat` | Keep-alive ping |
| POST | `/submit` | Submit selections |
| POST | `/save` | Save snapshot |
| POST | `/cancel` | Cancel deck |
| POST | `/generate-more` | Request new options |
| POST | `/regenerate-slide` | Request replacement options |
| POST | `/save-model-default` | Save default model |

**SSE events:**
- `new-option` -- `{ slideId, option }` (new option generated)
- `replace-options` -- `{ slideId, options }` (regenerated options)
- `generate-failed` -- `{ slideId, reason? }`
- `regenerate-failed` -- `{ slideId, reason? }`
- `deck-close` -- `{ reason }` (submitted, user, stale, aborted, closed)

### 3.2 Client-Side State Management

**Global state in `deck-core.js`:**
- `slides[]` -- mutable copy of config slides (options can be appended)
- `selections{}` -- slideId -> label map
- `optionNotes{}` -- slideId -> { label, notes }
- `finalNotes` -- string
- `current` -- current slide index
- `isClosed`, `isSubmitting`, `isDirty`
- `pendingGenerate` -- Map of slideId -> pending generation state
- `selectedModel`, `selectedThinking`

**Persistence:**
- Selections + notes saved to localStorage keyed by `pi-deck-{sessionId}`
- Layout preference saved to localStorage (`pi-deck-layout`)
- Theme override saved to localStorage (`pi-deck-theme-override`)

**JS module structure (concatenated in order):**
1. `deck-core.js` -- state, config, DOM refs, utilities, theme, layout toggle, selection persistence
2. `deck-render.js` -- mermaid rendering, code blocks, preview blocks, option cards, slide rendering, summary
3. `deck-interact.js` -- selection logic, navigation, keyboard handling, model bar
4. `deck-session.js` -- network (postJson), save/snapshot, session lifecycle, generate-more, SSE, init

### 3.3 Agent-Tool Communication

The tool uses a Promise-based blocking pattern:

1. `design_deck()` starts server, opens browser, returns `blockOnDeck()` (Promise)
2. Promise resolves when user submits, cancels, or clicks generate-more
3. For generate-more: Promise resolves with structured prompt, agent processes, calls `add-options`
4. `add-options` pushes options via SSE and returns `blockOnDeck()` again
5. Cycle repeats until submit or cancel

**Module-level state:**
- `activeDeckServer` -- handle + current resolve callback
- `pendingDeckResult` -- for results that arrive when no resolve is waiting
- `activeDeckIdleTimer` -- 5-minute idle timer
- `restoreDeckThinking` -- function to restore thinking level on cleanup

### 3.4 Tool Parameter API

```typescript
DeckParams = {
  slides?: string,          // JSON string or file path
  action?: "add-option" | "add-options" | "replace-options" | "list" | "open" | "export",
  slideId?: string,         // target slide for option actions
  option?: string,          // JSON string of single option (add-option)
  options?: string,         // JSON array string (add-options, replace-options)
  deckId?: string,          // saved deck folder name (open, export)
  format?: string,          // export format ("html")
}
```

### 3.5 Persistent Server Across Re-invocations

The server persists because:
1. `activeDeckServer` is module-level state (survives across tool calls)
2. First call creates server, subsequent `add-options`/`add-option` calls interact with same server
3. Server closes only on: submit, cancel, stale heartbeat, idle timeout, abort, or session shutdown
4. Browser stays open -- SSE reconnects automatically if needed

### 3.6 Asset Serving

- Image blocks reference absolute file paths on disk
- Server copies images to temp dir (`mkdtempSync`)
- Served via `/assets/{uuid}{ext}` with appropriate MIME types
- Supported: png, jpg/jpeg, gif, webp, svg, avif
- Cleanup: temp dir removed on server close (`rmSync`)
- Snapshots copy images to `images/` subdirectory with relative paths

### 3.7 Settings System

**File:** `~/.pi/agent/settings.json` under `designDeck` key

```typescript
interface DesignDeckSettings {
  port?: number;              // Server port (0 = random)
  browser?: string;           // Browser app name
  theme?: {
    mode?: "auto" | "light" | "dark";
    toggleHotkey?: string;    // e.g., "mod+shift+l"
  };
  snapshotDir?: string;       // Snapshot directory (~ expansion)
  autoSaveOnSubmit?: boolean; // Default: true
  generateModel?: string;     // Default model for generation
}
```

**Migration:** Auto-migrates `interview.deckGenerateModel` to `designDeck.generateModel`.

---

## 4. UI/UX Patterns

### 4.1 Layout System

**Grid columns auto-detection (`optionCountClass`):**
- 1 option: 1 column
- 2 or 4 options: 2 columns
- 3+ options: 3 columns
- Per-slide `columns` override
- Global layout toggle (1/2/3/4 buttons in footer) overrides everything via `data-layout` attribute
- Layout persisted in localStorage

**Responsive breakpoints:**
- <1200px: 3-col grid collapses to 2
- <900px: 2-col and 3-col collapse to 1; slide padding reduces; save status hidden

**CSS Grid subgrid:** Options use `grid-row: span 3` with subgrid for header/preview/footer alignment

### 4.2 Animations

- **Slide transition:** opacity + translateY (0.35s ease)
- **Check mark pop:** scale 0->1 (0.35s cubic-bezier overshoot)
- **Option entry (generated):** opacity + scale(0.92) + translateY(8px) + blur(6px) (0.5s)
- **Regenerated options:** translateY(12px) + scale(0.96) with staggered delays (0.05s per item)
- **Skeleton shimmer:** linear-gradient background-position animation (1.5s infinite)
- **Regen overlay fade-in:** 0.3s ease-out
- **Progress bar:** width transition (0.4s cubic-bezier)
- **Loading overlay:** fade-out (0.25s)
- **Toast notification:** translateY(8px) -> 0 (0.3s)
- **Confirm bar:** translateY(-100%) -> 0 (0.25s)
- **Reduced motion:** All animations disabled via `prefers-reduced-motion`

### 4.3 Navigation Patterns

- Linear slide progression (Back/Next buttons)
- Progress bar showing position
- Arrow keys for slide navigation (left/right) and option focus (up/down within radiogroup)
- Summary as final slide
- Back disabled on first slide; Next disabled on summary

### 4.4 Selection Patterns

- Radio-button metaphor (one selection per slide)
- Visual: radio indicator, accent border, checkmark badge, header background change
- Number keys for quick selection (1-9)
- Click anywhere on option card
- Selection state tracked independently from focus

### 4.5 Summary Slide Behavior

- Auto-populated from current selections
- Shows preview thumbnail (first block only: code snippet 3 lines, image 80px, mermaid miniature, or HTML preview)
- Shows aside text (truncated to 120 chars)
- Shows user notes per option
- Final notes textarea
- Submit button: disabled until all selections made, shows "Still need: X, Y"
- After submit: button changes to "Submitted" with green background

### 4.6 Confirmation Dialogs

**Cancel confirmation bar:**
- Fixed at top of viewport, slides down
- Shows: "Cancel deck? Selections will be lost."
- Two buttons: "Cancel" (red) and "Keep Going"
- Auto-hides after 5 seconds
- First Escape shows bar; second Escape (or click Cancel) confirms

**Close overlay:**
- Fixed full-screen overlay with blur backdrop
- Color-coded: green (submitted), amber (cancelled), red (stale/aborted/closed)
- Messages: "Selections sent to agent", "Deck cancelled", "Session ended -- lost connection", "Session was ended by the agent", "Session was closed"
- Auto-closes tab after 800ms for submit/cancel

---

## 5. Gherkin/Cucumber Scenarios

### Feature: Creating a New Deck

```gherkin
Feature: Deck Creation
  As a developer using an AI agent
  I want to view visual design options in a browser
  So that I can make informed implementation decisions

  Scenario: Start a new deck with previewHtml options
    Given the agent has generated a deck config with 3 slides
    And each slide has 2-4 options with previewHtml
    When the agent calls design_deck with the slides JSON
    Then a local HTTP server starts on a random port
    And the browser opens to the deck URL with a session token
    And the deck displays the first slide with options in a grid
    And a progress bar shows 1/4 (including summary)

  Scenario: Start a new deck with previewBlocks options
    Given a deck config with code, mermaid, and image blocks
    When the agent calls design_deck with the slides JSON
    Then code blocks render with Prism.js syntax highlighting
    And mermaid blocks render as SVG diagrams
    And image blocks display from the temp assets directory
    And blocks stack vertically within each option card

  Scenario: Deck with per-slide column override
    Given a slide with columns set to 1
    When the deck renders that slide
    Then options display in a single-column layout
    And other slides use auto-detected column counts

  Scenario: Deck with context text
    Given a slide with a context property
    When the deck renders that slide
    Then the context text appears below the slide title
    And it is styled as secondary text with max-width 640px

  Scenario: Deck rejects invalid config
    Given a deck config with a slide ID of "summary"
    When the agent calls design_deck
    Then it throws an error: '"summary" is reserved'

  Scenario: Deck rejects duplicate slide IDs
    Given a deck config with two slides both having id "arch"
    When the agent calls design_deck
    Then it throws an error about duplicate slide ids

  Scenario: Deck rejects option with both previewHtml and previewBlocks
    Given an option that has both previewHtml and previewBlocks
    When the agent calls design_deck
    Then it throws an error: "must have either previewHtml or previewBlocks, not both"

  Scenario: Deck rejects option with neither preview type
    Given an option that has neither previewHtml nor previewBlocks
    When the agent calls design_deck
    Then it throws an error about requiring non-empty preview

  Scenario: Only one deck active at a time
    Given a design deck is already active
    When the agent calls design_deck with new slides
    Then it returns an error: "A design deck is already active"

  Scenario: Deck requires interactive mode
    Given the agent is running in headless/RPC mode
    When the agent calls design_deck (not list or export)
    Then it throws an error about requiring interactive mode
```

### Feature: Navigating Slides

```gherkin
Feature: Slide Navigation
  As a user viewing a design deck
  I want to navigate between slides
  So that I can review all decision points

  Scenario: Navigate forward with button
    Given the deck is showing slide 1 of 3
    When I click the "Next" button
    Then slide 2 becomes active with a fade transition
    And the progress bar updates to 2/4
    And the heading of slide 2 receives focus

  Scenario: Navigate backward with button
    Given the deck is showing slide 2 of 3
    When I click the "Back" button
    Then slide 1 becomes active
    And the Back button becomes disabled

  Scenario: Navigate with arrow keys
    Given the deck is showing slide 1
    And no option card is focused
    When I press the Right arrow key
    Then slide 2 becomes active

  Scenario: Arrow keys within radiogroup
    Given an option card has focus
    When I press the Down arrow key
    Then focus moves to the next option card
    And the slide does not change

  Scenario: Navigate to summary slide
    Given the deck is showing the last regular slide
    When I click "Next"
    Then the summary slide appears
    And the "Next" button shows "Done" and is disabled

  Scenario: Back button disabled on first slide
    Given the deck is showing slide 1
    Then the "Back" button is disabled
```

### Feature: Selecting Options

```gherkin
Feature: Option Selection
  As a user viewing a design deck
  I want to select one option per slide
  So that my choices are communicated to the agent

  Scenario: Select by clicking
    Given slide 1 has 3 options
    When I click option "Microservices"
    Then option "Microservices" shows as selected
    And a checkmark badge appears with a pop animation
    And the radio indicator fills with accent color
    And selections are saved to localStorage

  Scenario: Select by number key
    Given slide 1 has 3 options
    When I press the "2" key
    Then the second option becomes selected

  Scenario: Select by Space key
    Given an option card has focus
    When I press Space
    Then that option becomes selected

  Scenario: Change selection
    Given option "Monolith" is selected on slide 1
    When I click option "Microservices"
    Then "Microservices" becomes selected
    And "Monolith" is deselected
    And dirty state is marked

  Scenario: Selection persists across page reload
    Given I have selected options on slides 1 and 2
    When I reload the page
    Then my previous selections are restored from localStorage

  Scenario: Add notes to selected option
    Given option "Microservices" is selected
    When I type "Use event sourcing" in the notes textarea
    Then the notes are saved to localStorage
    And dirty state is marked
    And notes appear in the summary slide

  Scenario: Recommended badge display
    Given an option has recommended: true
    And it is not selected
    Then a "Recommended" badge appears in the header

  Scenario: Aside text display
    Given an option has aside text with newlines
    Then the aside text renders below the preview
    And newline characters render as line breaks
```

### Feature: Generate-More Flow

```gherkin
Feature: Generate More Options
  As a user who wants additional design options
  I want to request AI-generated alternatives
  So that I have more choices to consider

  Scenario: Generate one additional option
    Given the deck is showing a slide with 2 options
    When I click "Generate" with count set to 1
    Then a skeleton placeholder with shimmer animation appears
    And the button shows "Generating..." with a spinner
    And the prompt input is disabled
    And the agent receives a generate-more instruction
    When the agent pushes a new option via add-options
    Then the skeleton is replaced with the new option card
    And the card has an entry animation (scale + blur)
    And a "Generated" badge appears on the option
    And the grid rebalances for the new option count

  Scenario: Generate multiple options at once
    Given the deck is showing a slide with 2 options
    When I select count "3" and click "Generate"
    Then 3 skeleton placeholders appear
    And the agent receives count=3 in the instruction
    When the agent pushes 3 options via add-options
    Then skeletons are removed one by one as options arrive

  Scenario: Generate with custom prompt
    Given I type "make it more minimal" in the prompt input
    When I click "Generate"
    Then the prompt text is included in the agent instruction
    And the prompt input is cleared

  Scenario: Generate with Enter key in prompt
    Given focus is in the prompt input
    When I press Enter
    Then generation is triggered (same as clicking Generate)

  Scenario: Generation timeout
    Given I clicked "Generate"
    And 30 seconds pass without receiving an option
    Then a toast shows "Generation timed out -- try again"
    And the generate button is restored
    And skeletons are removed

  Scenario: Generation failure
    Given the agent encounters an error generating options
    Then a "generate-failed" SSE event is sent
    And a toast shows "Generation failed"
    And the button is restored

  Scenario: Regenerate all options
    Given the slide has 3 options
    When I click "Regenerate all"
    Then a skeleton overlay covers the existing options grid
    And a centered spinner with "Regenerating options..." text appears
    And the agent receives a regenerate-slide instruction
    When the agent pushes 3 replacement options via replace-options
    Then the overlay is removed
    And new options appear with staggered entry animations
    And the previous selection for this slide is cleared

  Scenario: Concurrent generation prevented
    Given a generation is already in progress
    When I try to click "Generate" or "Regenerate all"
    Then the buttons are disabled and nothing happens
```

### Feature: Model Selection for Generation

```gherkin
Feature: Model Selector
  As a user who wants control over option generation
  I want to choose which AI model generates new options
  So that I can get options from different model capabilities

  Scenario: Model bar appears with multiple models
    Given the agent has 3+ models available
    When the deck loads
    Then a model bar appears below the header
    And "Current" pill is active by default
    And provider pills are shown (anthropic, google, etc.)

  Scenario: Select a model from a provider
    Given the model bar is visible
    When I click the "google" provider pill
    Then a model list appears with Google models
    When I click "gemini-3.1-pro"
    Then the model is selected and shown in the label
    And subsequent generate-more requests use this model

  Scenario: Save model as default
    Given a model is selected
    When I check the "Default" checkbox
    Then the model is saved to settings.json
    And future decks pre-select this model

  Scenario: Thinking level adjustment
    Given the current model supports reasoning
    And no override model is selected
    Then thinking level pills appear (off, low, medium, high)
    When I click "high"
    Then the thinking level is included in generate requests

  Scenario: Model bar hidden with fewer than 2 models
    Given the agent has only 1 model available
    When the deck loads
    Then no model bar appears
```

### Feature: Save/Load/Export

```gherkin
Feature: Save and Load Decks
  As a user who wants to preserve my design decisions
  I want to save, load, and export deck snapshots
  So that I can resume work or share decisions

  Scenario: Manual save with Cmd+S
    Given I have selections on 2 slides
    When I press Cmd+S
    Then a POST /save request is sent
    And a snapshot is saved to the snapshots directory
    And a toast shows "Saved to ~/.pi/deck-snapshots/..."
    And the save status shows "Saved at HH:MM"

  Scenario: Auto-save on submit
    Given autoSaveOnSubmit is true (default)
    When I submit the deck
    Then a snapshot is saved with "-submitted" suffix
    And image assets are copied to an images/ subdirectory

  Scenario: Auto-save on cancel with selections
    Given I have selected options
    When I cancel the deck
    Then a snapshot is saved with "-cancelled" suffix

  Scenario: List saved decks
    Given there are 3 saved decks
    When the agent calls design_deck({ action: "list" })
    Then it returns an array of deck metadata
    And each entry has id, title, savedAt, status, slideCount

  Scenario: Open a saved deck
    Given a deck "api-design-myapp-main-submitted" exists
    When the agent calls design_deck({ action: "open", deckId: "..." })
    Then the deck opens with selections pre-populated
    And notes are restored
    And image paths are resolved relative to the snapshot

  Scenario: Export as standalone HTML
    Given a submitted deck exists
    When the agent calls design_deck({ action: "export", deckId: "...", format: "html" })
    Then an export.html file is written next to deck.json
    And it contains embedded CSS, inlined images, and meta chips
    And all slides are visible simultaneously (no navigation)

  Scenario: Dirty state tracking
    Given I make a selection
    Then save status shows "Unsaved changes"
    And the Save button gets a warning style
    When I save
    Then status shows "Saved at HH:MM"
    And the Save button returns to normal
```

### Feature: Keyboard Navigation

```gherkin
Feature: Keyboard Navigation
  As a user who prefers keyboard interaction
  I want full keyboard support
  So that I can navigate and select efficiently

  Scenario: Quick select by number
    Given slide 1 has 4 options
    When I press "3"
    Then the third option is selected

  Scenario: Enter advances to next slide
    Given I am on slide 1
    And no option or button has focus
    When I press Enter
    Then slide 2 becomes active

  Scenario: Enter on summary submits
    Given I am on the summary slide
    And all selections are made
    When I press Enter
    Then the deck is submitted

  Scenario: Escape shows confirmation then cancels
    Given I have selections
    When I press Escape
    Then the confirmation bar appears
    When I press Escape again
    Then the deck is cancelled

  Scenario: Escape with no selections cancels immediately
    Given I have no selections
    When I press Escape
    Then the deck is cancelled immediately

  Scenario: Arrow navigation between options
    Given an option card has focus
    When I press ArrowDown
    Then focus moves to the next option
    When I press ArrowUp
    Then focus moves to the previous option
    And wrapping occurs at boundaries
```

### Feature: Theme Switching

```gherkin
Feature: Theme Switching
  As a user with theme preferences
  I want to toggle between light and dark themes
  So that the deck matches my environment

  Scenario: Default dark theme
    Given no theme override exists
    And theme mode is "dark" (default)
    When the deck loads
    Then the page uses dark theme variables
    And meta theme-color is #18181e

  Scenario: Toggle to light theme
    Given the deck is in dark theme
    When I press Cmd+Shift+L
    Then the page switches to light theme
    And meta theme-color is #f8f8f8
    And the override is saved to localStorage

  Scenario: Auto theme follows OS
    Given theme mode is "auto"
    And OS is in light mode
    When the deck loads
    Then light theme is applied
    When OS switches to dark mode
    Then dark theme is applied

  Scenario: Theme shortcut label in footer
    Given a theme toggle hotkey is configured
    Then the footer shows the hotkey combination
```

### Feature: Error Cases

```gherkin
Feature: Error Handling
  As a user of the design deck
  I want graceful error handling
  So that I don't lose my work

  Scenario: Browser loses connection
    Given the deck is open
    When the browser stops sending heartbeats
    And 60 seconds pass
    Then the server detects stale connection
    And the deck is cancelled with reason "stale"
    And any pending generations are cleared

  Scenario: Agent idle timeout
    Given the agent received a generate-more request
    And 5 minutes pass without the agent responding
    Then the deck is closed with reason "idle-timeout"

  Scenario: Agent aborts the deck
    Given the deck is open
    When the agent receives an abort signal
    Then the deck is closed with reason "aborted"
    And a close overlay shows "Session was ended by the agent"

  Scenario: Invalid JSON in add-options
    Given the agent calls add-options with malformed JSON
    Then the tool returns an error with the parse message
    And a snippet of the bad JSON is shown
    And pending generation is cancelled

  Scenario: Invalid option structure
    Given the agent calls add-option with an option missing a label
    Then the tool returns a validation error
    And specifies what is required

  Scenario: Tab closed by user
    Given the deck is open with selections
    When the user closes the browser tab
    Then a cancel beacon is sent via navigator.sendBeacon
    And selections are included for auto-save
```

---

## 6. Example Runs

### Minimal Deck Config
```json
{
  "slides": [{
    "id": "s1",
    "title": "Pick one",
    "options": [
      { "label": "A", "previewHtml": "<div>A</div>" },
      { "label": "B", "previewHtml": "<div>B</div>" }
    ]
  }]
}
```

### Architecture Comparison Deck (from SKILL.md)
```json
{
  "title": "Architecture Direction",
  "slides": [{
    "id": "arch",
    "title": "System Architecture",
    "context": "Choose the high-level architecture for the backend.",
    "columns": 2,
    "options": [
      {
        "label": "Monolith",
        "description": "Single deployable, shared database",
        "aside": "Simpler to deploy and debug. Good starting point.\nWatch for coupling as the codebase grows.",
        "previewBlocks": [
          { "type": "mermaid", "content": "graph TD\n  Client-->API\n  API-->DB" },
          { "type": "code", "code": "app.listen(3000)", "lang": "ts" }
        ]
      },
      {
        "label": "Microservices",
        "description": "Event-driven, independently deployable",
        "aside": "Independent scaling and deployment per service.\nRequires service mesh, distributed tracing, and eventual consistency patterns.",
        "previewBlocks": [
          { "type": "mermaid", "content": "graph LR\n  Gateway-->Auth\n  Gateway-->Orders\n  Gateway-->Inventory" },
          { "type": "code", "code": "bus.publish('order.created', payload)", "lang": "ts" }
        ],
        "recommended": true
      }
    ]
  }]
}
```

### Saved Deck Structure (deck.json)
```json
{
  "config": { "title": "API Design", "slides": [...] },
  "selections": { "auth": "JWT + Refresh Tokens", "db": "PostgreSQL" },
  "savedAt": "2026-03-01T10:30:45.000Z",
  "id": "api-design-myapp-main-2026-03-01-103045-submitted",
  "status": "submitted",
  "modifiedAt": "2026-03-01T10:30:45.000Z",
  "notes": { "auth": "Use short-lived tokens" },
  "finalNotes": "Prioritize security over convenience",
  "savedFrom": { "cwd": "~/work/myapp", "branch": "main", "sessionId": "uuid" }
}
```

### Generate-More Prompt (what agent receives)
```
The design deck is still open and waiting for your response.

User clicked "Generate 2 options" for slide "System Architecture".
Context: Choose the high-level architecture for the backend.

Existing options:
- Monolith: Single deployable, shared database -- Simpler to deploy and debug.
- Microservices: Event-driven, independently deployable -- Independent scaling and deployment per service.

YOU MUST generate 2 distinctive additional options and call design_deck with add-options (one call with all options in an array). Do not skip this step or decide the user has enough options -- they explicitly requested 2 more.

design_deck({"action":"add-options","slideId":"arch","options":"[{"label":"Option label","description":"Short rationale","aside":"Explanatory notes below the preview","previewBlocks":[{"type":"code","code":"...","lang":"ts"}],"recommended":false}, ...]"})

The options field must be a JSON string containing an array of 2 option objects.
Each option needs: label, optional description, optional aside, optional recommended, and either previewHtml or previewBlocks.
Use previewBlocks (array of typed blocks: html, mermaid, code, image) to match the existing options.

Make each option distinctive -- they should represent genuinely different approaches.
```

---

## 7. Token Cost Analysis

### Current Approach: Token Usage per Interaction

**Initial deck creation (agent generates slides JSON):**
- Tool description + parameters schema: ~500 tokens
- Slides JSON for a 3-slide deck with 2-3 options each: ~2,000-8,000 tokens
  - previewHtml options: 500-2,000 tokens per option (raw HTML with inline styles)
  - previewBlocks with code: 200-500 tokens per option
  - previewBlocks with mermaid: 100-300 tokens per option
- Total initial call: ~2,500-8,500 tokens output

**Generate-more loop (per round):**
- Prompt returned to agent: ~300-500 tokens (structured instructions)
- Agent generates 1-3 new options: ~500-3,000 tokens output per option
- `add-options` call: ~500-3,000 tokens (JSON string of options)
- Total per generate-more round: ~1,300-6,500 tokens

**Completion (submit):**
- Result text: ~100-200 tokens
- Selection map: ~50-100 tokens

**Typical 3-slide interaction with 1 generate-more:**
- Initial: ~5,000 tokens
- Generate-more: ~3,000 tokens
- Completion: ~200 tokens
- **Total: ~8,200 tokens** (output only; input context window cost depends on conversation)

### StreamWeaver DSL Approach: Estimated Token Savings

With a StreamWeaver DSL, the agent would not generate raw HTML or construct complex JSON. Instead:

**DSL-based approach:**
```ruby
design_deck "Architecture Direction" do
  slide "arch", "System Architecture", context: "Choose the backend architecture" do
    option "Monolith", recommended: false,
      aside: "Simpler to deploy and debug" do
      mermaid "graph TD\n  Client-->API\n  API-->DB"
      code "app.listen(3000)", lang: "ts"
    end
    option "Microservices", recommended: true,
      aside: "Independent scaling per service" do
      mermaid "graph LR\n  Gateway-->Auth\n  Gateway-->Orders"
      code "bus.publish('order.created', payload)", lang: "ts"
    end
  end
end
```

**Token comparison:**
- DSL blocks: ~60-70% of equivalent JSON token count (no structural boilerplate, no escaping)
- previewHtml savings: DSL components (if StreamWeaver provides them) could reduce UI mockup tokens by 50-80%
- Generate-more: StreamWeaver's reactive model might eliminate the SSE push pattern entirely if the server can render new options directly

**Estimated savings:**
- Initial deck creation: 30-50% token reduction
- Generate-more: 20-40% reduction (still need option content)
- **Overall: ~30-45% token reduction** for a typical interaction

**Key insight:** The biggest token cost is in previewHtml (raw HTML with inline styles for UI mockups). A DSL with pre-built UI component primitives would provide the largest savings here. previewBlocks (code, mermaid) are already relatively compact and would see smaller savings.

### Additional Considerations

- StreamWeaver's server-side rendering eliminates the need to send HTML/CSS to the client
- Alpine.js reactivity in StreamWeaver could handle the generate-more loop without SSE
- The persistent server pattern maps well to StreamWeaver's architecture
- Selection state management could leverage StreamWeaver's existing state primitives
- The skill/prompt system is agent-framework-specific and wouldn't port directly

---

## 8. Key Architectural Decisions for StreamWeaver Port

### What Maps Directly
- Multi-slide navigation with options grid
- Preview block types (code, mermaid, image, HTML)
- Selection tracking and summary slide
- Save/load snapshots
- Theme support (StreamWeaver already has theme-aware CSS)
- Keyboard shortcuts
- Layout toggle

### What Needs Rearchitecting
- **SSE push for generate-more:** StreamWeaver's Alpine.js reactivity with polling or WebSocket could replace this
- **Agent communication protocol:** The Promise-based blocking pattern is Pi-specific; StreamWeaver would use its own tool/callback mechanism
- **Module-level singleton state:** StreamWeaver's class-based approach is different
- **Asset serving:** StreamWeaver already has Rack-based serving
- **Client JS:** Would be replaced by StreamWeaver's component system + Alpine.js

### What Can Be Dropped
- Pi-specific: `model-runner.ts` (headless pi spawner), Pi extension API integration
- `generate-prompts.ts` (prompt building for Pi agent)
- `server-utils.ts` session registry (StreamWeaver has its own session management)
- Export HTML (could be added later as a separate feature)

### Unique Value to Preserve
- The generate-more loop concept (user requests more AI options during an active session)
- Skeleton shimmer placeholders during generation
- The summary slide pattern with preview thumbnails
- Notes per option + final notes
- Auto-save behavior (submit saves, cancel with selections saves)
- Confirmation dialog on cancel with existing selections
