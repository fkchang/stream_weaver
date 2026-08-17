# StreamWeaver Doc Viewer (browser extension)

Renders StreamWeaver docs on GitHub the way they look when run, instead of as
raw source — for viewers who have neither StreamWeaver nor Ruby installed.

**Status:** working, verified live against real github.com. Renders both
`.rb` (DSL source) and `.org` (the roundtrippable export) docs.

## Build and load

```bash
bin/vendor_browser_assets   # once -- fetches mermaid, which is too large to commit
bin/build_extension         # assembles extension/vendor/ (~7MB)
```

Then in Chrome: `chrome://extensions` → enable **Developer mode** → **Load
unpacked** → select this directory. Open any StreamWeaver doc on GitHub; a
**View rendered** button appears in the file toolbar.

`extension/vendor/` is generated and gitignored. Re-run `bin/build_extension`
after changing anything under `lib/`, or the extension keeps rendering with the
old runtime. Reloading the extension in `chrome://extensions` does not update
content scripts already injected into tabs that were open before the reload —
hard-refresh any open GitHub tab after reloading, not just re-click the button.

## How it works

```
GitHub blob page
   │  content.js reads the file from GitHub's embedded JSON (no network),
   │  checks the first 10 lines for the .rb stamp or the .org header marker
   ▼
"View rendered" button → source into chrome.storage.session
   │  background.js opens the viewer tab
   ▼
viewer.html   extension APIs: reads the stashed source, hands it over,
   │          unhides the sandbox iframe *before* asking it to render
   ▼
sandbox.html  compiles the Ruby (converting .org to DSL text first, if
              that's what came in) and renders it
```

**Detection is by content, not filename.** `.rb` docs carry `DocStore`'s
`# streamweaver-doc: v1` stamp; `.org` docs carry their own
`#+STREAMWEAVER_DSL: 1` header keyword (a real org keyword, not a
StreamWeaver invention — see `docs/superpowers/specs/2026-08-13-org-doc-format-design.md`).
Both travel with the file through forks and moves, where a path or extension
rule would not. Not gists, currently — those live on `gist.github.com`,
which `manifest.json`'s `content_scripts` doesn't match; the marker would
travel there fine, the extension just doesn't run on that page yet.

**Two formats, one runtime.** `StreamWeaver::Org::Reader` (org → DSL text
only, not `Writer` — `Writer` needs `ripper`, which isn't Opal-compatible,
and the extension only ever *reads* `.org`, never writes it) is bundled into
`sw-runtime.js` alongside the rest of the framework. `sandbox.js` detects
`.org` content by its header marker and runs it through `Reader.to_dsl`
before compiling — the exact same org → DSL → render path `canvas-read` uses
server-side, just client-side here.

**Why two pages.** Rendering means compiling Ruby in the browser, and the
compiler's output has to be evaluated. Manifest V3 pins extension pages to
`script-src 'self'` and rejects `unsafe-eval` there, so the work cannot happen
in `viewer.html`. A sandboxed page is the one place MV3 permits it. The cost is
that the sandbox has a null origin and no extension APIs, so `viewer.html` does
the storage read and passes the source in by `postMessage`.

**`chrome.storage.session` needs an explicit access grant.** It defaults to
trusted contexts only (extension pages, the service worker) — a content
script injected into github.com is untrusted for that API by that policy
alone, regardless of same-extension origin. `background.js` calls
`chrome.storage.session.setAccessLevel({accessLevel: "TRUSTED_AND_UNTRUSTED_CONTEXTS"})`
once at startup; only the service worker can grant this, `content.js` can't
opt itself in.

**Everything is local.** MV3 forbids remote script outright, so mermaid, Prism,
marked, morphdom and jsdiff are all bundled. A render makes zero network
requests — verified once in a manual headless Chromium run with all HTTP
blocked (no committed automated test covers this yet; see Known gaps).

**Heredocs are rewritten before compiling.** Opal's self-hosted parser cannot
lex heredocs in any form, while the MRI-hosted compiler handles them fine. Doc
bodies are full of them, so `sw-heredoc-rewrite.js` converts them to quoted
strings first. Without that step, in-browser compilation fails on essentially
every real document.

**`#app-container`, not `#sw-app`, and region divs get unwrapped.** A lot of
`:doc`-theme CSS (sidebar_toc's sticky grid layout, doc_header's chrome
removal) is scoped to `body[class*="sw-layout-"] > #app-container`, matching
the server-rendered shape exactly — using a different mount id/no layout
class would silently drop all of that. `OpalRuntime#render_html` (shared with
the live/interactive runtime) also wraps every top-level component in
`<div id="sw-region-N">` for morphdom patching, which the sandbox never uses
(`SWRuntime.start()` is deliberately never called for a static doc view) but
which breaks the CSS's `> .foo` direct-child selectors regardless —
`unwrapRegions()` in `sandbox.js` removes the now-pointless wrappers after
render rather than weakening those selectors for every other host.

**Opal's `\A`/`\z` anchors don't translate in runtime-built regexes.** A real
Opal compiler bug, not specific to this codebase: `\A`/`\z` only become JS's
`^`/`$` for a regex *literal* known at compile time — any regex built at
runtime (interpolation, `Regexp.new`) passes them through unrecognized, so
they silently match nothing. `lib/stream_weaver/opal/regexp_anchor_patch.rb`
patches this, compiled into `sw-runtime.js` immediately after `opal` (see
`bin/build_extension`'s comment on why the position in the build sequence
matters — every compiled file captures its own local reference to the
function it patches, at load time).

**Mermaid needs a real paint before it measures.** `viewer.html`'s sandbox
iframe starts `hidden`; unhiding it happens *before* `sandbox.js` is asked to
render (not after), since mermaid measures real DOM layout (`getBBox` etc.)
to position diagram nodes, and a hidden ancestor makes those measurements
come back `NaN`. Even so, `postMessage` IPC between the extension's separate
frames has enough latency variance that "frame unhidden" and "mermaid
measures" aren't strictly ordered by wall clock alone — `sandbox.js` wraps
the mermaid call in a double `requestAnimationFrame` as a wall-clock-
independent guarantee ("the browser has completed a real layout+paint pass")
instead of relying on message-ordering luck.

**Docs render inert.** The viewer uses `SWRender.html()` rather than starting
the live runtime — there is nothing to interact with in a document, so it skips
event delegation and the re-render loop.

## Verified

Against a real repo (`github.com/fkchang/streamweaver-doc-demo`), live, both
`demo.rb` and `demo.org`: doc_header, sidebar_toc, callouts (all variants),
tables, a comparison block, code blocks with syntax highlighting, cards, and
mermaid diagrams (sequence + graph) all render correctly and identically
between the two formats.

Also verified in headless Chromium against `examples/components/prd_dsl.rb`
(385 lines, 17 heredocs) with all HTTP blocked: 27 headings, 5 tables, 7 code
blocks, 11 TOC links, 3 callouts, 1 typeset mermaid SVG, 200 Prism tokens, 0
network requests, 0 page errors. Detection checked against a real captured
GitHub blob page: a plain `Rakefile` gets no button; the same page with
stamped content does.

## Known gaps

- **No committed automated test for the extension itself.** Everything under
  "Verified" was checked manually (headless Chromium runs, live github.com).
  `spec/` has no extension coverage and `bin/browser_smoke` covers the canvas
  parity slices, not this. A real gap — this is the part most likely to
  silently regress.
- **No icons.** Chrome falls back to a default.
- **Toolbar anchor is a guess.** `mountButton` tries several selectors and
  falls back to a floating button. GitHub reshuffles this markup regularly —
  this is the part most likely to need attention over time, and the reason the
  viewer is its own page rather than injected into GitHub's.
- **Private repos** work through the embedded-JSON path, since the page is
  already authenticated. The `raw.githubusercontent.com` fallback would need a
  token.
- **Bundle is ~7MB**, mostly mermaid (3.5MB) and the compiler + runtime
  (3.7MB). Fine from local disk; it is never downloaded per page.
- **`.rb` detection is content-heuristic-only in the CI/local-tooling paths**
  (`doc_header(`/`sidebar_toc(`/`use_theme :doc`) — the extension itself uses
  `DocStore`'s real stamp. No known gap in the extension specifically; noted
  here because a dedicated `.rb` marker convention (mirroring `.org`'s) would
  still be a nice simplification if one lands upstream.
