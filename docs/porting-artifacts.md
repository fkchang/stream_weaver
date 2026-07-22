# Porting a Claude Artifact into StreamWeaver

A repeatable process for reproducing a claude.ai-hosted Artifact (or any
rich static HTML/CSS document) as a StreamWeaver app at high visual
fidelity, and for feeding what you learn back into the framework. Proven
on `examples/components/design_review_dsl.rb` / `design_review.css` (a
six-option design-review document with option cards, chips, a comparison
matrix, and a checklist split) -- see that pair, plus the `doc-parity`
example bundled in the `streamweaver-visual-companion` skill, for two
different genres this process has produced.

This is a process doc, not a tutorial -- it assumes familiarity with
`docs/theming-hooks.md` (the sw- hook contract) and the component/DSL
vocabulary in `lib/stream_weaver/display_dsl.rb`.

## The steps

### a. Fetch the artifact HTML, strip the frame-runtime preamble

A claude.ai Artifact page is served inside a "frame-runtime" wrapper: a
large minified script handling theme sync with the parent claude.ai
shell, scroll-position restore, link-click interception, MCP capability
proxying, and an RTC lockdown. None of that is the authored content --
it's platform plumbing for embedding the page in an iframe. The authored
document always starts at the page's own `<title>` tag and the `<style>`
block that follows it. Locate that boundary before doing anything else;
everything above it is safe to ignore entirely.

### b. Dissect into a rendering-capability checklist

Read the authored `<style>` block and body once, closely, and produce two
things:

1. **Exact palettes.** Transcribe every custom property in both the light
   and dark color sets verbatim (hex values, not approximations) -- these
   become CSS custom properties in your own port, prefixed to avoid
   collision with StreamWeaver's own `--sw-*` tokens (this port used
   `--ad-*`; pick a prefix tied to the artifact's subject, not
   StreamWeaver's).
2. **A numbered checklist of rendering techniques**, not a prose
   description -- "bordered callout with colored left accent + mono
   kicker label", "option card: badge + title/subtitle + optional
   pinned tag + wrapping chip row", "checklist tile: bordered card with
   fixed-width colored glyph column", etc. Each item should be scoped
   tightly enough that step (c) can answer "component, CSS, or gap?" for
   it individually. The design-review port used 15 such items.

### c. Gap-assess against the component vocabulary

For each checklist item, check in this order:

1. `docs/theming-hooks.md` -- does an existing component already emit a
   stable `sw-` hook you can restyle? (Coverage note: that doc lists the
   structural components; the doc-component family -- `doc_header`,
   `doc_section_header`, `callout`, `columns`, `markdown` -- also emits
   stable hooks not yet listed there (stream_weaver-d11). When a component
   is missing from the doc, read the classes the adapter actually emits.)
2. The doc/component family (`doc_header`, `doc_section_header`,
   `callout`, `card`/`card_header`/`card_body`, `table`, `comparison`,
   `columns`/`column`, `status_dot`, `badge`) -- proven to reach 1:1
   Artifact parity for editorial documents (`doc-parity-example`).
3. A prior parity slice (`examples/parity/tyrion_warroom_components.rb`)
   for anything board/lane/topbar/navbar-shaped.
4. Only if none of the above expresses it: `wireframe`/`wireframe_block
   (html:)` for raw HTML/SVG passthrough. This is a last resort, not a
   starting point -- see the "sanctioned escape hatches inside existing
   components" note below before reaching for it.

**Sanctioned escape hatches inside existing components, short of
`wireframe_block`:**

- `table(..., markdown: true)` renders each cell's markdown-processed
  HTML *raw* -- already used by the framework to turn `[text](url)` into
  `<a>` tags. A cell that needs a colored status dot or any other small
  inline markup (not achievable through the table's own options) can emit
  that markup directly as a string, e.g. a rating cell built from
  `%(<span class="sw-status-dot sw-status-dot-green sw-status-dot-sm">
  </span>#{value})`. This is a real, intentional feature of `Table`, not
  a workaround -- prefer it over `wireframe_block` for anything
  table-cell-shaped.
- A `card_header`/`callout`/any container's block accepts arbitrary DSL
  calls as extra children, rendered after that component's own built-in
  fields. Use this to add a pinned corner badge, a markdown-rendered
  subtitle (see gap notes below on why `card_header`'s own `meta:` can't
  hold markdown), or any other small addition -- then position it with
  CSS rather than fighting the DSL for a parameter that doesn't exist.

### d. Port via the shared-DSL pattern + one unlayered CSS file

Follow `prd_dsl.rb`/`prd_demo.rb`'s split:

- `<name>_dsl.rb` -- a bare DSL body (no `app` wrapper), safe to load via
  `instance_eval` from either a standalone demo or `canvas-push`. Caveat:
  the canvas bridge currently injects only master-theme CSS, so a port
  whose look lives in its own stylesheet renders on a canvas as correct
  structure without the re-skin (stream_weaver-9uk) -- the standalone demo
  is the faithful rendering until that lands or the genre's vocabulary is
  promoted into a theme (step g).
- `<name>_demo.rb` -- the standalone wrapper.
- `<name>.css` -- **one** stylesheet, targeting only the `sw-` hooks
  documented in `docs/theming-hooks.md` plus your own invented classes for
  the handful of elements with no dedicated component.

Every framework-emitted style lives in `@layer stream-weaver` (since
stream_weaver-oeo), so a plain unlayered stylesheet always wins,
regardless of selector specificity or `<head>` document order. There is
no specificity fight to plan around -- write the CSS you want the
rendered page to have, full stop.

**The chrome-neutralization recipe.** StreamWeaver's default chrome wraps
app content in `body.sw-layout-default` (caps width, adds padding) plus a
child `#app-container` div that paints its *own* background/border/shadow
from theme tokens (`--sw-color-bg-card`, etc.). If your port's content
column is meant to be the *entire* page (an editorial document, not a
dashboard with chrome around it), both of those need neutralizing or
they'll show through as a visible "card within a card" boundary and can
silently reintroduce the base theme's own light/dark palette underneath
your own:

```css
body[class*="sw-layout-"] {
  max-width: none;
  padding: 0;
  background: var(--your-bg-token);
}
#app-container {
  background: transparent;
  padding: 0;
  margin: 0;
  border: none;
  box-shadow: none;
  border-radius: 0;
  max-width: none;
}
```

Let your own top-level wrapper div (e.g. `.ad-doc`) become the sole
layout/background authority: its own `max-width`/`margin: 0 auto`/padding
replaces what `body`/`#app-container` used to provide.

**A related gotcha worth checking early:** if your port uses
`app(...) do ... end` (the top-level convenience wrapper) with a local
`stylesheets:` path, `App#script_dir` resolves to the wrapper's own call
site inside `lib/stream_weaver.rb`, not your script -- the local-file
auto-detection raises `ArgumentError: ... resolves outside the app's
script directory`. Use `StreamWeaver::App.new(...) do ... end` +
`App.generate.run!` directly (the pattern
`examples/parity/tyrion_warroom_components.rb` already uses), with an
explicit `assets_dirs: [__dir__]` -- the top-level helper's fixed kwarg
list has no `assets_dirs:` param at all, so this isn't optional once
`stylesheets:` points at a local file.

### e. Main-thread browser verification against the reference -- never builder self-assessment

The agent that builds the port should verify the server renders without
exceptions (boot it, curl it, grep the response for the structural
markers you expect, kill the boot). It should **not** be the one to judge
visual fidelity. A builder that wrote the CSS is the worst-positioned
reviewer of whether it actually looks right -- render a page confidently
wrong and re-reading your own rules won't catch it. Visual sign-off needs
a separate pass, on the main thread, with both the port and the original
artifact open side by side, in both light and dark mode.

Two sharp edges specific to this workflow:

- `playwright-cli` (and most headless browser tooling) blocks `file://`
  navigation by default. Serve the reference artifact HTML over a real
  origin instead: `ruby -run -e httpd <dir-containing-the-html> -p <port>`
  from Ruby's stdlib, no extra gem needed.
- Verify `location.href` in the browser before trusting a screenshot --
  a stale tab left open from a prior round, or a redirect, will silently
  screenshot the wrong page. Similarly, dark-mode toggles that persist
  their preference to `localStorage` will carry a prior round's choice
  into the next one -- clear it (or use a fresh browser context) before
  comparing light mode again, or you will spend time debugging a "bug"
  that's actually stale toggle state.

### f. File framework gaps as bugs; fix at the app level first

A port will surface real gaps -- places where an existing component is
missing a `class:`/`style:` passthrough, has no per-row/per-item
modifier hook, or where a convenience wrapper (like the top-level `app`
helper above) breaks under a combination of options nobody had hit
before. File each one as its own issue (this port's run filed
stream_weaver-0n6, stream_weaver-mcn, stream_weaver-rhi, and
stream_weaver-t37) rather than silently working around it and moving on
-- the workaround belongs in the port either way (you can't block a port
on a framework fix), but the gap needs to be visible to whoever plans the
next promotion pass. Examples from this port:

| Gap | Component | Workaround used |
|---|---|---|
| No per-row `class:`/tone hook | `Table` | Rely on the "pick" row being deterministically last (`tr:last-child`) |
| No `class:`/`style:` passthrough | `Callout` | Wrap in a scoping `div` + descendant-selector CSS |
| `meta:` renders escaped plain text, no markdown | `CardHeader` | Render the subtitle as an extra block child through `md` instead |
| `stylesheets:` + top-level `app()` helper resolves `script_dir` wrong | `App` / top-level `app()` | Use `StreamWeaver::App.new` directly with `assets_dirs:` |

### g. The promotion pass -- this is where token savings actually come from

Be honest about the economics before claiming a port was cheap. This
port's `design_review.css` + `design_review_dsl.rb` totals roughly 36.5KB
of Ruby+CSS against the source artifact's 37.3KB of authored HTML+CSS --
essentially 1:1, not a savings. That's expected: the artifact's palette,
type pairing, chip/card idiom, and layout are all *bespoke to that one
document*, so nothing in this port's CSS was reusable from an existing
theme -- every rule had to be written fresh. Compare that to the
`doc-parity-example` port, which reached the same 1:1 visual fidelity at
roughly a 6x size reduction, because it could lean on the already-built
`:doc` theme (Charter serif, compact editorial spacing, `--sw-color-*`
tokens) almost as-is and only needed a handful of component calls on top.

The lesson: a single port's cost is dominated by however much of its
visual vocabulary is genuinely new. The savings show up the *second*
time a similar genre gets ported -- if, and only if, someone takes the
promotion step of pulling the recurring parts (the chip pattern, the
pick-state idiom, the checklist-tile pattern, the chrome-neutralization
recipe above) out of the one-off app CSS and into either a registered
theme (`StreamWeaver.register_theme`) or genuinely new components. Budget
for this as a distinct follow-up step, not something that happens for
free as a side effect of shipping the first port. Until it happens, treat
"tokens saved vs. hand-authoring the HTML" as *prose-only* savings (you
still write the artifact's text once, not twice) rather than a savings on
the surrounding visual machinery.

### h. Add the pair to the visual-companion skill gallery

Once a port is genericized (see below) and verified, copy the DSL/demo/CSS
trio into
`lib/stream_weaver/skills/streamweaver-visual-companion/examples/` so it
ships with the skill (duplicated, not symlinked, so the skill stays
self-contained if packaged separately -- see that directory's existing
files for why). Add one line to that skill's `SKILL.md` gallery index
naming the genre and the techniques it proves out, so a future session
can tell at a glance which example is the closer starting point for a new
request.

## A note on genericizing content before it ships

If the artifact you're porting contains anything personal or
organization-specific (real names, an employer, an internal tool's real
name, a personal design-philosophy framework), rewrite it as
fictional-but-plausible content *before* committing -- same standard
`prd_dsl.rb` already holds itself to (invented company, invented author).
Preserve every visual pattern exactly (same number of option cards, same
chip dimensions per card, same table shapes, same checklist tile count) --
only the words change. Rename the example's own files at the same time if
their name was content-derived (an artifact literally about "agent
discovery" produced `agent_discovery_*` files; once genericized to a
fictional product, the files were renamed to the genre-based
`design_review_*` to match how `doc-parity-example` is named after its
*genre* -- a document proving Artifact-grade doc parity -- not its
original PRD's subject matter).
