# Worker-Session Mining: StreamWeaver University Live UAT

Source transcripts (read-only mining, session IDs only — full paths omitted):

| Session | Date | Duration | Steps covered |
|---|---|---|---|
| `9fc075bb` | 2026-08-31 | ~9 min | Step 1 (hello canvas), Step 2 (counter app) |
| `25b1a28c` | 2026-09-03 | ~1h45m (elapsed; most of the gap is between step 1 and step 2, likely the human stepping away) | Steps 1-5 (hello canvas, counter, radio_group form + canvas-wait, growing-doc, org-export + gist + extension) |

Only two worker sessions in the project's transcript directory matched the course signature
(`"Using stream_weaver, ..."` prompts). The coordinator session and several other large
transcripts were general StreamWeaver dev work, not course UAT, and were excluded.

## 1. User-customization collisions

| Collision | What happened | Course impact |
|---|---|---|
| `gstack /browse`-only rule vs. reflex reach for Chrome MCP | In `25b1a28c`, right after starting the counter app, Claude ran `ToolSearch` for `mcp__claude-in-chrome__*` tools, got an empty result, then self-corrected: *"I need to correct course — the repo's CLAUDE.md says to use the gstack `/browse` skill for web browsing, not `mcp__claude-in-chrome__*` directly."* | One wasted tool call + a visible reasoning detour per session. Self-corrected cleanly both times, but it's a repeatable tax the course prompts could pre-empt by naming the browser tool up front. |
| Headless-browser CLAUDE.md rule vs. "install the extension" course step | Step 5 in `25b1a28c` asks the agent to install a Chrome extension and compare rendering. Claude correctly identified that `gstack browse` is a disposable headless Chromium daemon with no access to the user's real, logged-in Chrome — so it can't install a Web Store extension or show its effect. It flagged this constraint honestly *before* attempting anything, then used `AskUserQuestion` with three options: (1) "You install it yourself (recommended)" — click the Web Store link in real Chrome, refresh, click "View rendered"; (2) "I attempt it in the headless browser anyway" — likely blocked, won't persist, but shows what happens; (3) "Skip it." | This is the biggest single collision: a course step that structurally requires a persistent, logged-in browser profile is incompatible with the project's headless-only browsing rule. The user picked "I have it installed, just open the page" (a fourth, unlisted answer), and Claude correctly explained *again* that it still can't reach the user's real Chrome from the headless daemon — it can only show the plain-GitHub view it already had. |
| Push-hook / git-push restriction | Not triggered in either session — neither worker committed or pushed. No evidence either way from these transcripts. |
| Skill auto-triggering | The `browse` skill's own preamble (gstack-update-check, session bookkeeping, proactive-mode check) ran automatically and correctly both times with no visible friction — this one helped, not hindered. |

## 2. Browser-control dependency

Every step from the counter app onward needed a browser to verify server-rendered UI (StreamWeaver's whole pitch is "no client JS," so verification means watching the DOM change after a real click). Both sessions reached for the same tool, in this order:

1. Reflexive attempt at `mcp__claude-in-chrome__*` tools (session `25b1a28c` only; `9fc075bb` went straight to `/browse`, suggesting the reflex is intermittent, not universal).
2. Self-correct (or start directly) with the gstack `browse` CLI: `goto`, `text`, `snapshot -i`, `click @ref`, `network`, `prettyscreenshot`.
3. For the counter/radio/growing-doc steps, `browse` fully sufficed — headless is enough to click a button and read the resulting text, and it worked cleanly except for one recurring quirk (below).
4. For the extension-install step, headless was a hard wall — no logged-in profile, no persisted extensions, no way to reach the user's real Chrome from the agent's side at all.

**What a user with no browser tooling would experience**: steps 1-4 of the course would fail outright, or fall back to a much weaker "trust me, curl showed the HTML changed" verification (both sessions actually did use `curl`/`grep` on the raw HTML as a first check before touching a browser at all, so a no-browser session isn't *totally* blind — it can confirm the server round-trip via `POST .../action/... → 200` and grep the returned HTML for the expected text). Step 5's extension comparison would be entirely unreachable without the user doing it by hand — which, as this UAT showed, is true even *with* the best browser tooling available in this repo (headless), since that step needs the user's own logged-in Chrome regardless.

**Recommended course phrasing**: state the browser dependency and the fallback explicitly, e.g.:
> "This step verifies UI state by reading the rendered page. If you have `claude-in-chrome`, `playwright-cli`, or a project `/browse`-style skill configured, use it to click through and confirm the count/text visually. If none of those are available, verify via `curl <url> | grep <expected text>` before and after the action, plus `POST .../action/... → 200` in the app's own log — that's sufficient to prove the DSL block re-ran server-side, just without a screenshot."

For the extension step specifically, the course should say up front: *"This step needs your own logged-in Chrome — no automated/headless browser tool can complete it, by design (Chrome blocks extension installs from automation, and a headless session has no access to your profile). Expect the agent to hand this step back to you."*

## 3. Good response patterns worth institutionalizing

| Pattern | Where | Why it landed well |
|---|---|---|
| Honest capability boundary + structured choice | `25b1a28c` step 5: named the exact constraint (headless daemon, no logged-in profile, Web Store blocks automated installs), then gave 3 concrete options with one-line tradeoffs each, rather than silently attempting and failing or silently skipping. | Textbook "surface the tradeoff, don't hide confusion" — the user could make an informed call in one turn. Worth turning into a named pattern (something like "capability-boundary AskUserQuestion") for any course step that touches a resource the agent structurally cannot reach. |
| Mechanism-level counter explanation | Both sessions, step 2: after clicking the button, Claude didn't just report the count — it pulled the raw HTML (`hx-post="/action/btn_increment_..."`), then in `9fc075bb` explicitly ran `browse network` to show the real `POST .../action/... → 200` calls, concluding *"each click fires a real HTTP POST ... the server re-runs the app block ... no client-side JS holding the counter."* | This is exactly the pedagogical point of StreamWeaver (server-side re-execution, not client JS) proven with evidence, not asserted. The course's own step-2 prompt already asks for this ("that's the same DSL block re-running, not JavaScript") — Claude's response consistently over-delivered on it by showing the network trace unprompted. |
| Proactive location-mismatch flag | `25b1a28c` step 4: the saved doc landed at `~/.streamweaver/canvas/doc-demo-*.rb` instead of the course's assumed `docs/streamweaver_canvas/doc-demo.rb`, because the canvas bridge process (started in an earlier session) has a different cwd. Claude flagged this immediately and precisely ("likely because the canvas bridge process ... has a different working directory than this shell") rather than silently adjusting or failing later. | Saved the *next* course step from breaking silently — step 5's prompt hard-codes the `docs/streamweaver_canvas/doc-demo.rb` path, and Claude had already told the user it wouldn't be there. |

## 4. Friction/waste

| Issue | Sessions | Detail |
|---|---|---|
| Step-2 startup failure, two different causes | Both | `9fc075bb` (Aug 31): first draft of `app.rb` had no `.run!` — bare `app "Title" do...end` only builds the app, doesn't start the server; process exited immediately with no error, requiring several minutes of `lsof`/`ps`/source-diving to find `SinatraApp.run!`. `25b1a28c` (Sep 3): first draft was missing `require 'stream_weaver'` — hit `NoMethodError: undefined method 'app'` immediately, fixed in one turn by checking `streamweaver llm` and an example file. Same course step, same 6-line-app goal, two independent trial-and-error paths — evidence the "6 lines" framing in the prompt undercounts the two lines (`require` + `.run!`) that are structurally necessary but easy to omit. |
| Slow first-run discovery path | `9fc075bb` | Rather than checking `streamweaver llm` (which `25b1a28c` used immediately and successfully), this session dispatched an `Explore` subagent to grep the repo for the button/state DSL, then used `ScheduleWakeup` to poll it twice (90s, then 120s) before the result came back — roughly 90+ seconds of pure waiting that the Sep 3 session avoided entirely by running `streamweaver llm | grep -n -i state` directly. |
| `browse` "ambiguous selector" on ref-based clicks | `25b1a28c`, twice | Clicking a `@ref` returned from `snapshot -i` (not a CSS selector) twice failed with "Selector matched multiple elements. Be more specific or use @refs from 'snapshot'" — once on a radio button (`@e2`), once on a modal's Save button (`@e5`, which collided with a hidden "Saving..." `<span>` sharing structure). Both times Claude recovered by falling back to a hand-written CSS class selector (`.sw-save-doc-save`) found by grepping the raw HTML — a working but manual detour that cost 2-3 extra tool calls each time. |
| Redundant polling loops for background server startup | Both | Both sessions ran 2-3 rounds of `sleep N && cat task-output.log` waiting for the "server started" banner to flush, then fell back to `lsof`/`ps` to find the bound port because the banner never appeared in the captured output at all (output buffering, not a real failure). Worked, but ~6 tool calls per session spent on what should be a fixed, known port-discovery recipe. |
| Gist defaulted to secret | `25b1a28c` | `gh gist create` produced a **secret** gist (gh's default) even though the course step describes opening it and sharing/comparing rendering — Claude flagged this after the fact ("let me know if you wanted it public instead") rather than asking first or defaulting to `--public`. Not wrong, but a step that explicitly plans to open the gist URL and later compare it via a public-facing browser extension probably wants `--public` by default. |

## Recommended changes

### Course-prompt changes

- Step 2 (counter app): explicitly note the two "invisible" required lines — `require 'stream_weaver'` at the top and `.run!` chained onto the `app do...end` block — so the "6-line app" framing doesn't cost agents a debug cycle discovering both independently. Alternatively, point straight at `streamweaver llm`'s canonical counter example as the first move, before writing anything from memory.
- Step 5 (org-export + gist + extension): split into two explicit sub-steps with different expectations — (a) org-export + gist + view plain rendering, fully agent-completable; (b) extension install + "View rendered" comparison, framed as "hand this back to the user" rather than something the agent should attempt. State the headless-browser limitation up front instead of letting the agent discover and explain it live.
- Step 5: default `gh gist create` to `--public` in the course's own suggested command, since the step's payoff depends on opening the URL and later showing it with the extension.
- Any step that reads back rendered state after a click: suggest verifying via the app/action HTTP log (`POST .../action/... → 200`) as a browser-optional fallback, not just as bonus evidence.

### Get-started/prereq changes

- State explicitly, before the course begins, which browser-automation tool the session should use and why (e.g. "this repo's CLAUDE.md restricts browsing to gstack's `/browse` skill — don't reach for `claude-in-chrome` or `playwright-cli` directly here"), so the reflexive `ToolSearch` → correction detour seen in `25b1a28c` doesn't recur per session.
- Add a one-line callout that the extension-install step is structurally out of reach for any headless/automated browser tool (claude-in-chrome-headless included), regardless of which one is configured — it needs the user's real, logged-in browser.
- Document the fixed port-discovery recipe (`lsof -i :4567-4620 -sTCP:LISTEN`, per the project's own memory note) as the canonical way to find a backgrounded StreamWeaver server's port, instead of leaving agents to rediscover the `sleep && cat log` → `lsof` fallback each time.

### Docs changes

- README/growing_doc step: note that a doc saved via the canvas "Save as doc" button lands under `~/.streamweaver/canvas/` (not `docs/streamweaver_canvas/<repo>/`) whenever the canvas bridge process was started from a different working directory than the current shell — this is exactly what broke the assumed path in the org-export step of the Sep 3 session, and the design doc (`docs/plans/canvas-doc-location...`) is already flagged as not-yet-built for the global-vs-repo toggle.
- `streamweaver llm` reference: confirm it's positioned as the first stop for DSL syntax questions (it worked well when used) — the Aug 31 session's slower path (dispatching an Explore subagent instead) suggests it isn't yet the obvious/first instinct.
