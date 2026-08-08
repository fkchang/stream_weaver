# streamweaver-doc: v1
header1 "Glimmer: Inspired By, Not Dependent On"

  div(style: "height:8px")

  columns widths: ["50%", "50%"] do
    column do
      card do
        header3 "Why we skip the Glimmer gem"
        badge "Too heavy for Opal", color: :red
        div(style: "height:8px")
        md "Glimmer depends on **facets** — a massive Ruby utility library. Compiled to Opal, facets alone balloons the JS bundle."
        div(style: "height:8px")
        md "Also: the `<=>` / `<=` binding syntax is confusing — it reuses comparison operators for a completely different meaning."
        div(style: "height:8px")
        md "We take the **ideas**, not the code."
      end
    end
    column do
      card do
        header3 "What we take from Glimmer"
        badge "Conceptual only", color: :green
        div(style: "height:8px")
        md "**Observer pattern** — the right model for reactive state"
        md "**Direct DOM** (no virtual DOM) — proven to be sufficient"
        md "**Observable model enhancement** — state auto-notifies observers when keys change"
        div(style: "height:8px")
        md "We implement this in ~70 lines of pure Ruby/Opal. No dependencies."
      end
    end
  end

  div(style: "height:24px")
  header2 "ReactiveState: ~70 Lines, Zero Deps"
  div(style: "height:8px")

  card do
    header3 "Design"
    columns widths: ["50%", "50%"] do
      column do
        md "**ReactiveState** is a Ruby hash wrapper:"
        md "- `[]` tracks which block regions read which keys during render"
        md "- `[]=` notifies observers when a key changes"
        md "- Observers are DOM updater lambdas registered at render time"
        div(style: "height:8px")
        md "Explicit watch for edge cases:"
        md "- `watch(:search) { |val| ... }` — readable, obvious"
        md "- No operator overloading confusion"
      end
      column do
        md "**Invisible to the user — no API change:**"
        md "Phase 1: plain hash, whole block re-runs"
        md "Phase 2: ReactiveState proxy, only affected DOM nodes update"
        div(style: "height:8px")
        md "Same DSL code works in both phases. Upgrade is internal to the adapter."
        div(style: "height:8px")
        badge "Zero learning curve for app authors", color: :green
      end
    end
  end

  div(style: "height:24px")
  header2 "Final Layer Map"
  div(style: "height:8px")

  table(
    headers: ["Layer", "What it is", "Phase"],
    rows: [
      ["User DSL", "Unchanged StreamWeaver DSL — same app/card/text_field/button", "Now"],
      ["Adapter::Opal", "Renders DSL to HTML string, wires event listeners, holds state", "1"],
      ["OpalBuilder", "opal-build command → dist/index.html + dist/app.js", "1"],
      ["morphdom.js", "Client-side DOM patching after block re-execution", "1"],
      ["ReactiveState", "~70-line Observable hash: auto-tracks reads, notifies on write", "2"],
      ["History API wrapper", "route DSL via pushState/popstate — same calls as Sinatra routes", "2"],
      ["Supabase client", "Thin Ruby/Opal wrapper — sync state to Supabase on demand", "3 (MMA app)"]
    ]
  )