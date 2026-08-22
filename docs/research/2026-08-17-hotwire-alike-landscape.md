# Landscape Scan: Is There a "Hotwire for htmx/Alpine"?

Date: 2026-08-17

## Research question

Rails/Hotwire works as a system because the backend (REST resources, `dom_id`,
partials, scaffolding) and the frontend library (Turbo Frames/Streams,
Stimulus) were designed together by the same team, with shared conventions
and defined failure semantics. htmx and Alpine.js are deliberately
backend-agnostic transport/behavior libraries — they don't prescribe how your
server organizes routes, partials, or IDs. The hypothesis under test: **no
one has built the unifying "omakase" layer that gives htmx/Alpine the same
zero-custom-JS, convention-driven power Hotwire gives Rails.** This scan
verifies or refutes that hypothesis against the current (August 2026)
landscape.

## Method

Web search + primary-source reading across the projects most often cited as
"Hotwire-adjacent" for htmx/Alpine, plus a sweep for any 2024-2026 project
explicitly pitched as filling this gap. Findings below are organized by
project, then a verdict.

## Findings by project

### Alpine AJAX (imacrayon/alpine-ajax)

**What it is**: An Alpine.js plugin, explicitly Hotwire-inspired, that adds
`x-target`, `x-merge`, and similar attributes so links/forms can swap HTML
fragments without full-page reloads — Alpine's version of "AJAX navigation."

**Layer**: Transport + light conventions, framework-agnostic. It is an Alpine
plugin, not a full-stack system.

**Backend assumption**: None. The project's own comparison page states the
appeal directly — the server just needs to respond with plain HTML; no JSON
contract, no special response headers, no required framework. This is a
deliberate rejection of Turbo's approach, where Turbo requires the server to
distinguish "Turbo requests" from regular requests and often maintain two
templates.

**Opinionation**: Convention-over-configuration *within Alpine's own idiom*
(their docs literally use that phrase), but only at the DOM-targeting level —
which attribute swaps which fragment. It does not touch routing, resource
naming, model-to-partial mapping, or ID generation.

**What it lacks vs. Hotwire**:
- No `dom_id`-equivalent convention for naming targets consistently across
  create/update/destroy responses.
- No Turbo Streams equivalent — no standard way to push multiple
  out-of-band fragment updates from one response; Alpine AJAX instead relies
  on custom JS/DOM events for anything beyond the single fragment a request
  targets.
- No scaffolding/generator layer, no ActionCable-style broadcast integration,
  no mobile-app bridge (Turbo Native has no analog here).
- No opinion on backend resource conventions at all — every project invents
  its own routes/partials from scratch.

**Maturity**: Small, active, single-maintainer-driven; genuinely popular in
the Alpine niche but nowhere near Hotwire's ecosystem depth (generators,
gems, native bridges, broadcast helpers).

Sources: [Alpine AJAX comparisons](https://alpine-ajax.js.org/comparisons/), [htmx alternatives essay](https://htmx.org/essays/alternatives/)

### Datastar (data-star.dev)

**What it is**: A from-scratch hypermedia framework (~11KB) that merges
htmx-style backend-driven DOM patching with Alpine-style client-side
reactive state ("signals"), unified around Server-Sent Events as the
transport. Originally conceived as a TypeScript rewrite of htmx before
becoming an independent project.

**Layer**: This is the most ambitious of the group — it operates as
*transport + client reactivity* in one package, explicitly positioning
itself as a replacement for *both* htmx and Alpine simultaneously, not a
layer on top of them.

**Backend assumption**: None fixed, but strongly SSE-centric — "the backend
is the source of truth for state," and the framework expects your server to
emit signal/fragment updates as an SSE stream rather than one-shot HTTP
responses. It has moved to JSON-in for form/event data (a deliberate
departure from htmx's FormData-first model) and ships a `ServerSentEventGenerator`
convention that every SDK re-implements per language, which is the closest
thing to a cross-language shared convention in this whole landscape.

**Opinionation**: Moderate-to-high at the *protocol* level (SSE events,
signal naming, `data-*` attribute vocabulary) but zero at the *backend
architecture* level — no resource/routing/partial conventions, no
scaffolding. Official SDKs exist for Go, Python, Rust, Ruby, PHP, .NET,
Java, Kotlin, Clojure and more, each providing the SSE-generator primitive,
but none prescribe how you structure a full application (no equivalent to
Rails controllers/resources, no generators).

**What it lacks vs. Hotwire**:
- Pre-1.0 (RC as of this scan) — explicitly unstable, "not yet a complete
  full-stack opinionated ecosystem comparable to Rails" by its own author's
  framing.
- No backend framework of its own — it's a client+protocol layer that any
  backend can target, same category gap as htmx.
- No scaffolding/generators, no resource-naming or `dom_id` convention, no
  official ORM/partial-rendering integration.
- Community/ecosystem is much younger and smaller than Turbo's.

**Maturity**: Fast-growing mindshare in the htmx-adjacent community as of
2026, praised for being "one ~11KB library instead of htmx+Alpine," but
still pre-1.0 and without full-stack scaffolding.

Sources: [Why another framework?](https://data-star.dev/essays/why_another_framework), [Datastar SDKs reference](https://data-star.dev/reference/sdks), [htmx alternatives essay](https://htmx.org/essays/alternatives/)

### Unpoly

**What it is**: The oldest and most mature entrant here — a
progressive-enhancement library (10+ years old, heavily used in the Ruby
community pre-dating Hotwire) that intercepts links/forms and swaps HTML
fragments, with a genuinely sophisticated **layers** system (modals,
drawers, popups as first-class navigation layers) that goes beyond what
Turbo Frames offers.

**Layer**: Transport + fairly deep conventions at the fragment-targeting and
navigation-layer level. Closest philosophical cousin to Turbo of anything in
this scan — multiple comparison sources use the analogy "htmx is to Unpoly
as Django is to Rails," i.e., Unpoly is the more convention-driven, batteries-included
member of the htmx-adjacent family.

**Backend assumption**: Explicitly none — works with "any language," plain
HTML in, no special headers required by default (though it offers optional
headers for smarter responses). This is the same trade Alpine AJAX makes:
buy convention on the client, ask nothing of the server.

**Opinionation**: Highest of the transport-layer libraries surveyed — built-in
scroll-position preservation, form validation-without-reload, caching,
preloading, and true nested layers (Turbo can only approximate nesting by
re-rendering frames). But again, *zero* backend/resource conventions —
no scaffolding, no `dom_id` equivalent, no generator ecosystem. One comparison
source frames the trade directly: Unpoly requires "almost no training" and
no server cooperation, in exchange for less architectural guidance than
Hotwire gives a Rails app.

**What it lacks vs. Hotwire**: No resource/routing conventions, no
scaffolding/generators, no broadcast (ActionCable-equivalent) integration,
no mobile bridge. It solves the *frontend* half of Hotwire's value
proposition very well and does not attempt the backend half at all.

**Maturity**: High — long track record, stable API, real production usage
predating the htmx/Hotwire split. The most mature project in this scan by
calendar age.

Sources: [unpoly.com](https://unpoly.com/), [Hotwire vs HTMX vs Unpoly](https://www.mendelowski.com/blog/2024/11/hotwire-htmx-unpoly), [Alpine AJAX comparisons](https://alpine-ajax.js.org/comparisons/)

### Backend-side "omakase" attempts

These are the projects that take the opposite approach from Alpine AJAX/Datastar/Unpoly:
instead of building a smarter client, they build an opinionated *backend*
around plain htmx.

| Project | Backend | What it prescribes | Gap vs. Hotwire |
|---|---|---|---|
| Loco.rs | Rust | Rails-inspired full-stack framework (routes, models, jobs, CLI) with `cargo loco generate scaffold --htmx` producing CRUD views wired to htmx | No fragment-update protocol equivalent to Turbo Streams; scaffolds views but doesn't define a shared `dom_id`/broadcast convention |
| FastHTML (Python) | Starlette/ASGI | Python objects *are* HTML elements; htmx bundled by default; encourages server-driven interactivity with minimal JS | No resource/REST scaffolding comparable to Rails; conventions are about Python-as-HTML ergonomics, not app architecture |
| Django + django-htmx / django-htmx-patterns | Django | Documented *patterns* (separate-partials, inline-partials) for structuring views/templates around htmx requests | These are community pattern docs, not a shipped convention layer — every team still hand-rolls the plumbing; explicitly flags the "locality of behaviour" problem Hotwire's `dom_id` + partials solve natively |
| turbo-laravel (Hotwired-Laravel) | Laravel | Literally a Turbo/Turbo Streams port for Laravel — closest thing to "Rails' actual conventions, transplanted" | Not htmx-based at all — it's Hotwire itself ported to another backend, which supports the paper's premise rather than refuting it |
| Laravel Livewire | Laravel | Full component-based reactive framework (closer to LiveView than Hotwire) | Different paradigm entirely — server-rendered stateful components, not a hypermedia/htmx layer |
| Ruby: htmx-rails / rails-htmx gems | Rails | Thin helpers for including htmx script tags and reading htmx request headers in Rails | Genuinely minimal — no scaffolding, no conventions beyond header detection; nowhere near Turbo-rails' depth |
| Go + Templ + htmx "stack" | Go (Echo/Chi + Templ) | Community-standardized *stack* (Templ for typed templates, sqlc, htmx, Tailwind) reused across many starter templates | A popular stack, not a framework — no shared project prescribes resource/fragment conventions; every starter kit reinvents its own partial/target naming |

None of these back-end-side efforts reach parity with `turbo-rails` (the
actual Rails gem), which provides `dom_id`, `broadcasts_to`, automatic
Turbo Stream responses from `respond_to`, and scaffolding that wires all of
it together. The closest analog to "Hotwire's actual conventions" is
**turbo-laravel**, and it works by porting Hotwire itself rather than
building an equivalent for htmx.

Sources: [Loco.rs htmx casts](https://loco.rs/casts/007-htmx/), [FastHTML overview](https://mikelev.in/futureproof/fast-html-framework-opinions/), [django-htmx-patterns](https://github.com/spookylukey/django-htmx-patterns), [turbo-laravel](https://github.com/hotwired-laravel/turbo-laravel), [htmx-rails gem](https://rubygems.org/gems/htmx-rails)

### Different-mechanism cousins (worth noting, not competing directly)

**Phoenix LiveView** achieves Hotwire's "no custom JS" promise via a
fundamentally different mechanism: persistent per-connection server
processes and stateful diffing over WebSockets, rather than stateless HTML
fragments over HTTP. It *is* a fully opinionated, single-vendor,
backend+frontend co-designed system — arguably the strongest existing
counter-example to "no one builds these anymore" — but it isn't htmx/Alpine
at all, and its statefulness (one live process per user) is a different
operational model than Hotwire's stateless-server / stateful-browser split.
It's evidence that the *idea* of an omakase hypermedia system is alive, just
not manifesting on top of htmx or Alpine specifically.

Sources: [Hotwire vs Phoenix LiveView (HN)](https://news.ycombinator.com/item?id=25510116), [Benjamin Oakes: Hotwire vs LiveView](http://www.benjaminoakes.com/programming/2021/05/19/Hotwire-by-Basecamp-vs-Phoenix-LiveView/)

### Hypermedia Systems (the book, Carson Gross et al.)

The book is explicitly a *philosophy and technique* text, not a framework
spec. It teaches HATEOAS principles and htmx/Hyperview patterns through
worked examples, and is candid that this is "HTML/XML/hypermedia purism" —
some reviewers find it prescriptive in *values* (favor hypermedia over
JSON APIs, keep state on the server) but it does not prescribe a concrete
convention set (no canonical partial-naming scheme, no scaffolding spec).
It leaves "how do I structure my Django/Rails/Express app around this" as
an exercise for the reader — which is itself evidence for the hypothesis:
even htmx's own creator's book stops short of shipping the Hotwire-style
opinionated backend layer.

Sources: [Hypermedia Systems book review](https://acritelli.medium.com/book-review-hypermedia-systems-65a9379767cf), [Ben Nadel's review](https://www.bennadel.com/blog/4769-hypermedia-systems-by-carson-gross.htm)

### Explicit "Hotwire for htmx" pitches

A targeted search for projects explicitly marketed as "Hotwire alternative
for htmx" or "Rails-like conventions for hypermedia apps" turned up nothing
new in 2024-2026 beyond the projects already covered above. The framing
that keeps recurring across independent comparison articles is the same
Django/Rails analogy: **htmx ≈ Django (flexible, minimal-opinion), Unpoly ≈
Rails (convention-rich, still backend-agnostic)** — but even that framing is
about frontend/transport conventions, not the backend-resource conventions
that make Hotwire+Rails a single designed system.

## Verdict

**The hypothesis holds.** No project currently occupies the "Hotwire-grade
omakase layer over htmx/Alpine" slot — the slot that requires *both* a
convention-rich frontend behavior layer *and* a co-designed backend
convention set (resource naming, partial/`dom_id` mapping, scaffolding,
broadcast integration) shipped as one opinionated system, the way
`turbo-rails` + Rails scaffolding + Turbo/Stimulus are one thing from one
team.

What exists instead is a landscape split cleanly along the fault line the
premise predicts:

- **Frontend-side convention layers** (Alpine AJAX, Datastar, Unpoly) each
  add real opinion about DOM-targeting and swap semantics, but explicitly
  and proudly ask *nothing* of the backend — that's their whole pitch versus
  Turbo. This is a deliberate design choice, not an oversight: it's what
  lets them claim "works with any backend."
- **Backend-side attempts** (Loco.rs scaffolding, FastHTML, django-htmx
  patterns, Go+Templ starter stacks) add real opinion about server code
  structure, but none of them define the missing middle piece — a shared,
  cross-project convention for how server-rendered fragments get IDed,
  targeted, and multiplexed the way `dom_id` + Turbo Streams do together.
- The one project that *did* port Hotwire's actual conventions to a new
  backend (turbo-laravel) did it by transplanting Hotwire itself, not by
  building an htmx-based equivalent — which is arguably confirmation rather
  than refutation.
- Phoenix LiveView proves the *appetite* for a fully co-designed,
  zero-custom-JS omakase system is real and satisfiable — just not via
  htmx/Alpine's request/response model.

**Closest approaches, ranked:**
1. **Unpoly** — most mature, most opinionated at the transport/DOM layer,
   closest "feel" to Turbo, but zero backend conventions by design.
2. **Datastar** — most technically ambitious unification of htmx+Alpine
   into one coherent protocol (SSE + signals), with the beginnings of a
   cross-language shared convention (the SDK `ServerSentEventGenerator`
   pattern) — but pre-1.0 and still backend-architecture-agnostic.
3. **Loco.rs's `--htmx` scaffolding** — the only project that ships an
   actual Rails-style generator producing wired-up htmx views, but it's
   scoped to one young Rust framework and doesn't define a portable
   fragment/ID convention others could adopt.

**Remaining gap**: nobody has shipped the htmx/Alpine equivalent of
`dom_id` + `broadcasts_to` + scaffold-generated Turbo Stream responses —
a small, named, cross-project convention for "how a fragment gets an ID,
how a create/update/destroy action knows which fragments to patch, and how
that travels over the wire" that a backend framework and a frontend library
could both implement once and share. Every project surveyed either declines
to specify that convention (frontend-side libraries, by design) or invents
its own local, non-portable version of it (backend-side scaffolding
attempts).
