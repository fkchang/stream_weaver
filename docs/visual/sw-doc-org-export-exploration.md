# Mapping StreamWeaver Docs to Org-mode: Export, GitHub Viewing, and What the Parser Actually Needs

**Date:** 2026-08-07
**Status:** Exploratory design — spike-verified, not implemented
**Supersedes claims in:** `sw-plan-format-exploration.md`, `sw-plan-rendering-deep-dive.md` (June 2026)

**TL;DR:** The mapping works, and better than expected — ~85% of components in a
real StreamWeaver doc land on native org constructs with zero loss. But the framing
should change: don't build "an org exporter," build a **document IR** with pluggable
backends, because for the stated goal (*view docs on GitHub*) markdown renders
strictly better than org, while org is the only format that round-trips back into a
live canvas. Also: "expand the org mode parser" turns out to be mostly unnecessary —
what's needed is a dispatch layer on top of org-ruby, not a parser expansion. The one
place expansion is genuinely required is custom blocks, and there org-ruby is worse
than previously documented.

---

## What Changed Since June

The two June exploration docs asked: *what format should we author checked-in plan
files in?* The answer was org, and the reasoning holds up.

This document asks a different question, the one actually on the table:

> Can we take **StreamWeaver docs we already have** — the Ruby DSL bodies in
> `docs/streamweaver_canvas/`, `examples/components/prd_dsl.rb`, anything the
> `streamweaver-doc-builder` skill produces — and convert them to org so they're
> readable on GitHub?

That's an **export** question, not an authoring question. It changes what matters:
the source of truth is an existing component tree, not a human's text file, and the
success criterion is "a reviewer on github.com understands this," not "a human can
hand-write it."

---

## Spike Results: org-ruby 0.9.12, Verified

Everything below was run against org-ruby 0.9.12 in a clean Ruby 3.3.6 environment.
Several June claims did not survive contact.

### Correction 1: org-ruby is NOT already installed

The June doc states org-ruby is "already installed in the StreamWeaver gem
environment" and repeats it as a headline advantage ("Already installed: ✅ org-ruby
0.9.12 present"). In a clean checkout that is false:

- Not in `stream_weaver.gemspec` (runtime or development dependencies)
- Not in `Gemfile`
- `require 'org-ruby'` raises `LoadError`

It was presumably present on the authoring machine via an unrelated gem. Adopting org
means **adding a new runtime dependency**. For contrast, `kramdown` and
`kramdown-parser-gfm` already *are* runtime dependencies — which matters for the
markdown-vs-org comparison below.

This doesn't kill the idea. It removes a thumb from the scale.

### Correction 2: the proposed parser code would have crashed

The June Phase-1 parser sketch reads body lines via `l.respond_to?(:line)` and
`l.line`. `Orgmode::Line` has **no public `line` method**. The verified accessor is
`to_s`:

```ruby
# Orgmode::Line own public methods (org-ruby 0.9.12) — no :line
[:assigned_paragraph_type, :begin_block?, :block_lang, :block_type, :blank?,
 :code_block?, :comment?, :output_text, :paragraph_type, :properties,
 :property_drawer_item, :table?, :table_row?, :table_separator?, ...]
```

Related trap: `Parser#lines` returns **raw `String`s**, not `Orgmode::Line` objects.
Structured lines are only reachable through `Headline#body_lines`. Any parser must go
headline-first.

### Correction 3: custom blocks are destroyed, not merely dropped

June's rule — "no custom `#+BEGIN_` blocks for content that must be readable on
GitHub" — is right but understated. The reality is harsher. Given:

```org
* Wireframe probe

#+BEGIN_SW_WIREFRAME
<div>hello</div>
#+END_SW_WIREFRAME
```

`body_lines` contains, in full:

```
heading1   "* Wireframe probe"
blank      ""
comment    "#+END_SW_WIREFRAME"     block_type=SW_WIREFRAME
blank      ""
```

The `#+BEGIN_` line and **the entire block content are gone from the line stream**.
Only the stray `#+END_` marker survives, as a comment.

This is the important escalation: the content isn't just unrendered on GitHub — it is
**invisible to StreamWeaver's own parser**, because org-ruby swallows it before we get
any access. Custom blocks aren't a degraded option, they're an unavailable one. Using
them would require pre-processing the raw text before handing it to org-ruby, or
forking the gem.

**Design rule, hardened:** every component's payload must live in a native org
construct — table, `#+BEGIN_SRC`, `#+BEGIN_QUOTE`, `#+BEGIN_EXAMPLE`, list, or prose.
No exceptions, because there is no fallback.

### Confirmed: the parts that work

| Capability | Verified behavior |
|---|---|
| `Parser#in_buffer_settings` | Hash of `#+KEY: value`; **arbitrary keys accepted** — `SW_THEME`, `SW_PILLS`, `EYEBROW` all parsed |
| `Headline#property_drawer` | Clean Ruby Hash, e.g. `{"SW_COMPONENT"=>"callout", "SW_VARIANT"=>"warning"}` |
| `Headline#tags` | `* Warning :callout:warning:` → `["callout", "warning"]` |
| `Headline#level` | Correct; but `headlines` is a **flat** array — nesting must be rebuilt from `level` |
| `Headline#body_lines` | Own headline + following lines, stopping at the next headline of *any* level (children excluded) |
| `Line#block_lang` | `#+BEGIN_SRC mermaid` → `"mermaid"`; content arrives as `:paragraph` lines between `:src` delimiters |
| Property drawers in `to_html` | **Emitted nowhere** — fully invisible on GitHub ✅ |
| Tags in `to_html` | **Stripped from the heading** — `* Warning :callout:warning:` renders as `<h1>Warning</h1>` ✅ |

### New finding: tags beat property drawers

June left this as Open Question #1 ("Property drawer vs tag syntax?") and leaned toward
drawers on semantic grounds. The spike settles it on evidence: **both are equally
invisible in GitHub's rendered output**, and tags cost one line instead of three.

```org
* Root cause                                    :callout:warning:
```
versus
```org
* Root cause
:PROPERTIES:
:SW_COMPONENT: callout
:SW_VARIANT: warning
:END:
```

Both render as a bare `<h1>Root cause</h1>`. Tags are terser in source, terser in
diffs, and native to Emacs' agenda/filtering. The tradeoff: tags are an unordered set,
so they carry a component *type* and simple flags well but can't express key-value
data (`SW_ID: architecture`, a recommended-option id, a chart's y-axis label).

**Proposed split:** tags for type + boolean-ish variants; property drawer only when a
component needs key-value parameters. Most doc components need only the former.

### New finding: don't use `to_markdown` as the GitHub path

org-ruby ships `Parser#to_markdown`, which looks like a shortcut to "org source of
truth, markdown for GitHub." It emits broken GFM tables — the separator row is dropped:

```
| Component   | Responsibility   |
| Enforcement | Require entry    |
| Sync script | Write state      |
```

No `|---|` line, so GitHub renders this as paragraph text, not a table. If we want
markdown output we emit it ourselves.

---

## The Mapping, Grounded in a Real Doc

Rather than design against a hypothetical, here's the component census of
`examples/components/prd_dsl.rb` — 385 lines, the canonical doc-builder reference:

| Component | Instances | Org target | Fidelity |
|---|---|---|---|
| `md` | 16 | prose | ✅ native |
| `doc_section_header` | 11 | `* Heading` (number derivable from position) | ✅ native |
| `code_block` | 7 | `#+BEGIN_SRC <lang>` | ✅ native |
| `table` | 5 | org table | ✅ native |
| `text` | 3 | prose | ✅ native |
| `callout` | 3 | `#+BEGIN_QUOTE` + `:callout:<variant>:` | ✅ native |
| `card` / `card_header` / `card_body` | 3 each | nested `** Heading` + body | ⚠️ layout flattens |
| `sidebar_toc` | 1 | *nothing* — GitHub derives its own TOC from headings | ✅ free |
| `doc_header` | 1 | `#+TITLE:` / `#+EYEBROW:` / `#+SW_PILLS:` | ✅ native |
| `mermaid` | 1 | `#+BEGIN_SRC mermaid` | ⚠️ source only, see below |
| `comparison` / `before` / `after` | 1 | two `**` sub-headings or a 2-column table | ⚠️ approximation |

**~85% of component instances map to native org with zero loss.** That is a genuinely
good result, and it's better than the plan case the June docs analyzed, because
editorial docs are mostly prose, tables, and code — exactly org's native surface.

`sidebar_toc` mapping to *nothing* is a quiet win: it's pure navigation chrome, and
GitHub already generates a heading-based TOC for org files. The component disappears
and the capability survives.

### Where it degrades

**Layout components.** This is the real gap, and the June docs never hit it because
they modeled plans as a flat sequence of semantic sections. Real StreamWeaver docs are
not flat. From `docs/streamweaver_canvas/glimmer_initial_final_layer.rb`:

```ruby
columns widths: ["50%", "50%"] do
  column do
    card do
      header3 "Why we skip the Glimmer gem"
      badge "Too heavy for Opal", color: :red
      div(style: "height:8px")
      md "Glimmer depends on **facets** — a massive Ruby utility library..."
```

`columns`, `column`, `card`, `div(style: "height:8px")`, `badge`, `grid`, `hstack`,
`vstack`, `scroll_box`, `sticky` — none have an org equivalent, and more to the point
**none have a GitHub equivalent**: GitHub's org rendering is a single linear column.
Side-by-side content becomes stacked content.

That's not a format failure, it's a medium difference, and it should be stated as
policy rather than papered over:

> **Export policy:** layout containers flatten. `columns`/`grid` emit their children in
> document order. `card` becomes a sub-heading. Spacer `div`s vanish. `badge` becomes
> inline bold or a tag. The exporter should *warn* on lossy flattening rather than
> silently produce a worse document.

**Mermaid.** GitHub natively renders mermaid in fenced blocks in **`.md` files only** —
org support predates that feature and doesn't participate. In `.org` a diagram is
readable source, not a picture. For a doc whose whole point is an architecture diagram,
that's a real loss, and it's the single strongest argument for a markdown backend.

**Interactivity.** Buttons, `select`, `expandable_card`, `theme_toggle`, charts fed
from state, Alpine-driven behavior — none of it round-trips. June flagged this
(Open Question #4) and the answer stands: export is a *document* snapshot, not a canvas
snapshot. Components with behavior should export their *content* and drop their
behavior, or refuse to export and warn.

---

## The Question the June Docs Didn't Ask: Why Org and Not Markdown?

June compared org against MDX and the Ruby DSL. It never compared org against plain
GFM markdown — which, for the goal *"view these docs on GitHub,"* is the obvious
competitor and wins on rendering:

| On GitHub | `.org` | `.md` |
|---|---|---|
| Headings, tables, lists, blockquotes | ✅ | ✅ |
| Code syntax highlighting | ❌ (`skip_syntax_highlight: true` is hardcoded in github/markup) | ✅ |
| Mermaid diagrams rendered | ❌ | ✅ native |
| Collapsible sections | ❌ | ✅ `<details>` |
| Task lists, footnotes, alerts | ❌ | ✅ |
| Invisible metadata channel | ✅ property drawers + tags | ✅ HTML comments |
| Parser already a project dependency | ❌ org-ruby is new | ✅ kramdown, kramdown-parser-gfm |
| Emacs/org-mode native tooling | ✅ | ❌ |
| Structured metadata is *parsed*, not conventional | ✅ drawers are a first-class API | ⚠️ HTML comments are a convention you hand-roll |

Markdown renders better on GitHub on every axis that isn't metadata. The honest
statement of org's advantage is narrower than June's "strictly better" verdict against
MDX suggests:

1. **Round-trip.** Property drawers are a real parsed structure with a real API. In
   markdown you'd invent `<!-- sw:callout variant=warning -->` and write the parser
   yourself. Workable, but it's a convention, not a format feature.
2. **Emacs.** If docs are meant to be lived in from org-mode, that's decisive and
   nothing else competes.
3. **Hierarchy + metadata together.** Org's headline tree carrying per-node properties
   is a genuinely better fit for a component tree than frontmatter-plus-prose.

If the goal is *only* "make our docs viewable on GitHub," markdown is the better
answer and it's cheaper. If the goal includes *"and load them back into a live
canvas,"* org earns its keep.

---

## The Recommendation: A Doc IR With Two Backends

The framing that resolves this: **the hard part isn't org syntax.** Emitting org from a
component tree is maybe 150 lines. Emitting markdown is another 120. The genuinely
hard, genuinely reusable work is the layer underneath both — walking a StreamWeaver
component tree and reducing it to a linear, semantic **document IR**:

```
StreamWeaver component tree  (Ruby DSL / canvas session)
            │
            ▼
      Document IR            ← the real work: flatten layout, drop behavior,
   (section, prose, table,     classify each node, warn on loss
    code, quote, figure,
    metadata)
            │
     ┌──────┴──────┐
     ▼             ▼
  org backend   markdown backend
     │             │
     ▼             ▼
  .org file     .md file
  (round-trips  (renders best
   back to SW)   on GitHub)
```

Why this ordering is right:

- The IR is where every hard decision lives (layout flattening, lossy-export warnings,
  behavior stripping). Both backends inherit those decisions instead of each
  re-litigating them.
- It defers the org-vs-markdown argument instead of resolving it prematurely. Ship
  whichever backend answers the immediate need; the second one is cheap.
- It makes the reverse direction tractable: **org → IR → StreamWeaver DSL** is the
  import path, and it reuses the IR vocabulary rather than inventing a parallel one.
- If markdown is ever the only backend anyone uses, we've spent ~120 lines finding
  that out, not a whole org integration.

---

## So What Does "Expand the Org Mode Parser" Actually Mean?

Directly, because this was the premise worth testing: **mostly, it doesn't need
expanding.** The work splits into three tiers, and only one is a parser problem.

**Tier 1 — nothing to build.** Headings, prose, tables, `#+BEGIN_SRC`, `#+BEGIN_QUOTE`,
`#+BEGIN_EXAMPLE`, lists, in-buffer settings, property drawers, tags. org-ruby parses
all of it today, verified above. This covers ~85% of a real doc.

**Tier 2 — a dispatcher, not a parser.** Mapping `SW_COMPONENT`/tags onto StreamWeaver
components, rebuilding the headline tree from flat `level` values, extracting table
rows from `:table_row` lines, pulling code out from between `:src` delimiters. This is
consumption of data org-ruby already hands us. It's the ~150-line "OrgParser" from
June's Phase 1 — accurately described as a **dispatch layer over org-ruby**, and it
should be named that way so nobody goes looking to modify the gem.

**Tier 3 — genuinely blocked.** Anything needing a construct org-ruby doesn't model:
custom `#+BEGIN_SW_*` blocks (content destroyed, per Correction 3), nested/side-by-side
layout, inline component references mid-paragraph. Options here are pre-processing the
raw text before org-ruby sees it, or forking the gem. **Recommendation: don't.** Design
Tier 3 out of the format instead — it's the same conclusion June reached, now with a
sharper reason (the content is unreachable, not merely unstyled).

The practical upshot: budget for a dispatcher and an emitter, not for parser surgery.

---

## Suggested Phasing

Ordered so the first phase is independently useful and the org-vs-markdown decision
stays open as long as possible.

| Phase | Work | Notes |
|---|---|---|
| 1 | **Document IR + tree walker** | The real work. Layout flattening rules, lossy-export warnings, behavior stripping. Independently useful. |
| 2 | **Markdown backend** | Cheapest path to "viewable on GitHub." No new dependency. Mermaid and highlighting render. Validates the IR. |
| 3 | **Org backend** | Adds round-trip capability and Emacs. Requires adding `org-ruby` to the gemspec. |
| 4 | **Org → IR → SW dispatcher** | The import path. `streamweaver serve plan.org`. Tier 2 above. |
| 5 | **CLI wiring + fixtures** | `canvas-export --format org\|md`, round-trip tests over `examples/components/prd_dsl.rb`. |

June's estimate was 4–5 sessions for the org-only path. This is comparable in total but
front-loads the reusable half, and phase 2 delivers the stated goal — docs viewable on
GitHub — before any dependency is added.

---

## Open Questions

1. **Is the goal viewing, or round-tripping?** This determines whether phase 3 happens
   at all. If nobody will ever load a doc back into a canvas, markdown alone is the
   whole project.
2. **What's the export source — DSL file or live canvas?** Parsing `prd_dsl.rb`
   statically is a Ruby AST problem. Exporting a live canvas session means instrumenting
   the render pass to capture the component tree. The latter is more faithful and
   probably easier; it also matches the existing "Save as doc" flow.
3. **Round-trip fidelity target.** Is `SW → org → SW` expected to be lossless for the
   Tier 1 subset? Worth committing to explicitly, because it's testable and it
   constrains the format.
4. **Does flattening `columns` produce an acceptable document?** Worth answering
   empirically before building: hand-convert `glimmer_initial_final_layer.rb` (the
   layout-heaviest doc in the repo) and look at it on GitHub. Cheap experiment, and it
   de-risks the whole layout-flattening policy.
5. **Numbered sections.** `doc_section_header "01", ...` carries an explicit number.
   Org derives numbering from position. Round-tripping a doc whose numbers are
   non-sequential (or intentionally skipped) needs either `SW_NUMBER` in a drawer or a
   decision that numbering is presentational.

---

## Verdict

The mapping is real and the fidelity is better than the June analysis predicted for
docs specifically — 85% native coverage, with `sidebar_toc` disappearing for free.

Three things should change from the June plan: org-ruby is a **new dependency**, not a
free one; the "custom blocks are dropped" constraint is stronger than documented
(content is unreachable by our own parser, so design around it absolutely); and
**tags are the better metadata carrier** than property drawers for the common case,
which the spike settles with evidence.

The strategic adjustment is to stop treating this as "an org feature." It's a document
export capability that happens to have org as one of two sensible backends — and for
the goal as stated, *viewing docs on GitHub*, markdown is the backend that renders
better and costs less. Build the IR first, and the choice stops being a fork in the
road.

---

*Spike-verified against org-ruby 0.9.12 / Ruby 3.3.6. Component census from
`examples/components/prd_dsl.rb`. GitHub rendering behavior per `github/markup`'s
pinned invocation (`allow_include_files: false`, `skip_syntax_highlight: true`).*
