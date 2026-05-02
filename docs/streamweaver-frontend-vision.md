# StreamWeaver Frontend Vision

## The Thesis

A **Hotwire-equivalent frontend stack for Ruby/Rails developers**, built on lighter infrastructure than Hotwire and with no build step:

```
Ruby DSL  +  htmx  +  Alpine.js  +  Idiomorph
```

Same capabilities as Turbo + Stimulus, but cheaper to load, easier to read for Rails developers, and aligned with the way StreamWeaver already ships UI: a Ruby DSL renders complete server-side pages, the browser swaps regions intelligently, and nobody runs `npm install`.

The goal is to make StreamWeaver the obvious choice when a Ruby developer wants to build a browser UI without leaving Ruby — and to make those apps **look and feel like well-built Rails apps** so anyone with Rails muscle memory can read them.

## Why Not Hotwire Directly

Hotwire is excellent. The reasons we're not adopting it wholesale:

- **Asset pipeline assumptions.** Turbo and Stimulus expect a Rails-flavored build pipeline (importmaps, esbuild, propshaft). StreamWeaver apps are a single Ruby file plus a CDN script tag — bringing in Hotwire's tooling violates that promise.
- **Bundle size.** Turbo (~30kb) + Stimulus (~10kb) is fine in absolute terms but heavier than htmx (~10kb) + Alpine (~15kb) + Idiomorph (~5kb).
- **Tied to a worldview.** Stimulus controllers are JavaScript classes registered to DOM elements. Alpine declarations live inline in the markup, closer to the data they affect. For Ruby developers used to ERB partials with embedded behavior, Alpine is a smaller mental jump.
- **Token efficiency.** Alpine inline declarations and htmx attributes are token-cheap when an LLM is generating views — relevant given how much of StreamWeaver gets written by Claude.

We are not anti-Hotwire. We are choosing the same shape with lighter materials.

## What We Keep From Hotwire

- **Server renders complete pages.** No virtual DOM in the browser, no client-side router, no JSON-and-render-on-client pattern. The server is the source of truth for what the page looks like.
- **Diff-based morph for navigation.** Idiomorph is literally the same algorithm Turbo 8 uses; we adopt it directly. State preservation across navigation comes from the morph algorithm, not from explicit per-region swap configuration.
- **Bookmarkable resource URLs.** Every meaningful view has its own URL. Users can share links, back-button works, refresh works.
- **Forms POST to controllers, return updated views.** No client-side form state machines. The server says what the page should look like after a submission.

## What We Use Instead

| Hotwire | StreamWeaver convention | Why |
|---|---|---|
| Turbo Drive | htmx `hx-boost` | Lighter, no build step, same UX |
| Turbo Frames | htmx `hx-target`/`hx-swap` | More explicit, less opinionated, fits htmx idioms |
| Turbo Streams | htmx out-of-band swaps + Alpine | OOB covers the partial-update case; Alpine covers the live-update case |
| Stimulus controllers | Alpine `x-data` declarations | Closer to the markup, no separate JS file per component |
| Idiomorph (extracted from Turbo) | Idiomorph (used directly) | Same library |

## Rails-isms We Are Adopting

This is the part of the vision still being filled in. Confirmed directions:

### Resource URLs
Every meaningful view gets a Rails-style resource URL. No positional indexes that depend on local server state.

```
/docs/:name                        # show
/docs                              # index
/history/:session                  # session's history
/history/:session/:timestamp       # specific snapshot
```

Filed as bd `stream_weaver-9ei`.

### Routes-as-conventions
Sidebar navigation, Prev/Next links, all link emission produces these resource URLs. No hand-rolled query-string indexes.

### Layouts and Partials (in progress)
Templates compose from a layout + content + nav region structure. Partials would be a future addition once the layout convention stabilizes.

### Forms (open question)
Rails form helpers (`form_with`, `form_for`, `f.text_field`) translate naturally to a StreamWeaver DSL. The user has signaled interest in stealing the patterns:

```ruby
form_with(url: "/docs", method: :post) do |f|
  f.text_field :name
  f.submit "Save"
end
```

This is **not yet implemented**. It is on the roadmap. The current DSL has `text_field :name, placeholder: "..."` which is closer to Rails' `text_field_tag`. Migrating to a `form_with`-style block is plausible.

### Scaffolding (long-term)
A `streamweaver new <name>` generator that scaffolds a resource (model + canvas templates + URLs) following these conventions. This is well downstream — the conventions need to stabilize first.

## Naming

The combined frontend stack ("htmx + Alpine + Idiomorph + StreamWeaver DSL with resource URL conventions") deserves a name so it can be referred to as a unit. Working title: **streamwire** (StreamWeaver + Hotwire-shape). Open to alternatives. The naming matters because once a thing is named, conventions can be enforced ("this should follow streamwire patterns") instead of restated each time.

## State Conventions

Where each kind of state lives:

| State type | Lives in | Examples |
|---|---|---|
| What is being viewed | URL | which doc, which session, which tab |
| Persistent data | Server (file/DB) | saved docs, user preferences |
| Ephemeral UI state | Client (Alpine) | dialog open/closed, dropdown expanded |
| In-progress input | Client (Alpine) | text being typed before submit |
| Bookmarkable filters | URL query string | search query, sort order |

The principle: **state is in the URL when sharing/bookmarking the URL should restore it.** Otherwise it's client-only.

## What Solves What

The recurring bug pattern Forrest has hit ("my apps reload the whole page and lose state") is solved structurally by Idiomorph. Once the bridge_server and reader templates use morph as the default swap strategy, future features inherit state preservation without thinking about it. No new feature can accidentally regress to "click → full reload → lose accordion state" because that path stops existing in the layouts.

## Path Forward

1. **Adopt Idiomorph in StreamWeaver layouts** (bd `stream_weaver-2ds`, P2). Replaces hand-rolled OOB swaps and JS active-class fixups with one extension.
2. **Adopt resource URLs in canvas-read** (bd `stream_weaver-9ei`, P2). Establishes the URL convention.
3. **Document everything in `llms.txt` (linked as `docs/for_llms.md`)** so LLMs build new apps correctly without rediscovering the patterns. This is the most important deliverable — Forrest reports significant churn from unclear conventions.
4. **Migrate existing examples** to the conventions once the patterns are documented. Existing apps under `examples/` become reference material.
5. **(Later)** Forms — translate Rails form helpers to the DSL.
6. **(Later)** Scaffolding generator.

## Open Questions

- Naming: streamwire? streamweave? something else?
- Forms: how much Rails form helper API to mirror exactly?
- Multi-page apps: routing conventions for apps with several resources
- Asset handling: how a single-file Ruby app declares its own CSS/JS without a build step
- Testing: convention for testing StreamWeaver views (currently spec-by-rendered-HTML — fine for now)

These get answered as the conventions get exercised by real apps.

---

*This document captures the strategic direction. For the practical "how to build a StreamWeaver app correctly" guide, see `llms.txt` (linked as `docs/for_llms.md`).*
