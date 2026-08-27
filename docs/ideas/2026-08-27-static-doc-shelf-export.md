# Static Doc Shelf — free multi-doc export for canvas docs

**Status:** captured, not scheduled. Brainstormed 2026-08-27; no implementation.
**Trigger to pick this up:** when a doc corpus needs to reach a reader who
should not have to run StreamWeaver, use GitHub, or hold an account.

## The gap, in one line

`streamweaver export` gives you one self-contained HTML file. `canvas-read`
gives you a browsable *shelf* of many docs — but only as a local Sinatra app.
**There is no static shelf.** That is the whole missing piece.

## Why this is small

Both halves already exist and are reused verbatim:

- `StreamWeaver::Export::HtmlExporter.from_dsl_file(path, theme:, layout:)` —
  per-doc rendering, already handles `.rb`, mermaid, images, CDN collection.
- `StreamWeaver::Canvas::Reader::FileList.build(args, ...)` — input resolution,
  already globs `.rb` and `.org`, already does multi-root discovery.
- `StreamWeaver::Org::Reader` — `.org` → DSL, already parses `#+TITLE:`
  (`lib/stream_weaver/org/reader.rb:62`).

No new rendering engine. No Opal component-parity dependency.

## Framing decisions (settled during the brainstorm)

| Question | Decision |
|---|---|
| What is the durable asset? | The extraction pipeline, the doc format, and the curated corpus. **Not** the delivery. |
| So how much delivery do we build? | As little as possible. Delivery is plumbing; over-building it means building the thing that is not the moat. |
| What do recipients do? | **Read only.** Published shelf. No accounts, no writes, no server. Tracking stays on the author's side. |
| Build strategy | Approach A (a real `shelf` command), shipped C-first (walk + export + index usable before search exists). |

### Approaches considered and rejected

- **One Opal app that is the shelf.** Single bundle, instant nav, snappy — but
  every doc in the corpus must first clear Opal component parity (tables,
  mermaid, images), and `stream_weaver-5n9w` shows doc output there still has
  rough edges. Rejected: it gates a content corpus on framework work.
- **Bash loop + hand-written index.** `for f in docs/*.rb; do streamweaver
  export "$f"; done` plus a small index generator. Genuinely available today
  and worth doing if the need is urgent and one-off. Differs from the real
  thing by exactly two features: search and shared nav.

## Design § 1 — Doc identity and the manifest

This is the part that is expensive to change later, and the reason to design it
now rather than improvise it under time pressure.

**Stable, content-derived slugs — never ordinal.** The reader addresses docs by
position (`?file=0`); `FileList` carries `files`, `history_roots`, and `labels`
but no slug or id. A link to "the third doc in the directory" breaks the moment
a doc is added. Precedence for the shelf:

1. explicit `#+SLUG:` in the org file
2. slugified `#+TITLE:`
3. filename basename

Output is `dist/<slug>.html`, stable across rebuilds and reordering.

**`dist/shelf.json` — one manifest, three consumers.** An array of
`{slug, title, source, headings[], tags[], links_out[], links_in[]}`:

1. feeds client-side search (no separate `search.json`)
2. is what an **agent** reads to find what is in the corpus without crawling HTML
3. is the substrate a future wiki computes related-content over

The builder walks every file anyway, so this is close to free.

**Tags from org.** Teach `Org::Reader` to read `#+FILETAGS:` into the manifest —
a few lines, and it means docs can be categorized in the authoring format
starting immediately, so a later wiki inherits real data instead of an empty
corpus.

### Wiki-readiness (deliberate seam)

An org-based Karpathy-style wiki over the doc corpus is anticipated but **out of
scope here** — no related-content rendering, no category pages, no graph view.
What this design *does* commit to, so the wiki is cheap when it arrives:

- `[[slug]]` resolves to `<a href="slug.html">` when the slug is in the
  manifest; stays literal text when it is not. ~10 lines.
- Forward links **and backlinks** are recorded in `shelf.json`.

The payoff is timing: links can be written into org docs from day one, so the
corpus arrives at the wiki already connected rather than needing a linking pass
over the whole shelf. Related: a desire to extend UKF to support org mode.

## Design § 2 — The build pipeline

**Command:** `streamweaver shelf <paths...> [-o dist/] [--title "..."] [--offline]`

Same argument shape as `canvas-read`, using **the same `FileList.build`** — so
whatever `canvas-read` shows, `shelf` builds, and the two cannot drift into
disagreeing about what is in the corpus.

**Three passes, because links force it:**

1. **Metadata** — walk every file, extract `{slug, title, tags, source}`. No
   rendering. Exists because `[[slug]]` cannot resolve until all slugs are known.
2. **Render** — per doc, `HtmlExporter.from_dsl_file(path, theme: :default,
   layout: :fluid)` (identical defaults to `streamweaver export`, so a shelf
   page and a single-file export of the same doc are byte-comparable), then
   resolve `[[slug]]` and record edges.
3. **Write** — `dist/<slug>.html`, `dist/index.html`, `dist/shelf.json` with
   backlinks now that all edges are known.

**Units:**

| Unit | Job | Knows nothing about |
|---|---|---|
| `Shelf::Manifest` | slug/title/tag extraction, doc list | HTML |
| `Shelf::LinkResolver` | `[[slug]]` → anchor, emits edges | files, rendering |
| `Shelf::IndexPage` | builds the index | the filesystem |
| `Shelf::Builder` | orchestrates passes, writes output | how any of the above work |

**The index page is itself a StreamWeaver DSL doc**, rendered through the same
`HtmlExporter`. No second templating system, no second styling path — the index
inherits the theme and is authored in the DSL.

**Where a shelf differs from N single files** (decided, not open):

- **Images copy to `dist/assets/` with paths rewritten, not base64.**
  `--inline-images` suits one emailed file; across a 50-doc shelf it duplicates
  every shared image into every referencing page. The flag stays for the
  single-file path.
- **Mermaid is written once to `dist/assets/` and shared.** `--offline`
  currently inlines the whole library per document — fine once, absurd fifty
  times. One copy, every page points at it, still works with no network.

## Slices

1. **Walk + per-doc export + generated index.** Usable immediately; no search.
2. **`shelf.json` + client-side search + shared nav strip.**
3. **`[[slug]]` resolution + backlinks.** (Can fold into 1 if links are wanted
   from the very first corpus.)

## Open questions deferred to build time

- **Hosting/privacy.** GitHub Pages is free only for public repos; a corpus
  intended for a named set of students is not obviously public. Alternatives
  worth pricing then: Netlify or Cloudflare Pages (both serve from a private
  repo on free tiers).
- Whether readers want search at all, categorization by category/position, or
  links back to source-video timestamps. Unknown until a real reader uses it —
  do not guess, ship slice 1 and watch.

## Related

- `docs/opal-jamstack.md` — the static Opal path and its Phase 1 scope limits
- `stream_weaver-5n9w` — opal-build standalone HTML `sidebar_toc` scroll-spy gap
- `stream_weaver-mdc` — canvas docs epic (discovery, export, cleanup, fidelity)
