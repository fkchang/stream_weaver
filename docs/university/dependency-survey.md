# Dependency & Setup Surface Survey

Read-only survey for a future `streamweaver get-started` command that verifies/installs
dependencies for a newcomer on a fresh Mac, and degrades gracefully on Linux/Windows.
Companion to `docs/university/roadmap.md` and `docs/university/capability-inventory.md`.

## 1. Dependency summary table

| Dependency | Required / Optional | Platform | Where declared / used | Notes |
|---|---|---|---|---|
| sinatra, sinatra-contrib | required | any | `stream_weaver.gemspec:38-39` | web framework |
| phlex | required | any | `stream_weaver.gemspec:40` | view layer |
| puma | required | any | `stream_weaver.gemspec:41` | server |
| rackup | required | any | `stream_weaver.gemspec:42` | server |
| kramdown, kramdown-parser-gfm | required | any | `stream_weaver.gemspec:43-44` | markdown |
| ostruct | required | any | `stream_weaver.gemspec:45` | Ruby 3.5+ compat |
| diffy | required | any | `stream_weaver.gemspec:52` | DiffBlock |
| **iterm2_ruby** | **optional** | **macOS only** | not in gemspec (deliberately) | see [1] below |
| `open` (BSD) | required for browser auto-launch | macOS | `iterm.rb:39`, `service_client.rb:35`, `cli.rb:1060`, `server.rb:1064` | |
| `xdg-open` | required for browser auto-launch | Linux | `service_client.rb:37`, `cli.rb:1062`, `server.rb:1066` | |
| `start` | required for browser auto-launch | Windows | `service_client.rb:39`, `cli.rb:1064`, `server.rb:1068` | via `system('start', url)` |
| `osascript` | optional (terminal-focus convenience) | macOS only | `cli.rb:2159` | see [2] below |
| `iterm2ctl` (bin from iterm2_ruby gem) | optional | macOS only | not called from this repo's `lib/`; only from `~/work/claude_code_history` worker-session tooling | see [4] below — outside this gem |
| `herdr` socket/CLI | optional | any (Forrest's personal tool) | not in this repo; used by `/worker-session` | see [4] below |

**[1] `iterm2_ruby`** — Not a gemspec runtime dependency by design (`stream_weaver.gemspec:46-50`, comment explicitly states it is optional so `StreamWeaver::ITerm` degrades gracefully). Required by `lib/stream_weaver/iterm.rb:85` (`require "iterm2"` inside `check_availability`, rescued as `LoadError` → `false`). Availability gating in `iterm.rb:78-89`: only even attempts the require when host OS matches `darwin` (`iterm.rb:79`) and `ENV['ITERM_SESSION_ID']` is set (`iterm.rb:83`), i.e. only inside a live iTerm2 session on macOS — this also avoids spawning the gem's Python-API subprocess unnecessarily. Setup needed for `iterm2_ruby` itself (per `~/work/iterm2_ruby/README.md:67-69`): macOS + iTerm2 installed, Ruby >= 3.1, and iTerm2's own **Preferences > General > Magic > Enable Python API** toggle switched on — no separate Python venv needed (the gem's own README says "No external WebSocket gems required" and does not mention a Python dependency for the Ruby side; iTerm2's built-in Python API server is what it talks to over its own socket). No install script/launcher is provided by this repo; the only guidance is `gem install iterm2_ruby`.

**[2] `osascript`** — `lib/stream_weaver/cli.rb:2159`, inside `self.focus_terminal`, used to bring the terminal back to front after the browser auto-closes; runs an AppleScript block checking `System Events`/iTerm2/Terminal.app. Gated behind `RbConfig::CONFIG['host_os']` matching `/darwin|mac os/` (`cli.rb` case statement just above `2148`, see `2143-2165` range) — no-ops elsewhere.

## 2. `iterm2_ruby` — error handling / messaging when missing

- `ITerm.available?` (`iterm.rb:11-14`) memoizes `check_availability`, which returns `false` on `LoadError` (`iterm.rb:87-88`) — every downstream `ITerm` call (`split_vertical_with_url`, `close_pane`, `split_vertical_with_command`, `navigate_browser`) short-circuits to a `false`/`nil`/no-op return, so nothing raises.
- `split_vertical_with_url` (`iterm.rb:31-44`) falls back to `system("open", url)` (the plain macOS opener) when the pane split isn't available and `open_browser: true` — this is the "degrade to system browser" path referenced in the gemspec comment.
- The one place StreamWeaver actively *tells the user* the gem would help: `ITerm.gem_missing?` (`iterm.rb:20-27`) is true only when **not** available, **is** macOS, and **is** inside an iTerm2 session (`ENV["ITERM_SESSION_ID"]` present) — i.e. the one case where installing the gem is actually actionable. Consumed at `lib/stream_weaver/cli.rb:1921-1922`:
  ```
  if ITerm.gem_missing?
    puts "(Tip: `gem install iterm2_ruby` to open canvases in an iTerm split pane)"
  end
  ```
  This hint was added in commit `a5c5571` ("feat(cli): hint 'gem install iterm2_ruby' when split-pane would help"); the gem was made optional (not a runtime dep) in `12d76b5` ("fix(gem): make iterm2_ruby an optional enhancement, not a runtime dep"), then pinned to the published RubyGems version in `c3dfaf7`. Full history: `git log -S 'iterm2_ruby' --oneline` shows 12 touching commits from the original hand-rolled-AppleScript replacement (`58866e3`) through the current optional-gem state.
- Docs mentioning setup gotchas: `docs/claude-code-companion-skill-spec.md:24` ("StreamWeaver's `iterm.rb` uses the `iterm2_ruby` gem to: split pane, open browser pane, keep it persistent"); `docs/university/capability-inventory.md:70` and `:132` (corrects stale session-memory that referenced a nonexistent `bin/iterm_split_browser.py` — the real mechanism is `lib/stream_weaver/iterm.rb` + the optional gem, invoked via `streamweaver panel`); `docs/university/roadmap.md:36` proposes (not yet built — status `[loose]`) a future `streamweaver university` command that "checks `iterm2_ruby` gem (prompts if absent)."

## 3. `streamweaver setup` subcommand (`lib/stream_weaver/cli.rb:2095-2133`, `self.setup`)

Currently a two-step, Claude-Code-specific bootstrap — **it does not touch `iterm2_ruby` at all**:

1. **Bash permission**: reads (or creates) `~/.claude/settings.json`, ensures `permissions.allow` contains `'Bash(streamweaver *)'`, writes it back pretty-printed (`cli.rb:2098-2118`).
2. **Skill install**: calls `install_skill(['--global'])` (`cli.rb:2121`) — see §3 below for what that installs and where.

No dependency checks (no Ruby version check, no `iterm2_ruby` check, no browser-opener check) and no cross-platform branching — it unconditionally writes to `~/.claude/settings.json`, which only makes sense for a Claude Code user. This is the gap a `get-started`/`streamweaver university` command would need to fill; `docs/university/roadmap.md:36` sketches exactly that (story `university-door-command`).

**Update (get-started-door-command, shipped):** the gap above is now closed — `streamweaver get-started` (`CLI.get_started` in `cli.rb`) wraps `setup`, adds the Ruby-version/canvas-bridge/agent-skill/premier-iTerm2 dependency report this section describes, and pushes the `university` canvas session.

## 4. `streamweaver install-skill` (`lib/stream_weaver/cli.rb:2039-2091`, `self.install_skill`)

Yes — **Codex is supported today**, alongside Claude Code and (per the printed help text) Gemini CLI and GitHub Copilot, via a single cross-tool alias directory. Two target roots, chosen by `--global`/`-g`:

| Tool | Global path | Project path |
|---|---|---|
| Claude Code | `~/.claude/skills` (`cli.rb:2043`) | `.claude/skills` (cwd) |
| Codex / Gemini CLI / Copilot alias | `~/.agents/skills` (`cli.rb:2044`) | `.agents/skills` (cwd) |

Behavior:
- `streamweaver-panel.md` (inline `SKILL_CONTENT`, a flat `.md` with no frontmatter) is written **only** to the Claude-Code path (`cli.rb:2049-2052`) — explicitly noted as "not SKILL.md-spec-compliant, so Claude Code only."
- Four gem-sourced, spec-compliant skills (`streamweaver-visual-companion`, `streamweaver-doc-builder`, `streamweaver-way`, `streamweaver-canvas-safe`; `cli.rb:2057-2062`) are symlinked — **whole directory, not just SKILL.md** (fixed in the commit tagged `stream_weaver-5fyf` per the comment at `cli.rb:2064-2067`, so sibling `examples/`/`references/` content stays reachable) — into **both** `claude_dir` and `agents_dir` (`cli.rb:2069-2076`).
- Printed summary explicitly documents the Codex path (`cli.rb:2088-2090`): "Also installed to `#{agents_location}` — the cross-tool alias Codex CLI, Gemini CLI, and GitHub Copilot all discover natively (Claude Code uses its own path above instead)."

**Tested?** Yes, partially — `spec/cli_install_skill_spec.rb:38-39` has a test asserting the `.agents/skills` symlink is created for `streamweaver-canvas-safe`. No test found asserting Codex itself discovers/loads from that path (that would require a real Codex CLI invocation, out of scope for this repo's spec suite).

**Caveat vs. Codex's own conventions**: `docs/reference/agent-skills-comparison.md:16` documents that Codex actually looks in `~/.agents/skills/` (user), `$REPO_ROOT/.agents/skills/` (repo-root), `$CWD/.agents/skills/` (working dir), **and** historically `~/.codex/skills/`, plus an admin-level `/etc/codex/skills/`. StreamWeaver's installer only ever writes to `~/.agents/skills` or `<cwd>/.agents/skills` — it does not also mirror into the legacy `~/.codex/skills/` path, so a Codex install expecting the legacy path specifically would miss it (the modern `.agents/skills` convention is covered).

## 5. `/worker-session` skill — dependency chain

Location: `~/.claude/skills/worker-session/SKILL.md` (single file, no sibling `references/`/`examples/`).

The skill itself is a thin dispatcher: it resolves `--dir`/`--task`/`--model`/`--session-name`/`--mode` and shells out to:

```
~/work/claude_code_history/bin/worker-session --dir <dir> --task-file <path> [--model][--name][--mode]
```

That script (`bin/worker-session`) requires `../lib/worker_session_launcher` (`ClaudeCodeAnalyzer::WorkerSessionLauncher`), which chains to:

| Dependency | Type | Used for |
|---|---|---|
| `ENV['HERDR_PANE_ID']` / `ENV['TERM_PROGRAM']` | env inspection | detects calling terminal (`:herdr` vs `:iterm` vs `:unknown`) — `worker_session_launcher.rb caller_terminal` |
| `TerminalAdapter::HerdrAdapter` (`herdr_adapter.rb`) | Ruby class, shells to `herdr` CLI | when caller is inside a herdr pane: `herdr api snapshot`, `herdr tab create --cwd ... --label ... --focus`, `herdr pane run <pane_id> <command>`, `herdr tab focus <tab_id>` — all via `IO.popen(['herdr', *args], ...)` |
| `herdr` socket | file existence check | `HerdrAdapter.detected?` checks `~/.config/herdr/herdr.sock` exists before considering herdr "running" |
| `iterm2ctl` (from the `iterm2_ruby` gem's `bin/`) | external binary, `IO.popen` | when caller is plain iTerm (not herdr): `iterm2ctl create tab`, `iterm2ctl send-text <session_id> <text>` — `worker_session_launcher.rb run_iterm2ctl` |
| `claude` CLI | shelled-out command | the actual command sent into the new pane/tab (`build_command`, prefixes with `--model`/`-n`/`--permission-mode` as given) |

So the full external chain for `/worker-session` is: **herdr** (socket + CLI, optional — only when inside a herdr pane) **or** **iterm2ctl** (binary shipped by the `iterm2_ruby` gem, optional — only when inside plain iTerm and not herdr) → **claude** CLI itself. None of this lives in the `stream_weaver` repo — it's entirely in `~/work/claude_code_history` (personal tooling), invoked by a global skill, not a repo-local one. Not a dependency of the `stream_weaver` gem or its `get-started` surface, but flagged since it was in scope of the ask.

## 6. Platform-specific shell-outs in `lib/` and `exe/`

All `osascript` / `system(...)` / backtick invocations found (excludes comments and non-shell backtick usage in prose, e.g. inline-code markdown in comments):

| Call | File:line | Platform gate | Purpose |
|---|---|---|---|
| `system("open", url)` | `lib/stream_weaver/iterm.rb:39` | none explicit (only reached after `available?` macOS/iTerm gate upstream) | fallback browser open when pane split unavailable |
| `system('open', url)` | `lib/stream_weaver/service_client.rb:35` | `when /darwin/` | browser open |
| `system('xdg-open', url)` | `lib/stream_weaver/service_client.rb:37` | `when /linux/` | browser open |
| `system('start', url)` | `lib/stream_weaver/service_client.rb:39` | `when /mswin\|mingw\|cygwin/` (Windows) | browser open |
| `system('open', url)` | `lib/stream_weaver/cli.rb:1060` | `when /darwin\|mac os/` | browser open |
| `system('xdg-open', url)` | `lib/stream_weaver/cli.rb:1062` | `when /linux/` | browser open |
| `system('start', url)` | `lib/stream_weaver/cli.rb:1064` | `when /mswin\|mingw\|cygwin/` | browser open |
| `system('osascript', '-e', script)` | `lib/stream_weaver/cli.rb:2159` | `when /darwin\|mac os/` (`self.focus_terminal`) | refocus terminal after browser auto-close |
| `system("open", url)` / `system("xdg-open", url)` / `system("start", url)` | `lib/stream_weaver/server.rb:1064,1066,1068` | same three-way OS case | browser open (server-side variant) |

All three OS-specific browser-open call sites (`service_client.rb`, `cli.rb`, `server.rb`) implement the same `open`/`xdg-open`/`start` fallback triad independently — i.e. this logic is duplicated three times rather than factored into one shared helper. No `Process.spawn`/`Open3`/other shell-out patterns found for anything beyond these two purposes (browser-open, terminal-refocus) and the `iterm2ctl`/`herdr` calls covered in §5 (which live outside this repo).

## 7. Skill packaging levels (private/team/world) — not found

Grepped `docs/` and `~/work/cultiv-ai/wiki` for "world" near "skill"/"packag": no hits describing a private/team/world skill-packaging tier scheme. The only adjacent material is `docs/reference/agent-skills-comparison.md:112`, which notes Claude Code has no equivalent to Codex's "plugin packaging layer (distributable bundles of multiple skills + MCP config)" — a different axis (bundling, not visibility/audience tiers). If a private/team/world scheme exists, it isn't documented in this repo or in the cultiv-ai wiki index as of this survey.
