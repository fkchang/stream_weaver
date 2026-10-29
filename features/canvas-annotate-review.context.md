# Epic wiki: canvas-annotate-review

Read this first, then `features/canvas-click-comments.context.md` (the v0 epic this builds on; its Learnings section lists real file:line facts for the notes store). Append what you learn under "Learnings" at the bottom (file:line). Facts marked VERIFIED were checked in code or in a browser; UNVERIFIED ones are from reading or from design and must be confirmed before you rely on them.

## What we are building

v0 (shipped, commits a763ca4..da0b10d) lets a person Alt-click or use a floating "comment" pill, type a comment, and the agent pulls it with `streamweaver canvas-notes NAME`. Using it showed three gaps: nothing says what a click does or what happened to a comment; the person must go back to the terminal and type "I left comments"; nothing marks the element they pointed at.

This epic turns that into a review flow (modelled on lavish-axi's UX and held to the trilaws):

- Annotate mode with a visible toggle; while OFF the page is unchanged except a small "comment" pill.
- A right-hand side panel (320px; bottom sheet under 860px) holding the toggle, the list of comments as pills, the composer, Send to Agent and Send & End, status and the agent's summary.
- Hover and selected-element highlight; the composer is titled with the element kind ("Annotate <td>").
- Comments are stored on the bridge as `queued` until Send; Send releases a batch once to a waiting agent (`canvas-notes NAME --wait-submit`), and the sidebar says "No agent is listening" with a copyable line when nobody waits.
- `streamweaver canvas-annotate [NAME|FILE]` plus a skill / `/sw-annotate` as the single entry for both "doc not on screen" and "canvas already running".
- The panel is a named REGION of the page shell updated independently of the doc: a main-doc `canvas-push` must leave it, the open composer and any typed draft untouched.

Phase 2 (NOT this epic): Submit as a message into the agent session via peerpressure `reply_to` (Codex support). Do not build it; do not make choices that block it.

NOT in scope: source-line mapping, revision rings, LCS pin successors, "shown" receipts, generation fencing, images, layout-issue inbox, whiteboards. They were designed and cut; the parked design is docs/ideas/2026-10-22-canvas-annotation-large-design-parked.md. Do not resurrect them.

## Decisions already made

- Opt in only. No top bar (see spike). The toggle lives in the panel header.
- Alt-click (long-press on touch) stays as the shortcut that opens ONE comment from either state.
- `Enter` in the composer queues the comment (server side, state `queued`); only Send / Send & End makes a batch. Reload or a second device shows the same queued comments.
- Notes never travel over `/event`, `forward_to_claude`, canvas-wait, listeners or reply_to. Keep the dedicated `POST /canvas/:name/note` family.
- Viewer text is untrusted: print it with `inspect` on one line under a trusted header; the agent summary is escaped plain text, never markup; any new place that interpolates the session name into HTML or JS must escape it (existing bug: disc-215).
- The sidebar is rendered by the bridge in Ruby (Phlex), not by pushing DSL, so updating it costs the agent no tokens. The composer textarea lives OUTSIDE the swapped list so a region update never loses typing or focus.
- Statuses per comment: queued, then Sent, then Seen (the wait returned it to the agent), then Working (the doc was re-pushed after Send), then Done (agent posted a reply). The agent's one-line summary comes from `streamweaver canvas-notes reply NAME "summary"`.

## Facts

- VERIFIED (spike 2026-10-22, doc-parity example, doc theme): a fixed right panel 320px wide plus `body{padding-right:352px}` reflows the doc with no overlap and no horizontal scroll at 1280px; container went 1216px to 896px wide.
- VERIFIED: a fixed 44px top bar HIDES the doc theme's sticky TOC: `.sw-sidebar-toc` is `position:sticky; top:0; z-index:10` (computed), so after scrolling it sits at 0..52px behind the bar. The only workable fixes are `top:44px` on the TOC or no top bar. We chose no top bar.
- VERIFIED: at 390px a bottom sheet (`position:fixed; bottom:0; height:40vh`) with `body{padding-bottom:calc(40vh + 32px)}` looks right. The document's `scrollWidth` is already 621px at 390px WITHOUT any chrome (the doc's own horizontally scrolling TOC row); that overflow is pre-existing, not yours.
- VERIFIED: the canvas poll replaces the whole doc: `container.innerHTML = data.html` when `data.version > currentVersion` (lib/stream_weaver/canvas/bridge_server.rb:515); the poll handler is at ~152-165 and the client poll loop at ~426-515. There is no morph in the bridge; Idiomorph appears only in docs/streamweaver-frontend-vision.md and the HTML exporter. Nothing targets a section today.
- VERIFIED: the save-doc widget, sw-replay.js and the v0 overlay are mounted in `render_canvas_page` OUTSIDE `#app-container` (bridge_server.rb ~335-350), so a poll swap never removes them. Mount the panel the same way.
- VERIFIED: `Streamer` (lib/stream_weaver/streamer.rb) has replace/append/prepend/remove, but only inside app `every()` blocks; live sessions (lib/stream_weaver/service.rb:79-85) have target+action push over SSE. Neither is reachable from the canvas bridge. Do NOT try to reuse them; build the small region mechanism in the bridge.
- VERIFIED (v0 learnings): Bridge dispatcher is a `case message[:type]` (canvas/bridge.rb:53-76, `else` at ~73 rejects unknown types); Session public `add_note` / `drain_notes` guard a private mutex (canvas/session.rb); route `post '/canvas/:name/note'` with NOTE_MAX_TEXT / NOTE_MAX_BODY in bridge_server.rb; overlay is `lib/stream_weaver/assets/js/sw-canvas-notes.js` (148 lines, inlined); `canvas-notes` CLI is in cli.rb with protocol.rb; specs spec/canvas/bridge_notes_spec.rb, spec/canvas/canvas_notes_overlay_spec.rb, spec/cli_canvas_notes_spec.rb.
- VERIFIED (co-edit precedent): the University co-edit loop already runs an agent blocked in a BACKGROUND `canvas-wait`, which the harness re-invokes on exit (docs/university/co-edit-loop.md). `--wait-submit` should work the same way.
- VERIFIED: `Client#send_message` returns `messages.first` with no type check (canvas/client.rb:112-113), so a forwarded event can be read as a push response. Existing bug, tracked separately; do NOT fix it here, only avoid making it worse (new long-poll commands must not sit on a forwarded-event socket).
- UNVERIFIED: how `streamweaver panel` / the page shell decides layout width; test `--layout=full|wide|default` for the panel reflow (the spike only covered default).

## How to run a test bridge safely (cost the last session time)

- NEVER use the user's real bridge or ~/.streamweaver. Boot an isolated one: `export HOME=<tmp>/home STREAMWEAVER_CANVAS_SOCKET=<tmp>/c.sock STREAMWEAVER_CANVAS_PID=<tmp>/c.pid SW_NO_OPEN=1`, then `bundle exec exe/streamweaver canvas NAME` (this STARTS the bridge; `canvas-push` alone does not) and then `canvas-push NAME < file`.
- Unix socket paths are limited to 104 bytes: keep `<tmp>` SHORT, like `/private/tmp/claude-504/swNN`. A path under the long scratchpad directory fails with "too long unix socket path".
- Overriding HOME breaks `tyrion` (its DB is under HOME): run tyrion with the real HOME.
- Do NOT touch the isolated bridge on port 4701 named `conduct-status` (the coordinator's live status panel runs there). Boot yours on its own socket; it will pick the next free port.
- Browser checks are the COORDINATOR's. Leave them unchecked with a runbook note: exact boot command, URL, actions, expected observations, teardown. Use `playwright-cli -s=<name>`; Alt-click is `keydown Alt`, `click <ref>`, `keyup Alt`; synthetic `TouchEvent` dispatch via `eval` for long-press (hasTouch config via `--config`).

## Gotchas for every builder

- Other sessions leave modified tracked files in this checkout. NOT yours, do not edit, stage or revert them: docs/plans/2026-09-13-audit-report-doc-genre-design.md, lib/stream_weaver/org/reader.rb, lib/stream_weaver/skills/streamweaver-doc-builder/SKILL.md, lib/stream_weaver/skills/streamweaver-way/SKILL.md, llms.txt, spec/org/writer_spec.rb, plus many untracked files. Stage explicit paths only; never `git add -A`, `.` or `-u`.
- Repo is headed for open source: no `/Users/...` paths, personal emails or employer names in committed files. Do not push.
- Ruby first. Browser JS only where unavoidable, small, no build step, no dependencies. Prefer extending `sw-canvas-notes.js` or one new asset served the same way.
- No em or en dashes in anything you write (feature-file comment lines already use them; leave those).
- `tyrion epic-context` does not exist in this install: read and append to this file by hand.
- Specs build a Bridge/BridgeServer in-process (see spec/canvas/bridge_notes_spec.rb); never boot the real bridge in a spec.

## Learnings

(builders append below, with file:line)

- bridge lane (side-region, submit-and-wait, status-and-summary): Session now owns `@notes` (id, state queued/sent/seen/working/done) and `@regions` (lib/stream_weaver/canvas/session.rb); every notes mutation re-renders the `side` region via `NotesPanel` (lib/stream_weaver/canvas/notes_panel.rb, Phlex, auto-escaping) inside the session mutex, bumping the version only if the html changed. `drain_notes` keeps its v0 meaning: returns queued AND sent notes, marks them seen.
- bridge lane: /poll takes `?rv[side]=N` and returns `regions: {side: {html, version}}` only when newer (bridge_server.rb poll route + `region_versions_param`); the page shell has `<aside data-sw-region="side">` right after `#app-container` and the poll script swaps only that element (`regionVersions` map in `polling_script`). The composer must be a SIBLING outside that aside. Region buttons use one delegated click script keyed on `[data-sw-region] [data-sw-action]` (send, send-end, copy); it posts to `location.pathname + '/send'`, so no session name is interpolated.
- bridge lane: `Bridge#handle_claude_message(message, alive = -> { true })` takes the liveness lambda POSITIONALLY. A keyword arg breaks every caller that passes a braceless hash (`handle_claude_message(type: 'create', ...)` becomes unknown keywords under Ruby 3).
- bridge lane: blocking `wait_submit` runs in the per-connection thread (BridgeServer.handle_claude_connection), and `BridgeServer.connection_alive?` peeks the socket (MSG_PEEK) every 0.25s inside `Session#wait_for_submit`; a `kill -9` of the waiting CLI cleared "Your agent is waiting" within 1.5s on a real isolated bridge. `Client.request_typed` is the typed read (ignores `event` frames); `Client.send_message` is unchanged.
- bridge lane: POST /canvas/:name/note needs `Content-Type: application/json`; a curl `-d` without it is parsed as a form and returns 422 "Invalid note". (Browser overlay already sends JSON.)
- bridge lane: `tyrion handoff` does not exist in this install; a lane that must serially start the next story has to `tyrion unclaim` the previous one (criteria and evidence survive, status returns to pending).
- bridge lane: the full suite has 4 order-dependent failures in spec/cli_canvas_read_default_spec.rb (they read the real ~/.streamweaver history, 21 files); the file passes alone. Not related to this epic.
- bridge lane: the `canvas-notes reply` subcommand is detected by `args.first == 'reply'`, so a canvas literally named "reply" cannot be pulled by name (use `canvas-notes reply` only as the subcommand).

### Coordinator learnings after lane A (2026-10-29)

- BUG CLASS TO AVOID: JS inside an interpolating Ruby heredoc (`<<~HTML` in `render_canvas_page`, bridge_server.rb) has its backslashes eaten: `/\/$/` was served as `//$/`, which is a JS line comment, so the whole inline script failed to PARSE and the Send, Send & End and copy buttons did nothing in a real browser while 726 specs passed. Put page JS in `lib/stream_weaver/assets/js/*.js` and inline it with `File.read` (as sw-replay.js, sw-canvas-notes.js and sw-region-actions.js are). `spec/canvas/bridge_page_scripts_spec.rb` now runs `node --check` on every inline script; keep it green and add your scripts to what it covers.
- SPEC HYGIENE: a spec that saves a doc wrote a real file into the repo's docs/streamweaver_canvas and made an unrelated spec fail only in the full suite. Point STREAMWEAVER_DOC_ROOT (and STREAMWEAVER_HISTORY_ROOT) at a tmpdir in any spec that saves or records history. Bisect order-dependent failures with `bundle exec rspec A B --order defined`; never call a full-suite-only failure "unrelated" without that.
- BROWSER TESTING HAZARD: other Claude sessions on this machine run `playwright-cli kill-all`, which closes YOUR session mid-test ("The browser '<name>' is not open"). The coordinator runs the browser gates, but if you must use a browser, do open, act and read in ONE command, and treat empty output as "session died", never as a result.
- WHAT LANE A BUILT (all committed, region markup is deliberately plain): `Session` regions + `GET /canvas/:name/poll?rv[side]=N`; `NotesPanel` (lib/stream_weaver/canvas/notes_panel.rb) renders the side region in Ruby with presence line, the queued/sent/seen/working/done list, Send and Send & End buttons (`data-sw-action`), the copyable "see my comments" line, the agent summary; `POST /canvas/:name/send` (with `end`), `canvas-notes NAME --wait-submit`, `canvas-notes reply NAME "summary"`; `Client.request_typed`; assets `sw-region-actions.js` (delegated clicks for send / send-end / copy).
- NOT BUILT YET (yours): the annotate-mode flag held on the session (toggle shown in the panel header, same state across reload and tabs); the panel's page layout (fixed right panel with body padding, bottom sheet under 860px, collapsed "comment" pill when annotate is off); hover and selected-element highlight; composer title "Annotate <td>"; per-comment edit and remove for UNSENT comments (needs routes, e.g. PATCH and DELETE under /canvas/:name/note/:id, server side too); `canvas-annotate` CLI and the /sw-annotate skill.
- The v0 composer is in `sw-canvas-notes.js`: Enter POSTs the note at once, and with lane A that note is created `queued` (shown in the region) until Send. The composer is a sibling of the region, not inside it (a region swap must never touch it).
- Tyrion: `tyrion start` for a story that is `pending` after a handoff works; `tyrion handoff <slug>` needs the SOURCE binary `bin/tyrion` in the tyrion source checkout (the installed 0.1.0 lacks it); the claim gate hook reads the whole shell command, so run `tyrion start` as its own command before any `tyrion check`/`note` in the same call.

### Lane B learnings (ui and entry)

- Annotate flag lives on Session (`annotate?` / `annotate=`, lib/stream_weaver/canvas/session.rb) and is rendered into the side region (toggle button, aria-pressed), so a flip bumps the region version. The poll JSON carries `annotate`, applied by `window.swSetAnnotate` (sw-canvas-notes.js); the page body gets `sw-annotate-on` server side on load. Routes: `POST /canvas/:name/annotate {on}`, `PATCH` and `DELETE /canvas/:name/note/:id` (queued only, else 404); socket message `annotate` for the CLI.
- Panel CSS and layout live in sw-canvas-notes.js (aside[data-sw-region=side] hidden until body.sw-annotate-on). The "comment" pill now turns annotate ON (and hides while on); posting a comment no longer turns the mode off.
- `render_dsl` does not rescue SyntaxError (a ScriptError), so a pushed DSL with a syntax error raises out of Bridge#handle_push (lib/stream_weaver/canvas/bridge.rb:275). Pre-existing; not fixed here.
- Phlex leaves `<` unescaped inside a quoted attribute value (safe) but escapes `"`; specs assert on `&quot;`.
- Pill "element changed" is computed in the browser (MutationObserver on #app-container and the region), by matching stored element_text and breadcrumb.
