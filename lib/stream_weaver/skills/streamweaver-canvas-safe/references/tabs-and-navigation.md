# Tabs and Navigation

## tabs (eager, default) — plays well everywhere

```ruby
tabs :settings_tabs do
  tab "General" do
    text "General settings content"
  end
  tab "Notifications" do
    text "Notification settings content"
  end
end
```

Pure client-side `@click activeTab = N` — WORKS identically in A, B, and C. Variants (`variant: :enclosed`, `variant: :"soft-rounded"`) are CSS-only, no change to this. This is the form to reach for in the comprehensive example / any doc that has to survive an export.

## tabs url: true — the one component that's MORE capable off the live canvas

```ruby
tabs :view, url: true do
  tab "Overview" do ... end
  tab "Details" do ... end
end
```

On canvas (A, B) this degrades to plain client-side tabs and logs a warning once per render — to the **agent's** stderr, never shown to the human viewing the page (`route_tabs? = component.url? && !websocket_mode?`). In an export (C), `sw-route-tabs.js` is inlined and runs real `pushState` routing, so the URL updates and the tab state survives a reload. This is intentional and informational (disc-099), not a bug — but if you're diagnosing "why does this tab set behave differently exported vs. on canvas," this is why. Not yet confirmed under `file://` — several browsers throw `SecurityError` for `pushState` on `file://` origins, so an exported doc opened directly from disk (not served over HTTP) may still break tab switching; check by hand if that's how the export will be opened.

## collapsible / expandable_card / dropdown — plays well everywhere

```ruby
collapsible "Show Details" do
  text "Detail content"
end

expandable_card "Section" do  # like collapsible, but the SERVER learns the expanded state
  text "..."
end
```

Pure Alpine `x-show`/`x-data`, no server dependency — WORKS in A, B, C. Use `expandable_card` over `collapsible` only if you need `state` to know whether a section is open; that's a server round-trip and inherits the sendEvent-only-on-live-canvas disposition for that specific bit of state (the panel itself still opens/closes client-side everywhere).

## modal — needs a real server, half the time

Modal *closing* is Alpine-only and works everywhere. Modal *opening* is server-state driven — on the live canvas an agent has to push the state that opens it; on canvas-read and export there's no way to open one at all (SILENTLY-DEAD). Don't build a doc where the only path to some content is "click to open a modal" if that doc needs to survive being saved and reopened later.

## route_by / route / page — needs a real server

The SSE client and routing/`popstate` scripts are `AppView`-only. Canvas (A, B) renders through `AppContentView`, export (C) through `ComponentRenderer.render_html` — neither ever gets those scripts, so `route_by` has no client at all backend-less. The initial paint shows and nothing ever updates. Out of scope for this skill's fixes; know it going in rather than debug a page that "isn't routing."

## The gotcha

Route tabs are the one component in this whole skill where "more functional off the live canvas" is correct and not a regression. Every other asymmetry in this doc runs the other direction (live canvas is the most capable context) — this is the exception, and it's easy to mistake for a bug if you don't know it's by design.
