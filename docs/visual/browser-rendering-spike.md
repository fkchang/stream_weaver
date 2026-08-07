# Rendering StreamWeaver Docs Without Ruby: Browser Extension and npm Package

**Date:** 2026-08-07
**Status:** Spike complete — end-to-end verified, not productized

**TL;DR:** A StreamWeaver doc can be compiled from Ruby source and rendered
entirely in JavaScript, with no Ruby installed — verified end to end at 640ms
for the 385-line reference PRD, producing output identical to the Ruby-built
version. One blocker stood in the way and is now solved: **Opal's self-hosted
parser cannot lex heredocs of any form**, and doc DSL files are full of them.
A source rewrite (`sw-heredoc-rewrite.js`) clears it. The same artifact serves
both the browser extension and an npm package — they are one build, not two.

---

## The Realization That Reframes Both

A browser extension that renders docs from GitHub has to handle Ruby *source* —
that's what GitHub serves. Rendering it client-side therefore means **compiling
Ruby in the browser**, not merely running a precompiled bundle.

That is the same requirement an npm package has for anyone without Ruby. So the
extension and the npm package are not two projects sharing a theme; they are
one compiled artifact with two wrappers.

```
        .rb source (GitHub raw, local file, stdin)
                        │
                        ▼
          sw-heredoc-rewrite.js        ← required; see below
                        │
                        ▼
       Opal.compile()  (opal-parser.js, self-hosted)
                        │
                        ▼
   StreamWeaver Opal runtime + Adapter::Static renderers
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
  browser extension                 npm package
  (viewer page/side panel)      (CLI, CI, VS Code preview)
```

---

## Verified

Every claim below was executed, not reasoned about.

| Claim | Result |
|---|---|
| Opal compiles itself to JS | `opal` + `opal-parser` → **2.98MB** bundle |
| That bundle compiles Ruby in Node, no Ruby installed | `Opal.compile("[1,2,3].map { \|x\| x * 2 }.inspect")` → `[2, 4, 6]` |
| StreamWeaver runtime + compiler in one bundle | **3.65MB** |
| A doc compiles and renders in-browser from source | ✅ 640ms for `prd_dsl.rb` |
| Output matches the Ruby-built version | 12,972 chars, 27 headings, 5 tables, 7 code blocks, 11 TOC links, 3 callouts — identical |
| Page errors | none |

Size: ~3.65MB runtime + 3.5MB mermaid ≈ 7.2MB uncompressed. Unremarkable for an
extension (loaded from local disk, no download per page) and fine for an npm
package. Roughly 1–1.5MB gzipped if ever served over a network.

---

## The Blocker: Heredocs

`opal-parser.js` **fails on every heredoc form**:

```
<<~MD    → "unterminated string meets end of file"
<<-MD    → same
<<MD     → same
<<~"MD"  → same
```

Multi-line strings, `%w[]`, and `#{}` interpolation all parse fine — it is
specific to heredoc lexing. The MRI-hosted compiler handles heredocs correctly,
so this is a gap in the self-hosted parser only (Opal 1.8.3). Adding `strscan`
and `racc/parser` to the build does not help; `StringScanner` itself works.

This matters because heredocs are how doc DSL files are written —
`md <<~MD`, `code_block(<<~TXT, lang: "ruby")`, `mermaid <<~MERMAID`. The
reference PRD has **17 of them**. Without a fix, in-browser compilation fails on
essentially every real document.

### The fix

`lib/stream_weaver/assets/js/sw-heredoc-rewrite.js` rewrites heredocs into
double-quoted string literals before compilation. Double quotes preserve `#{}`
interpolation, so the rewrite is transparent for the interpolating forms;
`<<~'X'` is emitted single-quoted to stay non-interpolating. Squiggly heredocs
get their common indentation stripped, matching Ruby's semantics.

Verified against: plain squiggly, heredoc-as-argument with a following keyword
argument, interpolation, embedded double quotes, and the full 17-heredoc PRD.

**Known limits.** One heredoc per line; multiple heredocs opened on a single
line are not handled. Nested heredocs are not handled. Neither appears in
StreamWeaver doc files, but both would need work before this is a general Ruby
tool. It is a targeted preprocessor, not a Ruby parser.

---

## Two Products, One Artifact

### Browser extension

Fetch raw `.rb` → rewrite → compile → render in an extension page or side panel.
Per the earlier analysis, an extension *page* rather than in-page injection
avoids both style collision with GitHub and the DOM-churn maintenance tax.

Remote **script** is what MV3 forbids, which is why mermaid and Prism had to be
bundled. Remote stylesheets and fonts are not restricted by the default policy,
so Google Fonts is fine — worth an opt-out only for offline or privacy reasons.

### npm package

The same bundle plus a thin API:

```js
const { render } = require('@streamweaver/render')
const html = render(fs.readFileSync('doc.sw.rb', 'utf8'))
```

Uses that don't involve GitHub at all:

- `npx streamweaver-render doc.rb > doc.html` for people with no Ruby
- Static site generation and CI, without adding Ruby to the image
- A VS Code preview pane
- Any JS toolchain that wants StreamWeaver docs as HTML

**One caveat for the Node path.** The Opal runtime's render pass builds an HTML
string without touching the DOM, but `OpalBridge` and `patch_dom` do. A Node
renderer therefore needs either jsdom or a render-to-string entry point that
skips the bridge. The string path exists inside the runtime already
(`OpalRuntime#render_html`); it just is not exposed. That is the main piece of
work between this spike and a shippable npm package.

---

## Recommended Order

1. **Expose render-to-string** in the Opal runtime, bypassing the bridge. Small,
   and it unblocks the entire Node path.
2. **npm package** wrapping compiler + runtime + assets + rewriter. Testable in
   CI, no browser or store review involved.
3. **Browser extension** on top of the same package. Now the only new work is
   the GitHub URL detection and the viewer page.

Doing the npm package first means the extension inherits something already
proven, and gets a test surface that does not require a browser.

---

## Open Questions

1. **Upstream the heredoc gap?** Worth an Opal issue — a self-hosted parser that
   cannot lex heredocs is a general limitation, not a StreamWeaver one. If it is
   fixed upstream, the rewriter can be deleted.
2. **Is `ruby.wasm` a better long-term base?** `@ruby/wasm-wasi` runs real CRuby,
   so no parser gaps at all — but it is 10–30MB and would need the gem's server
   dependencies stubbed. Worth revisiting if the parser gap widens.
3. **Which file extension marks a StreamWeaver doc?** The extension needs to
   decide what to render. `.sw.rb` is unambiguous; plain `.rb` under
   `docs/streamweaver_canvas/` is convention-based and would misfire elsewhere.
4. **Interactive components in a viewer.** Buttons and inputs work in Opal, but a
   doc viewer probably wants them inert. Worth deciding whether the viewer
   renders read-only.

---

*Spike verified against Opal 1.8.3, Ruby 3.3.6, Chromium (headless) with all
HTTP blocked. Reference document: `examples/components/prd_dsl.rb`.*
