# Canvas doc: multi-repo view, delete, single instance

**Status:** design locked, ready to implement. No code yet.
**Related:** epic `stream_weaver-mdc`.
**History:** this file went through several rejected/superseded designs (a `DocIndex` registry, a two-location-only model) before landing here — see `git log -p -- docs/plans/canvas-doc-location-and-discovery.md` if that deliberation ever matters again. Not repeated below.

## The ask

1. One app shows both global and local (repo) saves — view all-local, all-global, or everything.
2. Launching the app from inside a repo defaults the filter to that repo's saves.
3. Delete button in the saves listing.
4. Launching the app attaches to an already-running instance (with the right filter) instead of starting a new one; only boots fresh if nothing's up.

## Spec

**Discovery (scan + lightweight registry).** A scan-of-fixed-parents-only misses real cases — a repo under `~/rails` or `~/src` that's not under the scanned parent never shows up. Two sources, unioned:
- **Scan**: `$STREAMWEAVER_DOCS_SCAN_ROOTS` (default `~/work`) one level deep for `*/docs/streamweaver_canvas`, glob `*.{rb,org}`. Catches repos under known parents automatically, including ones that arrived via `git pull` and were never saved-to or visited locally.
- **Registry**: `~/.streamweaver/docs_roots.log`, one absolute docs-root path per line, append-only (small appends are atomic on a local filesystem — no locking, no JSON, no labels/timestamps). Appended by (a) every `DocStore.save`, and (b) every `canvas-read <explicit path>` outside the scan roots — so visiting a pre-existing doc once is what backfills it, no dedicated migration command. Duplicate lines are harmless, deduped on read.
- Both filtered to `File.directory?` on every read (self-healing — a deleted/moved repo just drops off, no `.forget()` needed) and the global store (`DocStore::DEFAULT_ROOT`) always included as its own group.
- Key results by canonical root path, not basename (a basename-keyed hash would silently drop same-named repos from different roots — disambiguate the display label instead). No cache/TTL on the scan half — cheap at real repo counts; the registry read is a flat file, cheaper still. `STREAMWEAVER_DOCS_SCAN_ROOTS` entries get `File.expand_path`'d.

**Filter.** Sidebar groups by repo label + a "Global" group. `?repo=<label>` is the active filter, defaulting to the host process's own repo (`Reader.repo_docs_root`), one link to clear to "all."

**Delete.** `POST /delete-doc` in `reader.rb` only. Plain `File.delete` — no git shelling (an unstaged deletion in `git status` afterward is the intended outcome; committing it is on the user, same as deleting in Finder). Allowed only for the two roots the *host* process resolves at boot — `Reader.repo_docs_root` + `DocStore::DEFAULT_ROOT` — never a peer repo the scan surfaces, never Browse mode. Path check: `File.dirname(File.realpath(path)) == canonical_root` (equality on a canonicalized direct parent, not a `start_with?` prefix match — that would false-accept a sibling dir like `..._evil/`). Confirm via the existing dialog pattern, not JS `confirm()`. Deleting the open doc advances to the next surviving doc at the same position, else previous, else empty state.
  - *Known limitation, on purpose:* you can only delete a repo's own docs when that repo is the current host. A session attached to someone else's host can't delete a different repo's docs — narrower blast radius wins over full reach.

**Attach-or-boot.** Fixed well-known port for `canvas-read` (not today's auto-increment). On launch: hit a small identity route (`GET /__canvas_read__` → `{app: "streamweaver-canvas-read", protocol: 1}`); if it answers and matches, open the browser at `<url>?repo=<host's repo>` and exit — no new process bound. If nothing answers, boot as today, on the fixed port. If the port's held by something that doesn't match, fail with a clear message + `STREAMWEAVER_CANVAS_READ_PORT` override — never silently fall back to auto-increment. On `EADDRINUSE` from the real bind, re-probe the identity route once before giving up (covers two terminals launched the same second). Attach applies **only** to the bare no-arg invocation — an explicit file/dir arg or `--theme`/`--layout` always forces a fresh boot on its own auto-incremented port. No daemon: no fork-to-background, no PID file, no stop command. Whichever terminal is running it *is* the server; closing that terminal just means the next invocation boots fresh and becomes the new host.

**Also fixed while in here (pre-existing bugs, not new scope):**
- `SW_NO_OPEN` doesn't work for `canvas-read` today (`open_browser` never checks it) — wire it into both the boot and attach paths.
- `DocStore.save`'s `File.write` isn't atomic — switch to temp-file + `File.rename`, since the new per-render scan makes the read-during-write race far more frequent than it used to be.

**Explicitly declined** (found in review, not worth it here): hardening the delete path against a symlink-swap race between the realpath check and the delete (single-user local tool, out of the realistic threat model); requiring `Sec-Fetch-Site` to be present rather than just non-cross-site (would break legitimate local `curl`/script access without stopping a real browser-borne attack, which already carries the header); a cache/TTL for the scan (not slow at real repo counts).

## Beads

`stream_weaver-iugu` (scan + filter), `stream_weaver-uvaj` (delete), `stream_weaver-16fx` (attach-or-boot), `stream_weaver-5nvz` (atomic write). All under epic `stream_weaver-mdc`.
