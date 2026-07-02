# StreamWeaver 1.0 Roadmap — The Pareto Production Plan

Synthesized 2026-07-02 from three research inputs (all in `gsd/research/`):
`repo-audit-1.0.md` (facts on the ground), `production-patterns-research.md`
(proven minimal mechanisms from Streamlit/Rails-Solid/LiveView/Roda), and
`market-positioning-research.md` (the market moment + site/video strategy).
Tracked as beads epic `stream_weaver-b9g`.

---

## The Thesis

StreamWeaver's moment: the industry is standardizing on **rich HTML as the
agent-to-human surface** (Anthropic's "Unreasonable Effectiveness of HTML"
post, May 2026; the ratified MCP Apps standard, Jan 2026 — shipped in Claude,
ChatGPT, Goose, VS Code) while openly conceding the token cost. Independent
benchmarks put HTML at **4-8x markdown tokens**. StreamWeaver's claim:
**markdown-level token cost, HTML-artifact richness, real-time push**.

Positioning rule: do NOT say "10x cheaper" until we publish our own benchmark
(bench script comparing StreamWeaver DSL vs equivalent raw HTML vs markdown
for the same rendered UI). The independent 4-8x figure is citable; our own
numbers become the headline.

Canvas mode is the flagship of this story — it replaces both the Chrome-based
visual companion and token-heavy HTML artifacts with a persistent, push-driven,
interactive surface. 1.0 messaging leads with canvas, not with "Streamlit for
Ruby."

---

## The Four Modes (and the "where to use what" answer)

The audit confirms four legit modes plus a deployment wrapper. The 1.0 docs
must open with this table — it IS the "where to use what" doc Forrest wants:

| Mode | Reach for it when | Maturity gap for 1.0 |
|---|---|---|
| Standalone script (`ruby app.rb`) | Quick helper UI, one file, one user | None — this is done |
| Agentic (`run_once!`) | Agent needs one answer from a human | None |
| Service mode (`streamweaver run`) | Several apps, one server, lives all day | Hash URLs (fix exists, unwired) |
| Canvas push (`streamweaver panel` / `canvas-push`) | Agent pushes live UI to a human mid-session | Crash recovery, SSE replay, bridge_server specs |
| Puma-dev wrapper | Memorable `myapp.test` URLs on your Mac | Docs only |

---

## Tier 0 — Release Blockers (mechanical, do first)

These are why `gem install stream_weaver` doesn't work for anyone but Forrest.

1. **Unblock the `iterm2_ruby` dependency** — it's a runtime dep pointed at
   `~/work/iterm2_ruby` (Gemfile:9). Either publish `iterm2_ruby` to
   rubygems.org or demote it to an optional/soft dependency (rescue
   LoadError; iTerm panel features degrade gracefully). Hard blocker.
2. **Version/changelog hygiene** — VERSION says 0.1.1, CHANGELOG has only ever
   cut 0.1.0 with ~200 lines sitting in `[Unreleased]`. Cut 0.2.0 honestly,
   then version toward 1.0.
3. **CI** — no `.github/workflows/` at all. Add rspec matrix (Ruby 3.3/3.4)
   + rubocop. The 2,090-example suite runs in ~5s; this is cheap insurance.
4. **Repo hygiene** — add `dist/` to `.gitignore` (2.7MB one `git add -A` from
   disaster), remove stray root `.gem` files, reconcile the tracked-but-
   supposedly-ignored `docs/superpowers/` files.

## Tier 1 — The Production 20% (the mechanisms)

Ordered by leverage-per-effort. Items 5 and 7 are the "never rewrite in
Sinatra again" fixes.

5. **Human-readable multi-app URLs** — smallest, highest-leverage fix in the
   repo. `aliased_path_for` (service.rb:186) already builds `/:source/:name`
   routes; the CLI just never passes `source:` (cli.rb:123-166). Wire a slug
   derived from the app's declared name (fallback: filename) into the default
   `streamweaver run` path: `/apps/sales-dashboard`, hash kept as canonical
   fallback. This single change revives the whole multi-app feature.
6. **SessionStore story** — the cookie-overflow trauma is already 80% solved
   (file store is default, 4KB ceiling gone). Finish it: (a) make the legacy
   cookie store raise loudly on overflow instead of silently dropping keys,
   (b) add a SQLite-backed store behind the same `SW_SESSION_STORE` switch as
   the service-mode/multi-instance default (Rails 8 "Solid" philosophy — DB,
   not Redis), (c) document the graduation path in one page.
7. **Escape hatches** — adopt Streamlit's graduated model, stop at two:
   (a) a `raw_html` / iframe component for arbitrary markup, and
   (b) an `endpoint` DSL (`app.get "/webhook" { |req| ... }` style) that
   registers raw Rack endpoints inside the same app — webhooks, JSON APIs,
   file downloads without leaving StreamWeaver. Add multipart file-upload
   support to the form layer. Skip a bidirectional custom-component protocol
   until demand exists.
8. **Canvas production hardening** — canvas is a shipped skill's dependency,
   so the bar is higher: (a) persist bridge sessions to disk so a crash
   doesn't lose open canvases (LiveView's "durable recipe" lesson), (b) SSE
   monotonic event `id:` + `Last-Event-ID` replay + `retry:` backoff (the
   classic silent-drop bug), (c) validate theme/layout wire values against
   the registry, (d) a dedicated spec file for `bridge_server.rb` (1,111
   lines, zero direct specs today).
9. **Security posture for 1.0 (docs + defaults, not systems)** — keep
   localhost-bind default and document it as a feature; opt-in CSRF for
   auto-submit forms (Roda `route_csrf` as the model); one documented
   middleware slot with a Basic Auth example; one Kamal-ready Dockerfile
   example. Do not build an auth system.

## Tier 2 — Adoption Surface (docs, site, tutorials, videos)

10. **docs/ cleanup** — 73 files, ~9 genuinely user-facing. Archive the
    planning/session logs (`docs/plans`, `docs/visual-skills`, spikes) out of
    the shipping tree; delete or fix `canvas-ipc-session-summary.md`, which
    actively contradicts the current architecture. Merge `llms.txt` /
    `docs/for_llms.md` overlap.
11. **Tutorial revamp** — the wired-in tutorial predates ~6 months of
    features: zero coverage of canvas/panel, resource DSL, navbar, `:doc`
    theme, theme_switcher, card_header. Restructure as one lesson per mode
    (the four-modes table above becomes the tutorial's spine), and make it
    the first-outside-tester onboarding path — their first session is the acceptance
    test.
12. **Website (charm-ruby.dev pattern)** — shallow 4-item nav; sell with
    runnable code not prose; component cards grouped by function; and the
    charm trick applied literally: the site's visuals ARE StreamWeaver output
    (dogfood the `:doc` theme — the site is a StreamWeaver app or its static
    export). Hero = the token-cost benchmark, side-by-side with the same UI
    as raw HTML.
13. **Demo videos (pareto stack)** — VHS `.tape` files for terminal demos +
    Playwright 1.59 screencast for "agent pushes to canvas live" captures +
    ElevenLabs voiceover + Descript assembly. Entire pipeline scriptable:
    `bin/demos` regenerates every asset. Skip Remotion/asciinema for v1.
14. **README restructure** — install-first, pitch second (current order
    inverted). Keep the philosophy essay, move it below Quick Start.
15. **Token benchmark** — small script + published table: same UI in
    StreamWeaver DSL vs raw HTML vs markdown-equivalent fidelity. This is
    the marketing headline AND a regression guard on DSL verbosity.
16. **Opal directive — copyable example + docs** — the Opal mode (Phases
    2a+2b done; 2c ReactiveState and 2d Mermaid/ChartJS queued) becomes
    useful at 1.0 if a newcomer can copy one polished example, modify it,
    and ship — pick/finish one compelling scenario (the `dist/` demos are
    the seed), document the `opal-build` workflow end to end, and cross-link
    it from the four-modes table as the "client-side Ruby" option.
17. **Opal vs React benchmark** — extends item 15 with two more axes:
    (a) authoring token cost — same app written via StreamWeaver+Opal vs
    idiomatic React (an LLM writes both; count tokens), and (b) library
    load — bytes shipped to the browser (Opal runtime + morphdom + marked
    vs react + react-dom + build-toolchain output). Together with item 15
    this becomes one benchmark suite: tokens-to-author, bytes-to-load,
    fidelity delivered.

---

## Triumvirate Check (applies to items 10-14)

| Law | Application |
|---|---|
| Matt's Law (find it, digest it) | Four-modes table opens every doc surface; shallow nav; one decision guide instead of 73 files |
| Forrest's Law (zero friction + perks) | `gem install` just works (Tier 0); memorable URLs by default (item 5); value shown not discovered — site leads with live output and the benchmark |
| Gloria's Law (design for the brain you have) | The site/docs must be as attractive as the `:doc` theme output; videos over walls of text; the want-to threshold is functional, not decorative |

---

## The 20% of the 20% — Buildable Immediately

In order, each independently shippable:

1. Tier 0 complete (deps/version/CI/hygiene) → `gem install` works, 0.2.0 cut
2. Item 5: slug URLs wired into `streamweaver run`
3. Item 7b: `endpoint` DSL escape hatch
4. Item 8a+8b: canvas crash recovery + SSE replay
5. Item 11: tutorial revamp → first-outside-tester onboarding
6. Item 15: token benchmark → unlocks honest positioning copy

Everything else (site, videos, SQLite store, CSRF) sequences behind these
without blocking them.
