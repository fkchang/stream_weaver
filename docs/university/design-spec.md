# StreamWeaver University — course canvas design spec

Story: `course-canvas-design` (epic `university-getting-started`). Binding input for `course-list-canvas`, `progress-ledger`, `driver-worker-runner`, and every `step-N-*` story.

Mockup: `docs/university/mockups/course_canvas_mockup.rb` (runs standalone with `ruby`, and pushes to a canvas with `canvas-push`).
Screenshots: `course-list-light.png`, `course-list-dark.png`, `step-screen-light.png`, `step-screen-dark.png` in the same directory.

---

## 1. Visual direction

**Warm paper beside a dark terminal.** The canvas is not a web app in a browser tab — it is a split pane sitting next to a terminal, at roughly 500–900px wide, read by someone whose attention is already spent on the shell. So the surface commits to the `:doc` theme's editorial world: Charter serif for the one display voice, system sans for every piece of UI, `#F5F4EF` paper, `#1E4ED8` as the single accent, and no second color anywhere.

Four decisions carry the design:

**a. The next step is the hero; the course list is the map.** The screen opens with one serif line — "Pick up at step 3." — the step's own title as a subtitle, and one filled button. The five-step list sits *below* that, as orientation. A new user's first run reads "Start with step 1." A returning user never has to scan a list to find their place. (Gloria's Law: if the user cannot instantly identify what needs their attention, the cognitive overhead is itself the barrier.)

**b. One *primary* action per screen, not one action per screen.** Every step keeps a working Run/Repeat control, because the brief requires it and locking steps would be pure friction. Hierarchy carries the guidance instead, across three button weights: filled accent (the one thing to do now) → outlined (the current step's own Run) → faint-hairline quiet (repeat a done step, jump ahead). Nothing is disabled; nothing is hidden behind hover.

**c. Progress is a rail of five, not a percentage.** A `progress_bar value: 40` is the AI-theater version of this: it looks like data and tells the user nothing they can act on. The rail is five segments matching five steps, current one wider and full-strength, plus a plain `2 of 5 done`. It reads as position in a sequence, which is what the user actually wants to know.

**d. Depth is hairlines, not shadows.** The `:doc` theme is near-flat by design. Rather than reintroduce elevation, the whole page separates with 1px `--sw-color-border` rules and one background tint (`--sw-color-accent-light`) for the current step. No shadows, no colored left borders, no cards inside cards. This is also why the disabled future courses need no special "greyed out" treatment: they are a rule-separated list at reduced weight — a shelf of promises, not a wall of dead buttons.

**Type.** One display face (`--sw-font-display`, Charter) used exactly twice per screen — the hero line and the step title. Everything else is the body sans at four sizes: 15px prose, 14.5px step title, 13px payoff/meta, 11px uppercase micro-labels with `0.1em` tracking. Prose is capped at 66ch, step payoffs at 56ch. Numerals in the rail label and step numbers are `tabular-nums`.

**Motion.** Deliberately none on load. The canvas is re-pushed by an agent many times per session; a re-entrance animation on every push would be an attention tax rather than a delight. The motion budget is spent entirely on 120ms state transitions (hover, focus) with a `prefers-reduced-motion` guard.

**Light and dark.** Every bespoke value derives from a `--sw-*` token, so the dark variant required **zero** dark-mode rules. The one trap solved explicitly: a filled accent button needs white text in light (`#1E4ED8` bg) and near-black in dark (`#6699FF` bg). `color: var(--sw-color-secondary-foreground)` is that pair already — one declaration, ≥6.5:1 in both themes.

---

## 2. What each screen must assert

### Course list

| Region | Content | Why it's there |
|---|---|---|
| Topbar | `STREAMWEAVER UNIVERSITY` wordmark, theme toggle | Identity, one control, no nav |
| Hero | "Pick up at step N." + step title + `Run step N` (primary) + `Repeat step N-1` (quiet) | The single answer to "what do I do now" |
| Rail | 5 segments + "N of 5 done" | Position in the sequence |
| Getting Started | 5 rows: state mark, number, title, one-line payoff, Run/Repeat | The map; every step re-runnable |
| Courses in the works | 3 rows: name + one-line blurb, no controls | Promise, not denial |
| Footer note | `streamweaver tutorial` in a code chip + "the classic component tour, being refreshed" | The escape hatch to the old tour |

### Step screen

| Region | Content | Why it's there |
|---|---|---|
| Topbar | wordmark + breadcrumbs `Getting Started · Step 3` | Where am I |
| Step line | `← All steps` / `Step 3 of 5` | Back out, and position |
| Title | serif h1 | The step |
| Why this matters | 2 short paragraphs, ≤66ch | Motivation before mechanics |
| The prompt your worker session receives | verbatim monospace block | **Transparency.** No hidden prompt, no paraphrase — the user sees exactly what gets sent |
| Actions | `Run in worker session` (primary) + `Copy prompt` (outlined) | Premier path and degraded path, side by side |
| What you should see | 3 checked lines | The payoff, stated before they run it |
| Mark step N done | quiet outlined, below a rule | The exit, not competing with Run |

Monospace appears exactly once per screen, on the prompt block, where it is doing its real job: showing a verbatim payload character-for-character.

---

## 3. Component and token inventory

Existing components used as-is (prefer these in the build; do not hand-roll replacements):

| Component | Used for | Hook restyled |
|---|---|---|
| `topbar(wordmark:, breadcrumbs:)` | app chrome on both screens | `.sw-topbar`, `.sw-topbar-wordmark`, `.sw-topbar-crumb`, `.sw-topbar-crumb--active` |
| `theme_toggle mode: :auto` | light/dark control | `.sw-theme-toggle__btn`, `.sw-theme-toggle__icon`, `.sw-theme-toggle__label` |
| `button(label, submit: false, key:, class:)` | every Run / Repeat / Mark done | `.sw-button` |
| `copy_button(label, text:, copied_label:)` | Copy prompt (degraded path) | `.sw-button` (it emits the same hook) |
| `header1` / `header2` | hero line, step title, step-row titles | none — styled via own class |
| `phrase` / `div` / `md` | rows, labels, prose, the prompt block | `.markdown-content` for `md` bodies |
| `tabs :screen, variant: :line` | **review chrome only** — see §6 | none |
| `use_theme` / `use_layout` / `use_stylesheet` | in-DSL theme + stylesheet, so one file serves standalone and canvas | — |

Theme tokens consumed (all from `body.sw-theme-doc` in `views.rb`, light and dark blocks):

| Token | Used for |
|---|---|
| `--sw-color-text` | all primary text |
| `--sw-color-text-muted` | payoffs, blurbs, micro-labels, quiet buttons |
| `--sw-color-border` | every hairline rule |
| `--sw-color-border-strong` | step marks, outlined buttons, scrollbar thumb |
| `--sw-color-accent` / `--sw-color-primary-hover` | the single accent, hover |
| `--sw-color-accent-light` | current-step row tint |
| `--sw-color-secondary-foreground` | text on the filled accent button (the light/dark pair) |
| `--sw-color-bg` / `--sw-color-bg-elevated` | page ground, prompt block ground |
| `--sw-font-display` / `--sw-font-body` / `--sw-font-mono` | the three voices |

`--sw-color-text-light` is deliberately **not** used for any text: at `#A09D96` on paper it is 2.4:1 and fails WCAG AA. It is fine for hairlines only. Anything that needs to recede uses `--sw-color-text-muted` (4.9:1 light, 7.1:1 dark) and drops *weight* rather than contrast.

---

## 4. Bespoke CSS

One stylesheet, carried inline via `use_stylesheet` (see §5 for why inline rather than a sibling `.css`). All of it lives in the `uni-` namespace except the sw-hook overrides listed in §3.

| Class | What it is |
|---|---|
| `.uni-i`, `.uni-i--check/play/repeat/back` | the drawn icon set — masked inline SVG at one stroke weight, `background-color: currentColor` so icons inherit text color and theme automatically. No emoji, no icon library. |
| `.uni-hero`, `.uni-hero__lead`, `.uni-hero__sub` | the resume block |
| `.uni-actions` | the primary/secondary button row |
| `.uni-btn`, `--run`, `--outline`, `--quiet` | the three-weight button ladder, applied via `class:` on `button`/`copy_button` |
| `.uni-rail`, `__track`, `__seg`, `__seg--done`, `__seg--current`, `__label` | the five-segment progress rail |
| `.uni-micro` | 11px uppercase section labels |
| `.uni-steps`, `.uni-step`, `--done/--current/--todo`, `__mark`, `__num`, `__title`, `__payoff` | the step list |
| `.uni-shelf`, `__row`, `__name`, `__blurb` | the future-courses shelf |
| `.uni-note` | the `streamweaver tutorial` footer line |
| `.uni-stepline`, `.uni-back`, `.uni-count`, `.uni-title`, `.uni-prose`, `.uni-prompt`, `.uni-payoff`, `.uni-done` | the step screen |
| chrome neutralization on `body[class*="sw-layout-"]` + `#app-container` | holds one 840px reading column whether the host set `sw-layout-fluid` (canvas) or `sw-layout-default` (standalone) |
| `::selection`, `:focus-visible`, scrollbar rules | browser surfaces themed from the palette instead of left at browser defaults |

Two structural notes for the build: the icon set is data-URI masks, so it costs no network request and needs no asset route; and `.uni-step__title` is an `<h2>` with the theme's own h2 treatment explicitly reset, so the document outline stays h1 → h2 with no skipped level.

---

## 5. Gaps found

| Gap | Impact on the build | Suggested fix |
|---|---|---|
| **`use_theme` in a pushed DSL body does not reach the live canvas page.** `Canvas::Session` fixes `theme`/`layout` at create time (`bridge.rb` `handle_create`); `render_canvas_page` emits `sw-theme-#{session.theme}`. A body declaring `use_theme :doc` still renders under `sw-theme-default`. | `course-list-canvas` **must** create its session with the doc theme — the canvas will silently look wrong otherwise. | Have the push path adopt the body's `use_theme`/`use_layout` (canvas-read already does), or at minimum let `streamweaver canvas` accept `--theme=`. |
| **`streamweaver canvas <name>` has no `--theme=` flag** (only `panel` does). Recreating a session with a theme currently needs `panel --fresh --theme=doc` or a raw protocol message. | Any headless canvas setup for the course app needs `panel`, which also opens a pane. | Add `--theme=` to `canvas_session`, matching `panel`. |
| **`use_stylesheet` must be handed literal CSS, not a path, for canvas.** Path resolution is relative to the *evaluating* script dir, which canvas-push does not set. | The mockup inlines its CSS in a heredoc. Same constraint applies to the built app. | Either keep CSS inline in the body, or teach `canvas-push` to resolve `use_stylesheet` paths against the pushed file's directory. |
| **`theme_toggle` ships an emoji icon plus a `System/Dark/Light` word label** with no option to suppress either. | The mockup overrides both in CSS (hides the label, re-masks the two icon spans by `:nth-of-type`). Brittle if the component's markup order changes. | Add `compact: true` (icon only) and/or an `icon:` option to `theme_toggle`. Worth a `sw-` hook on each icon variant so `nth-of-type` isn't the selector. |
| **`Header` drops unknown options.** `header2 "x", "data-foo": 1` silently loses the attribute (only `:class`/`:style` forward). | Step numbers are a separate `phrase` in a grid column instead of a `::before` on the title. Fine, but worth knowing. | Forward arbitrary `data-*` through `render_header`. |
| **No component for a "list row with state mark + number + body + action".** This is the step list, and it will recur (course lists, checklists, run logs). | Built from `div` + grid CSS here. | Candidate component after `course-list-canvas` proves the shape: `step_row(number:, title:, detail:, state:, &action)` emitting `.sw-step-row`, `.sw-step-row__mark/__num/__title/__detail`, `.sw-step-row--done/--current/--todo`. |
| **No progress-rail component.** `progress_bar` is a percentage bar, which is the wrong instrument. | Built from five `div`s. | Candidate: `step_rail(total:, done:, current:)` emitting `.sw-step-rail`, `.sw-step-rail__seg`, `--done`, `--current`. |
| Canvas WebSocket handshake 404s and falls back to polling (`ws://…/canvas/<name>/ws` → 404 in the console). | Pre-existing; not caused by this design. Content still updates. | Out of scope here — worth a separate mark if it isn't already tracked. |

---

## 6. How to build `course-list-canvas` from this

1. **Start from the mockup file, not from scratch.** `docs/university/mockups/course_canvas_mockup.rb` already holds the finished stylesheet and both screens' markup. Lift the `_css` heredoc verbatim into the real app; it is the design.
2. **Drop the tabs.** `tabs :screen` in the mockup is review chrome so both screens are visible in one push. The real app has no tabs: the course list and the step screen are two renders of the same app, chosen by state (`state[:step]`, nil = list).
3. **Replace the literal arrays with the curriculum.** The `steps` array in the mockup (number, title, payoff, state) is the shape the curriculum layer must supply. `state` comes from the progress ledger (`progress-ledger`), so it is `:done` / `:current` / `:todo` — the CSS keys off exactly those three.
4. **Wire the buttons.** Every `button` in the mockup is `submit: false` and inert. In the build: hero Run and each row's Run/Repeat call the driver (`driver-worker-runner`); `Mark step N done` writes the ledger; `← All steps` clears `state[:step]`. Keep `key:` on every button in the loop — the mockup already does, and without it loop-derived ids collide.
5. **Keep `use_theme :doc` + `use_stylesheet` in the DSL body** so the app renders identically standalone, on a canvas, through `canvas-read`, and through `export`. And per §5, create the canvas session itself with the doc theme (`panel --theme=doc`) — `use_theme` alone will not colour the live page.
6. **Degraded mode is a hierarchy swap, not a different screen.** With no worker session, drop the Run buttons and promote `Copy prompt` from `.uni-btn--outline` to `.uni-btn--run`. The hero's `Run step N` becomes `Copy step N prompt`. Nothing else changes.
7. **States the mockup does not show, which the build owes:**
   - *First run* (0 of 5): hero reads "Start with step 1.", rail all-empty, no Repeat button in the hero.
   - *All done* (5 of 5): hero congratulates and points at the shelf / `streamweaver tutorial`; every row shows Repeat.
   - *Running*: the row whose step was just dispatched needs a "sent to your worker session" acknowledgement — the canvas cannot see the worker's progress, so say only what is true.
8. **Do not add:** a percentage progress bar, per-step time estimates, step locking, a second accent color, card grids, or an entrance animation. Each was considered and rejected above.

---

## 7. Verification done

- Rendered on the live canvas bridge and screenshotted at 1000px and 620px wide (the narrow case is the real iTerm pane), light and dark, both screens.
- Booted standalone (`ruby docs/university/mockups/course_canvas_mockup.rb`) and confirmed `<body class="sw-layout-default sw-theme-doc">` — the same file drives both delivery modes.
- Ran the Impeccable mechanical detector over the rendered page. One finding was ours (h1 → h3 skipped heading) and is fixed; the remaining findings (`pulsing-dot`, a zero-offset red glow) come from framework CSS this page does not use.
