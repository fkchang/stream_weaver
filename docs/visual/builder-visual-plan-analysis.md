# BuilderIO visual-plan vs StreamWeaver — Analysis & Steal Plan

**Date:** 2026-06-17
**Source:** https://github.com/BuilderIO/skills/tree/main/skills/visual-plan

---

## 1. What Builder's visual-plan Is

An MCP-connected Claude Code skill that turns text plans into rich, hosted MDX
documents with structured blocks — file maps, decisions, annotated code,
wireframes, diagrams, and open question forms. Published to a hosted Plan viewer
at plan.agent-native.com. Two slash commands:

- `/visual-plan` — prospective: generate a plan *before* coding starts
- `/visual-recap` — retrospective: generate a visual summary *after* code is
  committed (diff → annotated document)

The key workflow: Claude Code calls `get-plan-blocks` (live block registry),
then calls `create-visual-plan` / `create-visual-recap` with a structured
`PlanContent` object (version 2), receives a deep-link URL back, and shares that
URL. The plan is a static artifact — one-shot publish.

---

## 2. The Fundamental Difference

| Dimension | Builder visual-plan | StreamWeaver Canvas |
|---|---|---|
| **Delivery model** | One-shot static publish | Live push over Unix socket |
| **When it runs** | Before or after coding | *During* coding, incrementally |
| **Interactivity** | Comment/review in browser | Button callbacks, form state, `canvas-wait` |
| **Agent loop** | Publish → URL → done | Push → wait → user acts → push again |
| **Document format** | MDX with JSX components | Ruby DSL (block-based) |
| **Rendering** | Hosted React app | Local Sinatra + Alpine.js |
| **Planning components** | Rich (ImplementationMap, Decision, AnnotatedCode) | Sparse |
| **Data/chart components** | Sparse | Rich (Chart.js suite, KPI dashboard, pipeline) |

**StreamWeaver's irreplaceable moat:** liveness. Claude Code pushes while it
*thinks*. The canvas evolves in real time. Users can interrupt. That's
fundamentally more powerful for an active coding session.

**Builder's edge:** the planning-phase component vocabulary. `ImplementationMap`,
`Decision`, `AnnotatedCode`, `Wireframe` with device frames, and `Diff` blocks
are things StreamWeaver simply doesn't have.

The smart play: steal Builder's planning components and bring them into the live
canvas model. Best of both worlds — rich planning artifacts that *also* update
in real time as Claude Code works.

---

## 3. Builder's Full Component Inventory

### Document blocks (`plan.mdx`)

| Component | What it does |
|---|---|
| `<RichText>` | Markdown prose with headings |
| `<Callout>` | Callout box — tones: `info`, `decision`, `risk`, `warning`, `success` |
| `<Checklist>` | Checkbox list |
| `<Table>` | Data table |
| `<Code>` | Syntax-highlighted code |
| `<CodeTabs>` | Tabbed code snippets |
| `<ImplementationMap>` | File path → note map |
| `<Wireframe>` | UI wireframe (html + css + surface) |
| `<Diagram>` | Architecture/flow diagram |
| `<Image>` | Image block |
| `<Tabs>` | Tabbed panel grouping |
| `<Columns>` | Column layout |
| `<CustomHtml>` | Raw HTML passthrough |
| `<QuestionForm>` | Open-ended review questions |
| `<VisualQuestions>` | Visual decision questionnaire |
| `<Decision>` | Structured options + `recommended` flag |
| `<Mermaid>` | Mermaid diagram |
| `<ApiEndpoint>` | Single API endpoint spec |
| `<OpenApiSpec>` | Full OpenAPI spec |
| `<DataModel>` | Entity relationship visualization |
| `<Diff>` | Code diff (split view) |
| `<FileTree>` | File tree navigator |
| `<JsonExplorer>` | Interactive JSON drill-down |
| `<AnnotatedCode>` | Code with line-number-pinned annotation bubbles |

### Canvas blocks (`canvas.mdx`)

| Component | What it does |
|---|---|
| `<DesignBoard>` | Root canvas wrapper |
| `<Section>` | Groups artboards by flow |
| `<Artboard>` | Individual screen/state |
| `<Screen>` | Wireframe HTML container with device chrome |
| `<Annotation>` | Callout bubble pinned to artboard edge |

Device surfaces: `browser`, `phone`, `tablet`, `desktop`, `popover`, `card`,
`widget`, `sheet`

Sketch aesthetic: rough.js overlay + Excalifont on all text = "this is a
planning sketch, not production UI"

Prototype navigation: `data-goto="artboard-id"` on buttons links screens

---

## 4. What `/visual-recap` Does (and Whether StreamWeaver Covers It)

**visual-recap** is the post-hoc counterpart. After Claude Code finishes a
coding task, `/visual-recap` takes the git diff and produces a visual document
summarizing:
- What files changed and why (`ImplementationMap`)
- Before/after code (`Diff` blocks, `AnnotatedCode`)
- Architecture changes (`Diagram`)
- Any decisions made during implementation

**Does StreamWeaver cover this?** Partially but not intentionally:
- `comparison` block handles before/after visually
- `code_block` shows code, `mermaid` handles architecture
- `dir_tree` with `[new]`/`[modified]`/`[deleted]` markers covers file changes

**What's missing:** there is no first-class "recap session" pattern. Nothing
that says "Claude Code just finished — here's what it did." Builder's
`create-visual-recap` is a *dedicated action* specifically designed to consume a
diff and output a structured recap document. StreamWeaver would need:

1. A `diff` block (split-view code diff, not just comparison panels)
2. A `recap_session` CLI command pattern: `streamweaver canvas-recap <session>`
3. Automatic session capture so Claude Code can call it at end-of-task

---

## 5. StreamWeaver's Existing Component Inventory (for reference)

### Layout
`div`, `card`/`card_header`/`card_body`/`card_footer`, `vstack`/`hstack`,
`grid`/`grid_area`, `columns`/`column`, `scroll_box`, `sticky`,
`overlay`/`fullbleed`, `collapsible`, `alert`, `hero`, `prose`, `app_header`

### Text / Display
`text`, `md`/`markdown`, `phrase`, `header1`–`header6`, `badge`, `status_dot`,
`type_tag`, `pulse_indicator`, `stat_display`, `score_table`, `status_badge`,
`pullquote`, `link_to`, `external_link_button`, `activity_item`,
`timeline_event`, `priority_item`

### Data Visualization
`bar_chart`, `hbar_chart`, `line_chart`, `sparkline`, `area_chart`, `pie_chart`,
`doughnut_chart`, `stacked_bar_chart`, `chart`, `kpi_dashboard`, `table`,
`mermaid`, `pipeline`, `image_block`, `code_block`

### Form / Input
`text_field`, `text_area`, `code_editor`, `checkbox`, `checkbox_group`,
`select`, `radio_group`, `tag_buttons`, `form`

### Navigation
`tabs`, `breadcrumbs`, `navbar`, `dropdown`, `sidebar_toc`

### Interactive / Overlays
`button`, `expandable_card`, `modal`, `show_toast`

### Visual / Presentation
`slide_container`, `comparison`, `callout`, `dir_tree`, `legend`, `flow_arrow`,
`layout_toggle`, `progress_bar`, `spinner`, `theme_preset`, `theme_toggle`,
`keyboard_shortcuts`

---

## 6. Gap Analysis — What Builder Has That StreamWeaver Doesn't

### Missing planning-phase components

| Builder Component | StreamWeaver Equivalent | Gap |
|---|---|---|
| `<ImplementationMap>` | None | **Full gap** — no file-to-rationale mapping |
| `<Decision>` | `button` (interactive) | Partial — no static decision-capture block |
| `<AnnotatedCode>` | `code_block` | Partial — no line-pinned annotation bubbles |
| `<Wireframe>` + device frames | None | **Full gap** — no device-framed mockups |
| `<Diagram>` sketch mode | `mermaid` (code-based) | Partial — no sketch/rough aesthetic |
| `<ApiEndpoint>` | None | Full gap |
| `<DataModel>` | `mermaid` ER | Partial |
| `<Diff>` | `comparison` | Partial — comparison is panel-level, not code-diff |
| `<FileTree>` | `dir_tree` | Mostly covered |
| `<JsonExplorer>` | None | Full gap (niche) |
| `<Callout tone="decision">` | `callout(:info/:warning/etc)` | Missing `decision` and `risk` tones |
| `<QuestionForm>` | None | Full gap (async review workflow) |

### Missing canvas/artboard model

StreamWeaver has no spatial artboard canvas — no `DesignBoard`, `Section`,
`Artboard`, device chrome, `Annotation` pins. The canvas is a single scrolling
panel, not a multi-screen design board.

---

## 7. Steal List — Prioritized

### P0 — High value, relatively contained

**`implementation_map`**
```ruby
implementation_map files: [
  { path: "lib/auth/session.rb", note: "Add guest token issuer" },
  { path: "app/routes/checkout.rb", note: "Branch on guest vs auth user" },
  { path: "db/schema.rb", note: "Add guest_sessions table" }
]
```
Perfect for Claude Code pre-flight: show what's about to be touched and why.
Renders as a styled file-tree with inline rationale. Extremely low novelty risk
(it's just a structured list), high value for planning sessions.

**`decision` block**
```ruby
decision question: "How should guest sessions be stored?" do
  option id: "jwt", label: "JWT in cookie", detail: "Stateless, no DB lookup"
  option id: "opaque", label: "Opaque token in DB",
          detail: "Revocable, enables account merge later", recommended: true
end
```
Planning is full of architecture forks. Capture them explicitly with a visual
treatment and a recommended path. Currently you'd approximate this with `callout`
+ `button`, but that's interactive not declarative/static.

### P1 — High value, moderate implementation

**`annotated_code`**
```ruby
annotated_code language: :ruby, annotations: [
  { line: 3, note: "Guest tokens use 'guest' role to restrict API scopes" },
  { line: 7, note: "24h TTL matches cleanup job cadence" }
] do
  <<~RUBY
    def issue_guest_token(email)
      # ...
      JWT.encode({ sub: email, role: 'guest' }, SECRET, exp: 24.hours.from_now)
    end
  RUBY
end
```
Code walkthroughs are a primary Claude Code output. Line-anchored annotations
are strictly better than prose-above-code-block for explaining what's happening
and why.

**`wireframe` with device frames**
```ruby
wireframe surface: :browser do
  <<~HTML
    <div class="page">
      <header class="topbar">MyApp</header>
      <main>
        <h2>Continue as guest?</h2>
        <button data-goto="b">Continue as Guest</button>
      </main>
    </div>
  HTML
end
```
Browser/phone/tablet chrome wrapping HTML mockups. The `data-goto` prototype
navigation is a bonus. Closes the gap for product/design work entirely.

**`diff` block**
```ruby
diff language: :ruby do
  before { "def old_method\n  session.fetch(:user)\nend" }
  after  { "def current_user\n  JWT.decode(token)\nend" }
end
```
The `comparison` block is panel-level. A `diff` block is line-level code diff
with +/- syntax and line numbers — distinct need, especially for the recap
use case.

### P2 — Lower effort additions

**Callout tones: `decision` and `risk`**
```ruby
callout :decision do
  "Choose between JWT and opaque tokens before implementing — hard to reverse."
end

callout :risk do
  "Guest sessions must expire. Proposed TTL: 24h. Missing this causes unbounded DB growth."
end
```
Two new tone values alongside existing `info/warning/success/error`. Semantic
precision matters in planning documents.

**`api_endpoint`**
```ruby
api_endpoint method: :post, path: "/api/v1/guest-sessions",
  description: "Issue a guest session token",
  params: [{ name: "email", type: "string", required: true }],
  response: { token: "string", expires_at: "iso8601" }
```
Ruby shops need API planning surfaces. Mermaid sequence diagrams are clunky for
simple endpoint specs.

**Sketch/rough aesthetic mode**
A `:sketch` theme preset that adds a hand-drawn quality (grainy backgrounds,
rough borders, Excalifont or similar). Visually distinguishes "planning canvas"
from "production dashboard" — psychologically important for stakeholders.

### P3 — Consider later

- **`json_explorer`** — niche but useful for API response exploration
- **`data_model`** — mermaid ER covers most cases
- **`QuestionForm`** — async review workflow; `canvas-wait` is better for live sessions
- **Artboard/DesignBoard model** — full spatial canvas is a major architectural
  undertaking; scope separately

---

## 8. The visual-recap Gap

Builder's `/visual-recap` is a dedicated post-coding artifact:

> After Claude Code finishes a task, consume the git diff → produce a visual
> document with ImplementationMap, AnnotatedCode, Diff blocks, and Diagram
> showing what changed, how, and why.

StreamWeaver has no equivalent pattern. To close this gap:

1. **Add `diff` block** (prerequisite) — line-level split diff rendering
2. **Add `recap_panel` CLI command** — `streamweaver recap <session_name>` that:
   - Runs `git diff HEAD~1` or takes a diff file
   - Pushes a structured canvas: `implementation_map` + `annotated_code` + `diff`
     + `mermaid` architecture summary
   - Optionally auto-saves as a doc: `docs/streamweaver_canvas/recap-<date>.rb`
3. **Companion Claude Code skill instruction**: at end of task, call
   `streamweaver recap <session>` with the diff

This is a natural complement to the existing canvas-panel workflow and
would give StreamWeaver a distinct capability Builder doesn't have: the
recap is *live*, can show work-in-progress before the task is complete,
and can be updated incrementally.

---

## 9. Implementation Sequence

```
Phase 1 — Planning blocks (2-3 sessions)
├── implementation_map component + DSL method
├── decision block component + DSL method
└── callout :decision and :risk tones

Phase 2 — Code display (1-2 sessions)
├── annotated_code component (code + line-pinned annotation bubbles)
└── diff block (split-view line diff)

Phase 3 — Visual mockups (2-3 sessions)
├── wireframe component with surface presets (browser/phone/tablet/card)
├── data-goto prototype navigation
└── :sketch theme preset (rough aesthetic)

Phase 4 — API surface (1 session)
└── api_endpoint component

Phase 5 — Recap workflow (1-2 sessions)
├── streamweaver recap CLI command
└── Claude Code companion skill for end-of-task recap
```

---

## 10. What StreamWeaver Keeps as Moat

None of the above steals touch what makes StreamWeaver actually different:

- **Live socket push** — canvas updates as Claude Code thinks, not after
- **`canvas-wait`** — pause agent loop, wait for human interaction, resume
- **Full interactivity** — Alpine.js state, button callbacks, form submissions
- **Chart suite** — Chart.js charts, kpi_dashboard, pipeline, sparkline
- **Theme system** — editorial/technical/dark/warm presets
- **`slide_container`** — presentations inside the live canvas

Builder can't replicate liveness without rebuilding their whole architecture.
That's the real differentiator to protect and deepen.

---

*Analysis by Selene — June 2026*
*Reference: https://github.com/BuilderIO/skills/tree/main/skills/visual-plan*
