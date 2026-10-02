# `replay` component: animated event replay as a Ruby DSL

**Status:** spike built and verified in a browser (2026-10-01). Not committed, not pushed.
**Source studied:** `~/work/ops_sector/2026-10-02-thursday-replay.html` (186 lines, 11.1 KB, hand-written HTML/CSS/JS).

## 1. Component structure of the source page

| Piece | What it does | Where it lives in the source |
|---|---|---|
| Header | Title plus a large tabular-nums clock: day label and HH:MM | `.title`, `.clock`, `render()` |
| Counters | Labeled totals; the number glows for 500ms on increment | `COUNTERS`, `.counter .n.bump` |
| Lanes | Named rows with color and subtitle; the track right-aligns chips | `LANES`, `.lane`, `.track` |
| Chips | Time plus text; pop-in animation; previous chips fade to `.old`; capped at 4 per lane; milestones have a dashed border | `emit()`, `.chip` |
| Events | `[time, lane, text, {counter: n}, human?]` tuples | `EVENTS` |
| Windows | Active time ranges; the clock only runs inside them | `WINDOWS`, `toMin()` |
| Gaps | Full-stage card between windows: caption plus subcaption | `GAPS`, `interstitial()` |
| Finale | Closing card; text interpolates final counter totals | tail of `tick()` |
| Controls | Play/pause, restart, speed cycle (1x, 2x, 0.5x), keys: space and r | footer, `keydown` |
| Time compression | `MS_PER_MIN = 340` wall-clock ms per simulated minute | `tick()` |

The hand-written page is about 25 lines of per-instance data that matters (lanes, counters, windows, gaps) plus about 30 lines of events. The other ~120 lines are engine and CSS that never change between replays. That split is the whole case for a component.

## 2. The DSL

```ruby
replay title: "Wednesday night to Thursday noon", subtitle: "five deliverables, one person",
       ms_per_minute: 340, height: "100vh" do
  counter :commit, "commits"
  lane :access, "DinoCloud access", sub: "AWS, GitHub, vendor asks", color: :cyan
  window "Wed 18:40".."Wed 18:50"
  gap "Then 6 hours away.", sub: "Back after dinner, past midnight."
  window "Thu 00:36".."Thu 01:00"
  event "Thu 09:48", :nowcast, "commit: remove one-time dedupe task", commit: 1
  milestone "Thu 11:46", :prep, "Ask: \"I have 15 min to prep\""
  finale "Noon.", "{commit} commits, {invite} invites before lunch."
end
```

Decisions baked in:

- **Times are `"[Day ]HH:MM"`** with free-form day labels ("Wed", "Thu 10-01"). Day order is first appearance. No `W`/`T` code table to declare, and it matches what `session-skeleton` emits.
- **Windows are optional.** With none declared, one window is inferred from the first to the last event (plus 1 minute padding). A raw skeleton dump plays with zero ceremony.
- **`milestone` is `event` with `human: true`** (dashed chip), the "human decision vs machine effect" distinction from the source's footer.
- **Finale placeholders `{commit}` are resolved in Ruby** at build time, so the totals are testable and the JS stays dumb. Unknown placeholders raise.
- **Fail loudly at build time**: unknown lane or counter, event outside every window, wrong gap count, malformed time. The hand-written page silently drops or misplaces these.
- **Colors** are palette symbols (`:cyan :blue :yellow :magenta :green :orange :red :violet`, the solarized set from the source) or any `"#hex"`.
- The block is `instance_eval`'d on the component (or yielded it when it takes an argument). Trade-off: app-level helper methods are not visible inside the block; plain locals are.

## 3. How it maps onto StreamWeaver

Follows the existing leaf-component pattern (`Pipeline`, `KeyboardShortcuts`):

| Layer | File | Notes |
|---|---|---|
| Component | `lib/stream_weaver/components/replay.rb` | DSL builder plus `to_config` (validation, minute math, sorting, finale totals) |
| DSL entry | `display_dsl.rb#replay` | `replay(title:, **opts, &block)`; works in apps and canvas-doc fragments |
| Adapter | `adapter/alpinejs.rb#render_replay` + `REPLAY_CSS` | Static markup plus `<script type="application/json">` config; `Base#render_replay` raises NotImplementedError like its siblings |
| Engine | `assets/js/sw-replay.js` | Vanilla JS, inlined once via `inject_asset_script` |

### Client-side vs server streaming: client-side, decided

| Requirement | Client JS (chosen) | Server streaming (SSE/htmx) |
|---|---|---|
| Smooth | rAF clock, 60fps | One round trip per tick; jitter |
| Works offline | Yes, no network at all | No |
| Iframe in org-reveal deck | Yes, any static host or file | Needs a live server |
| Screen-recordable | Yes, deterministic | Network timing leaks into the recording |
| Exportable (`streamweaver export`) | Yes, verified | No |

The replay is a pure function of data, so the server has nothing to contribute after render. The engine uses no Alpine and no CDN (the export has zero external `<script src>`), which is stronger than "works offline": it works under a strict CSP such as SharePoint's HTML preview.

Engine notes (differences from the source page): a `requestAnimationFrame` clock with `dt` clamped to 100ms replaces per-minute `setTimeout` (steady under pause/resume and speed changes); gap durations scale with speed; cards are `position:absolute` inside the stage rather than `fixed` over the viewport, so a replay can sit inside a doc; text goes through `textContent`, so event text cannot inject markup; the JSON config escapes `</` so event text cannot close the script tag. Each stage exposes `el.swReplay` (`play/pause/restart/state`), used by the browser verification below and available to a deck's own controls.

## 4. Data loader: `session-skeleton`

`Replay.events_from_skeleton(report, map:, label:)` turns one `session-skeleton <uuid> --json` report into event tuples, oldest first. `Replay.events_from_skeletons({ lane => report }, counters: { kind => counter_key })` merges several sessions, one lane per session. Kinds not listed are dropped (unconfirmed attempts and noise stay out). Times keep their date (`"Thu 10-01 09:48"`): the clock shows the weekday, but the date is what keeps two different Thursdays apart.

```ruby
reports = { dev: load("uuid-a"), ops: load("uuid-b") }   # parsed session-skeleton JSON
replay title: "My week", height: "100vh" do
  counter :commit, "commits"; counter :pr, "PRs"
  lane :dev, "Dev work"; lane :ops, "Ops"
  auto_windows idle: 180
  events Replay.events_from_skeletons(reports, counters: { git_commit: :commit, pr_opened: :pr })
end
```

`auto_windows idle: N` splits the timeline wherever two consecutive events are more than N minutes apart and writes a gap card for each break ("15h 4m later" / "Back at Thu 10-01 09:48"). An explicit `gap` at the same position wins. The caption is measured event to event, and when the day labels carry `MM-DD` it uses the real calendar distance: `Thu 10-01` to `Thu 10-08` reads "7d later", not "1d". **Limitation:** without dates in the labels, consecutive labels are assumed to be consecutive days (`Mon` then `Fri` reads "1d later"), because a label alone carries order, not distance. In org it is the header arg `:auto-windows 180`.

**Chip text.** The default label is a humanized effect kind with a count ("2 commits", "PR opened"), not the raw command: `session-skeleton` truncates `cmd` to 140 characters and real ones are compound shell lines, so the prefix is often unrelated to the effect (a `sed` ahead of the `git commit`; the commit message is usually cut off). Pass `label: ->(kind, item) { ... }` to override. Chips in a multi-day replay say their day when it changes within a lane (`Mon 16:27`, `Tue 15:42`, `15:49`), so time never appears to run backwards.

Tried on three real sessions (this week plus mid-September): 44 events became 11 windows and 10 generated gap cards with no hand-written windows or captions, including a "7d 8h later" across two Thursdays.

## 5. Verification

- `spec/components/replay_spec.rb`: 20 examples (minute math, day order, sorting, window inference, finale interpolation, every validation error, skeleton loader, rendering, `</script>` escape, single injection of CSS and engine, DSL registration). All pass.
- Full suite: 4541 examples, 1 failure: `slim_graph_r_builtin_spec.rb:99`. It packages the gem from `git ls-files`, so it can't see the new, still-untracked `components/replay.rb`; it passes on a clean tree and should pass once these files are committed. Confirmed unrelated to logic.
- Browser (playwright-cli over local HTTP, exported file): the page loads with no console errors; at 1x the clock reached the first gap in ~4s (10 sim minutes at 340ms); at 2x it crossed the second gap, rendered chips and glowing counters (screenshot reviewed), and finished in the `done` state with the finale reading "14 commits, 5 invites, 5 email drafts, 2 vendor posts" (matches the hand-computed totals from the source's event list).

## 6. Size

| | Lines | Bytes |
|---|---|---|
| Hand-written source page | 186 | 11.1 KB |
| `examples/components/replay_thursday.rb` (same content) | 57 | 3.6 KB |

Roughly 3x fewer lines and bytes, and about 3x fewer tokens (the source is dominated by CSS and engine; the example is dominated by the 33 event rows, which are the irreducible content). The author-facing cost is the data: chrome plus structure is about 24 lines. A new replay of a different day is the same ~25 lines of structure plus its events.

## 7. Org authoring syntax

Two designs, merged. Tested against org-ruby 0.9.12 (the renderer GitHub uses; GitHub's deployed version may differ), 2026-10-02:

| Org construct | org-ruby result |
|---|---|
| `#+NAME: x` followed by a table | Real HTML table with header row. The `#+NAME:` line is silently ignored. |
| `#+BEGIN_REPLAY ... #+END_REPLAY` (unknown block) | **Dropped entirely, including its content.** Renders as nothing. |
| `#+begin_src replay ... #+end_src` | Monospace block with the content verbatim, including `#+WINDOW:`-style lines. |

**Proposal from the dinocloud-setup session** (org-babel style): lanes and events as `#+NAME`d org tables, config in a block whose header args reference them (`:lanes lanes :events events :ms-per-minute 340 :counters "commit:commits invite:invites"`), with `#+WINDOW:`, `#+GAP:`, `#+FINALE:` lines inside the block. Event tables carry one column per counter plus a `milestone` column.

**Weighing it:**

- **Take: data as named tables.** Better than my earlier single events table. Lanes become a table too, the file shows real tables on GitHub (they are the evidence), Emacs gives sorting and formulas for free, and the mapping to the DSL is 1:1 (a lane row is `lane`, an event row is `event`/`milestone`, a numeric cell in a counter column is `commit: 1`). Counter columns by `:counters` naming is cleaner than my `{key => n}` hash.
- **Change: the config block must be `#+begin_src replay`, not `#+BEGIN_REPLAY`.** As verified above, an unknown special block vanishes on GitHub, so the windows, gaps and finale text would be invisible to anyone reading the .org there. The src form keeps them visible. Same header args, same body lines; only the block name changes. Precedent: the reader already special-cases `lang mermaid` (`org/reader.rb:375`).
- **Change: use real day labels in the tables** (`Thu 09:48`), not the `W`/`T` codes. The clock displays the day label as written, and day order is first appearance, so `T` would show as "T" on screen. If short codes are wanted for typing, add a `:days "W=Wed T=Thu"` header arg that expands them; not needed for v1.
- **Open point: `#+NAME` resolution is new work.** `org/reader.rb` does not handle `#+NAME:` today (grep finds nothing). The reader must attach each name to the table that follows and resolve `:lanes`/`:events` against it. Fallback when args are omitted: the nearest preceding lane/event tables, so the simple case needs no names.
- **Open point: where windows live.** Body lines (`#+WINDOW:`) are fine and stay readable; with none present the component already infers one window. Gaps pair with windows by order, as in the DSL.
- **Writer round trip** is easier with tables than with my embedded-table-in-src idea: tables are first-class org, so the writer does not need to re-serialize them.

**Combined sketch:**

```org
#+NAME: lanes
| id     | name             | sub         | color |
|--------+------------------+-------------+-------|
| access | DinoCloud access | AWS, GitHub | cyan  |

#+NAME: events
| at        | lane    | text                       | commit | milestone |
|-----------+---------+----------------------------+--------+-----------|
| Thu 09:48 | nowcast | commit: remove one-time    |      1 |           |
| Thu 11:46 | prep    | Ask: I have 15 min to prep |        | t         |

#+begin_src replay :title "Thursday" :lanes lanes :events events :ms-per-minute 340 :counters "commit:commits"
#+WINDOW: Wed 18:40 .. Wed 18:50
#+GAP: Then 6 hours away | Back after dinner, past midnight
#+WINDOW: Thu 09:05 .. Thu 12:02
#+FINALE: Noon. | {commit} commits before lunch
#+end_src
```

Tyrion story `replay-org-src-block` should be read with this design: its "org table of events" criterion becomes "named lane and event tables plus a `#+begin_src replay` block with header args".

## 8. Built vs proposed

Everything below is built and committed locally (epic `interactive-widgets` in Tyrion, 2026-10-01 to 02):

- The `replay` DSL (counter, lane, window, gap, event, milestone, finale, events), validation, and the vanilla-JS engine (play/pause/restart/speed, space and r keys).
- `streamweaver export --bare` for edge-to-edge iframe embedding.
- One renderer in `Adapter::Static` (shared by the Alpine and Opal adapters); the engine initializes stages itself and ships in the canvas and reader page shells, so re-pushed and later-pushed replays work.
- Org authoring: `#+NAME` tables plus `#+begin_src replay`, Reader and Writer, fixpoint round trip, readable on GitHub's org renderer (`spec/org/replay_org_spec.rb`).
- The Chrome extension: engine bundled, stage id derived from content, morph guard so live re-renders do not restart a replay, org reader fixed for Opal.
- Session data: `events_from_skeleton(s)`, `auto_windows`, generated gap cards with real calendar distance, humanized default labels, a day prefix on chips when the day changes.

**Still open:**

1. **Installed-extension check.** The extension work was verified on the real `sandbox.html` and `sandbox.js` served over HTTP, not in the installed extension (manifest CSP and the viewer frame were not exercised). One manual pass in real Chrome remains.
2. **Canvas re-push restarts the replay.** The canvas morphs with idiomorph, which rebuilds the stage from markup; the Opal runtime's skip-if-initialized guard has no canvas equivalent yet.
3. **Identical replays on one page share a stage id** (and all respond to space/r). Fine for one per page.
4. **Theming.** The stage is always solarized-dark via scoped `--bg/--panel/--text` vars on `.sw-replay`; map them to theme tokens if replays should follow doc themes.
5. **Seek/scrub** (a timeline slider) and **loop**. The engine's state is small enough that both are cheap; the source page has neither.
6. **No dates in labels means no real gap distance.** `auto_windows` assumes consecutive day labels are consecutive days; give labels an `MM-DD` for the real distance (skeleton data already has it).
