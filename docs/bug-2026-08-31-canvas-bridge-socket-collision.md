# BUG: two canvas bridges racing for one hardcoded socket path - the later one silently wins, the earlier one goes unreachable

**Status:** open, worth a dedicated look
**Severity:** medium - not exploitable, but it's a silent-misroute waiting to happen: a push intended for one
bridge lands on a completely different one with no error
**Filed:** 2026-08-31, from an agent task in billing_engine that needed to push an edited doc to a specific
one of two live bridges (ports 4700 and 4701) and confirmed the wrong one received it
**Area:** canvas bridge (`bridge_server.rb#start_unix_socket_server`, `#write_pid_file`) /
`canvas/client.rb` (hardcoded `SOCKET_PATH` / `PID_FILE_PATH`) / `cli.rb#canvas_push`

## Symptom

`StreamWeaver::Canvas::Client::SOCKET_PATH` and `PID_FILE_PATH` are process-wide constants
(`~/.streamweaver/canvas.sock`, `~/.streamweaver/canvas.pid`), overridable only via
`STREAMWEAVER_CANVAS_SOCKET` / `STREAMWEAVER_CANVAS_PID` env vars. When two `BridgeServer.run!` processes
start on the same machine without those env vars set (e.g. two independent `streamweaver panel` sessions on
different ports), both call `start_unix_socket_server`, which unconditionally does
`File.delete(socket_path) if File.exist?(socket_path)` then binds a fresh `UNIXServer` at that same path -
and both call `write_pid_file`, which unconditionally overwrites the pid file. Whichever process starts
**later** wins: it deletes the earlier process's live socket out from under it and overwrites the pid file
to point at itself. There is no check for "is this socket already owned by a live process" - it's a bare
delete-and-rebind race, not a refusal.

`canvas-push` (`cli.rb#canvas_push` -> `Canvas::Client.send_message`) always connects via the default
socket path, with no `--socket` / `--port` selector. So once the race resolves, **every** `canvas-push`
call - regardless of which bridge's URL the user is actually looking at - goes to whichever process won,
silently. The loser keeps serving HTTP on its own port, but its Unix-socket listener is orphaned: its
sessions become permanently unreachable for pushes until it's restarted, with no error surfaced anywhere.

## Evidence

Two `puma` processes observed live: pid 58524 on port 4700 (started 00:31:09), pid 58674 on port 4701
(started 00:31:15, six seconds later). `~/.streamweaver/canvas.pid` read `pid=58674\nport=4701` - the
later process. `lsof -p <pid>` on both showed 58674 holding the listening end of
`~/.streamweaver/canvas.sock` (multiple accepted connections), while 58524 held a single stale fd to the
same path with nothing actually listening on its behalf.

Confirmed behaviorally, not just via lsof: `curl http://localhost:4700/health` and
`curl http://localhost:4701/health` returned two **different** session lists (4700: 3 sessions; 4701: 15
sessions - each bridge's own independent in-memory session store, as expected for two separate processes).
A `canvas-push pm-discount-eng-brief` (default socket, no override) landed its new content on port 4701's
session, confirmed via `/canvas/:name` page-content diff before/after the push and via `/canvas/:name/poll`
returning empty `html` for port 4700's same-named session throughout - it had been structurally empty since
6 seconds after boot, because it never got a chance to receive a single push.

## Why it matters

1. **Silent misroute, not a failure.** `canvas-push` exits 0 and prints `Pushed to <name>` regardless of
   which bridge actually received it. A user (or an agent) watching a specific port's browser tab has no
   signal that their push went somewhere else.
2. **Data can land on the wrong session store.** In the observed case, a bridge deliberately kept separate
   for parked reference copies (many unrelated sessions) received a push meant for a different, narrower
   working bridge - purely because of six seconds of startup ordering, nothing about intent.
3. **Gets worse with GEA-style concurrency.** Multiple simultaneous `streamweaver panel` sessions (Forrest's
   normal 20+-concurrent-session operating mode) make this race routine, not an edge case.

## Suggested fix

- Derive the socket path (and pid file path) from the bridge's own port by default, e.g.
  `~/.streamweaver/canvas-<port>.sock` / `canvas-<port>.pid`, instead of one shared hardcoded path across
  every bridge process on the machine.
- Add a `--socket PATH` / `--port PORT` selector to `canvas-push` (and any other CLI command that talks to
  a bridge) so a caller can address a specific bridge unambiguously instead of always hitting "whatever the
  default socket currently resolves to."
- Make `start_unix_socket_server` refuse to start (or at least warn loudly) when the target socket path is
  already owned by a live process, rather than deleting and rebinding over it. A stale socket (owning
  process dead) should still be reclaimed - the current stale-cleanup behavior is fine - but a **live**
  owner should not be silently evicted.

## Acceptance criteria for a fix

- Two bridge processes started on different ports, with no env override, do not collide: both remain
  independently reachable for `canvas-push` for the lifetime of both processes.
- `canvas-push` against a specific bridge (via its new selector, or by construction once sockets are
  per-port) always lands on the session store of the bridge the caller intended, demonstrable with the same
  two-bridge shape observed here.
- Starting a second bridge that WOULD collide under the old scheme either binds its own distinct socket
  automatically, or fails fast with a clear message - never a silent takeover.

## Provenance

Observed live during a billing_engine doc-editing task (`pm-discount-eng-brief` canvas session), 2026-08-31.
Diagnosed via `/health` and `/canvas/:name/poll` diffs across ports 4700 and 4701, pids 58524 and 58674.
