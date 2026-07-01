# SW Plan Format: MDX Pipeline, GitHub Rendering, and the Design Strategy

**Date:** 2026-06-17
**Status:** Research complete — design conclusions

---

## How MDX Actually Compiles

MDX is not "Markdown with components." It's a full compiler that transforms
`.mdx` source through five distinct AST stages before you get renderable output.
Source-verified from `@mdx-js/mdx/lib/core.js`:

```
.mdx source
    ↓  remark-parse + remark-mdx (micromark + acorn for JS)
mdast (Markdown AST — nodes like paragraph, heading, JSX)
    ↓  remarkMarkAndUnravel + user remark plugins (e.g. remark-gfm)
mdast (transformed)
    ↓  remark-rehype (mdast-util-to-hast)
hast (HTML AST — div, span, pre nodes)
    ↓  user rehype plugins (syntax highlight, math, etc.)
hast (transformed)
    ↓  rehype-recma → recma-document → recma-jsx-rewrite → recma-build-jsx
esast (ES AST — JavaScript module tree)
    ↓  recma-stringify (astring codegen)
JS module string (React component code)
```

**The output is not HTML.** It's a JavaScript module:

```js
import { jsx as _jsx, jsxs as _jsxs } from 'react/jsx-runtime'

function _createMdxContent(props) {
  const _components = { h1: 'h1', ...props.components }
  return _jsxs(_Fragment, { children: [
    _jsx(_components.h1, { children: 'Overview' }),
    _jsx(_components.ImplementationMap, { files: [...] })
  ]})
}

export default function MDXContent(props = {}) { ... }
```

React renders that JS component to DOM at runtime.

### What This Costs in Setup

To use MDX you need:

- A bundler with MDX loader configured (webpack `@mdx-js/loader`, Rollup
  `@mdx-js/rollup`, or esbuild `@mdx-js/esbuild`)
- React and `react/jsx-runtime` as dependencies
- In Next.js App Router: a mandatory `mdx-components.tsx` file at project root
- For custom components: a provider or explicit `components=` prop passed to
  every `<MDXContent>` render call
- Plugin knowledge: remark/rehype ecosystem for anything beyond basic markdown

For **runtime rendering** (serving dynamic MDX from a DB like Builder does):
- `compile(mdxString, { outputFormat: 'function-body' })` → JS string
- `run(compiledCode, { ...runtime })` → React component
- This is essentially `new AsyncFunction(compiledCode)` — blocked by CSP in
  many production environments, and a security concern if content is
  user-controlled

**Summary of MDX friction:** You can't just point a server at a `.mdx` file and
have it render. You need a full JS build pipeline, React, and careful component
registry management. Builder gets away with this because they own a hosted SaaS
app that runs all of this. If you're not running that hosted app, `.mdx` files
are expensive text you can't easily render.

---

## How GitHub Renders `.org` Files — Source-Backed Facts

GitHub uses the `github/markup` gem, which for `.org` files calls:

```ruby
# From github/markup/lib/github/markups.rb (actual source)
GitHub::Markup.markup(:MARKUP_ORG, 'org-ruby', /org/, ["Org"]) do |filename, content, options: {}|
  Orgmode::Parser.new(content, {
    :allow_include_files => false,  # #+INCLUDE: is hardcoded OFF
    :skip_syntax_highlight => true  # no Pygments, raw <pre> only
  }).to_html
end
```

The HTML then passes through **html-pipeline's `SanitizationFilter`** (Selma),
which has a strict allowlist. This is the layer that kills most attempts at
custom rendering.

### What GitHub's Sanitizer Strips

After org-ruby generates HTML, Selma removes:
- `style="..."` attribute — stripped from ALL elements
- `class="..."` attribute — stripped from most elements
- `<script>`, `<style>`, `<link>` — blocked entirely
- `<iframe>` — blocked
- `#+BEGIN_HTML` blocks pass through org-ruby verbatim, then Selma sanitizes

**No mechanism exists to inject custom CSS or JS** into GitHub's rendered view
of a `.org` file. Not via in-buffer settings, not via `.gitattributes`, not at
all. GitHub Pages is different — but that's a separate deployment, not the
in-repo file view.

### The Critical Finding: What Happens to Custom Content

| Construct | org-ruby output | After GitHub sanitizer |
|---|---|---|
| `* Heading` | `<h1>` | ✅ Passes |
| `\| table \|` | `<table><tr><td>` | ✅ Passes |
| `- list` | `<ul><li>` | ✅ Passes |
| `#+BEGIN_SRC ruby` | `<pre class="src">` | ✅ Passes (class stripped) |
| `#+BEGIN_QUOTE` | `<blockquote>` | ✅ Passes |
| `#+BEGIN_EXAMPLE` | `<pre class="example">` | ✅ Passes |
| `:PROPERTIES:` drawer | **Nothing** | ✅ Nothing (invisible) |
| `#+BEGIN_MYBLOCK` | **Dropped** (treated as `:comment`) | Nothing |
| `style="..."` | Emitted | ❌ Stripped |
| `class="..."` | Emitted | ❌ Stripped |

The `:PROPERTIES:` drawer outcome is perfect for us: **completely invisible on
GitHub, but parsed by org-ruby into a clean Ruby hash** that our renderer reads.
The headline is still visible; the metadata is hidden.

The custom block outcome is a constraint we must design around: **any
`#+BEGIN_SW_WHATEVER` block gets silently dropped by org-ruby** before GitHub
ever sees it.

---

## The Design Constraint and the Insight It Unlocks

Here's the real question: do we need GitHub to render our custom components
beautifully? Or do we need the *content* of those components to be readable?

Those are different requirements.

**MDX on GitHub:** Custom component syntax is completely unreadable as raw text.
```
<ImplementationMap
  id="b2"
  files={[
    { path: "lib/auth/session.rb", note: "Add guest token issuer" },
    { path: "db/schema.rb", note: "Add guest_sessions table" },
  ]}
/>
```
A reviewer reading this in a PR sees JSX noise. No information is conveyed
without the renderer.

**SW-Org on GitHub (if we design it right):** The *content* of every component
is encoded in native org structures that GitHub already renders:

```org
* Implementation Map
:PROPERTIES:
:SW_COMPONENT: implementation_map
:END:

| File                    | Note                      |
|-------------------------|---------------------------|
| lib/auth/session.rb     | Add guest token issuer    |
| db/schema.rb            | Add guest_sessions table  |
```

GitHub renders this as a real heading + real table. A reviewer sees exactly what
they need. The `:PROPERTIES:` drawer is invisible. The StreamWeaver renderer
sees `SW_COMPONENT: implementation_map` and makes it beautiful.

**This is strictly better than MDX for raw readability** — and we can achieve it
without GitHub doing anything special.

---

## Format Design: Every Component Maps to Native Org

The design principle: **encode all component data in org constructs that already
render well on GitHub**. Use `:PROPERTIES:` only for machine metadata that
humans don't need to read.

### Implementation Map

```org
* Implementation Map
:PROPERTIES:
:SW_COMPONENT: implementation_map
:END:

| File                       | Role                         |
|----------------------------|------------------------------|
| lib/auth/session.rb        | Add guest token issuer       |
| app/routes/checkout.rb     | Branch on guest vs auth user |
| db/schema.rb               | Add guest_sessions table     |
```

**GitHub renders:** Heading + proper HTML table. ✅
**SW renders:** Styled file-map component with path icons and rationale.

### Decision Block

```org
* Decision: Token Storage Strategy
:PROPERTIES:
:SW_COMPONENT: decision
:SW_RECOMMENDED: opaque
:END:

| Option        | Detail                                      |
|---------------|---------------------------------------------|
| jwt           | Stateless, no DB lookup                     |
| *opaque*      | Revocable, supports account merge later ✓   |

The opaque token approach is recommended because it allows guest sessions to be
revoked immediately and merged into real accounts post-purchase.
```

**GitHub renders:** Heading + table (the `*opaque*` shows as bold, the ✓ is
a unicode character). The recommended option is visually distinguished even
without the renderer. ✅
**SW renders:** Styled decision block with highlighted recommended option and
rationale callout.

### Callout

```org
* Risk: Session Expiry
:PROPERTIES:
:SW_COMPONENT: callout
:SW_TONE: risk
:END:

#+BEGIN_QUOTE
Guest sessions must expire to prevent unbounded DB growth.
Proposed TTL: 24h — needs confirmation from data team.
#+END_QUOTE
```

**GitHub renders:** Heading + `<blockquote>`. Visually indented. ✅
**SW renders:** Styled risk callout with red/orange border and icon.

Note: `#+BEGIN_QUOTE` is one of org-ruby's supported block types — it renders
as `<blockquote>`. This is the right native fallback for callouts.

### Annotated Code

```org
* Auth Token Implementation
:PROPERTIES:
:SW_COMPONENT: annotated_code
:SW_LANG: ruby
:END:

#+BEGIN_SRC ruby
def issue_guest_token(email)
  JWT.encode({ sub: email, role: 'guest' }, SECRET, exp: 24.hours.from_now)
end
#+END_SRC

Annotations:
1. ~role: 'guest'~ restricts token scope — guest tokens cannot call admin APIs
2. ~exp: 24.hours~ matches the cleanup job cadence defined in ~db/jobs/session_cleanup.rb~
```

**GitHub renders:** Heading + syntax-highlighted code block + numbered list with
inline code. ✅ Every annotation is readable.
**SW renders:** Code with line-pinned annotation bubbles.

### Wireframe

This is the hard case — a wireframe is inherently visual. Fallback options:

```org
* Checkout Screen: Guest Path
:PROPERTIES:
:SW_COMPONENT: wireframe
:SW_SURFACE: browser
:END:

#+BEGIN_SRC html
<div class="page">
  <header>MyApp</header>
  <main>
    <h2>Continue as guest?</h2>
    <button data-goto="b">Continue as Guest</button>
    <a href="#">Sign in instead</a>
  </main>
</div>
#+END_SRC
```

**GitHub renders:** Heading + HTML source in a code block. Not a visual mockup,
but the HTML is readable and documents the intended structure. ✅
**SW renders:** Full device-framed browser mockup with prototype navigation.

This is the honest tradeoff: wireframes can't degrade to "beautiful on GitHub"
because they're fundamentally visual. But the HTML source is still more readable
than MDX's JSX prop syntax, and it renders perfectly in SW.

### Mermaid Diagram

```org
* Auth Flow Architecture
:PROPERTIES:
:SW_COMPONENT: diagram
:SW_DIAGRAM: mermaid
:END:

#+BEGIN_SRC mermaid
sequenceDiagram
  User->>App: Request checkout
  App->>Auth: Issue guest token
  Auth-->>App: JWT (role: guest, TTL: 24h)
  App-->>User: Checkout continues
#+END_SRC
```

**GitHub renders:** Code block labeled `mermaid`. GitHub *does* natively render
Mermaid in Markdown (`.md`) files — but **not** in `.org` files (org-ruby
predates that feature). Renders as source. ✅ (Readable source; not rendered.)
**SW renders:** Live Mermaid diagram via Mermaid.js.

---

## Friction Comparison: MDX vs SW-Org

### To render an MDX file from scratch

1. `npm install @mdx-js/mdx @mdx-js/rollup react react-dom @types/mdx`
2. Configure bundler plugin
3. Create `mdx-components.tsx` with component registry
4. Build (`next build` or Vite build)
5. Start server
6. Open browser

Or for runtime rendering:
1. `compile(mdxString, { outputFormat: 'function-body' })`
2. `run(code, { ...runtime })`
3. Pass `components` prop with full registry
4. Render to DOM via React

**Friction level:** High. Requires JS build toolchain, React, bundler
integration, and component registry management.

### To render an SW-Org file from scratch

```bash
streamweaver serve plan.org
```

That's it. The org-ruby gem is already installed (`gem list` confirms 0.9.12
is present). The parser is ~150 lines of Ruby reading from an already-installed
gem. No bundler, no React, no build step.

**Friction level:** Single command. Already lower than MDX by any measure.

---

## Can We Get GitHub to Natively Render Our Components?

**Short answer: No. And it doesn't matter.**

GitHub's org-ruby integration:
1. Uses `org-ruby` hardcoded with `allow_include_files: false`
2. Passes output through `html-pipeline` Selma sanitizer (strips `class=`,
   `style=`, all JS/CSS)
3. Custom `#+BEGIN_SW_*` blocks → **silently dropped** (org-ruby classifies
   unknown block types as `:comment`)
4. No `.gitattributes` hook for custom rendering
5. No way to inject CSS or JS into file rendering

**The format-design insight makes this a non-issue.** If we encode component
data in native org structures (tables, code blocks, blockquotes, headings), then
GitHub's natural org rendering IS the good degraded view. We're not asking
GitHub to render a custom component — we're asking it to render a table, which
it already does beautifully.

The `:PROPERTIES:` drawer being invisible is a feature: the machine metadata
stays out of the human's way on GitHub, while remaining fully accessible to
the StreamWeaver parser.

---

## The Rendering Architecture

```
plan.org  (checked in, human-readable on GitHub)
    │
    ├─ GitHub view: headings + tables + code blocks
    │  (degraded but fully readable, no renderer needed)
    │
    └─ StreamWeaver serve plan.org
           │
           ├─ OrgParser: read in-buffer settings + headlines
           ├─ Per-headline: dispatch on SW_COMPONENT property
           ├─ Render each block via StreamWeaver component DSL
           └─ Live canvas: full component styling + interactivity
```

**Bidirectionality:**
```
canvas-push (live Ruby DSL)  ←→  canvas-export --format org  ←→  git commit
```

You never write org by hand in normal flow. Claude Code writes the live DSL;
`canvas-export` serializes it to org; you commit. Future sessions restore from
the org file.

---

## The One Thing to Watch: Custom Blocks

Because `#+BEGIN_SW_CUSTOM` blocks are dropped by org-ruby → GitHub, we have a
design rule:

**Rule: No custom `#+BEGIN_` blocks for content that must be readable on GitHub.**

Use:
- `#+BEGIN_QUOTE` → callouts
- `#+BEGIN_SRC lang` → code and diagrams (as source)
- `| table |` → structured data
- `- list` / `1. numbered` → annotations and options

The `#+BEGIN_SRC html` fallback for wireframes is acceptable: the HTML source
is more informative than JSX prop syntax and clearly marks "this is a UI
component."

---

## Verdict

| Dimension | MDX | SW-Org |
|---|---|---|
| Raw readability on GitHub | ❌ JSX is noise | ✅ Tables, headings, code blocks |
| Renderer friction | ❌ React + bundler required | ✅ `streamweaver serve plan.org` |
| Custom component registry | ❌ Must configure + maintain | ✅ Property drawer dispatch |
| Checked-in artifact | ⚠️ Useless without hosted app | ✅ Readable anywhere |
| Bidirectional (canvas ↔ file) | ❌ Hard (JSX serialization is painful) | ✅ Natural text format |
| Already installed | ❌ Needs npm install | ✅ org-ruby 0.9.12 present |
| GitHub native rendering | ❌ JSX not rendered | ✅ Natural org elements render |
| LLM writability | ✅ Easy (learned from training) | ✅ Easy (tables + drawers) |
| Emacs integration | ❌ | ✅ Full org-mode native |

SW-Org is strictly better than MDX for StreamWeaver's use case. The only thing
MDX has going for it is ecosystem momentum — it's what JavaScript developers
already know. Since StreamWeaver is Ruby-first and the target audience writes
Ruby, that advantage doesn't apply.

---

*Research and design by Selene — June 2026*
*Sources: @mdx-js/mdx source (core.js), github/markup source (markups.rb),
org-ruby source (html_output_buffer.rb, parser.rb, line.rb)*
