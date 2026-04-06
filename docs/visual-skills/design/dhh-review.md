# DHH-Style Architecture Review: StreamWeaver Visual Skills

*Reviewed: 2026-03-12*
*Document under review: `docs/visual-skills/design/architecture.md`*

---

## Overall Assessment

This is a strong architecture document that mostly respects the existing codebase and resists the temptation to over-engineer. The DSL reads like Ruby, the flat namespace decision is correct, and the "DSL IS the API" philosophy is sound. The design deck DSL -- `design_deck`, `slide`, `option` -- composes beautifully and would feel natural to any Ruby developer. However, there are areas where the document drifts into enterprise architecture territory: too many component classes for what are essentially styled divs, a polling-based generate-more loop that should be simpler, and a directory tree that implies 40+ new files when half of them could be collapsed. The good bones are here, but the document needs a ruthless editing pass to separate what must exist from what merely could exist.

---

## Critical Issues

### 1. The Component Explosion

The document proposes roughly 30 new component classes. Many of these are CSS variations, not behavioral differences:

- `VeCard` is a `Card` with a CSS class. The document even acknowledges this: "a simpler depth-styled container." That is not a new class -- that is a `card depth: :hero` option.
- `DataTable` is `Table` with `sticky_header: true`. Add the options to `Table`.
- `HeroSection` is a `div` with a CSS class.
- `Prose` is a `div` with `max-width` set.
- `Pullquote` is a `blockquote` with styling.
- `FlowArrow` is an SVG arrow.
- `Legend` is a list of colored dots with labels.

Every new class is a file to maintain, a DSL method to document, and a concept a developer must learn. The bar for "this deserves to be a Component subclass" should be: does it have meaningful behavior or state that a CSS class cannot express?

**Recommendation:** Collapse pure-display components into existing primitives with variant/class options. Reserve new classes for components with actual behavior (Mermaid, SlideContainer, DesignDeck, KeyboardShortcuts, CodeBlock, Comparison).

### 2. Duplicate Table Implementations

Creating `DataTable` alongside `Table` is wrong. You already have a `Table` component. Extend it:

```ruby
table headers: ["Risk", "Severity"], rows: [...],
      sticky_header: true, alternating: true, scrollable: true
```

Two table classes in the same component library is a maintenance nightmare and a source of developer confusion. "Should I use `table` or `data_table`?" is a question no one should have to ask.

### 3. The Generate-More Polling Loop is Over-Engineered

Section 7 introduces a state machine with five states, a polling endpoint, a request queue, a thread in the agent script, timeout tracking, and skeleton replacement via SSE. This is a lot of machinery for "user clicks button, agent generates options, options appear."

The existing `Feed` + `Pushable` infrastructure already handles server-to-browser push. The missing piece is browser-to-agent signaling, and polling is the simplest answer -- fine. But the state machine diagram, the `deck_generate` state hash with six keys, and the explicit timeout handling are premature. Start with:

1. User clicks Generate. POST goes to server. Server queues it.
2. Agent polls, gets request, generates, pushes via Feed.
3. Done.

Timeout? The browser shows a spinner. If nothing arrives, the user clicks again. No state machine needed. No `started_at` tracking. No client-side timeout logic. Build the complex version when the simple version proves insufficient.

---

## Improvements Needed

### 4. The Deck Namespace is Correct but Inconsistent

The document says "flat namespace" then immediately creates `Components::Deck::*` with 10 classes. That is not flat. The deck subsystem deserves its own namespace -- that decision is sound. But call it what it is: a namespaced subsystem, not a flat namespace. The document's framing is misleading.

### 5. Repeated Container Capture Pattern

The existing `App` class has this pattern repeated approximately 15 times:

```ruby
parent_components = @components
@components = []
instance_eval(&block)
component.children = @components
@components = parent_components
```

The document proposes adding more instances of this same pattern for `design_deck`, `slide`, `option`, `comparison`, etc. The `capture_children_then_append` and `with_container` private methods exist but are not consistently used. Every new container DSL method should use one of these two helpers, not inline the pattern again.

The `design_deck` method in Section 4.1 inlines the pattern. The `slide` method inlines it. The `option` method inlines it. Use `with_container` or `capture_children_then_append`:

```ruby
def design_deck(title, **options, &block)
  deck = Components::Deck::DesignDeck.new(title, **options)
  with_container(deck, &block)
  deck.children << Components::Deck::DeckSummary.new
  deck.validate!
  deck
end

def slide(id, title = nil, **options, &block)
  raise "slide must be inside design_deck" unless @current_deck
  capture_children_then_append(Components::Deck::DeckSlide.new(id, title, **options), &block)
end
```

### 6. DSL Method Naming Collisions

The document proposes adding `slide` and `option` as top-level DSL methods on `App`. These are extremely generic names. Today, `slide` might mean a deck slide. Tomorrow, someone wants a carousel slide or a presentation slide.

The existing codebase avoids this -- `tab` is scoped by `@current_tabs` context, `crumb` by `@current_breadcrumbs`. The document does include context checks (`raise "slide must be inside design_deck"`), which is good. But consider whether `deck_slide` and `deck_option` would be clearer in the DSL:

```ruby
design_deck "Direction" do
  deck_slide "arch", "Architecture" do
    deck_option "Monolith" do ... end
  end
end
```

Actually, no. Within the `design_deck` block, the context is unambiguous. `slide` and `option` read better. The context checks are sufficient. Keep the short names. The DSL reads like prose, which is the goal.

### 7. CDN Asset Declaration is Good, But the Method Name is Wrong

```ruby
def cdn_assets
  [:mermaid]
end
```

This conflates the asset with its delivery mechanism. What if you later vendor these? Call it `required_assets` or `external_assets`. The component should declare what it needs, not how it is delivered.

### 8. The Skill Entry Points are Premature

Section 6.5 proposes `DesignDeckSkill` and `VisualExplainerSkill` classes that accept structured data and generate Ruby DSL scripts. This is a code generator that generates code for a DSL. That is one layer of indirection too many.

The agent already writes Ruby. The DSL IS the API. Why would the agent pass structured data to a skill class that then generates the same Ruby the agent could have written directly? This only makes sense if the agent cannot write Ruby -- but the entire architecture assumes it can.

Kill the skill entry points. The DSL is the skill entry point.

### 9. Theme Presets -- Good Concept, Watch the Scope

Nine presets is a lot for a first pass. Ship with two (one for deck, one for explainer). Add more when users ask. The preset mechanism itself is clean -- CSS custom properties via `theme_overrides` is the right approach.

---

## What Works Well

### The DSL Reads Beautifully

Section 10's examples are genuinely pleasant to read. This is the gold standard:

```ruby
design_deck "Component Library Direction" do
  slide "palette", "Color Palette",
        context: "Choose the color direction" do
    option "Warm Earth Tones", recommended: true do
      code_block <<~CSS, lang: "css"
        :root { --primary: #c2825a; }
      CSS
    end
  end
end
```

That reads like a description of what should appear. An agent could write this. A human could read this. This is what good DSL design looks like.

### The Visual Explainer Example (Section 10.2) is Excellent

The diff review page example composes cleanly. `hero_section`, `ve_card`, `callout`, `code_block`, `data_table` -- each call earns its place. The `sidebar_toc` with section IDs that match `ve_card` IDs is elegant implicit linking.

### Flat Namespace for Shared Components

Correct decision. `mermaid` belongs next to `table` and `card`. No `VisualSkills::Components::Mermaid` namespace soup.

### Design Deck as DSL Methods, Not a Subclass

Correct decision. `design_deck` is like `tabs` or `modal` -- a DSL method that composes children. No `DesignDeckApp < App` parallel hierarchy.

### The Open Questions are Well-Reasoned

All nine recommendations are sound:

- **Q1 (Session storage):** Server-side session, overflow to file if needed. Correct. Do not prematurely optimize.
- **Q2 (Adapter extension):** Display components render themselves, interactive components use the adapter. This is already the implicit pattern -- making it explicit is good.
- **Q3 (Polling):** Simple polling wins. Correct.
- **Q4 (Not a subclass):** Correct, as noted above.
- **Q5 (DisplayDSL for shared components):** Correct. Feed push of mermaid diagrams is powerful.
- **Q6 (Mermaid re-rendering):** `mermaid.run({ nodes: [newElement] })` after DOM insertion. Simple and correct.
- **Q7 (Anti-slop):** Documentation only. Correct. Do not build a CSS linter.
- **Q8 (Comparison syntax):** Named blocks (`before`/`after`). Correct. Follows existing `trigger`/`menu` pattern.
- **Q9 (Slash commands outside gem):** Correct. Agent logic and rendering logic should not be coupled.

### The Comparison Component DSL

```ruby
comparison before_label: "Current", after_label: "Proposed" do
  before { mermaid "..." }
  after { mermaid "..." }
end
```

This is clean and follows the established `dropdown` pattern with `trigger`/`menu`. Named blocks for multi-region components is the right idiom for this DSL.

### HtmlExporter as Infrastructure, Not a Component

Correct separation. Export is a pipeline operation on the entire app, not a renderable component.

---

## Summary of Recommendations

1. **Collapse CSS-only components** into existing primitives with options. Cut the class count by 40%.
2. **Merge DataTable into Table.** One table class, more options.
3. **Simplify the generate-more loop.** Kill the state machine. Queue, poll, push. Three steps.
4. **Use `with_container`/`capture_children_then_append` consistently** in all new DSL methods. Do not inline the capture pattern again.
5. **Rename `cdn_assets` to `required_assets`.**
6. **Kill the Skill entry points.** The DSL is the API. The agent writes Ruby directly.
7. **Ship two theme presets**, not nine. Add more when demanded.
8. **Phase 1 is correctly prioritized.** Mermaid, CodeBlock, and theme enhancements unblock everything. Ship those first and let the rest follow from real usage.

The architecture is fundamentally sound. The DSL design is strong. The main risk is building too many small classes that each do too little. Ruby's power is in expressive, composable abstractions -- not in having a class for every visual concept. A `div` with a CSS class is still a `div`. Treat it that way.
