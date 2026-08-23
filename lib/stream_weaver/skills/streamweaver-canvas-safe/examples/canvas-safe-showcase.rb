# streamweaver-doc: v1
# Canvas-safe showcase — every component below is drawn from the
# plays-well-everywhere list in SKILL.md. Verified to render correctly with
# no silently-dead component and no missing script pairing in all three
# backend-less contexts: the live bridge (websocket adapter), Canvas::Reader
# (canvas-read), and `streamweaver export`. Deliberately carries no
# sendEvent-only component (button, radio_group, ...) — see
# references/actions-and-buttons.md for how to layer live-canvas
# interactivity on top of a doc built from this skeleton.

sidebar_toc sections: [
  { id: "overview", label: "Overview" },
  { id: "data", label: "Data" },
  { id: "diagram", label: "Diagram" }
]

doc_header(
  eyebrow: "streamweaver-canvas-safe · example",
  title: "Canvas-Safe Component Showcase",
  pills: [{ text: "Reference" }, "Renders identically in canvas, canvas-read, and export"]
)

doc_section_header "01", "Overview", id: "overview"

md <<~MD
  Every component on this page owns its own state — either it's flat markup with
  no server dependency, or it's Alpine `x-data` that never asks an enclosing
  scope for anything. That's the whole trick: nothing here round-trips, so
  nothing here has anything to lose when the doc is reopened with no backend
  behind it.
MD

callout(variant: :info, title: "Why this matters") do
  text "A doc built only from this component set survives being saved and reopened " \
       "later, or exported and handed to someone with no StreamWeaver server running " \
       "at all — byte-for-byte the same interactivity in every context."
end

card do
  card_header "Status", badge: "Live", meta: "plays-well-everywhere"
  card_body do
    status_dot(status: :green)
    text "All components below: WORKS in canvas, canvas-read, and export"
    md "Collapse the section below to see client-side Alpine state that never touches a server."
  end
end

collapsible "Show implementation notes" do
  md "This panel opens and closes via Alpine `x-show` — no request, no round-trip, " \
     "identical behavior whether a bridge is listening or not."
end

tabs :showcase_tabs do
  tab "Plain tabs" do
    text "Eager, client-side tabs (no url: true) — pure @click state, works everywhere."
  end
  tab "Why not url: true?" do
    text "tabs url: true degrades on canvas (plain client tabs + an agent-only stderr " \
         "warning) but becomes MORE capable in an export (real pushState routing). " \
         "See references/tabs-and-navigation.md."
  end
end

doc_section_header "02", "Data", id: "data"

table(
  headers: ["Component", "A live canvas", "B canvas-read", "C export"],
  rows: [
    ["Everything on this page", "WORKS", "WORKS", "WORKS"],
    ["button / clickable / form submit", "WORKS", "DEGRADES", "SILENTLY-DEAD"],
    ["text_field auto-submit", "DEGRADES", "SILENTLY-DEAD", "SILENTLY-DEAD"]
  ],
  sortable: true
)

bar_chart data: { canvas: 3, "canvas-read": 3, export: 3 }

doc_section_header "03", "Diagram", id: "diagram"

mermaid <<~MERMAID
  graph LR
    A["Same .rb file"] --> B["Live canvas (A)"]
    A --> C["canvas-read (B)"]
    A --> D["streamweaver export (C)"]
    B --> E["Identical render"]
    C --> E
    D --> E
MERMAID

code_block(<<~RUBY, lang: "ruby", copy: true)
  # Pushed to a live canvas...
  streamweaver canvas-push showcase < canvas-safe-showcase.rb
  # ...or exported as a static file...
  streamweaver export canvas-safe-showcase.rb -o showcase.html
  # ...same DSL, same rendered result either way.
RUBY

theme_toggle
