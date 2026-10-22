# Parked: the large design for canvas annotation feedback (rev 2)

**Status: parked, not built.** The v0 that shipped is far smaller: click or Alt-click an element, comment, the agent pulls it with `streamweaver canvas-notes NAME` and finds the quoted text in its own DSL file (epic `canvas-click-comments`, `features/canvas-click-comments.feature`, skill section "Reading the person's comments"). This document is the bigger design that two panel rounds produced before that decision. It is kept so nobody re-derives it if revisions, receipts, a wake or source-line anchors are ever wanted.

## Why it was parked

Two rounds of design and adversarial review each found about 18 problems. The second round's new problems came almost entirely from the new machinery (revision ring, generation fencing, successor alignment, "shown" receipts, a journal with replay), not from the feature. Lavish-style feedback works without any of it: it sends the agent the element's text plus the comment, and the agent finds the text in its source. A small read-only vet of that smaller plan found no show-stopper and listed four details, all handled in v0. The rigor cost of the large design exceeded what the feature earns.

## What a second adversarial pass found wrong with rev 2 (summarized)

Reproduced by hand: Prism's location for a heredoc statement covers only `md <<~MD`, not the body, so the statement source is truncated and an edit to the body does not change its hash; two statements on one line (`2.times { md "A" }; x = 1`) give two components that both report that line.

Reported, not all re-verified:

- Source identity is unsound for helper methods defined in the DSL, a nested `instance_eval`, a different eval filename, and `Array#push` bypassing the proposed `<<` hook. All pass a containment check without degrading.
- Stamping "the first start tag" anchors a `<style>` before a chart, and a multi-root component anchors only its first root.
- Taking the session lock on writes does not make `/poll` read html and revision atomically; a failed push cannot be distinguished by the browser; generation is not fenced on incoming notes; a push committed to a session closed and recreated mid-render goes to a detached object.
- `max_applied_rev >= ack_rev` reports "shown" for a revision no viewer applied if a later push reverts it before any tab polls.
- Aligning statement hashes with LCS moves a pin to the wrong one of two identical statements.
- Skipping a torn journal tail does not repair an append-only file; the next append concatenates onto the broken line.
- Marking notes seen before delivery loses a wake if the waiting client dies in between; `seen_through` has no reader identity.
- Strict `rid` matching in `Client#send_message` breaks the auto-heal path that snapshots an older bridge with the new client.
- `VALID_NAME` does not match History's own name validation (`a..b` passes one and fails the other).

Two of these are existing bridge bugs worth fixing on their own regardless of this feature: `Client#send_message` returns the first frame with no type check (`lib/stream_weaver/canvas/client.rb:112-113`), so a forwarded event can be read as a push response; and the session name is interpolated unescaped into the page (tracked as Tyrion mark disc-215).

## The design (rev 2, as consolidated)

**Verdict on the hypothesis.** Partly true, and rev 1 understated the gap. One render loop (`views.rb:3787-3789`) and one DSL string per session (`bridge.rb:136`) make stamping cheap, now proven (section 1). Not cheap: the bridge has no revision, transaction, generation or request/response model (`session.rb:25,31`, `bridge.rb:122-139`, `bridge_server.rb:473,561-568,585`, `client.rb:112-113`) and reflects arbitrary session names into HTML and JS (`bridge.rb:26-27`, `bridge_server.rb:139-147`). About 40% of the work is capture UI and skills, 60% is making the bridge honest. The University loop contributes only the whole-doc re-push half.

## 1. Anchor model

**Capture the source line per component; never infer it from counts.** `Bridge#render_dsl` (`bridge.rb:215-229`; today `instance_eval(dsl)` at 218) installs a line-tracking array via `App#components=` (`app.rb:161-167`) and evaluates `instance_eval(dsl, "canvas", 1)`; the array's `<<` records `caller_locations.find { |l| l.path == "canvas" }.lineno`. Containers swap in a child array (`app.rb:489-495`), so only top-level components are recorded. Consolidator re-run, 8 inputs: `md "A"; md "B"` gives `[1,1]`; `x = 1\n2.times { md "A" }` gives `[2,2]`; `begin\n md "A"\nend` gives `[2]`; `if true; md "A"; md "B"; end\nmd "C"\nx = 1` gives `[1,1,2]`; `use_stylesheet(..)\nmd "A"\nmd "B"` gives `[2,3]`; card, heredoc, leading-blank correct. Every finding-1 counterexample is visible here and invisible to rev 1's count gate.

**Spans from Prism, Ripper as fallback.** `Prism.parse(src).value.statements.body` gives exact `[start_line, start_col, end_line, end_col]` (consolidator: `begin..end` L1:0-L3:3; two semicolon statements L4:0-6 and L4:8-14). Prism is stdlib on 3.3.5 and 3.4.7 and missing on 3.2.9 without the gem (verified); the gemspec floor is `>= 3.1` (`.gemspec:15`). Without Prism, spans come from `SourceSplitter` (`source_splitter.rb:32-38`) and a block's slice must parse as one statement under `Ripper.sexp` or it degrades, so `begin` degrades honestly instead of silently.

**Mapping rule.** A component with line L maps to the statement whose span contains L. Several components on one statement (loop, one-line `if`) share it, labelled `block i of k from this statement`; the edit target is the statement. k statements and k components on one line map in order; anything else, or a line in no span, degrades: line kept, `src: null`, 200 chars textContent. Counts are only a degrade signal. Statements adding no component (`use_theme`, `use_layout`, `use_stylesheet`, locals) simply get no block; no regex filter. Comments between statements belong to neither span, so editing B's comment never changes A's hash.

`h` = 8 hex of MD5 over whitespace-collapsed statement source. **Line numbers are file lines:** `canvas-push` sends `line_offset` = prepended `--stylesheet` lines (`cli.rb:1324-1334`) minus leading blanks dropped by `.strip` (`cli.rb:1283`); new `--file PATH` reads the file, records the path on the session, and the payload header prints it.

**Markers on the component's root element, not siblings.** A canvas-only `AnchoredContentView < AppContentView` wraps each `component.render` in Phlex `capture` (2.3.1, `Gemfile.lock:51`), injects `data-sw-n` into the first start tag, emits `raw safe`. Consolidator re-run: `text "Name"` then `text_field :name` renders `<p data-sw-n="0">Name</p><input data-sw-n="1" ...>`, so `p + input` and `p:has(+ input)` (`views.rb:954-962`) survive untouched (finding 11). Per-block metadata lives in one `<script type="application/json" id="sw-anchors">` `{rev, blocks:[{n, kind, line, end_line, h, shared, degraded}]}`. Output not beginning with a start tag (none seen; inferred rare) falls back to a `<template data-sw-n>` sibling via Phlex `template(data:)` (finding 18). Only `render_dsl` uses this view; canvas-read, export, save-doc and org stay content-only.

**Revisioned source map.** Each successful push gets `rev` and stores `{rev, dsl, blocks}` in a ring of the last 5. The browser sends `rev, n, h`; the bridge resolves `n` against that rev and confirms `h`; if evicted it looks `h` up in the current map; else `src: null, stale_anchor: true`. This replaces rev 1's resolve-against-current-dsl (finding 2).

**Fine anchors.** `render_table_row` already receives `idx` (`alpinejs.rb:1894`) and stamps `data-sw-row="idx"`, so sort (`alpinejs.rb:1851-1866`) cannot move it. Convention, stated once: 0-based index into `rows:`, printed `rows[1]`, header not counted; the JS also sends the cell text (finding 10). `md` quotes: 32-char prefix/suffix mapped to a Kramdown block line via `options[:location]` (consolidator verified: header 1, p 3, ul 5, p 8), slice 7. `code_block`/`mermaid`: line in block.

## 2. Capture UI

One JS file (about 300 lines) served like `sw-replay.js` (`bridge_server.rb:313`), mounted beside `#app-container` like the save widget (`:321`) so the poll swap cannot eat a draft; no `x-model`, so `getFormState` ignores it. Click a `[data-sw-n]` block: margin highlight, composer. Select text: comment chip. Click a cell: chip reads `rows[1] · Cost`. Enter posts; Esc cancels; drafts in localStorage keyed by session, generation, `h`.

Pins, one per note, drawn only when the poll's `version` equals the page's `currentVersion`: grey queued, blue seen, green-outline pushed, solid green shown, amber "acked, text unchanged", dotted "block changed since", hollow degraded, dashed stale anchor; tooltips carry the words. Agent bar: `listening` only from a live `wait_notes` for THIS session, never from `reply_to` (branch unmerged, verified; peerpressure drops non-action events, `relay.rb:44` per V3); else `last seen Nm` or `nobody listening, notes queue`. `Send now` closes a batch early, never required. Composer disabled when `#sw-anchors` is missing (error page: `bridge.rb:122` sets html before the error check). Under 860 px: bottom sheet, tap = click, `selectionchange` drives the chip; same-origin fetch passes `bridge_server.rb:100-101`.

## 3. Transport

**Dedicated endpoint, store only.** `POST /canvas/:name/note` `{id, rev, n, h, row, col, quote, prefix, suffix, text}` never calls `forward_to_claude` or (branch) `dispatch_to_reply_to`, so `canvas-wait`, University (`listener.rb:253-255` acts on `data[:button]`, per V2) and sinks never see notes and no socket client can read one as a response (findings 3, 12, 13). `/event` is untouched. Server derives `kind`, `lines`, `src` from `n` and the retained map; client values are ignored. Caps: text 2 KB, quote/prefix/suffix 512 B, body 16 KB (413), 200 pending per session (429). Dedupe by `id`; reply `{seq, status}`.

**One lock per session.** New public `Session#synchronize` (today `@mutex` is private, toasts only, `session.rb:31,96-114`). `handle_push` sets, in order, map, dsl, stylesheets, html, `rev` under it; the note path dedupes, assigns `seq`, snapshots, appends and signals a ConditionVariable under it. The lock covers the swap, not the render (S5).

**Journal.** `<History.root>/<session>/notes.jsonl`, append-only ops `{op: note|seen|pushed|shown|amber|retract|reply|closed|reset, seq, gen, ...}`. Reload folds in seq order, skips an unparsable last line, sets `next_seq = max + 1`, closes open batches. Names validated with `History::VALID_NAME` (`history.rb:22`) at `create_session` and every `/canvas/:name` route (400), so the store cannot raise on a name the bridge served. `History.cleanup` (`history.rb:49-65`, `*.rb` only, `MAX_AGE_DAYS = 7` at `:19`) gains: delete `notes.jsonl` untouched 30 days (open question 2). The bridge reads `History.root` at boot, so a spec must set the env before booting it.

**Generation.** Each Session carries `gen` (epoch ms). `close` appends `closed`; `reset!` (`session.rb:91-98`) appends `reset` and marks pending notes stale. GET auto-create (`bridge_server.rb:143`) or `canvas-restart` of a name with no trailing `closed` continues the journal's `gen`, so restart keeps pins live; reuse after `close` starts a new `gen` and older-gen notes load as stale, listed, never pinned. `canvas-notes` with no name walks History dirs (finding 7).

**Readers.** (1) Pull: `get_notes`/`ack_notes` beside `get_dsl` (`protocol.rb:65-67`, `bridge.rb:63-64`). (2) Wake A: `wait_notes {name, since, quiet_s}`, level-triggered ("return when unseen notes with `seq > since` exist and their batch has been quiet 8 s"), waiting on the ConditionVariable under the session lock, so no check-then-register race. While blocked, the handler probes the client socket for EOF each second so a killed `--wait` drops presence within a second (inferred: `bridge_server.rb:598-622` reads only between messages). It returns the batch and marks it seen: pull and wait are one call (finding 17). (3) Wake B (Codex): slice 8.

**Command/response hardening.** `Client#send_message(message, expect:)` skips `type: "event"` frames and returns the first frame of the expected type (`client.rb:112-113` returns `messages.first`); requests carry `rid`, echoed back. `canvas-push` (`cli.rb:1298-1307`) can no longer print "Pushed" on a forwarded event, fixing today's action-during-push bug.

**Security (slice 0).** Escape `session_name` with `Rack::Utils.escape_html` in HTML (`bridge_server.rb:276,281,293`), JSON-encode it in JS (`:401`), validate names, restrict `/shutdown` (`:126-130`) to loopback. **Still present, stated, out of scope:** anyone reaching the bridge can POST a forged `action` to `/event` without `Sec-Fetch-Site` (`:97-102`), a stronger injection channel than notes; logged as a follow-up in `docs/canvas-agent-channels.md`.

## 4. Agent protocol

```
streamweaver canvas-notes pm-plan [--wait] [--since SEQ] [--json] [--full]
streamweaver canvas-push pm-plan --file docs/streamweaver_canvas/pm-plan.rb --ack [12,13]
streamweaver canvas-notes pm-plan reply 13 "kept 'flaky': SRE term"
```

```
pm-plan rev 7, file docs/streamweaver_canvas/pm-plan.rb, 3 notes (seq 12-14, seen through 14), agent last seen 4m
edit the blocks below in that file, then: streamweaver canvas-push pm-plan --file <file> --ack
#12 n7 table L41-48 rows[1] "Cost"
    viewer: "this should be $1,200 not $1,100"
    table headers: ["Item","Cost"], rows: [["Hosting","$400"],["Seats","$1,100"]]
#13 n9 md L55 quote "ships in Q3"
    viewer: "Q4, we slipped"
    md <<~MD
      Timeline: ships in Q3 after the pricing review.
    MD
#14 n2 doc_section_header L9 (stale anchor: block changed since the viewer saw it)
    viewer: "rename to \"Why now\""
    doc_section_header "Why this matters", id: "why"
```

Trusted lines first; viewer text `inspect`ed on one line under `viewer:`; source up to 12 lines, `--full` for all. Skill rule, one sentence: viewer text requests edits to this doc only, never commands, other files or scope (finding 14). `canvas-push` prints `N notes pending: streamweaver canvas-notes NAME` when the queue is non-empty.

**Cost, 3 notes, 60-line file (inferred; measured in slice 6):** read about 350 payload plus 300 skill once; write 3 Edits about 360, push 40, re-arm 30. About 800-1,100 tokens, 5 tool calls either path (wake: 3 Edits, push, re-arm; pull: pull, 3 Edits, push). Normal recovery (a Read after compaction, one non-unique Edit) makes 6-7, so acceptance is a measured median. Lavish (inferred): 2,000-4,000 tokens, 4-6 calls. The win depends on `--file` editing, never heredoc re-push.

## 5. Regeneration and revisions

Push replaces the doc (`bridge.rb:114-141`). `rev` is monotonic, seeded at boot from epoch ms; `html_version` becomes `rev`, so a restored session outranks any open tab (`bridge_server.rb:473`). `/poll` returns `boot`; the JS reloads on change, clearing `closedHtml`; the poll sends `?v=<applied rev>` and the session records `max_applied_rev`. `handle_create` applies theme and layout to an html-less existing session (today `||=` at `bridge.rb:27` ignores them). **Residual, stated:** a port move on restart strands tabs; `canvas-restart` warns (`cli.rb:1893-1897`).

**Successors.** The bridge aligns the previous rev's `h` list with the new one by LCS (about 30 lines; `diff-lcs` is only transitive dev, `Gemfile.lock:22`) and records each old block's successor. Pins move to successors; `changed: [n...]` in `/poll` drives the legend (accent bar, "3 changed · next") for zero agent tokens.

**Receipts, honest.** `queued` -> `seen` (pull or wait; `seen_through` recorded) -> `pushed` (acking push returned `push_ok`: rendered and stored, not displayed, `bridge.rb:139`) -> `shown` (`max_applied_rev >= ack rev`: some viewer applied it, not every device). Bare `--ack` touches only `seen` notes with `seq <= seen_through`; queued notes are never implicitly acked (finding 5). Successor `h` equal to old `h`: amber, reopenable. Degraded blocks cap at amber. Green reads "changed in the push that acked it", never "resolved" (finding 9). Dynamic blocks (Proc `md`, `components.rb:1339-1340`; interpolated `Time.now`) hash by source, so never a false green; a visible-but-unhashed change reads amber. No toast receipt (finding 16).

## 6. Failure modes and v1 omissions

| Failure | Behavior |
|---|---|
| POST retry | same `id`, one note |
| Line in no span, or j != k on one line | degraded: hollow pin, `src: null`, amber cap |
| Shared statement (loop, one-line `if`) | all blocks anchor to it, `block i of k` |
| Note against evicted rev | `h` lookup, else `stale_anchor`, agent sees it |
| Push fails | nothing acked, `rev` unchanged, composer disabled |
| Bridge restart | journal folds; epoch rev swaps tabs; `boot` reloads; `gen` continues |
| Session closed, name reused | new `gen`; old notes stale, never pinned |
| Agent forgets `--ack` | notes stay `seen`; reprinted `(seen)` |
| Queue full | 429; composer says "queue full, agent must pull" |
| Invalid name | 400 at every route |

v1 omits: images, layout inbox, Excalidraw, `working`, playbooks, Wake B, author labels, `canvas-patch`, note export, a `--wait` that survives compaction.

## 7. Risks and unknowns

| Risk | Cheapest resolution |
|---|---|
| Prism missing on Ruby 3.1/3.2 | S1 |
| Component output not starting with a tag, or raising inside `capture` | S2 |
| `caller_locations` lineno differs under the real bridge thread | S3 |
| Background `--wait` not re-invoked by Claude Code | S4 |
| Session lock stalls `/poll` during a long render | S5 |
| LCS mis-moves pins on heavy rewrites | S6; "moved?" outline when successor `h` differs |
| Kramdown in-block normalization misses | ship block-line first; count "where" follow-ups |
| 8 s window | bridge setting; measure |
| Android selection UI vs chip | S7 |

## 8. Build slices (Tyrion-ready)

| # | Slice | Acceptance | RIGOR | LANE | Files |
|---|---|---|---|---|---|
| 0 | Hardening: `VALID_NAME` at create and routes, HTML/JS escaping, loopback `/shutdown`, `send_message(expect:)`, `rid` | `GET /canvas/a%27%3Balert(1)%3B%27` and `GET /canvas/%3Cimg...%3E` return 400 (Rack::MockRequest); an event frame written before `push_ok` on a scratch socket does not make `canvas-push` print "Pushed" | strict | bridge | `canvas/bridge.rb`, `canvas/bridge_server.rb`, `canvas/client.rb`, `canvas/protocol.rb`, `cli.rb` |
| 1 | Line-capture anchors, Prism spans with Ripper fallback, `AnchoredContentView`, `#sw-anchors`, `data-sw-row`, `line_offset`, `--file` | Spec asserts containment on the 8 probe inputs (semicolon both L1; `2.times` both shared, `x = 1` no block; `begin` L1-3 under Prism, degraded under Ripper; one-line `if` A,B shared, C = `md "C"`; `use_stylesheet` no degrade; `--stylesheet` plus 2 leading blanks reports file lines); `text`+`text_field` renders `<p data-sw-n="0">Name</p><input data-sw-n="1"`; sorted `<tr>` keep `data-sw-row`; `canvas-read` has zero `data-sw-n`; corpus spec over push-body docs (filter `.run!`) asserts every block's `src` is one statement containing its line | strict | render | `canvas/bridge.rb`, new `canvas/source_map.rb`, new `views/anchored_content_view.rb`, `org/source_splitter.rb`, `adapter/alpinejs.rb`, `cli.rb`, specs |
| 2 | Revision model: epoch `rev`, `boot`, `Session#synchronize`, map ring, `gen`, `handle_create` theme fix, `?v=` | Push A then B, note with rev A resolves to A's `src`; `h` mismatch stores `stale_anchor`; playwright: tab at rev N, `canvas-restart`, restored content with theme within 2 s; stale tab never gets pins for a newer rev | strict | bridge | `canvas/session.rb`, `canvas/bridge.rb`, `canvas/bridge_server.rb`, `canvas/protocol.rb`, `cli.rb` |
| 3 | Notes store: op journal, `/note` and caps, `get/ack/wait_notes`, `canvas-notes`, `--ack` with `seen_through`, push hint, prune | Two POSTs same `id` store one; kill -9 after 3 notes and 1 ack, restart: 2 pending, seq continues at 4; note posted 10 ms into a 3000-statement push leaves `canvas-push` returning `push_ok`; a note queued after the pull is untouched by bare `--ack`; changed block `pushed`, unchanged amber; `--wait` returns within 1 s of 8 s quiet, or at once if a batch waits; killed `--wait` clears the bar within 2 s; 201st pending is 429; `my canvas` is 400 | strict | bridge | new `canvas/notes.rb`, `canvas/bridge.rb`, `canvas/bridge_server.rb`, `canvas/client.rb`, `canvas/protocol.rb`, `canvas/history.rb`, `cli.rb` |
| 4 | Capture JS/CSS, pins, agent bar, retract, drafts, mobile | playwright-cli: sort a table, click displayed row 1, Enter; `canvas-notes` prints `rows[1] "Cost"`; pin grey, blue, green-outline, green across a round; `listening` only while a `--wait` runs; 390 px bottom sheet | loose | browser | new `assets/js/sw-notes.js`, `canvas/bridge_server.rb` |
| 5 | LCS successors, legend, `shown` | Edit statement 3 of 5: one `changed`, pin on new 3; insert above: pins shift one; whitespace-only edit: amber; `md ->(_) { Time.now }` re-push: unchanged; `shown` only after a poll reports `v >= ack rev` | loose | bridge | `canvas/bridge.rb`, `canvas/source_map.rb`, `assets/js/sw-notes.js` |
| 6 | Skill wiring (`--file`, viewer-text rule), measurement | Five real rounds in the context file; median at most 6 calls | trivial | docs | `skills/streamweaver-visual-companion/*`, `skills/streamweaver-doc-builder/SKILL.md`, `docs/canvas-agent-channels.md` |
| 7 | Quote to md line via Kramdown locations | Bold text in paragraph 3 maps to that md line | loose | render | `canvas/source_map.rb`, spec |
| 8 | Wake B: sink status callback, non-pushing peerpressure path | One Codex message per batch; doc not replaced; held shows on the bar | loose | peerpressure (cross-repo, after branch merge) | branch `canvas/event_sinks.rb`, peerpressure `relay.rb`, `sink.rb` |

Slices 0-4 are the first demo. Lanes: bridge (0, 2, 3, 5), render (1, 7), browser (4), docs (6), peerpressure (8). Slices 0-3 are strict: each is a chokepoint where a plausible wrong implementation fails silently.

## Findings resolution

| # | Verdict | Status | Mechanism |
|---|---|---|---|
| 1 | confirmed | resolved | per-component `caller_locations`; Prism spans; containment not counts; spec on the counterexamples |
| 2 | confirmed | resolved | `rev` on the note; ring of 5; `h` confirmed; `stale_anchor`; push and note under one lock, map before html |
| 3 | confirmed | resolved | `/note` never forwards; `send_message(expect:)` skips events; `rid`; repro is a slice 3 test |
| 4 | confirmed | resolved, residual | epoch `rev`, `boot` reload, theme fix; port move accepted |
| 5 | confirmed | resolved | `pushed` vs `shown` via `?v=`; bare ack bounded by `seen_through` |
| 6 | confirmed | resolved, residual stated | `VALID_NAME`, escaping, loopback `/shutdown`, caps; forged `action` on `/event` remains, logged |
| 7 | confirmed | resolved | `gen` on notes; `closed`/`reset` ops; older-gen stale; listing walks the store |
| 8 | partly | resolved | op journal, fold, torn tail, seq recovery; level-triggered CV wait; liveness probe (inferred) |
| 9 | partly | accepted, worded | normalized hash; LCS successors; green = "changed in acking push"; degraded caps amber |
| 10 | confirmed | resolved | `data-sw-row` from `idx`; 0-based `rows[i]`; example fixed |
| 11 | confirmed | resolved | root attribute via `capture` (consolidator verified); template only as fallback |
| 12 | partly | moot | notes never reach `/event`; University text corrected; forged-action out of scope |
| 13 | confirmed | moot for notes | no forward, no sink dispatch; `listening` only from live `wait_notes`; "content-free" claim removed |
| 14 | confirmed | resolved | server-derived fields; `inspect`ed viewer text; instruction first; caps; skill rule |
| 15 | partly | resolved | no-component statements get no block; `line_offset`; `--file`; comments outside spans; `--full` |
| 16 | confirmed | accepted, removed | pins only |
| 17 | partly | accepted | `--wait` prints the batch; re-arm counted; measured median; file in header |
| 18 | confirmed | accepted | Phlex `template(data:)` for the fallback only |

Verifier extras are covered by: session lock and seq recovery (3); `VALID_NAME` and History dir created only on a note (3); prune (3); `wait_notes` is not a forwarded client (3); presence liveness (3); successors for pins (5); `rows[1]` convention (1); degraded never green (5); corpus filter for `.run!` (1); `use_stylesheet` gets no block (1); `handle_create` theme (2); pins gated on version equality (4).

## Decisions and why

1. **Root-element attributes (R2) over template siblings plus parallel CSS (R1).** Consolidator re-run: `<p data-sw-n="0">Name</p><input data-sw-n="1"`, so `views.rb:954-962` needs no change; R1's parallel rules would have to track every future `+` selector.
2. **Prism spans (R1) with R2's per-block Ripper check as fallback.** Prism is exact on `begin..end` and same-line columns (verified 3.3.5/3.4.7) and missing on 3.2.9 (verified). R2 alone degrades `begin` everywhere; R1 alone breaks on 3.1/3.2.
3. **`shown` (R2) kept; R1's `pushed`-only rejected.** `?v=` on the existing 500 ms poll (`bridge_server.rb:152-165`) is nearly free and closes finding 5's "on your screen" gap.
4. **Hardening as slice 0 (R1), not folded into slice 2 (R2).** Independent, small, and the exposure exists today (V1 probe of `bridge_server.rb:276,281,293,401`).
5. **`--file` reads the file (R2), not `--file PATH < PATH` (R1).** Fewer tokens, one path source.
6. **Comments in no span (consolidator), not attach-forward (R1) or trim-trailing (R2).** Prism spans are exact statements; neither neighbour's hash moves.
7. **Ring of 5 (R2) over 3 (R1).** DSL strings are small.
8. **No no-op regex (consolidator).** With per-component lines a no-component statement simply has no block; R1's regex still misses locals.
9. **30-day retention (R2) over the 7-day `.rb` rule (R1).** `MAX_AGE_DAYS = 7` (`history.rb:19`) would delete pending notes an agent has not pulled in a week.

## Spikes before any build slice

| Spike | Question | Cheapest experiment | Result that changes the design |
|---|---|---|---|
| S1 Prism on 3.1/3.2 | Add `prism` as a dependency or accept the Ripper fallback? | `~/.rvm/rubies/ruby-3.2.9/bin/gem install prism` then `require`; 10 min | Clean: add the dep, drop the fallback. Native-ext trouble: keep fallback, document the higher degrade rate |
| S2 `capture` across components | Does every component start with a start tag, and does `capture` survive fragments and deferred blocks? | Run the `r2_probe_capture.rb` view over `examples/doc-parity-example.rb` and the 9 push-body docs; 20 min | Any raise: bypass `capture` for that class (template sibling). Non-tag starts: fallback becomes a slice 1 spec case |
| S3 `caller_locations` under the real bridge | Does `path == "canvas"` survive `instance_eval` from the socket handler thread? | Patch a local bridge's `render_dsl`, push the 9 docs, compare to `r1_probe.rb`; 15 min | Nil linenos: anchors fall back to count-gated markers, which finding 1 proved unsound; blocks slice 1 |
| S4 Background `--wait` in Claude Code | Does the harness re-invoke on exit, and is a Read needed? | `sleep 5` in background Bash; 10 min | No re-invocation: Wake A dead, v1 is pull plus push hint, Wake B moves into v1. Read needed: cost 6, median target 7 |
| S5 Lock vs render | Does `/poll` stall during a 3000-statement render? | Hold the lock during render, time `/poll`; 15 min | Stall: pin "lock covers only the swap" as a spec |
| S6 LCS on a real edit | Do pins land right after a 60-block edit? | Align `h` lists of two consecutive `~/.streamweaver/history/<session>/*.rb`; 20 min | Mis-moves: "moved?" outline, `h`-only fallback |
| S7 Android | Does the selection menu fight the chip? | 10 min on the phone over the tailnet | Fights: chip on selection end only, or long-press a block |

Already done: `caller_locations` on 8 inputs (three independent probes); `capture` root stamping; Prism spans and per-Ruby availability; Kramdown block locations; Phlex `template`.

## Open questions only the human can answer

1. Does Codex matter for v1? If yes, Wake B needs `canvas-reply-to` merged plus a peerpressure non-pushing path and status callback (cross-repo).
2. Retention: delete `notes.jsonl` after 30 days untouched, or never expire pending notes?
3. Should `--file` become the only documented push form in the skill, replacing the heredoc example?
4. If S1 shows `prism` installs cleanly on 3.1/3.2, add it as a dependency (one more native extension) or keep the Ripper fallback?
5. Author labels on notes (phone vs desktop on one canvas)? A localStorage nickname is cheap but is a setup step.
6. 8 s batch window: acceptable, or should the first note on a quiet canvas wake immediately?
7. Should slice 0 ship on its own ahead of the feature, given the bridge is already reachable over the tailnet?
