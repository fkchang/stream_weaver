# StreamWeaver Current Component Inventory

## Purpose
Reference for overlap analysis — what StreamWeaver already has that can serve
the visual-skills use cases.

## Display DSL (DisplayDSL module)

### Containers
- `div(**options, &block)` — generic container
- `app_header(title, subtitle:, variant:)` — page header
- `card(**options, &block)` — card container with header/body/footer
- `card_header`, `card_body`, `card_footer` — card sub-components
- `vstack(spacing:, align:, divider:)` — vertical stack
- `hstack(spacing:, align:, justify:, divider:)` — horizontal stack
- `grid(columns:, gap:)` — CSS grid layout
- `scroll_box(max_height:)` — scrollable container
- `collapsible(label, expanded:)` — expandable section
- `alert(variant:, title:, dismissible:)` — alert banner

### Text / Display
- `text(content)` — plain text
- `md(content)` / `markdown(content)` — markdown rendering
- `header1..header6` — heading levels
- `phrase(content)` — inline text

### Dashboard Display
- `stat_display(value:, label:, color:, size:)` — metric card
- `badge(text, variant:, size:)` — inline badge
- `status_dot(status:, pulse:, size:)` — status indicator
- `type_tag(type_name, color:)` — typed label
- `pulse_indicator(color:, label:)` — animated indicator
- `activity_item(time:, title:, summary:, type:)` — activity feed item
- `priority_item(priority:, title:, description:)` — prioritized item
- `progress_bar(value:, max:, variant:, show_label:, animated:)` — progress
- `spinner(size:, label:)` — loading indicator
- `score_table(scores:)` — score display
- `table(data:, headers:, rows:, file:, path:)` — data table
- `status_badge(status, reasoning)` — status with explanation
- `external_link_button(label, url:)` — external link
- `link_to(label, href:)` — hyperlink
- `navbar(**options, &block)` — navigation bar
- `nav_item(label, href:, active:)` — nav item

## Interactive Components (App DSL, not in DisplayDSL)
- `text_field(:key, placeholder:, submit:)` — text input
- `text_area(:key, rows:, transient:)` — multiline input
- `checkbox(:key, label, submit:)` — boolean toggle
- `select(:key, options, default:)` — dropdown
- `radio_group(:key, options)` — radio buttons
- `button(label, &callback)` — action button
- State management: `state[:key]` auto-binding

## Infrastructure
- Auto-port detection (scan from 4567)
- Auto-browser open
- Puma server with Pushable streaming (SSE)
- Session state via cookies
- Theme module (dark/light)
- Phlex-based rendering
- AlpineJS adapter for client-side reactivity
- Canvas system for bridged rendering

## What's MISSING for Visual Skills (preliminary)

### Needed for Design Deck
- [ ] Mermaid diagram rendering
- [ ] Code syntax highlighting (Prism.js equivalent)
- [ ] Slide navigation component
- [ ] Option selection with radio-group-in-card pattern
- [ ] SSE push for "generate more" (Pushable exists but needs deck-specific protocol)
- [ ] Snapshot save/load/export
- [ ] Keyboard shortcut system
- [ ] Summary slide pattern
- [ ] Shimmer/skeleton loading animation

### Needed for Visual Explainer
- [ ] Mermaid diagram rendering (shared with deck)
- [ ] Code syntax highlighting (shared with deck)
- [ ] Chart.js integration
- [ ] Sticky TOC / responsive navigation
- [ ] Slide deck mode with transitions
- [ ] Self-contained HTML export
- [ ] Auto-trigger on complex table output
- [ ] Share/deploy to Vercel

### Shared Needs (overlap)
- [ ] Mermaid rendering component
- [ ] Code highlighting component
- [ ] Theme system (dark/light/auto with toggle)
- [ ] Keyboard shortcut system
- [ ] HTML export (self-contained)
- [ ] Slide/presentation component
