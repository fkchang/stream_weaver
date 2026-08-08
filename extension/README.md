# StreamWeaver Doc Viewer (browser extension)

Renders StreamWeaver docs on GitHub the way they look when run, instead of as
Ruby source.

**Status:** working scaffold. The render pipeline and doc detection are both
verified against real GitHub markup in headless Chromium; loading it unpacked
against live github.com has not been done yet.

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
old runtime.

## How it works

```
GitHub blob page
   │  content.js reads the file from GitHub's embedded JSON (no network),
   │  checks the first 10 lines for "# streamweaver-doc: v1"
   ▼
"View rendered" button → source into chrome.storage.session
   │  background.js opens the viewer tab
   ▼
viewer.html   extension APIs: reads the stashed source, hands it over
   │
   ▼
sandbox.html  compiles the Ruby and renders it
```

**Detection is by content, not filename.** `DocStore` stamps every saved doc
with a marker comment, and the marker travels with the file — so this works on
gists, forks, and files that were moved, where a path or extension rule would
not. Guessing from the DSL was measured and rejected: real docs use 7–14
distinct DSL calls, but a thin one may use only `md`.

**Why two pages.** Rendering means compiling Ruby in the browser, and the
compiler's output has to be evaluated. Manifest V3 pins extension pages to
`script-src 'self'` and rejects `unsafe-eval` there, so the work cannot happen
in `viewer.html`. A sandboxed page is the one place MV3 permits it. The cost is
that the sandbox has a null origin and no extension APIs, so `viewer.html` does
the storage read and passes the source in by `postMessage`.

**Everything is local.** MV3 forbids remote script outright, so mermaid, Prism,
marked, morphdom and jsdiff are all bundled. A render makes zero network
requests — the test asserts this by failing on any HTTP attempt.

**Heredocs are rewritten before compiling.** Opal's self-hosted parser cannot
lex heredocs in any form, while the MRI-hosted compiler handles them fine. Doc
bodies are full of them, so `sw-heredoc-rewrite.js` converts them to quoted
strings first. Without that step, in-browser compilation fails on essentially
every real document.

**Docs render inert.** The viewer uses `SWRender.html()` rather than starting
the live runtime — there is nothing to interact with in a document, so it skips
event delegation and the re-render loop.

## Verified

Against `examples/components/prd_dsl.rb` (385 lines, 17 heredocs), in headless
Chromium with all HTTP blocked:

| | |
|---|---|
| Render | 27 headings, 5 tables, 7 code blocks, 11 TOC links, 3 callouts |
| Mermaid | 1 typeset SVG |
| Prism | 200 tokens |
| Network requests | 0 |
| Page errors | 0 |

Detection, against a real captured GitHub blob page: a plain `Rakefile` gets no
button; the same page with stamped content does.

## Known gaps

- **Not yet loaded unpacked against live github.com.** The pieces are tested in
  isolation; the integration is not.
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
