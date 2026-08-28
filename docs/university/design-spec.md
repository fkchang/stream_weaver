# StreamWeaver University — course canvas design spec

Story: `course-canvas-design` (epic `university-getting-started`). Binding input for `course-list-canvas`, `progress-ledger`, `driver-worker-runner`, and every `step-N-*` story.

Mockup: `docs/university/mockups/course_canvas_mockup.rb` (runs standalone with `ruby`, and pushes to a canvas with `canvas-push`).
Screenshots: `course-list-light.png`, `course-list-dark.png`, `step-screen-light.png`, `step-screen-dark.png` in the same directory.

**Revision note (v2).** v1 was reviewed and rejected as "a decent first start" that read as a *document* rather than an app: the course state sat at page level above everything, sections were divided by hairlines and 11px small-caps labels that reviewers missed entirely, and the single-blue palette left every state looking alike. v2 rebuilds the information architecture around course panels, replaces hairlines with real surfaces, raises the type scale, and introduces a three-colour state language. Sections 1–4 describe v2; §5 records what v1 taught us that still binds the build.

---

## 1. Visual direction

**A warm workbench.** The `:doc` theme's warm paper stays, but it is now the *room*, not the object. Courses sit on it as raised instrument panels — near-white in light, warm charcoal in dark — each with a title bar, a body, and its own state. The reader is someone with a terminal open beside this pane, at roughly 500–900px wide, whose attention is already spent. They must be able to tell in under a second: what is this, which course am I in, and what do I do next.

Five decisions carry the design:

**a. The course owns its state; the page owns nothing.** Nothing course-specific appears above the course list. The resume line ("Pick up at step 3."), the primary Run button, and the 5-segment rail all live *inside* the Getting Started panel, under its own title bar. This is what makes a second course additive rather than a rewrite: a course is a self-contained unit with a header, a state, and a list. The page above it carries only identity — the app name and one line saying what the app is for.

**b. Courses are accordion panels, open or dormant.** Getting Started renders open (`card depth: :elevated`) with a filled title bar, a status chip, and its full body. Future courses render closed (`card depth: :recessed`): transparent ground, quiet border, hollow dot, name and one-line blurb, a `Soon` chip with a drawn lock — and no controls at all. A dormant course is a promise on a shelf, not a wall of dead buttons.

**c. Surfaces, not hairlines.** v1 separated everything with 1px rules, and reviewers scrolled straight past the boundaries. v2 gives every region a real ground: page `#E7E4D9`, panel `#FDFCF9`, title bar `#F3F1E8`, recessed regions (resume band, prompt block, footer) `#F1EFE6`, plus a two-layer neutral shadow on the open panel. The panel edge is now the loudest line on the page, which is correct — it is the strongest structural fact.

**d. A three-colour state language, used identically everywhere.** One triad, no confetti:

| State | Light | Dark | Where it appears |
|---|---|---|---|
| Done | `#17754A` green | `#57C98A` | step mark (filled disc + check), rail segment, "What you should see" checks |
| Now | `#1E4ED8` blue (`--sw-color-accent`) | `#6699FF` | step mark (filled disc + number + ring), current-row band, rail segment, every primary button, course status dot |
| Not yet | `#6E6959` stone | `#9A9285` | step mark (hollow ring + number), `Soon` chip |

The rail's empty segments use a separate `--uni-rail-track` value rather than the stone. They are a *track*, not a state marker: the rail's meaning is carried by the filled done/now segments and by the always-present `N of 5 done` label beside it, so the track is not required to clear 3:1 and darkening it to that level would read as "filled."

Because the same three colours drive the mark, the rail, and the checks, the rail becomes readable without its label and the current step is findable at a glance from anywhere on the page. Colour is never the *only* signal: done also carries a check glyph, current also carries a filled disc and a tinted row band, dormant also carries a lock glyph and the word `Soon`.

**e. One primary action, three button weights.** Every step keeps a working Run/Repeat control — locking steps would be pure friction — but hierarchy carries the guidance: filled accent (the one thing to do now) → outlined (the current step's own Run, and Copy prompt) → quiet borderless (repeat a done step, jump ahead). Exactly one filled button exists per screen.

**Type.** Base is 16px, up from 15px. The serif display face (`--sw-font-display`, Charter) is used exactly twice per screen and only for voice, never for structure: the app name (27px) and the resume line / step title (~1.55rem / ~1.95rem). Everything structural is the body sans, at sizes that survive a skim: course name 20px/700, step title 17px/650, step payoff 14.5px, section labels 15px/650, prose 16px. **v1's 11px uppercase micro-labels are gone from the content flow.** Small caps survive only as *chrome* — the `IN PROGRESS` / `SOON` chips and the prompt block's title bar — where the enclosing shape, not the type size, does the work of being noticed.

**Motion.** Deliberately none on load. The canvas is re-pushed by an agent many times per session; a re-entrance animation on every push is an attention tax, not a delight. The budget is spent on 130ms state transitions (hover, focus) behind a `prefers-reduced-motion` guard.

**Light and dark.** v1 rode `--sw-*` tokens exclusively and claimed zero dark-mode rules as a win. That constraint is what produced the blandness: a control panel needs the page and the panel to be *different grounds*, and that is a two-value decision per theme, not one token. v2 therefore carries one explicit dark block, hung off the same selector the `:doc` theme uses for its own dark palette (`html[data-sw-theme="dark"] body`), so the two flip on exactly the same signal and can never disagree. Semantic tokens (`--sw-color-text`, `--sw-color-accent`, `--sw-font-*`) are still consumed directly.

---

## 2. What each screen must assert

### Course list

| Region | Content | Why it's there |
|---|---|---|
| App band | `StreamWeaver University` (serif, 27px), one-line tagline, theme toggle | Says what this is in under a second — the fix for "I thought it was a document" |
| Course panel — title bar | status dot, `Getting Started` (20px/700), `IN PROGRESS` chip | The course names itself at a size nobody scrolls past |
| Course panel — resume band | "Pick up at step N." + step title + `Run step N` (primary) + `Repeat step N-1` (quiet) + 5-segment rail + "N of 5 done" | The single answer to "what do I do now" — scoped to this course |
| Course panel — step rows | 5 rows: state mark, title, one-line payoff, Run/Repeat | The map; every step re-runnable |
| Divider | `In the works` (15px/650) + rule to the right edge | A section label at reading size, not a micro-label |
| Dormant panels | 3 closed cards: hollow dot, name, blurb, `Soon` chip. **No controls.** | Promise, not denial |
| Footer note | `streamweaver tutorial` in a code chip, on its own recessed panel | The escape hatch to the old tour |

### Step screen

| Region | Content | Why it's there |
|---|---|---|
| App band | wordmark + breadcrumbs `Getting Started · Step 3` + theme toggle | Where am I |
| Context row | `← All steps` button, the same 5-segment rail, `Step 3 of 5` | Back out, and position — the rail is the same instrument as on the list |
| Panel title bar | blue step-number badge + serif h1 title | The step, marked with the same "now" badge the list used |
| Why this matters | 2 short paragraphs, ≤66ch | Motivation before mechanics |
| Prompt block | labelled title bar + verbatim monospace body on a sunk ground | **Transparency.** No hidden prompt, no paraphrase — the user sees exactly what gets sent |
| Actions | `Run in worker session` (primary) + `Copy prompt` (outlined) | Premier path and degraded path, side by side |
| What you should see | 3 lines with green done-checks | The payoff, stated before they run it |
| Footer band | `Mark step N done` (outlined) + "Unlocks step 4." | The exit, on its own ground, not competing with Run |

Monospace appears exactly once per screen, on the prompt block, where it is doing its real job: showing a verbatim payload character-for-character.

---

## 3. Component and token inventory

Existing components used as-is (prefer these in the build; do not hand-roll replacements):

| Component | Used for | Hook restyled |
|---|---|---|
| `card(depth:, class:)` | every course panel — `:elevated` open, `:recessed` dormant | `.sw-card` |
| `card_header(class:)` | course title bar, step title bar | `.sw-card-header` |
| `card_body(class:)` | course body | `.sw-card-body` |
| `topbar(wordmark:, breadcrumbs:)` | app band on both screens | `.sw-topbar`, `.sw-topbar-wordmark`, `.sw-topbar-crumb`, `.sw-topbar-crumb--active` |
| `theme_toggle mode: :auto` | light/dark control | `.sw-theme-toggle__btn`, `.sw-theme-toggle__icon`, `.sw-theme-toggle__label` |
| `button(label, submit: false, key:, class:)` | every Run / Repeat / Mark done | `.sw-button` |
| `copy_button(label, text:, copied_label:)` | Copy prompt (degraded path) | `.sw-button` (it emits the same hook) |
| `header1` / `header2` / `header3` | step-screen title, course names, step-row titles | none — styled via own class |
| `phrase` / `div` / `md` | rows, chips, labels, prose, the prompt block | `.markdown-content` for `md` bodies |
| `tabs :screen, variant: :line` | **review chrome only** — see §6 | none |
| `use_theme` / `use_layout` / `use_stylesheet` | in-DSL theme + stylesheet, so one file serves standalone and canvas | — |

Theme tokens consumed directly:

| Token | Used for |
|---|---|
| `--sw-color-text` | all primary text |
| `--sw-color-text-muted` | payoffs, blurbs, quiet buttons, hints |
| `--sw-color-accent` | the "now" colour, in every state surface and primary button |
| `--sw-color-primary-hover` | primary button hover |
| `--sw-font-display` / `--sw-font-body` / `--sw-font-mono` | the three voices |

Values defined per-theme by this design rather than taken from a token, because no token expresses them: the four grounds (page / panel / bar / sunk), the two line weights, and the done / now-tint / not-yet triad. All are declared once on `body` and once on `html[data-sw-theme="dark"] body`.

`--sw-color-text-light` is deliberately **not** used for any text: at `#A09D96` on paper it is 2.4:1 and fails WCAG AA. Anything that needs to recede drops *weight* rather than contrast.

`--sw-color-text-muted` is also **overridden in light mode** (`#5F5C54` instead of `#6B6860`). The theme value measures 4.37:1 on this design's page ground, and the tagline and the dormant-course blurbs sit exactly there. The override clears 4.5:1 on all four grounds. Dark mode keeps the theme value (6.5:1+ everywhere).

---

## 4. Bespoke CSS

One stylesheet, carried inline via `use_stylesheet` (see §5 for why inline rather than a sibling `.css`). All of it lives in the `uni-` namespace except the `sw-` hook overrides listed in §3.

| Class | What it is |
|---|---|
| `.uni-i`, `--check/play/repeat/back/lock` | the drawn icon set — masked inline SVG at one stroke weight, `background-color: currentColor` so icons inherit text colour and theme automatically. No emoji, no icon library. |
| `.uni-course`, `--dormant`, `__bar`, `__dot`, `__name`, `__blurb`, `__body` | the course panel: open and dormant variants, title bar, status dot |
| `.uni-chip`, `--soon` | the `IN PROGRESS` and `Soon` status chips |
| `.uni-resume`, `__lead`, `__sub` | the resume band inside a course panel |
| `.uni-actions` | the primary/secondary button row |
| `.uni-btn`, `--run`, `--outline`, `--quiet` | the three-weight button ladder, applied via `class:` on `button`/`copy_button` |
| `.uni-rail`, `__track`, `__seg`, `--done`, `--current`, `__label` | the five-segment progress rail |
| `.uni-step`, `--done/--current/--todo`, `__mark`, `--hero`, `__title`, `__payoff` | the step rows and their state marks |
| `.uni-divider`, `__label`, `__rule` | the `In the works` section divider |
| `.uni-note` | the `streamweaver tutorial` footer panel |
| `.uni-context`, `.uni-back`, `.uni-count`, `.uni-title`, `.uni-section`, `.uni-label`, `.uni-prose`, `.uni-promptbox`, `.uni-prompt`, `.uni-payoff`, `.uni-foot` | the step screen |
| chrome neutralization on `body[class*="sw-layout-"]` + `#app-container` | holds one 860px column whether the host set `sw-layout-fluid` (canvas) or `sw-layout-default` (standalone) |
| `::selection`, `:focus-visible`, scrollbar rules | browser surfaces themed from the palette instead of left at browser defaults |

Four structural notes for the build:

- The icon set is data-URI masks, so it costs no network request and needs no asset route.
- Step titles are `h3` under the course's `h2` name, and the `:doc` theme's own `h2`/`h3` treatment is explicitly reset, so the outline nests correctly instead of running flat.
- Selectors that fight a theme rule are written `body.sw-theme-doc h2.uni-…` to win specificity outright rather than relying on source order.
- The card component's own `--elevated` / `--recessed` backgrounds are overridden by `body .sw-card.uni-course`; the depth argument is kept because it carries the semantic and any future theme work should key off it.

---

## 5. Gaps found

| Gap | Impact on the build | Suggested fix |
|---|---|---|
| **`use_theme` in a pushed DSL body does not reach the live canvas page.** `Canvas::Session` fixes `theme`/`layout` at create time (`bridge.rb` `handle_create`); `render_canvas_page` emits `sw-theme-#{session.theme}`. A body declaring `use_theme :doc` still renders under `sw-theme-default`. | `course-list-canvas` **must** create its session with the doc theme — the canvas will silently look wrong otherwise. | Have the push path adopt the body's `use_theme`/`use_layout` (canvas-read already does), or at minimum let `streamweaver canvas` accept `--theme=`. |
| **`streamweaver canvas <name>` has no `--theme=` flag** (only `panel` does). | Any headless canvas setup for the course app needs `panel`, which also opens a pane. | Add `--theme=` to `canvas_session`, matching `panel`. |
| **`use_stylesheet` must be handed literal CSS, not a path, for canvas.** Path resolution is relative to the *evaluating* script dir, which canvas-push does not set. | The mockup inlines its CSS in a heredoc. Same constraint applies to the built app. | Either keep CSS inline in the body, or teach `canvas-push` to resolve `use_stylesheet` paths against the pushed file's directory. |
| **`topbar`'s wordmark renders as a `div`, so a page whose title is the wordmark has no `h1`.** | The course list has no `h1` — its outline starts at the `h2` course name. Harmless visually, wrong for screen readers and for `export`. | Give `topbar` a `wordmark_level:` option (default `div`, opt into `h1`), or let the app pass its own heading into the wordmark slot. |
| **`card_header(content)` renders the title as `h4`,** which cannot sit under an `h2`/`h1` without skipping levels. | The mockup passes no content string and nests its own `header2`/`header1` as a child instead. | Add a `level:` option to `card_header`. |
| **`theme_toggle` ships an emoji icon plus a `System/Dark/Light` word label** with no option to suppress either. | The mockup overrides both in CSS (hides the label, re-masks the two icon spans by `:nth-of-type`). Brittle if the component's markup order changes. | Add `compact: true` (icon only) and/or an `icon:` option. Worth an `sw-` hook per icon variant so `nth-of-type` isn't the selector. |
| **`Header` drops unknown options.** `header2 "x", "data-foo": 1` silently loses the attribute (only `:class`/`:style` forward). | Step numbers live inside the mark element rather than as a `data-*` on the title. Fine, but worth knowing. | Forward arbitrary `data-*` through `render_header`. |
| **No component for a "list row with state mark + title + detail + action".** This is the step row, and it will recur (course lists, checklists, run logs). | Built from `div` + grid CSS here. | Candidate component after `course-list-canvas` proves the shape: `step_row(number:, title:, detail:, state:, &action)` emitting `.sw-step-row`, `__mark/__title/__detail`, `--done/--current/--todo`. |
| **No progress-rail component.** `progress_bar` is a percentage bar, which is the wrong instrument. | Built from five `div`s, and now used on *both* screens. | Candidate: `step_rail(total:, done:, current:)` emitting `.sw-step-rail`, `__seg`, `--done`, `--current`. |
| **No status-chip component.** `badge` exists but carries its own colour vocabulary. | `IN PROGRESS` / `Soon` are hand-rolled `.uni-chip`. | Either widen `badge` to accept a semantic state, or leave chips bespoke. |
| Canvas WebSocket handshake 404s and falls back to polling (`ws://…/canvas/<name>/ws` → 404 in the console). | Pre-existing; not caused by this design. Content still updates. | Out of scope here — worth a separate mark if it isn't already tracked. |

---

## 6. How to build `course-list-canvas` from this

1. **Start from the mockup file, not from scratch.** `docs/university/mockups/course_canvas_mockup.rb` already holds the finished stylesheet and both screens' markup. Lift the `_css` heredoc verbatim into the real app; it is the design.
2. **Drop the tabs.** `tabs :screen` in the mockup is review chrome so both screens are visible in one push. The real app has no tabs: the course list and the step screen are two renders of the same app, chosen by state (`state[:step]`, nil = list).
3. **Model a course, not a page.** The course panel is the unit of composition: `card(depth:) > card_header(title bar) > card_body(resume band + step rows)`. Adding a second live course means appending another panel with its own state — no page-level change. Keep the rule that **nothing course-specific renders above the course list.**
4. **Replace the literal arrays with the curriculum.** The `steps` array (number, title, payoff, state) is the shape the curriculum layer must supply. `state` comes from the progress ledger (`progress-ledger`), so it is `:done` / `:current` / `:todo` — the CSS keys off exactly those three, as do the rail segments.
5. **Wire the buttons.** Every `button` in the mockup is `submit: false` and inert. In the build: the resume-band Run and each row's Run/Repeat call the driver (`driver-worker-runner`); `Mark step N done` writes the ledger; `← All steps` clears `state[:step]`. Keep `key:` on every button in the loop — without it, loop-derived ids collide.
6. **Keep `use_theme :doc` + `use_stylesheet` in the DSL body** so the app renders identically standalone, on a canvas, through `canvas-read`, and through `export`. And per §5, create the canvas session itself with the doc theme — `use_theme` alone will not colour the live page.
7. **Degraded mode is a hierarchy swap, not a different screen.** With no worker session, drop the Run buttons and promote `Copy prompt` from `.uni-btn--outline` to `.uni-btn--run`. The resume band's `Run step N` becomes `Copy step N prompt`. Nothing else changes.
8. **States the mockup does not show, which the build owes:**
   - *First run* (0 of 5): resume line reads "Start with step 1.", rail all not-yet, no Repeat button, and the course chip reads `NOT STARTED` rather than `IN PROGRESS`.
   - *All done* (5 of 5): the chip reads `COMPLETE` in the done green, the resume band congratulates and points at the shelf / `streamweaver tutorial`, every row shows Repeat, and there is no primary button (the course has no "next").
   - *Running*: the row whose step was just dispatched needs a "sent to your worker session" acknowledgement — the canvas cannot see the worker's progress, so say only what is true.
9. **Do not add:** a percentage progress bar, per-step time estimates, step locking, a fourth accent colour, a nested card inside a course panel, or an entrance animation. Each was considered and rejected above.

---

## 7. Verification done

- Rendered on the live canvas bridge (session `university-design`, doc theme) and screenshotted full-page at 1000px, light and dark, both screens. Also checked at 620px — the real narrow iTerm pane — where step rows reflow to put the action under the text.
- Booted standalone (`SW_NO_OPEN=1 STREAMWEAVER_PORT=… ruby docs/university/mockups/course_canvas_mockup.rb`) and confirmed HTTP 200 with `<body class="sw-layout-default sw-theme-doc">` — the same file drives both delivery modes.
- Ran the Impeccable mechanical detector over the rendered page, then ran a two-assessment critique (independent design review + independent detector/contrast evidence) over the result. Findings and their attribution are in §8.

---

## 8. Critique findings (v2)

Recorded so the build inherits them rather than rediscovering them.

**Attribution rule.** The canvas bridge injects its own framework CSS and its own "Save canvas as doc" control into every page it serves. A detector finding belongs to this design only if it traces to markup or CSS authored in the mockup file.

| Finding | Attribution | Disposition |
|---|---|---|
| `skipped-heading`: `h1` "One form, two modes" followed by `h3` "Save canvas as doc" | Host — the Save-as-doc control is bridge chrome appended after page content | Not fixable from the DSL; ignore |
| `pulsing-dot`: `.sw-pulse-dot` with an infinite `sw-pulse` animation | Framework CSS — this page has no pulsing element (`.uni-course__dot` is static) | Ignore |
| `dark-glow`: zero-offset `#ef4444` box-shadow | Framework CSS — not a colour this design uses | Ignore |
| Course list has no `h1` | Ours, but caused by `topbar`'s wordmark rendering as a `div` | Recorded as a component gap in §5; the build should fix it there, not with a stray heading |
| Step titles were `h2` under an `h2` course name (flat outline) | Ours | **Fixed** — step titles are now `h3` |

Contrast was computed, not estimated, for every state colour against every ground it lands on in both themes. The first pass had three genuine failures, all now fixed:

| Pair | Was | Now | Fix |
|---|---|---|---|
| `not yet` stone on panel (todo step numerals) | 3.53 light / 4.43 dark | 5.35 / 5.34 | darkened light stone to `#6E6959`, lightened dark stone to `#9A9285` |
| `not yet` stone on the `Soon` chip ground | 2.49 light / 3.95 dark | 4.64 / 4.76 | chip ground split off from the rail track and lightened to `#EFECE1` — no stone value could pass against the old ground |
| muted text on the page ground (tagline, dormant blurbs) | 4.37 light | 5.24 | light-mode `--uni-muted` override, §3 |

Also fixed from the design review: the todo mark's ring was a 50% tint (2.07:1 as a boundary) and is now solid stone; the done mark, which replaces its number with a glyph, now carries visually-hidden state text (`.uni-sr`) so a screen reader gets "Step 1, done" rather than silence; body bottom padding became a real safe area (120px, 150px under 700px) because the host's floating "Save as doc" control was landing on the last payoff line in a narrow pane; the step screen's rail gained the same `N of 5 done` label the course list uses.

One review suggestion was implemented with a deliberate change: it asked for a `Next: step N →` **action** in the footer. Two equally-weighted exits there would have been ambiguous — only one of them writes the ledger — so `Mark step N done` keeps the outlined weight and `Next: step 4` sits at the quiet weight on the far side of the footer. The one-primary-action rule still holds; the screen's primary remains `Run in worker session`.
