# Production-Readiness Patterns: Precedent Survey

Research for the StreamWeaver "production-ready 20%" strategy. StreamWeaver
(this repo) grew from quick helper-UI
scripts into full web apps. The owner wants Rails-grade production mechanisms
*without* building Rails — the minimal proven mechanisms that give 80% of
production readiness for 20% of the engineering cost.

Known pain points driving this research:

- **(a)** State lived in session cookies until they overflowed the 4KB cookie limit.
- **(b)** Multi-app-in-one-server (`streamweaver app.rb` service mode) produces
  hash-based URLs instead of human-readable ones.
- **(c)** Users occasionally hit a wall and rewrite their app in raw Sinatra.

Five topics below. Each ends with a proven-pattern table and a recommendation.

---

## 1. Server-side state/session

**The scaling story, in order:** cookie session (client-side, ~4KB cap) →
in-memory server-side session (`Rack::Session::Pool`, single-process only) →
external store (Redis/Memcached, the traditional answer) → **database-backed
store on the app's existing DB** (the 2025-26 answer, popularized by Rails 8's
"Solid" trio — Solid Cache, Solid Queue, Solid Cable — explicitly built to
avoid requiring Redis as extra infrastructure).

**Streamlit** hits this exact wall: `st.session_state` is in-process/in-memory
per browser session by default, which is explicitly documented as
insufficient once you have multiple users or server restarts/multiple nodes.
Streamlit's own docs point users to Redis or to hand-rolling a
disk/EFS-backed session-key scheme — i.e., Streamlit does *not* solve this for
you; it punts to the deployer. That's the trap StreamWeaver should avoid
repeating.

**Sinatra/Rack apps** graduate off `enable :sessions` (cookie-based) to
`use Rack::Session::Pool` (server-side, in-memory hash — good for single
process, breaks under multiple workers/dynos) or plug in **moneta**, a gem
that provides one unified key-value interface over ~20 backends (Memory,
SQLite3, PStore/YAML file, Redis, Memcached, ActiveRecord, Sequel, etc.) and
ships a `Rack::MonetaStore` middleware plus direct Sinatra/Rails integration.
Moneta is the "swap the backend without rewriting the app" abstraction layer
— exactly the pattern needed for a gem that has to work identically for a
solo dev (file-backed) and a small team (DB-backed).

**Rails 8's Solid trio** is the strongest recent precedent for the philosophy
itself: default to the database you already have (SQLite is explicitly fine
— "SSDs are only marginally slower than RAM for reads, at a fraction of the
cost and complexity of running Redis"). Basecamp/HEY run this in production.
The win isn't the specific gem, it's the stance: **zero extra infrastructure
by default, pluggable up to Redis only if you need it.**

| Pattern | Project | Adopt/Adapt/Skip |
|---|---|---|
| In-memory session (works until multi-process/restart) | Rack::Session::Pool, current StreamWeaver | Skip as the *only* option — keep as dev-mode default |
| Unified key-value store abstraction (memory/SQLite/file/Redis, swappable) | moneta gem | **Adapt** — thin StreamWeaver-native abstraction over SQLite-first, Redis-optional |
| DB-backed session/cache using an embedded DB, no external service required by default | Rails 8 Solid Cache/Solid Queue philosophy | **Adopt the philosophy** — SQLite-backed session store as the 1.0 default |
| Punt state scaling to the deployer (EFS/Redis, docs-only) | Streamlit | Skip — this is the exact pain point already reported |

**Recommendation:** Ship a `StreamWeaver::SessionStore` interface with two
built-in backends: in-memory (today's default, fine for `ruby app.rb`
single-process) and **SQLite-backed** (default for `streamweaver` service
mode and anywhere `STREAMWEAVER_HOST=0.0.0.0`). No Redis dependency in core;
document a Redis/moneta adapter as an escape hatch for teams that already run
Redis.

---

## 2. App naming/routing (human-readable URLs for multi-app service mode)

The web has few frameworks solving "many small apps, one server, friendly
URLs" as a first-class feature — most precedent comes from tunnel/PaaS
products (ngrok, Heroku-style) and from Rails engine mounting, not from
peer micro-frameworks.

- **ngrok**: paid tiers let you claim a human-readable static subdomain
  (`myapp.ngrok.app`) per tunnel; multiple local services get separate named
  tunnels via a config file, each mapped 1:1 to a name. Wildcard domains
  (route-by-subdomain to one process) require the enterprise tier — i.e. even
  ngrok treats "one name = one process" as the easy case and "one process,
  many subpath names" as the harder, less-supported case.
- **Puma-dev** (already used by StreamWeaver, see README puma-dev mode):
  solves this locally for free — `puma-dev link` in a directory gives you
  `http://<dirname>.test` with zero config, auto-starts on first request. This
  is the actual precedent StreamWeaver already leans on, and it's the right
  shape: **name = directory/app name, not a hash.**
  - `puma-dev` doesn't do subpath routing at all — it's one name per process,
    which sidesteps the routing problem instead of solving it.
- **Rack::Builder / Sinatra modular mounting**: `run Rack::Builder.new { use
  App1; use App2 }` mounts multiple Sinatra apps in one process, but every
  request passes through every app's before-filters until one claims it —
  a real cost at scale, and the community's own conclusion (via projects like
  `sinatra-router`) is that a dedicated slug-based router in front of
  `Rack::Builder` is worth adding rather than relying on middleware stacking.

| Pattern | Project | Adopt/Adapt/Skip |
|---|---|---|
| Named local domain, zero config, one process | Puma-dev (already integrated) | **Adopt more** — make service-mode registration name-first, not hash-first |
| Named subdomain per tunnel/app | ngrok | Adapt the naming *convention* (slug from app name/directory), not the tunnel infra |
| Subpath router in front of Rack::Builder to avoid middleware-stacking cost | sinatra-router pattern | **Adopt** — give service mode a slug router: `/apps/<slug>` derived from `app "Name"` title or explicit `slug:` option |

**Recommendation:** In service mode, derive `/apps/<slug>` from the app's
declared name (slugified) or an explicit `app "Meeting Notes", slug: "notes"`
option, replacing the current hash. Keep Puma-dev mode as the "one app, one
memorable domain" path for users who want that instead of subpaths — don't
force a single routing model.

---

## 3. Escape hatches (never rewrite in Sinatra)

Every framework in this class has learned the same lesson: users will hit a
wall the DSL doesn't cover, and if there's no sanctioned drop-to-raw path they
leave the framework entirely. The mature answer is always **a small, explicit
API for "give me a raw request/response here," not a philosophy of covering
every case in the DSL.**

- **Streamlit**: `st.components.v1.html()` / `.iframe()` for one-way raw
  HTML/embed, and a full **Components API** (bidirectional, JS↔Python) for
  cases needing two-way data — explicitly documented as "start with html/
  iframe first, only reach for the bidirectional Components template if you
  need callbacks back into Python." This graduated-complexity offering (raw
  HTML → iframe → full bidirectional component) is a strong minimal template.
- **Phoenix LiveView**: `Hooks` — `phx-hook="MyHook"` lets you write arbitrary
  client JS and have LiveView guarantee it's wired up/cleaned up on
  mount/update/destroy, without leaving the LiveView model. Router-level,
  LiveView routes coexist with plain controller routes in the same router —
  users aren't forced to choose one paradigm for the whole app.
- **Hotwire/Turbo**: Turbo Frames/Streams degrade gracefully to normal
  full-page navigation, and standard Rails routes/controllers sit right next
  to Turbo-powered ones — there's no separate "Hotwire app" vs "Rails app,"
  it's additive.
- **Rack ecosystem generally**: any Sinatra/Roda/Rails app can `mount` a bare
  Rack app or define a raw route block that skips all the DSL and just
  returns `[status, headers, body]` — the universal Ruby web escape hatch.

| Pattern | Project | Adopt/Adapt/Skip |
|---|---|---|
| Raw HTML/iframe embed, no callback wiring | Streamlit `components.v1.html/iframe` | **Adopt** — `raw_html { }` / iframe component, already low-cost to add |
| Full bidirectional custom component (JS↔server), offered as escalation, not the default path | Streamlit Components API | **Adapt** — a `custom_component` hook for canvas/push mode only, document as "advanced" |
| Client-side hook wired to component lifecycle without leaving the framework's data model | Phoenix LiveView `Hooks` | **Adapt** — a `js_hook:` option on any component for custom client behavior |
| Raw Rack route block coexisting with DSL routes in the same app | Sinatra/Roda/Rails universal pattern | **Adopt** — `route "/webhook", methods: [:post] { |req| ... }` escape hatch returning a raw Rack triple, so users never need a second Sinatra process |

**Recommendation:** Ship two escape hatches, both small: (1) a `raw_html`/
`raw` component for arbitrary markup (Streamlit's html/iframe tier), and (2) a
`route` DSL method that registers a raw Rack endpoint inside the same app/
server (the universal Sinatra/Roda pattern) — covering webhooks, custom JSON
APIs, and file downloads without a second process. Skip building a full
bidirectional custom-component protocol until there's evidence of real demand
past (1) and (2); that's the expensive tier Streamlit only added because
"just embed HTML" wasn't enough for chart libraries specifically.

---

## 4. 1.0 gem production checklist

There isn't a single canonical 2026 checklist, but the RubyGems guides plus
current framework practice converge on the same short list:

- **Semver**: RubyGems' own guidance is to follow semantic versioning
  strictly from the first 1.0 tag — breaking changes bump major, and the gem
  should declare a `required_ruby_version` in the gemspec rather than assume.
- **Ruby version support**: as of 2026, Ruby 3.2 is EOL and 3.3 is
  security-only; a credible 1.0 targets 3.3 (min, if backward compat
  matters) through 3.4/4.0, tested via CI matrix (GitHub Actions with a Ruby
  version matrix is the de facto standard across Sinatra/Roda/Rails-family
  gems).
- **Security posture — bind address**: both Rails-adjacent minimal frameworks
  (Roda, Hanami) and StreamWeaver's own README already get this right in
  principle — default to `127.0.0.1`, require an explicit opt-in
  (`STREAMWEAVER_HOST=0.0.0.0`) for LAN/Tailscale exposure. That's the
  correct minimal default and should be called out explicitly as a security
  feature in 1.0 docs, not just a config knob.
- **CSRF**: Roda ships a `route_csrf` plugin (opt-in, per-route tokens) and
  Hanami bakes CSRF + secure-by-default headers (CSP, X-Frame-Options) into
  the framework itself rather than leaving it to the app. StreamWeaver's
  auto-submit form components are exactly the surface that needs CSRF
  protection once apps are bound beyond localhost — currently likely
  unprotected given the localhost-only original design assumption.
- **Auth hook for exposing beyond localhost**: neither Roda nor Hanami forces
  a specific auth scheme; both expose a middleware slot. The minimal
  equivalent for StreamWeaver is a documented Rack middleware insertion point
  (e.g. HTTP Basic Auth via `Rack::Auth::Basic`) that's trivial to enable
  when `STREAMWEAVER_HOST` isn't localhost.
- **Deployment story**: Kamal 2 is now the default Rails answer for
  "containerize and deploy to any VPS with zero-downtime," and it works for
  any Dockerized Ruby app, not just Rails — a Kamal-friendly `Dockerfile` +
  short "deploy with Kamal" doc is more credible in 2026 than a bespoke
  deploy guide. Puma-dev (already used) covers the "run persistently on my
  own machine" case well.

| Pattern | Project | Adopt/Adapt/Skip |
|---|---|---|
| Semver from 1.0, `required_ruby_version` in gemspec, GH Actions Ruby matrix (3.3–3.4/4.0) | RubyGems guides, Rails-family gems | **Adopt** — mechanical, low cost |
| Bind to `127.0.0.1` by default, explicit opt-in for `0.0.0.0` | Roda/Hanami convention; StreamWeaver already does this | **Adopt & document as a security feature**, not just a config default |
| Built-in CSRF plugin, opt-in but one-liner | Roda `route_csrf` | **Adapt** — wire CSRF token into StreamWeaver's existing auto-submit forms, on by default once host != localhost |
| Secure-by-default headers (CSP, X-Frame-Options) baked into framework | Hanami | **Adapt** — ship as default middleware, overridable |
| Documented middleware slot for auth (Basic Auth, etc.), not a built auth system | Roda/Hanami middleware pattern | **Adopt** — one doc page + example, don't build auth |
| Kamal-ready Dockerfile + deploy doc | Rails 8 default | **Adapt** — one example Dockerfile in `examples/`, not a StreamWeaver-specific deploy tool |

**Recommendation:** The 1.0 checklist is mostly *documentation and defaults*,
not new engineering: lock semver + Ruby CI matrix, keep localhost-default
bind but frame it explicitly as security posture, add opt-in CSRF for
auto-submit forms, and ship one example Dockerfile for Kamal deploys. Skip
building any bespoke auth system — a middleware insertion point plus a
Basic Auth example is the whole scope.

---

## 5. Real-time push at production quality (SSE/WebSocket robustness)

StreamWeaver's canvas push mode is SSE-based (per the bridge/session files in
the repo). The precedent split is stark: **LiveView-style (stateful,
WebSocket, server holds a process per client) vs. Datastar-style (stateless,
SSE, server recomputes from state on each push)** — and the failure modes are
different for each.

- **LiveView's known weak spot**: when the WebSocket drops, the server-side
  GenServer holding that session's state dies with it — everything in
  `assigns` is gone on reconnect unless it was persisted somewhere durable.
  The documented fix is architectural discipline: treat in-memory state as a
  disposable cache and always keep a "recipe" (DB row, URL params) to
  reconstruct it, never treat process memory as the source of truth.
- **SSE reconnection (the protocol StreamWeaver already uses)**: the
  browser's native `EventSource` auto-reconnects, but correctness requires
  the server to (1) send a `retry:` field to control backoff, and (2) assign
  a monotonic `id:` to every event so a reconnecting client's `Last-Event-ID`
  header lets the server replay only what was missed. Skipping `id:` is
  called out repeatedly as the most common silent bug — reconnection appears
  to work in dev (small gaps) and silently drops events under real network
  interruption.
- **Backpressure**: the consistent production pattern (Ktor/Kotlin Flow
  examples, Phoenix GenServer mailbox examples) is that the transport must
  apply backpressure by suspending/queuing at the producer when a client
  can't keep up, rather than unbounded buffering — for StreamWeaver's push
  model (owner explicitly pushes content, not a firehose) this is lower risk
  than a chat/metrics use case, but batching rapid successive pushes to the
  same session is the cheap defensive move.
- **Datastar's stance** (SSE + hypermedia, no WebSocket, no per-client
  process) is the closest architectural cousin to StreamWeaver's canvas
  push — worth reading as validation that SSE-only is a legitimate production
  choice, not just "the easy version," as long as event IDs + replay are
  handled.

| Pattern | Project | Adopt/Adapt/Skip |
|---|---|---|
| Monotonic `id:` on every SSE event + honor `Last-Event-ID` on reconnect to replay only missed events | SSE spec / general production guidance | **Adopt** — likely the single highest-leverage fix; check if `bridge_server.rb`/`protocol.rb` already assign event IDs |
| `retry:` field to control client backoff | SSE spec | **Adopt** — one-line addition |
| Never treat in-process state as sole source of truth; keep a durable "recipe" to rebuild on reconnect | Phoenix LiveView lesson-learned | **Adapt** — pairs directly with topic 1's session-store recommendation; canvas session state should live in the same SQLite-backed store, not only in the bridge process |
| Batch/coalesce rapid successive pushes per session rather than unbounded queuing | Ktor/GenServer backpressure pattern | **Adapt** — cheap given StreamWeaver's push is owner-driven, not high-frequency |
| Stateless SSE + hypermedia as a legitimate alternative to stateful WebSocket | Datastar | Reference/validate current approach — no change needed, just confirms SSE-only is production-credible |

**Recommendation:** Audit `lib/stream_weaver/canvas/protocol.rb` and
`bridge_server.rb` for event IDs and `Last-Event-ID` handling — if absent,
that's the top-priority fix for push-mode robustness. Add a `retry:` field.
Tie canvas session state to the same durable session store from topic 1 so a
bridge restart doesn't lose in-flight canvas content.

---

## Summary Table

| # | Topic | Adopt | Adapt | Skip |
|---|---|---|---|---|
| 1 | State/session | DB-backed-by-default philosophy (Rails 8 Solid) | moneta-style pluggable backend abstraction, SQLite default | Redis-required, EFS-style punt (Streamlit's gap) |
| 2 | App naming/routing | Slug-based `/apps/<name>` router | ngrok's naming convention (not its infra) | Hash-based mounting, wildcard-domain routing |
| 3 | Escape hatches | Raw HTML/iframe tier, raw Rack `route` block | LiveView-style `js_hook:` for client behavior | Full bidirectional custom-component protocol (until demand proven) |
| 4 | 1.0 checklist | Semver + Ruby CI matrix, localhost-default bind, middleware auth slot, Kamal-ready Dockerfile | Roda's opt-in CSRF, Hanami's secure headers-by-default | Building a bespoke auth system |
| 5 | Real-time push | SSE `id:`/`Last-Event-ID` replay, `retry:` field | Durable session-backed canvas state, push coalescing | Switching to WebSocket/per-client process model |
