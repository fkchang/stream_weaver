# StreamWeaver Plan Format Exploration: Ruby DSL vs MDX vs Org-mode

**Date:** 2026-06-17
**Status:** Exploratory design — not implemented
**TL;DR:** Org-mode wins for checked-in plan files. Ruby DSL wins for live canvas. The formats serve different moments and don't need to compete.

---

## The Problem

Builder's visual-plan uses MDX (Markdown + JSX components). It's clever, but
they themselves acknowledge a tension: **MDX looks ugly when read raw**. Custom
components like `<ImplementationMap files={[{path: "...", note: "..."}]} />` are
not human-readable without the renderer. The whole point of a checked-in plan
file is that a human (or Claude) can read it cold without spinning up a server.

StreamWeaver already has a live Ruby DSL for the canvas. But a canvas-push DSL
as a committed artifact is also awkward — it's executable Ruby, not prose.

So three candidates emerge:

1. **MDX** — what Builder does (Markdown + JSX props)
2. **Org-mode** — structured plaintext with native extensibility
3. **"SW-Ruby"** — StreamWeaver DSL embedded in a plan file format

---

## What We Proved in 30 Minutes

`org-ruby 0.9.12` is **already installed** in the StreamWeaver gem environment.
After a quick spike, the org-ruby parser:

- Parses `#+TITLE:`, `#+DATE:`, `#+SW_VERSION:` as in-buffer settings cleanly
- Exposes `:PROPERTIES:` drawers per-headline with full key-value access
- Headline + property combo maps directly to StreamWeaver component dispatch
- `#+BEGIN_SRC ruby` blocks are code-highlighted already
- Tables parse as table objects

This isn't theoretical. A working prototype parser is ~60 lines of Ruby.

---

## Format Comparison: Same Plan in All Three

### The Plan: Guest Auth Flow

A plan for adding guest checkout to a Rails app.
We want to show: prose, file map, a decision, a mermaid diagram, annotated code,
and a risk callout.

---

### Option A: MDX (Builder's way)

```mdx
---
title: "Guest Auth Flow"
brief: "Enable checkout without account creation."
version: 2
planId: "plan_84f748..."
source: "agent-native-plan"
---

<RichText id="b1">
### Overview

Enable users to proceed through checkout without creating an account.
Currently all paths require registration, causing ~30% mobile drop-off.
</RichText>

<ImplementationMap
  id="b2"
  files={[
    { path: "lib/auth/session.rb", note: "Add guest token issuer" },
    { path: "app/routes/checkout.rb", note: "Branch on guest vs auth user" },
    { path: "db/schema.rb", note: "Add guest_sessions table" },
  ]}
/>

<Decision
  id="b3"
  question={"How should guest sessions be stored?"}
  options={[
    { id: "o1", label: "JWT", detail: "Stateless, no DB lookup" },
    { id: "o2", label: "Opaque token", detail: "Revocable, account merge later", recommended: true },
  ]}
/>

<Callout id="b4" tone="risk">
Guest sessions must expire. Proposed TTL: 24h — confirm with data team.
</Callout>
```

**Raw readability:** ⚠️ Moderate. Prose sections are fine. Component props
are JSON-in-JSX — readable but verbose. The `files={[...]}` syntax is noise
that disappears in the renderer.

---

### Option B: Org-mode (proposed SW-Org format)

```org
#+TITLE: Guest Auth Flow
#+DATE: 2026-06-17
#+BRIEF: Enable checkout without account creation.
#+SW_VERSION: 1

* Overview

Enable users to proceed through checkout without creating an account.
Currently all paths require registration, causing ~30% mobile drop-off.

* Implementation Map
:PROPERTIES:
:SW_COMPONENT: implementation_map
:END:

| lib/auth/session.rb    | Add guest token issuer      |
| app/routes/checkout.rb | Branch on guest vs auth user |
| db/schema.rb           | Add guest_sessions table    |

* Decision: Token Storage
:PROPERTIES:
:SW_COMPONENT: decision
:SW_RECOMMENDED: opaque
:END:

| jwt    | Stateless, no DB lookup               |
| opaque | Revocable, supports account merge later |

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

* Issue Guest Token
:PROPERTIES:
:SW_COMPONENT: annotated_code
:SW_LANG: ruby
:END:

#+BEGIN_SRC ruby
def issue_guest_token(email)
  JWT.encode({ sub: email, role: 'guest' }, SECRET, exp: 24.hours.from_now)
end
#+END_SRC

#+BEGIN_ANNOTATIONS
[1] Guest tokens use restricted scope — limits what APIs they can call
[2] 24h TTL matches cleanup job cadence on the data team's cron
#+END_ANNOTATIONS

* Risk: Session Expiry
:PROPERTIES:
:SW_COMPONENT: callout
:SW_TONE: risk
:END:

Guest sessions must expire to prevent unbounded DB growth.
Proposed TTL: 24h — needs confirmation from data team.
```

**Raw readability:** ✅ Excellent. Every section reads as plain prose/table.
The `:PROPERTIES:` drawers are structured metadata that org-mode users understand
immediately. Tables are ASCII-legible. Code blocks are standard. Nothing requires
a renderer to understand.

---

### Option C: StreamWeaver Ruby DSL (canvas-push format)

```ruby
# guest-auth-flow.sw.rb
# SW Plan: Guest Auth Flow
# Brief: Enable checkout without account creation.

theme_preset :technical

header2 "Guest Auth Flow"
md "Enable users to proceed through checkout without creating an account."

implementation_map files: [
  { path: "lib/auth/session.rb",    note: "Add guest token issuer" },
  { path: "app/routes/checkout.rb", note: "Branch on guest vs auth user" },
  { path: "db/schema.rb",           note: "Add guest_sessions table" }
]

decision question: "How should guest sessions be stored?" do
  option "jwt",    "Stateless, no DB lookup"
  option "opaque", "Revocable, supports account merge later", recommended: true
end

mermaid do
  <<~MERMAID
    sequenceDiagram
      User->>App: Request checkout
      App->>Auth: Issue guest token
      Auth-->>App: JWT (role: guest, TTL: 24h)
  MERMAID
end

annotated_code language: :ruby, annotations: [
  { line: 1, note: "Guest tokens use restricted scope" },
  { line: 2, note: "24h TTL matches cleanup job cadence" }
] do
  <<~RUBY
    def issue_guest_token(email)
      JWT.encode({ sub: email, role: 'guest' }, SECRET, exp: 24.hours.from_now)
    end
  RUBY
end

callout :risk do
  "Guest sessions must expire to prevent unbounded DB growth. TTL: 24h."
end
```

**Raw readability:** ✅ Good for Ruby devs, readable for anyone. Clean method
names, block syntax is familiar. But it's executable — `require 'stream_weaver'`
and it runs. That's a feature AND a bug: nice for live push, weird for a
committed plan artifact.

---

## Side-by-Side Analysis

| Criterion | MDX | Org-mode | SW-Ruby DSL |
|---|---|---|---|
| **Raw readability** | ⚠️ Moderate | ✅ Excellent | ✅ Good |
| **LLM writability** | ✅ Easy | ✅ Easy | ✅ Easy |
| **GitHub renders nicely** | ❌ Shows JSX noise | ✅ Renders as plain text, tables intact | ⚠️ Syntax highlighted but not semantic |
| **Emacs native** | ❌ | ✅ Full org-mode tooling | ❌ |
| **VS Code** | ✅ MDX extension | ✅ org-mode extension | ✅ Ruby extension |
| **Structured metadata** | ✅ Frontmatter YAML | ✅ In-buffer settings + drawers | ⚠️ Comments only |
| **Extensible blocks** | ✅ Custom JSX | ✅ Custom drawers + keywords | ✅ Method calls |
| **Parse complexity** | High (JSX AST) | Medium (org-ruby exists) | Low (just Ruby eval) |
| **SW integration** | Would need port | **~60 line parser → SW components** | **Direct — already SW** |
| **Stands alone without renderer** | ❌ JSX unreadable | ✅ Yes | ⚠️ Only with Ruby context |
| **Diff-friendly** | ⚠️ Okay | ✅ Great | ✅ Great |
| **Works in GitHub PR review** | ❌ | ✅ Readable tables, code blocks | ✅ Ruby coloring |

---

## The Org-mode Advantage: What GitHub Actually Does

GitHub renders `.org` files natively — headings, bold, italic, links, tables,
code blocks. The `:PROPERTIES:` drawer is the one thing that doesn't render
beautifully (it shows as literal text), but it's concise and clearly structured.

Compare how a Decision block looks raw on GitHub:

**MDX (what you'd see in a PR):**
```
<Decision
  id="b3"
  question={"How should guest sessions be stored?"}
  options={[
    { id: "o1", label: "JWT", detail: "Stateless, no DB lookup" },
    { id: "o2", label: "Opaque token", detail: "Revocable", recommended: true },
  ]}
/>
```
→ Unrenderable JSX. A reviewer sees noise.

**Org-mode (what you'd see in a PR):**
```
* Decision: Token Storage
:PROPERTIES:
:SW_COMPONENT: decision
:SW_RECOMMENDED: opaque
:END:

| jwt    | Stateless, no DB lookup               |
| opaque | Revocable, supports account merge later |
```
→ GitHub renders the table. The properties are visible but terse. A reviewer
understands the intent immediately, even without the StreamWeaver renderer.

This directly addresses Builder's cited concern: plan files should be readable
*raw*.

---

## Implementation Plan: SW-Org Format

### Phase 1 — Parser (~1 session, ~150 lines Ruby)

```ruby
# lib/stream_weaver/plan/org_parser.rb

module StreamWeaver
  module Plan
    class OrgParser
      COMPONENT_MAP = {
        "implementation_map" => :render_implementation_map,
        "decision"           => :render_decision,
        "annotated_code"     => :render_annotated_code,
        "diagram"            => :render_diagram,
        "callout"            => :render_callout,
        "wireframe"          => :render_wireframe,
        "api_endpoint"       => :render_api_endpoint,
        nil                  => :render_prose,  # no SW_COMPONENT = plain markdown
      }

      def initialize(org_text)
        @parser = Orgmode::Parser.new(org_text)
        @meta   = @parser.in_buffer_settings
      end

      def title    = @meta["TITLE"]
      def brief    = @meta["BRIEF"]
      def date     = @meta["DATE"]

      # Yields DSL blocks to a StreamWeaver App context
      def to_canvas_dsl
        @parser.headlines.map do |headline|
          props     = headline.property_drawer || {}
          component = props["SW_COMPONENT"]
          body      = extract_body(headline)
          { component:, props:, headline: headline.headline_text, body: }
        end
      end

      private

      def extract_body(headline)
        # Get raw lines, skip property drawer lines
        lines = headline.body_lines.map do |l|
          next unless l.respond_to?(:line)
          next if [:property_drawer_begin_block,
                   :property_drawer_item,
                   :property_drawer_end_block].include?(l.paragraph_type)
          l.line
        end.compact
        lines.join("\n").strip
      end
    end
  end
end
```

### Phase 2 — Component renderers (~1-2 sessions)

Each `SW_COMPONENT` type gets a renderer that emits StreamWeaver DSL:

```ruby
# For implementation_map: parse org table rows → files array
def render_implementation_map(headline:, props:, body:, **)
  files = parse_org_table(body).map do |path, note|
    { path: path.strip, note: note.strip }
  end
  implementation_map(files:)
end

# For decision: first column = option id/label, second = detail
# SW_RECOMMENDED property picks the winner
def render_decision(headline:, props:, body:, **)
  recommended = props["SW_RECOMMENDED"]
  options = parse_org_table(body).map do |label, detail|
    { label: label.strip, detail: detail.strip,
      recommended: label.strip.downcase == recommended&.downcase }
  end
  decision(question: headline, options:)
end

# For annotated_code: SRC block + ANNOTATIONS block
def render_annotated_code(headline:, props:, body:, **)
  code   = extract_src_block(body)
  notes  = extract_annotations_block(body)
  lang   = props["SW_LANG"]&.to_sym || :ruby
  annotated_code(language: lang, code:, annotations: notes)
end
```

### Phase 3 — CLI integration (~half session)

```bash
# Push org plan to live canvas
streamweaver canvas-push <session> --file plan.org

# Serve org plan as standalone page
streamweaver serve plan.org

# Export running canvas as org plan
streamweaver canvas-export <session> --format org > plan.org
```

### Phase 4 — Bidirectional: Canvas → Org (~1 session)

The really interesting capability: Claude Code builds a live canvas, then you
can export it as a checked-in org plan file. Builder has no equivalent — their
plans live in the hosted DB. Your plans live in git.

```bash
streamweaver canvas-export guest-auth --format org > docs/plans/guest-auth.org
git add docs/plans/guest-auth.org && git commit -m "add guest auth plan"
```

---

## The Hybrid Architecture

These formats aren't competing — they serve different moments:

```
                    Planning Phase
                    ──────────────
Claude Code thinks  →  canvas-push (live Ruby DSL)
                           ↓ (user reviews in browser)
User approves       →  canvas-export --format org (checked-in artifact)
                           ↓ (in git, readable in GitHub PR)
Future Claude Code  →  canvas-push --file plan.org (restore from org)
                           ↓ (live again for the implementation phase)
Implementation done →  streamweaver recap <session> (visual-recap equivalent)
                           ↓
                       docs/recaps/YYYY-MM-DD-feature.org (committed recap)
```

The Ruby DSL is the **live wire** format — what Claude Code pushes in real time.
The org file is the **resting state** format — what gets committed, reviewed,
and loaded back.

You never need to write org by hand. Claude Code writes it. Humans read it raw.

---

## Is This Better Than MDX?

For StreamWeaver's use case: yes, clearly, on three dimensions:

**1. Raw readability.** Org tables and headings render well on GitHub. MDX JSX
component syntax doesn't. Builder acknowledged this as a concern — org solves
it without any compromise.

**2. No external dependency.** MDX requires a React renderer and a hosted Plan
app. Org-mode parsing is a pure Ruby library, already installed. A plan file
is readable with zero infrastructure — any text editor, GitHub's web UI, Emacs,
VS Code with the org extension. Builder's plan files are essentially useless
without plan.agent-native.com.

**3. Bidirectionality.** Canvas → Org export is natural. MDX round-trips are
hard (JSX isn't designed for serialization). Org is a text format that's
designed to be written by programs and read by humans.

Where MDX wins: if you're in a React/JS ecosystem with a polished hosted viewer.
Builder has that viewer. StreamWeaver's viewer is your local browser tab. For
that context, org-mode is strictly better.

---

## Effort Estimate

| Phase | Work | Estimate |
|---|---|---|
| Org parser + component dispatch | New file, ~150 lines | 1 session |
| Component renderers (5 types) | New file, ~200 lines | 1-2 sessions |
| CLI `--file plan.org` flag | Extend canvas-push | 0.5 session |
| Canvas → Org export | New renderer | 1 session |
| Tests + example plans | — | 0.5 session |
| **Total** | | **4-5 sessions** |

Comparison: MDX support would require a JS parser (or porting org-ruby's
equivalent), a React component registry, and a hosted viewer. That's a full
project, not a feature.

---

## Open Questions

1. **Property drawer vs tag syntax?** Could use org tags instead of drawers
   for component type: `* Implementation Map  :implementation_map:` — less
   verbose, but tags are normally for categorization not typing. Drawer is
   semantically cleaner.

2. **Nested components in org?** Org doesn't have great support for nesting
   blocks. A `columns` layout with two `wireframe` children is harder to express
   than in MDX or Ruby DSL. Could use level-2 headlines under a level-1
   `SW_COMPONENT: columns` headline. Works but is slightly awkward.

3. **Live push vs file format duality.** Should `canvas-push` accept both
   a heredoc DSL (current) AND a `--file plan.org`? Yes — they're the same
   push operation, different source formats. The parser is the adapter layer.

4. **Lossiness on export.** Some live canvas state (Alpine.js interactions,
   chart data loaded from state, button callbacks) can't round-trip to org.
   Export should be a planning document, not a full canvas snapshot. Clarify
   that boundary early.

5. **Alternative: a simpler YAML-frontmatter markdown format?** Something like:
   ```markdown
   ---
   sw_component: implementation_map
   ---
   | path | note |
   |------|------|
   ```
   Lighter than org, but loses the native hierarchy. Org's heading structure
   maps more naturally to a document with sections.

---

*Exploration by Selene — June 2026*
