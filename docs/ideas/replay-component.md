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

`Replay.events_from_skeleton(report, map:, label:)` turns `session-skeleton <uuid> --json` into event tuples. `map` is `effect_kind => [lane, counter_key]`; unmapped kinds are dropped (so unconfirmed attempts and noise stay out). Dates collapse as `"Thu 10-01 09:48"` to `"Thu 09:48"`.

```ruby
report = JSON.parse(`~/work/claude_code_history/bin/session-skeleton #{uuid} --json`)
replay title: "My Thursday" do
  counter :commit, "commits"; counter :invite, "invites"
  lane :dev, "Dev work"; lane :access, "Access"
  events Replay.events_from_skeleton(report, map: { git_commit: [:dev, :commit], github_invite: [:access, :invite] })
end
```

Limits found while reading `session-skeleton`: each item carries only `at`, `cmd` (a truncated shell command) and `count`, so the default chip text is the raw command. Real chips need a `label:` lambda or a hand-written pass. Lane assignment by session is also not in the data: one skeleton is one session, so a multi-lane replay means merging several sessions' reports (or lane-by-effect-kind). Merging is a few lines and was not built.

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

## 7. Built vs proposed

**Built (uncommitted):** `replay` DSL (counter, lane, window, gap, event, milestone, finale, events), validation, client engine with play/pause/restart/speed and space/r keys, Alpine-adapter rendering and CSS, `events_from_skeleton`, example, spec.

**Proposed, not built:**

1. **Chromeless export for iframes.** `streamweaver export` wraps the replay in the doc page shell (white card on beige in the screenshot). An org-reveal iframe wants the stage edge to edge. Needs a `--bare` or `chrome: false` export option (or a replay-only shell in `PageShell`).
2. **`auto_windows idle: 120`.** Split a skeleton's timeline on idle gaps over N minutes and synthesize gap cards ("6h 10m later") so skeleton data needs no hand-authored windows or captions.
3. **Multi-session merge** helper (several skeleton reports to lanes, one lane per session).
4. **Theming.** Today the stage is always solarized-dark via scoped `--bg/--panel/--text` vars on `.sw-replay`; map them to StreamWeaver theme tokens if replays should follow doc themes.
5. **Static and Opal adapters.** Only the Alpine adapter renders it (static export goes through that path, so export works); `Adapter::Opal` raises NotImplementedError like `pipeline` does today.
6. **Multiple replays per page** share space/r keys (all respond). Fine for one stage per page; scope to the focused stage if a doc ever hosts several.
7. **Seek/scrub** (a timeline slider) and **loop** option; the engine's state is small enough that both are cheap, but the source page has neither.

## 8. Next steps (need Forrest's go-ahead)

- Commit locally: stage explicit paths only (`components/replay.rb`, `assets/js/sw-replay.js`, spec, example, this doc, plus the edits to `alpinejs.rb`, `base.rb`, `components.rb`, `display_dsl.rb`). The working tree also holds unrelated pre-existing changes that must stay out.
- Decide on proposal 1 (bare export) before pointing a deck at it, since that is the actual embed path.
