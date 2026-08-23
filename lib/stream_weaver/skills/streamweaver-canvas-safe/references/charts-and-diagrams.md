# Charts and Diagrams

Both families WORK in all three contexts. This is the one area where the fix (chart-export-allowlist, 2026-08-23) is recent enough to be worth restating rather than assuming.

## Charts

```ruby
bar_chart data: { calendar: 45, news: 120, tasks: 30 }
hbar_chart data: { "Phase A" => 25, "Phase B" => 45 }
line_chart data: { jan: 10, feb: 25, mar: 18 }
pie_chart data: { chrome: 60, safari: 25, firefox: 15 }
sparkline data: [3, 7, 4, 9, 2, 8]
stacked_bar_chart data: [{ label: "Q1", series: { a: 10, b: 20 } }]
area_chart data: { jan: 10, feb: 25, mar: 18 }
doughnut_chart data: { chrome: 60, safari: 25, firefox: 15 }
chart type: :bar, data: { a: 1, b: 2 }  # the base component directly
```

Every one of the shorthand methods above builds a `ChartBase` subclass under the hood, not `Components::Chart` itself. Before 2026-08-23, `streamweaver export`'s CDN-inclusion check tested `is_a?(Components::Chart)` — so every shorthand method failed the check while `chart type: ...` passed it. The exported markup still carried the guarded `x-init="if (typeof Chart !== 'undefined') { new Chart(...) }"`, so nothing threw; you got an empty bordered box, console-silent, that looked like a rendering glitch rather than a missing library. **Fixed:** the gate now checks `components_include?(Components::Chart) || components_include?(Components::ChartBase)` — the whole family, keyed on the base class so a future chart subclass can't silently join the dead list the way the shorthand methods did.

## Mermaid

```ruby
mermaid <<~MERMAID
  graph LR
    A["Calendar"] --> B["Sync script"] --> C["state.yaml"]
MERMAID

mermaid diagram_code, zoom: true      # pan/zoom controls
mermaid diagram_code, compact: true   # reduced padding for card embedding
mermaid diagram_code, layout: :elk    # note: --offline export has no global ELK build
```

`sw-mermaid-zoom.js` (the interaction engine) is inlined and travels into every export; the mermaid *library itself* is CDN-referenced by default. `streamweaver export --offline` inlines the mermaid library so diagrams survive a CSP-locked viewer — but that flag covers mermaid only, not Alpine or Prism, and it doesn't help `layout: :elk` (no global ELK build to inline).

## The gotcha

Don't assume "WORKS in all three contexts" from this file also means "survives a CSP-locked viewer with no flags." A default (non-`--offline`) export still loads the chart/mermaid CDN scripts over the network — a CSP that blocks external hosts breaks them exactly like it breaks Alpine. `--offline` closes the mermaid gap; nothing closes the Chart.js one yet if you need a fully offline, CSP-safe chart export.
