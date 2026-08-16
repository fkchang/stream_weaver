# Canvas doc location & discovery — design (v2, right-sized)

**Status:** design proposal, not yet implemented. No code written.
**Date:** 2026-08-15
**Related:** epic `stream_weaver-mdc`, issue `stream_weaver-e13` (shared Save-as-doc widget).
**Supersedes:** v1 of this document (same filename, prior content), which in turn superseded Workstream 4 of `~/.claude/plans/mossy-tinkering-sunset.md`.

---

## 0. Why this version is much smaller

v1 designed a `DocIndex` registry: a JSON file at `~/.streamweaver/docs.json` tracking arbitrary saved-to directories across arbitrary repos, with flock/atomic-write/corruption-recovery, a backfill/scan CLI, label propagation, stale-root pruning, and session-sticky defaults. That's real, reviewed work — and it's solving a more general problem than the one that actually exists.

The user's own read, correctly: **it's scoped more than it needs to be.** Two changes collapse almost the entire registry apparatus:

1. **A file browser in `canvas-read`** answers "point me at a doc saved elsewhere" directly, live, with no index — you navigate to it. An index only earns its keep when *discovery* requires remembering *many* arbitrary locations. A live filesystem browse doesn't need anything remembered at all.
2. **A binary save choice — global vs. this repo** — replaces "arbitrary path with a datalist of every repo you've ever used." There are now only ever two non-history locations a doc can be in, and both are deterministically computable from `Dir.pwd` with zero persisted state. `canvas-read`'s "no-args default" becomes a union of two known paths, not a registry lookup.

What's lost, honestly: no unified "show me every doc I've ever saved across every repo" view without browsing to each one. That capability was the entire point of `DocIndex`, and it's the piece being deliberately cut. If that turns out to matter later, v1's design is sitting in git history / this file's predecessor — nothing about v2 forecloses building it. But there is no evidence yet that it's needed, and Pareto says don't build the registry until the two-location model actually proves insufficient.

---

## 1. Part A — file browser in `canvas-read`

### 1.1 What it does

A live, read-only filesystem browse view inside the already-running reader — the thing that's actually missing today. `canvas-read` already renders *any* file or directory you hand it as a CLI arg; the gap is purely that once it's running, you're stuck with what you started it with. Restarting the process with a new path is the whole friction.

### 1.2 Routes

- `GET /browse?dir=<abs path>` — lists immediate subdirectories and `*.rb` files under `dir`. Renders breadcrumbs (each path segment clickable, jumps to that ancestor) and two quick-jump shortcuts pinned at the top: **This repo** (`DocStore.git_root(Dir.pwd)`, hidden if not in a repo) and **StreamWeaver (global)** (`DocStore::DEFAULT_ROOT`). Defaults to `$HOME` if `dir` is omitted or invalid.
- `GET /open?path=<abs path to .rb file>` — renders that one file directly through `Reader.render_doc`, completely independent of `FileList`/`docs_groups`/`history_groups`. This is what makes browsing not need an index: viewing a browsed file was never routed through a precomputed list in the first place.
- A "Browse…" entry in the nav rail, above the existing docs/history sections, opens `/browse` in place of the current sidebar content (or as a distinct mode — see 1.4).

### 1.3 Validation and the security boundary — corrected during implementation

- `dir`/`path` must resolve (via `File.expand_path`) to something that exists; `resolve_browse_dir` falls back to `$HOME` on anything blank, relative-and-missing, or invalid (`~nosuchuser`, a null byte, a non-`String` param) rather than crashing.
- `/open` refuses anything not `File.file?` and ending in `.rb` — same guard the CLI arg path already has.
- **This section's original framing was wrong and was corrected during a review pass before shipping.** The claim was: "`127.0.0.1`-only + `canvas-read` already accepts arbitrary CLI paths today, so a browse UI is the interactive form of a capability that already exists, not a new trust boundary." That conflates two different things — a CLI arg is the user naming a file once, with intent; an HTTP GET is reachable from *any tab already open in the user's browser*, with no CSRF token required (`<img src="http://127.0.0.1:4800/open?path=...">` costs an attacker nothing), and `127.0.0.1`-binding only stops a *remote* client, not a local page's request. `/open` doesn't read the file, it `instance_eval`s it — this is a real code-execution surface, not a read primitive, and treating it as "not a new trust boundary" was the mistake.
- **Shipped instead:** a `before` filter on every route (not just Browse's) checking `request.host` (`127.0.0.1`/`localhost` only — closes the common case, though DNS rebinding can defeat it) and `Sec-Fetch-Site` (`same-origin`/`none`/absent only, rejecting `cross-site` and `same-site` — closes the rebinding gap, since it's set by the browser from the page's real origin and isn't spoofable from page JS). See `reader.rb`'s `before` block for the full reasoning.
- Filed as a follow-up, not fixed here: `bridge_server.rb` (the live canvas) has the identical `127.0.0.1`-only posture and several routes with real side effects (`save-doc`, `event`) with no equivalent gate yet (`stream_weaver-bzyt`).

### 1.4 UI integration

Simplest option, and the recommendation: browsing *replaces* the sidebar's file list while active, with a "← back to docs" link to return to the normal `docs_groups`/`history_groups` view. Avoids maintaining two simultaneous nav-rail states or a modal overlay. A user browsing to a doc in another repo, opening it, is now just looking at that file the same way any other doc renders — Prev/Next nav across the browsed directory's `.rb` files works for free if `/open` also accepts an optional `dir` context to compute siblings from (nice-to-have, not required for v1 of this feature).

### 1.5 What this explicitly does not do

No move/copy/delete. "Read a file anywhere" is a read capability; relocating a doc into a different repo is a plain `mv` on the command line, or a re-save with a different scope (§2) from within a live canvas session. Adding file management is a separate, bigger feature nobody asked for.

---

## 2. Part B — save location: global vs. this repo

### 2.1 The choice

`DocStore.path` already resolves to exactly one of two places — `<git_root>/docs/streamweaver_canvas` or `~/.streamweaver/canvas` (`DEFAULT_ROOT`, today's "no repo detected" fallback) — chosen automatically. The change: make that choice explicit and visible at save time instead of implicit and fixed.

```
Save canvas as doc

  Name       [ mailroom-incident-20260813-1543       ]

  Save to:   ◉ StreamWeaver (global)     ○ This repo (stream_weaver)

  → /Users/…/.streamweaver/canvas/mailroom-incident-20260813-1543.rb

                                     [ Cancel ]  [ Save ]
```

- Two radio buttons (or an equivalent toggle), not a picker — there are only two options, so a dropdown/datalist would be over-built for this.
- "This repo (`<name>`)" is disabled/hidden when the bridge's cwd isn't inside a git repo — nothing to target.
- The resolved absolute path renders live under the toggle, updating on click, before Save is pressed. This is the one line from v1 worth keeping regardless of everything else that changed: **visibility of the destination is what actually prevents the mistake**, not smarter defaults. Carried over unchanged from v1 §2b's finding.
- Success message shows the full absolute path and does not auto-dismiss on a timer (same v1 finding: the 1.8s auto-dismiss is why the wrong destination went unnoticed).

### 2.2 What StreamWeaver being a gem has to do with this

The user's own framing, and it's correct: since StreamWeaver is invoked from *any* repo, a save location tied to "whatever repo happens to be cwd" isn't really the tool's own default — it's an accident of where the bridge process was started. `~/.streamweaver/canvas` already exists for exactly this reason (the current no-repo fallback) — this change promotes it from "fallback when there's nothing better" to "a first-class, always-available choice," available even when a repo is present.

### 2.3 Default selection — open question, not resolved here

Two candidate defaults, both defensible:

- **(a) Preserve today's behavior as the default:** repo-local if in a repo, global otherwise. Least surprising relative to current behavior; the visibility fix (§2.1) is what catches a wrong guess, not a changed default.
- **(b) Default to global, always; repo-local becomes the deliberate opt-in.** Argued by tonight's own evidence: of the five canvas sessions actually saved this session (`session-harness-research`, `complete-session-doc`, `mailroom-incident`, `didx-arch-doc`, `audit0802`), effectively none were meant to be checked into `stream_weaver`'s own repo — they were investigation/reference docs that happened to be saved from a bridge running there. If that pattern is representative, "this repo" should be the thing you reach for on purpose, not the thing that happens unless you notice otherwise.

**Decided: (a).** Default stays repo-if-in-one, matching today's behavior — the visibility fix (§2.1's live resolved-path line) is what's doing the actual work of preventing a repeat of the incident, not a changed default.

### 2.4 Implementation

`DocStore.save(name, dsl, scope: :auto)` — new keyword, backward compatible (`:auto` = today's resolution, unchanged, so any caller that doesn't pass it keeps current behavior):

```ruby
def save(name, dsl, scope: :auto)
  root = case scope
         when :global then DEFAULT_ROOT
         when :repo   then git_root(Dir.pwd) or raise ArgumentError, "not inside a git repo"
         else path # today's env-override > repo > global resolution, unchanged
         end
  ...
end
```

Both save routes (`bridge_server.rb:141`, `reader.rb:204`) accept an optional `scope` in the JSON body and pass it straight through. The org-mode branch (`bridge_server.rb:154-176`, landed by a concurrent session tonight) calls `DocStore.save` too and gets this for free — no separate change needed there.

`stream_weaver-e13` (extract the duplicated ~120-line Save-as-doc widget out of `bridge_server.rb` and `reader_layout.erb`) is still the right precondition — two fewer places to add the same toggle to.

---

## 3. Part C — `canvas-read` default (no args)

With only two possible non-history locations, the union needs no stored state at all:

```ruby
def self.canvas_read_default_args
  repo_docs   = StreamWeaver::Canvas::DocStore.git_root(Dir.pwd) &&
                File.join(StreamWeaver::Canvas::DocStore.git_root(Dir.pwd), StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
  global_docs = StreamWeaver::Canvas::DocStore::DEFAULT_ROOT
  history_root = StreamWeaver::Canvas::History.root

  args = [repo_docs, global_docs].compact.select { |d| File.directory?(d) && Dir.glob(File.join(d, '*.rb')).any? }
  args.concat(Dir.glob(File.join(history_root, '*/')).map { |d| d.sub(%r{/\z}, '') }.sort)
  ...
end
```

Both roots get their existing label treatment for free — `reader_layout.erb`'s `File.basename(dir)` already produces `streamweaver_canvas` for the repo root (unhelpful with two roots present) and would do the same for the global root. Minimal fix: pass an explicit `labels: {repo_docs => repo_name, global_docs => "StreamWeaver"}` into `FileList.build` — a two-entry hash, not the label-propagation machinery v1 built for an arbitrary number of roots.

No `--here`/`--all` flag needed — with only two roots ever in play, both showing by default is not the noise problem N arbitrary repos would have been.

---

## 4. Migration

Nothing forced. The two mailroom docs sitting in `stream_weaver/docs/streamweaver_canvas/` right now stay exactly where they are — reachable today via `canvas-read`'s existing repo-docs default, and, once Part A ships, reachable from anywhere via Browse. If you decide either one belongs in `$ha` specifically, that's `mv` plus opening it once so it re-renders from the new path — no tooling needed for a one-off move.

---

## 5. Phasing

Both parts are independent and either can ship first.

- **Part A (file browser)** has no dependency on anything. Solves "point at a doc elsewhere" completely on its own, including for docs that will never go through a StreamWeaver save route at all (any `.rb` file, anywhere).
- **Part B (save toggle)** depends on `stream_weaver-e13` (widget extraction) as a precondition, same as v1 noted. Solves "don't land in the wrong place" going forward.
- **Part C (default-args union)** is a few lines, ships alongside B since it's what makes global saves show up without extra flags.

Given Part A alone solves the most urgent complaint ("how do I get to a doc saved elsewhere," right now, for docs that already exist), it's reasonable to build it first and independently, with B/C following once `stream_weaver-e13` lands.

---

## 6. Open questions

**OQ-1 — Default location bias (§2.3). Resolved: repo-if-in-one (today's behavior, unchanged).**

**OQ-2 — Prev/Next across a browsed directory.** Noted as a nice-to-have in §1.4, not required for v1 of Browse. Worth deciding if it's in scope now or later.

**OQ-3 — Does Browse need session-scoping later?** If StreamWeaver ever runs somewhere multi-user (unlikely for a local dev tool, but the repo is heading toward open-source release), an unauthenticated local file browser is a different risk posture than it is on a single-user laptop. Flagged, not blocking — `127.0.0.1`-binding already assumes single-machine, single-user today.
