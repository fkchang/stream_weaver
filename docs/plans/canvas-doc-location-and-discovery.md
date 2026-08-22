# Canvas doc location & discovery

**Status:** shipped (`stream_weaver-j3b3`).
**Related:** epic `stream_weaver-mdc`.
**History:** this file carried a lot of exploration that isn't needed anymore — a rejected `DocIndex` registry, a canvas-server-attach mechanism, an automatic silent-resolution design that a Codex review correctly rejected as over-scoped for a problem the user hadn't actually hit. See `git log -p -- docs/plans/canvas-doc-location-and-discovery.md` if any of that ever matters again. Not repeated below.

## Shipped

- File browser in `canvas-read` (navigate to any doc without restarting) — `stream_weaver-rdh`.
- Multi-repo discovery: scan + a lightweight append-only registry, so a doc saved anywhere shows up without manual registration — `stream_weaver-iugu`.
- Delete a saved doc from the sidebar — `stream_weaver-uvaj`.
- Atomic doc writes — `stream_weaver-5nvz`.

## The one real problem left (now fixed)

Docs save to the global store (`~/.streamweaver/canvas`) even when working in a repo, because `DocStore.save`'s automatic resolution asks "is the *server's* cwd a repo?" — meaningless once one canvas server outlives any single repo. Today the workaround is manually copying the file out of global into the right repo after the fact.

## Spec

- Every canvas push carries the directory it was pushed from. `Session` gets a `source_dir` attribute, set from `DocStore.git_root(Dir.pwd)` computed on the *pushing* side, not the server's own cwd. Updated on each successful push — expected to change as work moves between repos over a session's life. Guard: only update it on a push that actually succeeds, so it can't end up pointing at a different repo than the DSL it's paired with.
- Save-as-doc's dialog (already exists, both save routes) gets a visible toggle: **This repo** (`session.source_dir`, showing the resolved path) vs. **Global** — same choice already designed for Part B, just fed by the session's remembered directory instead of the server's own cwd. "This repo" is hidden when `source_dir` is nil.
- This is a manual choice, not automatic — you see the destination before you click Save, so there's no silent-redirect risk to design around.

## Not in scope here

Two things surfaced while investigating this that are real but unrelated — parking them, not building them now:
- Duplicate canvas/canvas-read instances (multiple ports for the same work) — annoying but not something actually hit yet; revisit if it becomes a real problem.
- A pre-existing race in the bridge's own boot sequence where a losing duplicate boot can delete a healthy sibling's PID/socket files — real bug, independent of everything above, filed separately at low priority (`stream_weaver-5tqz`).

## Beads

`stream_weaver-e13` (extract shared Save-as-doc widget — precondition, shipped) and `stream_weaver-j3b3` (`source_dir` + toggle, shipped). `stream_weaver-16fx` (attach-or-boot) deferred — needs materially more design than scoped, not blocking this.
