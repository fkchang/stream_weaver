# canvas-read: StreamWeaver DSL Viewer

**Date:** 2026-04-26
**Status:** Approved for implementation

## Summary

A standalone viewer for StreamWeaver canvas DSL files — `streamweaver canvas-read`. You point it at one or more `.rb` files or a directory and it opens a browser with a left sidebar file tree and a right pane that renders the DSL. Like markymark but for canvas DSL instead of markdown.

## Problem

Planning sessions generate multiple canvas DSL documents (e.g. `/tmp/arch-v1.rb`, `/tmp/arch-merged.rb`). There is no way to browse or replay them without manually re-running `canvas-push` for each one. The canvas bridge is a live push target, not a viewer.

## Design

### CLI

```
streamweaver canvas-read <file|dir> [file|dir ...]
```

Examples:
```bash
streamweaver canvas-read /tmp/
streamweaver canvas-read doc1.rb doc2.rb
streamweaver canvas-read /tmp/ ~/projects/arch/plan.rb
```

- If a directory is given, scans it for `*.rb` files (non-recursive by default)
- If no files resolve, exits with a clear error
- Starts a local Sinatra server, opens the browser (iTerm2 split pane or system fallback), then blocks until Ctrl-C

### Server

A new `CanvasReader` Sinatra app (`lib/stream_weaver/canvas/reader.rb`), structurally parallel to markymark's `ServerSimple`:

| Concern | Approach |
|---|---|
| Port | `find_available_port(4800)` — well above app range |
| File list | Built at startup from CLI args; held in class-level state |
| Rendering | Eval DSL file in a blank `StreamWeaver::App` context, call existing HTML renderer |
| Active file | Tracked via URL param `?file=<index>` |
| Browser open | Reuse existing `StreamWeaver::Iterm` / system browser logic |
| Shutdown | Ctrl-C; no PID file needed (foreground process) |

### Browser Layout

```
┌──────────────┬────────────────────────────────────┐
│  📁 /tmp     │                                    │
│    arch-v1   │   < rendered DSL content >         │
│  ▶ arch-v2   │                                    │
│              │                                    │
│  📁 ~/proj   │                                    │
│    plan      │                                    │
└──────────────┴────────────────────────────────────┘
      ◀ prev         1 of 3         next ▶
```

- Left sidebar: directories as collapsible accordion sections (same pattern as markymark)
- Active file highlighted
- Bottom bar: prev/next buttons + "N of M" counter
- Keyboard: ← → arrows navigate between files
- Clicking a sidebar entry or nav button does a full page navigation (`?file=N`) — no JS state management needed

### Routes

| Route | Purpose |
|---|---|
| `GET /` | Redirect to `?file=0` |
| `GET /?file=N` | Render file N; sidebar with active state |
| `GET /health` | Liveness check |

### Rendering Pipeline

```
CLI arg (path) → File.read → eval in DSL context → component tree → HTML string → embedded in layout ERB
```

The DSL eval reuses `StreamWeaver::Canvas::Bridge#render_dsl` (or its extracted helper) — same code path the bridge uses, called synchronously. DSL errors are caught and shown as a red error panel in the right pane instead of crashing the server.

### File Discovery (directory mode)

- `Dir.glob("#{dir}/*.rb")` — top-level only
- Sorted alphabetically within each directory group
- Files grouped by their parent directory for sidebar accordion sections

### Multi-directory sidebar

When files span multiple directories each directory is its own accordion section, mirroring markymark's `group_files_by_directory` pattern. Root-level files (passed directly, no common parent) go under a `📄 Files` section.

## What This Is Not

- Not a replacement for `canvas-push` (live agent output)
- Not persistent — no bookmarks, no server PID file, no state between runs
- No live reload on file change (that's a future enhancement)
- No authentication, no multi-user

## Files

| File | Purpose |
|---|---|
| `lib/stream_weaver/canvas/reader.rb` | Sinatra app + file list management |
| `lib/stream_weaver/canvas/reader_layout.erb` | HTML layout with sidebar + content pane |
| `lib/stream_weaver/cli.rb` | Add `canvas-read` command dispatch |

## Success Criteria

1. `streamweaver canvas-read /tmp/` opens a browser, renders the first `.rb` file found
2. Clicking a filename in the sidebar renders that file in the right pane
3. ← → keyboard nav works
4. Files from two different directories show as two accordion groups
5. A DSL file with a syntax error shows a red error panel, not a 500
6. Ctrl-C stops the server cleanly
