# share-to-gist — Epic Context

## Origin / lineage

Requested by Forrest (2026-08-31) via `/plan`: the canvas's Save-as-doc button covers
"save for myself" (repo/global, rb/org) but not "bounce this off a coworker before I
commit to it." The full design plan (trilaws walkthrough, UX rationale for every
decision below) lived in that planning session's local Claude Code plan file, which is
not part of this repo and is not guaranteed to still exist — the five scenarios above
plus this file carry everything needed to rebuild the feature without it.

Decisions locked during planning (do not re-litigate without going back to Forrest):
- Gist is a **third radio in the existing Save-as-doc dialog**, not a new button/surface.
- Every gist publish carries **both** `.org` (renders as a formatted doc on GitHub — the
  point of sharing) and `.rb` (re-runnable source of truth) in **one** `gh api` call, so
  one save = one gist revision.
- Default visibility: **secret**. Never send `public` on create; **never send `public` on
  a PATCH** — gist visibility is immutable after creation.
- **Phase 1 only.** "Restore from a past revision" is designed (see Deferred below) but
  explicitly NOT a story in this epic.

## Why doc-history is free

Every GitHub gist is a git repo. `<gist_url>/revisions` already serves the full diff
timeline with zero code from us — that's the entire answer to "Diego says the previous
version was better." The widget just needs to link to it. Locally, `Canvas::History`
(`lib/stream_weaver/canvas/history.rb`) already autosaves every push to
`~/.streamweaver/history/<session>/` with 7-day retention, so nothing is ever
only-in-the-gist.

## Prerequisite already confirmed (do not re-check)

`gh` 2.65.0 is on PATH, authed as `fkchang`, token scopes `gist, read:org, repo`. No new
auth setup needed. `gh gist create`/`gh gist edit` were considered and rejected in favor
of raw `gh api -X POST/PATCH /gists` — the `gist` subcommands can't put two files into one
call cleanly across create-vs-update, and `gh api` gives direct control over `public` (only
settable on create) and the exact JSON payload.

## File map (from exploration, verified current at planning time)

- `lib/stream_weaver/canvas/save_doc_widget.rb` — shared Alpine dialog, both call sites render through here
- `lib/stream_weaver/canvas/bridge_server.rb:144-200` — live canvas `POST /canvas/:name/save-doc`; `:310-336` the widget call site
- `lib/stream_weaver/canvas/reader.rb:583-639` — canvas-read's `POST /save-doc` (history-snapshot promotion)
- `lib/stream_weaver/views/canvas/reader_layout.erb:572-599` — reader's widget call site (is_history-gated)
- `lib/stream_weaver/canvas/doc_store.rb` — the atomic-write/normalize_name/ENV-override pattern every new module mirrors
- `lib/stream_weaver/org/writer.rb` — DSL -> org text + coverage; reused as-is, not modified
- `bin/browser_smoke:100-104` — the in-repo `Open3.capture3` wrapper pattern to follow (array argv, no shell string, exception on non-zero exit)
- `spec/canvas/bridge_save_doc_spec.rb` — the `Dir.mktmpdir` + ENV `around`-hook rack-test idiom every new spec follows
- `spec/canvas/canvas_action_parity_spec.rb` — exists precisely to catch bridge/reader drift; extend it rather than duplicating its intent

## Collision surface / sequencing

- `gist_store.rb`, `gist_publisher.rb`, and `save_doc_widget.rb` are three disjoint files
  with no dependency on each other — parallelize these three (worktree-safe).
- `bridge_server.rb`'s `POST /canvas/:name/save-doc` handler depends on all three (needs
  `GistStore`/`GistPublisher` to exist and the widget's new `gist:` kwarg contract settled)
  — SERIAL, after the three above land on main.
- `reader.rb` + `reader_layout.erb` mirror the bridge's now-settled pattern and are touched
  by `canvas_action_parity_spec.rb` alongside `bridge_server.rb` — SERIAL, after the bridge
  story, on main (disjoint files from bridge_server.rb, but the parity spec is the reason
  to keep it sequential rather than a false-parallel worktree).

## Cross-cutting constraints

- No spec may touch the real network or shell out to a real `gh` — `gist_publisher_spec.rb`
  stubs `Open3.capture3`.
- Gist visibility is immutable after creation: `public` must never appear in a PATCH payload.
- A `GistStore.record` write failure must never fail an otherwise-successful gist publish —
  degrade to a `warning:` string, mirroring how `DocStore.save`'s own `DocRoots.record`
  failure is already swallowed (`doc_store.rb:151`).
- Manual end-to-end verification must space out `gh` calls — GitHub's abuse detection has
  auto-deleted throwaway gists mid-session under rapid scripted traffic before
  (`feedback_gist_verification_abuse_detection.md`). One real create + one real update is
  enough; delete the gist (`gh gist delete <id>`) when done.
- Repo hygiene: no `/Users/...` paths in committed content; this file's plan-path reference
  above is the one deliberate exception (session-local breadcrumb, not committed content
  meant for the public repo — reconsider before the public-repo flip in epic `stream_weaver-b9g`).

## Deferred / not in scope (Phase 2, designed not built)

Restore-from-revision: `gh api gists/<id>` returns `history[]` (version sha +
committed_at); `gh api gists/<id>/<sha>` returns that revision's file contents. A revision
picker in the Gist pane could pull a chosen past `.rb` back into the live canvas via the
existing push path. Safe to build on top of (`Canvas::History` autosaves every push) but
it's a destructive write to live content needing its own story + confirm step. Ship Phase 1
first and let it reveal whether the plain Revisions link is already enough.
