# StreamWeaver Doc Viewer (browser extension)

Renders StreamWeaver docs on GitHub the way they look when run, instead of as
raw source — for viewers who have neither StreamWeaver nor Ruby installed.

**Status:** working, verified live against real github.com and real gists on
gist.github.com. Renders both `.rb` (DSL source) and `.org` (the
roundtrippable export) docs, on either host.

This is the viewer half of [StreamWeaver](../README.md), a small Ruby DSL
that compiles to full-styled docs (sidebar nav, callouts, tables, Mermaid
diagrams) instead of raw HTML/JS. A doc pushed to GitHub or a Gist without
this extension still degrades gracefully — `.org` already renders close to
markdown there — but this extension is what makes either format render
exactly as designed, entirely client-side, no StreamWeaver or Ruby install
required to view.

## Install

Most people just want to view docs: install from the
**[Chrome Web Store](https://chromewebstore.google.com/detail/streamweaver-doc-viewer/odjjednfpfiagefgpcfdlelldphmpcgj)**
— one click, no build step. The steps below are the dev path, for
contributors building the extension from source.

## Build and load

```bash
bin/vendor_browser_assets   # once -- fetches mermaid, which is too large to commit
bin/build_extension         # assembles extension/vendor/ (~7MB)
```

Then in Chrome: `chrome://extensions` → enable **Developer mode** → **Load
unpacked** → select this directory. Open any StreamWeaver doc on GitHub; a
**View rendered** button appears in the file toolbar.

## Shipping an update

Live on the Chrome Web Store with real users -- an update needs a version
bump (the store rejects a re-upload at the same version) and a clean
package, not just a rebuild:

```bash
bin/package_extension   # bumps version (patch/minor/major), rebuilds, zips
```

Then the manual console steps: `chrome.google.com/webstore/devconsole` →
Package → upload the new zip → Submit for review. See the
`streamweaver-extension-ship` project skill for the full checklist
(tests-first, store-listing updates, the version-bump commit), and
`store-listing.md` for exact Privacy-tab field text and screenshot assets.

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
rule would not, and both travel to gists too (see "Gist support" below).

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

**`<base target="_blank">` hijacks same-page fragment links too, not just
outbound ones — fixed at the cause, not just for `sidebar_toc`.** That base
tag exists so a doc's own outbound links (a markdown link to some other
site) don't navigate this frame in place. But a `<base target>` applies to
*every* link on the page without its own `target`, including a bare
`<a href="#id">` — `sidebar_toc`'s links, or a hand-written
`[text](#anchor)` inside an `md` block. Without something to intercept the
click, it inherits `target="_blank"` and tries to pop itself open in a new
tab instead of scrolling, which then gets blocked — reproduced live as a
genuine `ERR_BLOCKED_BY_CLIENT` navigation error, not a hypothetical.
`sandbox.js` now installs one delegated `click` listener for every
`a[href^="#"]` that scrolls the target into view instead, covering any
fragment link a doc produces, not only `sidebar_toc`'s.

**`sidebar_toc` additionally gets real scroll-spy highlighting, which the
delegated handler above doesn't provide on its own.** `Adapter::Opal#
inject_sidebar_toc_assets` skips loading `sw-sidebar-toc.js` (the
`IntersectionObserver`-driven active-link tracking) server-side — fine for
`opal-build`'s standalone HTML output, since a bare anchor still scrolls
there once the fix above exists everywhere; not fine for actually knowing
which section is active while scrolling, which needs the real script.
`bin/build_extension` bundles it the same way it already bundles
`sw-heredoc-rewrite.js`; the script exports `window.swInitSidebarToc` for
exactly this case (a host with no htmx to re-trigger it via a real
`htmx:afterSwap` event), and `sandbox.js` calls that directly right after
injecting the rendered doc.

**Mermaid diagrams are not the same story — bundling `sw-mermaid-zoom.js` is
not optional the way `sw-sidebar-toc.js` is.** `Adapter::Static#render_mermaid`
(shared by both adapters) writes each diagram's source into a
`data-sw-mermaid-code` attribute rather than element text, and only
`sw-mermaid-zoom.js` reads that shape — there is no bare-markup fallback the
way a plain `<a href="#anchor">` still scrolls without scroll-spy. A host
that skipped bundling it would render an empty box per diagram, not a
degraded-but-working one. `bin/build_extension` bundles it unconditionally,
the same way it bundles `sw-sidebar-toc.js`, and `sandbox.js`'s
`runMermaidWhenPainted()` calls `window.swMermaidInit()` after each render
(wrapped in the same double-`requestAnimationFrame` paint guard the old
direct `mermaid.run()` call needed, for the same hidden-iframe layout
reason described above). `lib/stream_weaver/opal/builder.rb` bundles it the
same way for `opal-build`'s standalone HTML output, which hits the same
shared markup and would otherwise regress identically.

## Local-file preview (no GitHub, no server)

`viewer.html` has a second way in besides the GitHub button: a drop zone /
file picker, built into the same page, for previewing any `.org` or `.rb`
file straight off disk. No GitHub page, no server, and — once the file is
read — no extension APIs either. It feeds the exact same
`postMessage({type: "sw:render", ...})` call into `sandbox.js` that the
GitHub flow uses, so `sandbox.js` needed zero changes; this is purely a
second supplier wired into `viewer.js`, the same way `content.js` is the
first.

**Two independent signals decide which mode `viewer.js` starts in**, because
they catch two different situations:

- **No `chrome.storage.session` / `chrome.runtime` at all** — this page was
  opened completely outside the extension: a bare `file://` open, or a plain
  `http://` page (a real Chromium quirk worth naming: `window.chrome` and
  even `chrome.runtime` exist as stub objects on ordinary pages, but
  `chrome.storage` does not — the check tests for `chrome.storage.session`
  specifically, not just `typeof chrome`, or every non-extension page would
  incorrectly look like extension context). There is no session storage to
  read regardless of what's in the URL, so this alone is enough to pick the
  drop zone. This is also *why* the drop zone had to be inline on
  `viewer.html` rather than a separate page: re-verifying this feature needs
  to work by opening a bare file or a throwaway local server, not by loading
  the packed extension into a real Chrome UI every time.
- **`chrome` APIs exist but no `key` query param** — inside the extension,
  but opened without a doc handed to it (bookmarked, or opened fresh from
  `chrome://extensions`). `content.js` always sets a key today, but nothing
  enforces that, so this page degrades to something useful instead of a
  dead-end "No document key" error.

A `key` that *is* present but fails to resolve (an expired or
already-consumed `chrome.storage.session` entry) stays a hard error rather
than falling back to the drop zone — that case means a doc *was* specified
and is now gone, worth surfacing distinctly from "nothing was ever
specified."

**The drop zone is inline on `viewer.html`, not a separate page.** The design
doc left this open; extending the existing page won this over a second page
mostly for the reason above (bare-file testability) but also because it's
the simpler change — one page, one script, one set of `sw:render`/
`sw:rendered`/`sw:render-failed` handlers, instead of duplicating the
sandbox-iframe wiring a second time.

**Validation is by file extension, not content-sniffed.** Unlike the GitHub
path's content-based `#+STREAMWEAVER_DSL:`/stamp detection (which exists to
survive forks and renames), a locally picked file has no ambiguity about
"is this the doc I meant to open" — the user just chose it. `handleFile()`
in `viewer.js` rejects anything not matching `/\.(org|rb)$/i` with an
inline error and leaves the drop zone open to try again, rather than
attempting to render arbitrary text and failing deep inside the Opal
compiler with a confusing message.

**A CSS trap worth naming for anyone touching this again:** `#drop-zone`'s
layout rule was originally a bare `#drop-zone { display: flex; ... }`. An ID
selector outranks the browser's built-in `[hidden] { display: none }` rule
by specificity, so `dropZone.hidden = true` in `viewer.js` was setting the
attribute correctly while the element stayed visually flexed anyway — caught
live (the drop zone kept showing through a fully rendered doc) rather than
by inspection. Fixed by scoping the rule to `#drop-zone:not([hidden])`
instead.

## Gist support

`manifest.json`'s `content_scripts.matches` also lists
`https://gist.github.com/*`, a second origin alongside `github.com`. Once
there, `content.js` feeds the exact same `handleClick(source, name)` →
`chrome.storage.session` → viewer/sandbox pipeline described above — gist
support is entirely a `content.js`/`manifest.json` change, no renderer code
touched.

**A gist page's DOM is not a blob page's DOM, confirmed by inspecting a real
one, not assumed.** Two things a blob page relies on don't hold on a gist:

- **No embedded-JSON payload.** A blob page's `rawLinesFromPage()` finds the
  whole file in a `script[type="application/json"]` block; a gist page's
  equivalent scripts carry only UI chrome (locale, feature flags, a keyboard-
  shortcuts doc URL) — never file content.
- **A rendered `.org` file's raw text isn't in the DOM at all.** GitHub
  renders `.org` into formatted prose the same as it does on a blob page, but
  a gist page has no code-view fallback showing the raw source underneath —
  the `#+STREAMWEAVER_DSL: 1` marker line is gone from the page entirely once
  rendered. (An `.rb` gist, by contrast, syntax-highlights line-by-line in an
  old-style `table.highlight`, which *does* keep the raw stamp visible in the
  DOM — but relying on that would mean two different scraping strategies for
  the two formats, one of them tied to markup GitHub could swap out. Fetching
  the Raw link works for both, so that's the only path this uses.)

So gist detection always fetches: each file on a gist page lives in its own
`.file` block with its own `.file-actions` toolbar containing a Raw link
(`gist.github.com/.../raw/<sha>/<name>`, which 301s to
`gist.githubusercontent.com/.../raw/<sha>/<name>`) — confirmed against a real
multi-file gist, not assumed, so a single-file gist (exactly one `.file`
block) and a multi-file gist take the same code path. `gistFileBlocks()`
collects `{file, actions, name, rawUrl}` for every file block; `scanGistPage()`
fetches each Raw URL, runs the fetched text through the same
`isStreamWeaverDoc()` check as everything else, and mounts a button into that
file's own `.file-actions` (falling back to a floating button only if that div
is missing) — so a gist with, say, an `.org` doc next to an unrelated `.rb`
script gets exactly one button, on the matching file. Each `.file` block gets
a `data-sw-scanned` marker the moment its fetch starts, not when it resolves —
the mutation observer that re-triggers `scan()` on every DOM change would
otherwise be able to fire a second fetch for the same file during the async
gap before the first one finishes.

**`gist.githubusercontent.com` needed its own `host_permissions` entry, and a
content-script `fetch` to it works despite gist.github.com's own page CSP
forbidding that exact host.** `raw.githubusercontent.com` was already listed
for the blob-page fallback; the gist Raw link's redirect target is a
different host, so it's now listed too. The CSP part is worth naming because
it looked like it should fail: `gist.github.com`'s page CSP `connect-src`
allows `raw.githubusercontent.com` but not `gist.githubusercontent.com` — a
plain unprivileged `fetch()` run as page script hits exactly that wall
(confirmed with a direct test). But `content.js`'s `fetch()` is a *content
script's* fetch, not the page's, and a host listed in `host_permissions`
lets it reach that host regardless of the page's own CSP — confirmed by
watching the real network log during a live click-through: a 301 from
`gist.github.com/.../raw/...` to `gist.githubusercontent.com/.../raw/...`,
then a 200 with the full doc body.

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

The local-file entry point was verified with the same rigor that applies
everywhere else in this file: a real `.org` doc (an incident-report fixture with
doc_header, sidebar_toc, two callout variants, two tables, two mermaid
diagrams, code blocks, and in-page anchor links) and its `.rb` twin, both
picked through `#file-input` against `viewer.html` served over a throwaway
local HTTP server (bare `file://` hits an unrelated Chromium restriction —
sandboxed null-origin iframes can't load `file://` resources, which would
have blocked `sandbox.html` regardless of this feature; `http://` sidesteps
it while still exercising the "no chrome APIs" code path identically, since
a plain HTTP page has no `chrome.storage.session` either). Both files
rendered with correct title, sidebar TOC, callouts, tables, and 2 mermaid
SVGs apiece (confirmed inside the sandbox iframe's own document, not just
the outer page), 0 console errors. The drop zone appeared correctly with no
stashed source present (including with a `?key=` param set, since a bare
page's `chrome.storage` is genuinely absent — the exact case the detection
logic is built for) and picking an unsupported file (`.txt`) showed an
inline error without losing the drop zone, recoverable by picking a valid
file next. Drag-and-drop itself (as opposed to the file picker) was not
independently exercised — both paths call the same `handleFile()`, and only
the event source differs (`change` vs `drop`), so this is a low-risk gap,
not an unverified render path.

**Gist support was verified with the packed extension genuinely loaded**, not
just by reading the code: `browse` (this repo's headless-QA tool) has an
undocumented `BROWSE_EXTENSIONS_DIR` env var that loads an arbitrary unpacked
extension, but only its `--headed` launch path strips Playwright's default
`--disable-extensions` flag (its plain headless/off-screen path doesn't,
confirmed by inspecting the launched Chromium's actual argv and by a
temporary in-page marker the content script never set) — so `--headed` was
the one that actually worked, and the browser was genuinely running with this
extension loaded, real content scripts included.

Two real throwaway public gists were published via `gh gist create` for the
test — one `.org`, one `.rb`, both realistic multi-section incident-report
docs (doc_header, sidebar_toc, callouts, tables, a code block, a comparison
block, a card, two mermaid diagrams each) — plus a third with no marker as
the negative-case control, plus a fourth multi-file gist (mixing a stamped
`.org`, a stamped `.rb`, and an unstamped `.rb` in one gist) to check the
multi-file mounting logic specifically. All four confirmed live:

- The button appeared on both stamped gists and did not appear on the
  unstamped control (confirmed the control's file *was* fetched and checked —
  `data-sw-scanned` was set — it just correctly didn't match).
- Clicking through rendered both docs correctly end to end: doc_header,
  sidebar_toc, all callout variants, tables, the code block, the comparison
  block, the card, and both mermaid diagrams (2 rendered `<svg>` elements
  each), with 0 console errors, confirmed inside the sandbox iframe's own
  document.
- The multi-file gist mounted exactly two buttons — one per matching file, on
  that file's own `.file-actions`, not the unstamped file — after the
  necessarily-sequential per-file fetches finished (see Known gaps).
- Repo blob-page behavior was re-verified after these changes (`makeButton`'s
  signature changed to support gist's multi-button case) and still works
  unchanged: button appears, click renders, 0 console errors.

The four test gists were deleted after verification via `gh gist delete`, or
would have been — GitHub had already removed all four by the time cleanup
ran (`404` on both the web page and the API, for a `GET`, not just a
`DELETE`), most likely automated abuse detection reacting to the burst of
scripted navigation and fetch traffic this verification generated in a short
window. Not something this session did or could prevent; noted here since
"cleanup succeeded" isn't quite the right description of what happened.

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
- **Local-file drag-and-drop wasn't independently exercised, only the file
  picker was** — no headless tool used for this verification round can
  synthesize an OS-level drag gesture carrying a real `File`. Low risk: both
  entry points call the same `handleFile()`, and the `drop` handler is a
  handful of lines (`e.preventDefault()`, pull `e.dataTransfer.files[0]`,
  delegate) with nothing render-path-specific in it.
- **The "stashed key present but expired" error path (`load()`'s "That
  document is no longer available" branch) was confirmed by code review, not
  live** — a real Chromium page always carries a `chrome.runtime` stub even
  outside an extension (see the local-file-preview section above), but never
  a working `chrome.storage.session`, so a headless page can't be made to
  take that exact branch without loading the packed extension into a real
  Chrome UI. The branch itself is untouched by this change (S2 only added a
  new `if` above `load()`, matching the acceptance criteria's file-drop
  scope), so the review-only confirmation is for the *routing*, not new
  logic.
- **Gist files are scanned one at a time, not in parallel.** `scanGistPage()`
  awaits each file's fetch before starting the next, so a gist with many
  files takes proportionally longer to finish scanning (confirmed directly:
  a 3-file gist needed roughly 2-3 seconds before its second matching file's
  button appeared, not instant). Fine for the handful of files a real gist
  typically holds; would be worth parallelizing (`Promise.all`) if gists with
  dozens of files turn out to be a real usage pattern.
- **Anonymous gists (URL shape `gist.github.com/<id>`, no username segment)
  were not tested.** `isGistPage()`'s regex matches on the trailing hex id
  and doesn't require a username segment, so this should work unchanged, but
  every gist created for this round of testing was attached to an
  authenticated account (`gh gist create` always attaches to the signed-in
  user), so the anonymous case is inferred from the regex, not observed.
- **Private gists were not tested.** Untested for the same reason private
  repos' embedded-JSON path was already covered but its raw-URL fallback
  wasn't (see the private-repos gap above) — a private gist's Raw link should
  work the same way (the content script fetches from an already-authenticated
  page, same as the blob-page fallback), but wasn't verified live.
