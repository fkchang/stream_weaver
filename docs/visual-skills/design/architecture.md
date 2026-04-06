# StreamWeaver Visual Skills -- Architecture Design

*Date: 2026-03-12*
*Author: Architecture design for porting pi-design-deck and visual-explainer into StreamWeaver*

---

## 1. Design Philosophy

### Core Principles

**The DSL IS the API.** An agent (Claude Code, Pi, Codex) communicates with StreamWeaver by writing Ruby DSL calls. Not JSON. Not raw HTML. Ruby. The DSL is expressive enough that the agent's output reads like a description of what should appear, and the framework handles rendering, theming, interactivity, and streaming.

**Follow existing patterns.** StreamWeaver already has a clear architecture: `Components::Base` subclasses, `DisplayDSL` module methods, `Adapter::Base` rendering dispatch, Phlex views, Sinatra routes, and `Pushable` for SSE. New visual skills components slot into this architecture -- they do not introduce parallel systems.

**Pareto code.** 37% of the two projects is shared infrastructure. Build the shared 37% first, then the deck-specific and explainer-specific components layer on top. No premature abstraction: if a component is only used by one skill, it lives in that skill's namespace.

**Composable, not monolithic.** Each component is independently usable. You can drop a `mermaid` block into any StreamWeaver app, not just a design deck or visual explainer. The deck and explainer are orchestrators that compose shared components into specific workflows.

### Architectural Decision: Flat Namespace

Components live in `StreamWeaver::Components::*` -- the same namespace as existing components. No `VisualSkills` sub-namespace. Rationale:

1. Existing components like `Table`, `Card`, `Grid` are already in `Components::*`
2. New components (`Mermaid`, `CodeBlock`, `Pipeline`) are general-purpose -- they belong alongside `Table` and `Card`
3. The DSL methods on `DisplayDSL` are flat (`mermaid`, `code_block`, `pipeline`) -- nesting the classes adds complexity with no benefit
4. Deck-specific orchestrators (`DesignDeck`, `DeckSlide`) are the exception -- they get a `Components::Deck::*` sub-namespace because they form a coherent subsystem

---

## 2. Module Structure

### Directory Tree

```
lib/stream_weaver/
  components.rb                    # Existing -- add new component classes here
  display_dsl.rb                   # Existing -- add new DSL methods here
  app.rb                           # Existing -- add deck/explainer DSL methods
  theme.rb                         # Existing -- enhance with presets, auto-mode
  pushable.rb                      # Existing -- no changes needed
  streamer.rb                      # Existing -- no changes needed
  feed.rb                          # Existing -- no changes needed

  components/
    mermaid.rb                     # Mermaid diagram component
    code_block.rb                  # Syntax-highlighted code block
    image_block.rb                 # Image with caption, base64 export support
    slide_container.rb             # Slide navigation (swap + scroll-snap modes)
    slide.rb                       # Single slide within a container
    progress_indicator.rb          # Fixed-position navigation progress bar
    keyboard_shortcuts.rb          # Shortcut registration system
    callout.rb                     # Bordered info/warning/tip box
    pipeline.rb                    # Step flow visualization
    comparison.rb                  # Side-by-side diff panels
    chart.rb                       # Chart.js wrapper
    sidebar_toc.rb                 # Sticky TOC with scroll spy
    ve_card.rb                     # Depth-tiered card (hero/elevated/default/recessed)
    kpi_dashboard.rb               # Metrics grid wrapping stat_display
    data_table.rb                  # Enhanced table with sticky headers

    # NOTE: hero_section, prose, pullquote, dir_tree, legend, flow_arrow,
    # and layout_toggle are CSS-only helpers -- no separate component files.
    # They are implemented as thin DSL methods that emit styled divs directly.

    deck/                          # Design deck subsystem
      design_deck.rb               # Top-level deck orchestrator
      deck_slide.rb                # Decision slide with options grid
      deck_option.rb               # Selectable option card
      deck_summary.rb              # Auto-generated summary slide
      generate_more_controls.rb    # Generate button, count, prompt
      skeleton_placeholder.rb      # Shimmer loading animation
      model_selector.rb            # AI model picker
      confirmation_bar.rb          # Cancel confirmation
      close_overlay.rb             # Post-submit/cancel overlay

  theme/
    presets.rb                     # Curated font+color preset definitions
    auto_mode.rb                   # OS preference detection, localStorage persistence

  export/
    html_exporter.rb               # Self-contained HTML generation pipeline

  assets/
    js/
      mermaid_zoom.js              # ~200 line zoom/pan engine
      keyboard_shortcuts.js        # Centralized key handler
      slide_navigation.js          # Shared slide nav logic
      deck_selection.js            # Option selection radio behavior
      generate_more.js             # SSE listener for new options
    css/
      visual_skills.css            # Shared visual skills styles
      deck.css                     # Deck-specific styles
      explainer.css                # Explainer-specific styles
      depth_tiers.css              # Surface depth tier styles
      slide_transitions.css        # Slide animation presets
```

### Module Inclusion Hierarchy

```
StreamWeaver::DisplayDSL           # Shared display-only DSL
  includes: mermaid, code_block, callout, pipeline, comparison,
            chart, ve_card, kpi_dashboard, data_table,
            image_block, sidebar_toc, slide_container
  # CSS-only helpers (thin DSL methods, no Component class):
  #   prose, pullquote, hero_section, dir_tree, legend,
  #   flow_arrow, layout_toggle

StreamWeaver::App
  includes DisplayDSL              # Gets all shared methods
  adds: design_deck, theme_toggle, keyboard_shortcuts,
        html_export, toast (already exists),
        theme_preset, generate_more_controls, model_selector,
        confirmation_bar, close_overlay

StreamWeaver::FeedBuilder
  includes DisplayDSL              # Feed can push any display component
```

---

## 3. Shared Components

### 3.1 Mermaid

```ruby
# DSL usage
mermaid "graph TD\n  A-->B\n  B-->C"
mermaid "graph LR\n  A-->B", zoom: true, layout: :elk
mermaid code, compact: true, theme_vars: { primaryColor: "#ff0000" }

# Class
class Components::Mermaid < Components::Base
  attr_reader :code, :zoom, :compact, :layout, :theme_vars

  def initialize(code, zoom: false, compact: false, layout: :default, theme_vars: {}, **options)
  def render(view, state)
  def cdn_assets  # => [:mermaid] or [:mermaid, :mermaid_elk]
end

# Adapter method
class Adapter::AlpineJS
  def render_mermaid(view, component, state)
    # Renders: <div class="sw-mermaid-wrap" [x-data for zoom state]>
    #            <pre class="mermaid">#{code}</pre>
    #            [zoom controls if zoom: true]
    #          </div>
  end
end
```

Conceptual HTML output:
- Compact mode: `<div class="sw-mermaid sw-mermaid--compact"><pre class="mermaid">...</pre></div>`
- Zoom mode: `<div class="sw-mermaid sw-mermaid--zoom" x-data="mermaidZoom()">` with +/- buttons, expand button, pan/zoom container

CDN: `<script type="module">import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs'</script>`

### 3.2 CodeBlock

```ruby
# DSL usage
code_block "const x = 1;", lang: "javascript"
code_block File.read("src/app.rb"), lang: "ruby", file: "src/app.rb"
code_block snippet, lang: "ts", truncate: 3  # thumbnail mode

# Class
class Components::CodeBlock < Components::Base
  attr_reader :code, :lang, :file, :truncate, :scroll

  def initialize(code, lang: nil, file: nil, truncate: nil, scroll: true, **options)
  def render(view, state)
  def cdn_assets  # => [:prismjs]
end
```

Conceptual HTML: `<div class="sw-code-block"><div class="sw-code-header">src/app.rb</div><pre><code class="language-ruby">...</code></pre></div>`

### 3.3 ThemeToggle

```ruby
# DSL usage (in App context)
theme_toggle mode: :auto, hotkey: "mod+shift+l"

# Class
class Components::ThemeToggle < Components::Base
  def initialize(mode: :dark, hotkey: nil, persist: true, **options)
  def render(view, state)
end
```

This enhances the existing `ThemeSwitcher` component. Adds:
- Auto mode via `prefers-color-scheme` media query listener
- Keyboard shortcut registration (delegates to `KeyboardShortcuts`)
- `localStorage` persistence of override
- `<meta name="theme-color">` management
- Sun/moon toggle button UI

### 3.4 KeyboardShortcuts

```ruby
# DSL usage (in App context)
keyboard_shortcuts do |kb|
  kb.on "mod+s", context: :global do |state|
    # save action
  end
  kb.on "ArrowRight", context: :navigation do |state|
    # next slide
  end
  kb.on "1..9", context: :selection do |state, key|
    # quick select
  end
end

# Class
class Components::KeyboardShortcuts < Components::Base
  def initialize(**options)
  def on(key, context: :global, &block)
  def render(view, state)  # Emits JS registration script
end
```

This is a non-visual component. It emits a `<script>` block that registers keyboard handlers. Context awareness is handled client-side: handlers check `document.activeElement` against suppression selectors (`.sw-mermaid-wrap`, `.sw-code-scroll`, `textarea`, `input[type=text]`).

"mod" maps to Meta on Mac, Control elsewhere. This mapping happens in JS.

### 3.5 HtmlExporter

```ruby
# DSL usage (not a display component -- called programmatically)
StreamWeaver::Export::HtmlExporter.export(
  app,
  path: "~/.agent/diagrams/review.html",
  inline_images: true
)

# Class (not a Component -- infrastructure)
module StreamWeaver::Export
  class HtmlExporter
    def initialize(app, state: {})
    def export(path:, inline_images: false)
    def to_html(inline_images: false)  # => String

    private
    def collect_cdn_links       # Mermaid, Chart.js, Prism.js, Google Fonts
    def inline_css              # All theme + component CSS
    def inline_images_as_base64 # Convert image src to data URIs
    def render_body             # Phlex render to string
  end
end
```

### 3.6 SlideContainer

```ruby
# DSL usage
slide_container mode: :swap, progress_bar: true do
  slide "intro", "Introduction" do
    # content
  end
  slide "arch", "Architecture" do
    # content
  end
end

slide_container mode: :scroll_snap, nav_dots: true, counter: true do
  slide "title", type: :title do ... end
  slide "content1", type: :content do ... end
end

# Class
class Components::SlideContainer < Components::Base
  attr_reader :mode, :progress_bar, :nav_dots, :counter, :keyboard_nav
  attr_accessor :children  # Array<Components::Slide>

  def initialize(mode: :swap, progress_bar: true, keyboard_nav: true,
                 nav_dots: false, counter: false, **options)
  def render(view, state)
end

class Components::Slide < Components::Base
  attr_reader :id, :title, :type
  attr_accessor :children

  def initialize(id, title = nil, type: :content, **options)
  def render(view, state)
end
```

Two modes share the same container class:
- `:swap` -- only active slide visible, Back/Next buttons, fade transition (deck use case)
- `:scroll_snap` -- all slides rendered, CSS `scroll-snap-type: y mandatory`, 100dvh per slide (explainer use case)

Both modes share: keyboard navigation state, progress tracking, Alpine.js `x-data` for current slide index.

### 3.7 ProgressIndicator

```ruby
# DSL usage (usually implicit within slide_container)
progress_indicator current: 2, total: 5, position: :top

# Class
class Components::ProgressIndicator < Components::Base
  def initialize(current: 0, total: 0, position: :top, animated: true, **options)
  def render(view, state)
end
```

Renders a fixed-position bar at the top of the viewport. Width = `(current / total) * 100%`. CSS transition on width for animation.

### 3.8 Toast

Already exists as `Components::ToastContainer` with `show_toast` DSL method. No new component needed. The existing implementation covers deck's needs for save confirmations and generation timeouts.

### 3.9 ImageBlock

```ruby
# DSL usage
image_block "assets/diagram.png", alt: "Architecture", caption: "System overview"
image_block "/path/to/file.png", base64: true  # for export mode

# Class
class Components::ImageBlock < Components::Base
  attr_reader :src, :alt, :caption, :base64_mode

  def initialize(src, alt: "", caption: nil, base64: false, **options)
  def render(view, state)
  def to_data_uri  # Convert file to base64 data URI
end
```

StreamWeaver's Rack server serves static assets. For local file paths, the adapter generates a URL to an asset-serving endpoint. In export mode (`base64: true`), the image is inlined as a data URI.

---

## 4. Design Deck Architecture

### 4.1 DesignDeck -- The Orchestrator

The design deck is **not** a subclass of `App`. It is a set of DSL methods available in `App` that compose shared components into the deck workflow. This follows the existing pattern where `tabs`, `modal`, and `form` are DSL methods on `App`, not separate app types.

```ruby
# Agent writes this Ruby script:
app "Architecture Direction", theme: :dark do
  design_deck "Architecture Direction" do
    slide "arch", "System Architecture", context: "Choose the backend pattern" do
      option "Monolith", aside: "Simpler to deploy" do
        mermaid "graph TD\n  Client-->API\n  API-->DB", compact: true
        code_block "app.listen(3000)", lang: "ts"
      end
      option "Microservices", recommended: true do
        mermaid "graph LR\n  Gateway-->Auth\n  Gateway-->Orders", compact: true
      end
    end

    slide "db", "Database Strategy" do
      option "PostgreSQL", aside: "ACID compliance" do
        code_block "CREATE TABLE users (...)", lang: "sql"
      end
      option "MongoDB" do
        code_block "db.users.insertOne({...})", lang: "javascript"
      end
    end
  end
end
```

```ruby
# Class hierarchy
class Components::Deck::DesignDeck < Components::Base
  attr_reader :title
  attr_accessor :children  # Array<Deck::DeckSlide>

  def initialize(title, **options)
  def render(view, state)

  # Validates: no duplicate slide IDs, no "summary" ID, only one active deck
  def validate!
end
```

The `design_deck` DSL method on `App`:

```ruby
class App
  def design_deck(title, **options, &block)
    deck = Components::Deck::DesignDeck.new(title, **options)
    @components << deck
    @current_deck = deck

    parent_components = @components
    @components = []
    instance_eval(&block)
    deck.children = @components
    @components = parent_components

    # Auto-append summary slide
    deck.children << Components::Deck::DeckSummary.new
    deck.validate!

    @current_deck = nil
    deck
  end

  def slide(id, title = nil, **options, &block)
    raise "slide must be inside design_deck" unless @current_deck
    slide = Components::Deck::DeckSlide.new(id, title, **options)
    @components << slide

    parent_components = @components
    @components = []
    instance_eval(&block)
    slide.children = @components
    @components = parent_components
  end

  def option(label, **options, &block)
    raise "option must be inside a slide" unless @current_deck
    opt = Components::Deck::DeckOption.new(label, **options)
    @components << opt

    parent_components = @components
    @components = []
    instance_eval(&block)
    opt.children = @components  # preview blocks: mermaid, code_block, etc.
    @components = parent_components
  end
end
```

### 4.2 DeckSlide

```ruby
class Components::Deck::DeckSlide < Components::Base
  attr_reader :id, :title, :context_text, :columns
  attr_accessor :children  # Array<Deck::DeckOption>

  def initialize(id, title, context: nil, columns: nil, **options)
  def render(view, state)
  def auto_columns  # => 1, 2, 3, or 4 based on option count
end
```

Renders as a grid of option cards within a slide wrapper. Auto-column detection: 1 option -> 1 col, 2 -> 2, 3 -> 3, 4+ -> 2 or auto-fit.

### 4.3 DeckOption

```ruby
class Components::Deck::DeckOption < Components::Base
  attr_reader :label, :aside, :recommended
  attr_accessor :children  # Preview blocks

  def initialize(label, aside: nil, recommended: false, description: nil, **options)
  def render(view, state)
end
```

Renders as a clickable card with:
- Radio indicator (unfilled circle / filled circle)
- Label header with optional "Recommended" badge
- Preview content area (children: mermaid, code_block, image_block, etc.)
- Aside text below preview
- Notes textarea

Selection state stored in `state[:deck_selections]` hash: `{ slide_id => option_label }`.

ARIA: `role="radio"`, `aria-checked`, parent grid has `role="radiogroup"`.

### 4.4 DeckSummary

```ruby
class Components::Deck::DeckSummary < Components::Base
  def initialize(**options)
  def render(view, state)
    # Reads state[:deck_selections] to build summary cards
    # Shows: slide title, selected option label, preview thumbnail, aside, notes
    # Submit button gated on complete selections
    # Final notes textarea
  end
end
```

Auto-generated. No DSL call needed -- appended automatically by `design_deck`.

### 4.5 GenerateMoreControls

```ruby
# Rendered within each slide's footer area
class Components::Deck::GenerateMoreControls < Components::Base
  attr_reader :max_count

  def initialize(max_count: 3, **options)
  def render(view, state)
end
```

Renders: prompt text input, count dropdown (1-3), "Generate" button, "Regenerate all" button. Uses Alpine.js for loading states.

### 4.6 Remaining Deck Components

```ruby
# All in Components::Deck namespace

class SkeletonPlaceholder < Components::Base
  def initialize(count: 1, **options)
  # Shimmer animation: linear-gradient background-position 1.5s infinite
end

class ModelSelector < Components::Base
  def initialize(models: [], default_model: nil, **options)
  # Provider filter pills, model list, thinking level pills
end

class ConfirmationBar < Components::Base
  def initialize(message:, confirm_label: "Cancel", cancel_label: "Keep Going",
                 auto_hide: 5, **options)
  # Fixed top bar, slide-down, auto-hide timer
end

class CloseOverlay < Components::Base
  def initialize(status:, message:, **options)
  # Full-screen blur backdrop, color-coded, auto-close tab
end

class LayoutToggle < Components::Base
  def initialize(**options)
  # Footer buttons: 1 / 2 / 3 / 4 columns
end
```

---

## 5. Visual Explainer Architecture

The visual explainer is simpler than the deck architecturally. It is a **page generator** -- the agent writes a Ruby script that uses shared components, and either:
1. Serves it live via StreamWeaver (for interactive viewing), or
2. Exports it as self-contained HTML (for sharing/archiving)

There is no special orchestrator class like `DesignDeck`. The agent simply composes components in an `app` block.

### 5.1 VeCard

```ruby
# DSL usage
ve_card depth: :hero, accent: :a do
  header2 "Executive Summary"
  text "The changes introduce..."
end

ve_card depth: :recessed, label: "RISK" do
  text "Cognitive complexity exceeds threshold"
end

# Class
class Components::VeCard < Components::Base
  attr_reader :depth, :accent, :label
  attr_accessor :children

  def initialize(depth: :default, accent: nil, label: nil, **options)
  def render(view, state)
end
```

Depth tiers map to CSS classes:
- `:hero` -- `sw-card--hero` (accent-tinted bg, elevated shadow)
- `:elevated` -- `sw-card--elevated` (subtle shadow)
- `:default` -- `sw-card--default` (flat, border)
- `:recessed` -- `sw-card--recessed` (inset shadow)
- `:glass` -- `sw-card--glass` (transparent, backdrop blur)

**Design Decision:** `VeCard` is a separate class from `Card`, not a variant. The existing `Card` has header/body/footer sub-components with specific rendering. `VeCard` is a simpler depth-styled container. Attempting to merge them creates complexity with minimal benefit.

### 5.2 KpiDashboard

```ruby
# DSL usage
kpi_dashboard metrics: [
  { value: "3,500", label: "Requests/sec", color: :blue, trend: :up },
  { value: "12ms", label: "P99 Latency", color: :green },
  { value: "99.97%", label: "Uptime", color: :green, trend: :flat }
]

# Class
class Components::KpiDashboard < Components::Base
  attr_reader :metrics

  def initialize(metrics:, **options)
  def render(view, state)
  # Renders auto-fit grid of KPI cards
  # Each card: large value, label, optional trend arrow, fadeScale entry animation
end
```

### 5.3 DataTable

```ruby
# DSL usage
data_table headers: ["File", "Lines", "Status"],
           rows: [
             ["app.rb", "42", { status: :match, label: "Match" }],
             ["config.rb", "18", { status: :gap, label: "Missing" }]
           ],
           sticky_header: true

# Class -- enhances existing Components::Table
class Components::DataTable < Components::Base
  attr_reader :headers, :rows, :sticky_header, :alternating, :hover, :scrollable

  def initialize(headers:, rows:, sticky_header: true, alternating: true,
                 hover: true, scrollable: true, **options)
  def render(view, state)
end
```

**Design Decision:** New class rather than modifying existing `Table`. The existing `Table` accepts data in multiple formats (positional, headers+rows, file, path) with block support. `DataTable` has a focused API for the visual explainer's specific needs (status badges, sticky headers, scroll container). They can share CSS but the classes serve different use cases.

### 5.4 SidebarToc

```ruby
# DSL usage
sidebar_toc sections: [
  { id: "summary", label: "Executive Summary" },
  { id: "architecture", label: "Architecture" },
  { id: "risks", label: "Risks" }
]

# Class
class Components::SidebarToc < Components::Base
  attr_reader :sections

  def initialize(sections:, **options)
  def render(view, state)
  # Desktop: sticky 170px sidebar, IntersectionObserver scroll spy
  # Mobile (<1000px): horizontal scrollable sticky bar
end
```

### 5.5 Other Explainer Components

```ruby
# Comparison panels
comparison before_label: "Current", after_label: "Proposed" do
  before { mermaid "graph TD\n  A-->B" }
  after { mermaid "graph TD\n  A-->B\n  B-->C" }
end

class Components::Comparison < Components::Base
  attr_accessor :before_content, :after_content, :before_label, :after_label
  def initialize(before_label: "Before", after_label: "After", **options)
  def render(view, state)
end

# Pipeline
pipeline steps: [
  { label: "Parse", description: "Read input", status: :complete },
  { label: "Transform", description: "Apply rules", status: :active },
  { label: "Emit", description: "Write output", status: :pending }
]

class Components::Pipeline < Components::Base
  attr_reader :steps
  def initialize(steps:, **options)
  def render(view, state)
  # Horizontal flow with arrow connectors, responsive vertical fallback
end

# Chart (Chart.js)
chart type: :bar, data: { labels: [...], datasets: [...] }, height: 300

class Components::Chart < Components::Base
  attr_reader :type, :data, :chart_options, :height
  def initialize(type:, data:, options: {}, height: 300, **extra)
  def render(view, state)
  def cdn_assets  # => [:chartjs]
end

# Callout
callout variant: :warning, title: "Breaking Change" do
  text "This removes the deprecated API endpoint."
end

class Components::Callout < Components::Base
  attr_reader :variant, :title
  attr_accessor :children
  def initialize(variant: :info, title: nil, **options)
  def render(view, state)
  # Colored left border: info=blue, warning=amber, success=green, tip=purple
end

# Prose
prose width: :narrow, dropcap: true do
  md "Long-form content with **markdown** support..."
end

class Components::Prose < Components::Base
  attr_reader :width, :dropcap
  attr_accessor :children
  def initialize(width: :default, dropcap: false, **options)
  def render(view, state)
end

# Pullquote
pullquote "Design is not just what it looks like. Design is how it works.",
          attribution: "Steve Jobs"

class Components::Pullquote < Components::Base
  attr_reader :text, :attribution, :centered
  def initialize(text, attribution: nil, centered: false, **options)
  def render(view, state)
end

# Hero Section
hero_section variant: :centered do
  header1 "Diff Review: feature/auth"
  text "main...feature/auth -- 14 files changed"
end

class Components::HeroSection < Components::Base
  attr_reader :variant
  attr_accessor :children
  def initialize(variant: :centered, **options)
  def render(view, state)
end

# Directory Tree
dir_tree <<~TREE
  src/
    app.rb          [modified]
    config.rb       [new]
    routes/
      api.rb        [modified]
TREE

class Components::DirTree < Components::Base
  attr_reader :tree
  def initialize(tree, **options)
  def render(view, state)
  # Monospace, color-coded: green=new, amber=modified, red=deleted
end

# Legend
legend items: [
  { color: "#22c55e", label: "New" },
  { color: "#eab308", label: "Modified" },
  { color: "#ef4444", label: "Deleted" }
]

class Components::Legend < Components::Base
  attr_reader :items
  def initialize(items:, **options)
  def render(view, state)
end

# Flow Arrow
flow_arrow label: "transforms into"

class Components::FlowArrow < Components::Base
  attr_reader :label
  def initialize(label: nil, **options)
  def render(view, state)
end
```

### 5.6 Theme Presets

```ruby
# DSL usage (at app level)
app "Diff Review", theme: :dark do
  theme_preset :editorial  # Sets fonts, colors, surface styles
  # ... page content
end

# Infrastructure
module StreamWeaver::Theme::Presets
  PRESETS = {
    editorial: {
      fonts: { display: "Instrument Serif", body: "Source Sans 3", mono: "JetBrains Mono" },
      palette: { accent: "#c2825a", accent_dim: "rgba(194,130,90,0.15)",
                 surface: "#1a1917", text: "#e8e4dc" }
    },
    technical: {
      fonts: { display: "DM Sans", body: "DM Sans", mono: "Fira Code" },
      palette: { accent: "#14b8a6", accent_dim: "rgba(20,184,166,0.15)",
                 surface: "#0f172a", text: "#e2e8f0" }
    },
    warm: { ... },
    minimal: { ... },
    terminal: { ... },
    # Slide-specific:
    midnight_editorial: { ... },
    warm_signal: { ... },
    terminal_mono: { ... },
    swiss_clean: { ... }
  }.freeze

  def self.apply(name, app)
    preset = PRESETS.fetch(name)
    # Registers Google Fonts CDN links
    # Sets CSS custom properties via theme_overrides
  end
end
```

---

## 6. Agent Communication Protocol

### 6.1 Primary Protocol: Agent Writes a Ruby Script

The agent generates a Ruby file, runs it, and StreamWeaver serves the result.

```
Agent                    StreamWeaver                Browser
  |                          |                          |
  |-- writes deck.rb ------->|                          |
  |-- runs: ruby deck.rb --->|                          |
  |                          |-- starts Puma server ---->|
  |                          |-- opens browser --------->|
  |                          |                          |-- user views deck
  |                          |                          |
  |                          |<-- SSE /stream -----------|
  |                          |                          |
  |                          |<-- POST /action/submit ---|  (user submits)
  |                          |-- result -> stdout ------>|
  |<-- reads stdout ---------|                          |
```

For **design deck** (bidirectional): use `run_once!` which blocks until the user submits, then returns the result as JSON to stdout.

For **visual explainer** (unidirectional): use `run!` for live serving, or `HtmlExporter.export` for static file output.

### 6.2 Agent Receives Deck Results

The deck uses StreamWeaver's existing `run_once!` pattern:

```ruby
# Agent generates and runs this:
result = app("Architecture Direction") {
  design_deck "Architecture Direction" do
    slide "arch", "System Architecture" do
      option "Monolith" do ... end
      option "Microservices" do ... end
    end
  end
}.run_once!(auto_close_window: true)

# result => { deck_selections: { "arch" => "Microservices" }, deck_notes: { ... } }
```

The `run_once!` method already exists and handles:
- Starting the server
- Opening the browser
- Blocking until form submission
- Returning state as JSON
- Shutting down

The deck's "Submit" button on the summary slide sets `state[:_result]`, which triggers `run_once!` to unblock and return.

### 6.3 Agent Pushes Generate-More Options (Push-to-State)

The agent pushes new options into server-side state via `POST /deck/add_option`. StreamWeaver's reactive re-render handles display -- no direct DOM manipulation via SSE.

```ruby
# Agent script (simplified):
app_instance = app("My Deck") {
  design_deck "My Deck" do
    slide "arch", "Architecture" do
      option "Monolith" do ... end
    end
  end
}

# The agent polls for generate requests, then pushes options to state:
# 1. User clicks "Generate" -> browser POSTs to /deck/generate
# 2. Server queues the request, updates state to :generating (re-render shows skeletons)
# 3. Agent polls GET /deck/pending, receives the request
# 4. Agent generates new options with LLM
# 5. Agent pushes each option to state via POST /deck/add_option
# 6. Server updates state hash, triggers SSE re-render notification
# 7. Browser re-renders -- new option appears, skeleton count decreases,
#    summary slide automatically reflects the new option

# See Section 7 for the full state machine and endpoint details.
```

### 6.4 Visual Explainer Output

For the explainer, the agent either:

**Option A: Live server** (interactive viewing with scroll spy, theme toggle):
```ruby
app "Diff Review: feature/auth", theme: :dark do
  theme_preset :editorial
  sidebar_toc sections: [...]
  hero_section { header1 "Diff Review" }
  ve_card(depth: :hero) { ... }
  # ...
end
# App.run! starts server and opens browser
```

**Option B: Static HTML export** (for sharing, archiving):
```ruby
my_app = app "Diff Review: feature/auth", theme: :dark do
  # ... same DSL
end
StreamWeaver::Export::HtmlExporter.export(my_app, path: "~/.agent/diagrams/review.html")
system("open", "~/.agent/diagrams/review.html")
```

### 6.5 Agent Integration (No Skill Classes in Gem)

**The DSL IS the API.** Skill entry point classes (`DesignDeckSkill`, `VisualExplainerSkill`) are intentionally excluded from the gem. The agent communicates with StreamWeaver by writing Ruby DSL scripts directly -- no wrapper classes needed.

Agent glue code (slash commands like `/design-deck`, `/diff-review`, etc.) lives outside the gem as **Claude Code custom commands** in the project's `.claude/commands/` directory. These commands handle data gathering (git diffs, file reading, codebase analysis) and then emit DSL scripts that StreamWeaver renders.

This separation keeps the gem focused on rendering and keeps agent-specific orchestration where it belongs -- in the agent's command layer. See Q9 in Section 12 for the rationale.

---

## 7. The Generate-More Loop (Push-to-State Architecture)

This is the most architecturally complex feature. The key architectural decision is **push-to-state, not push-to-DOM**: the agent pushes new options into server-side state, and StreamWeaver's reactive re-render handles display. This eliminates the "phantom option" race condition (user on Slide B when options arrive for Slide A), keeps the summary slide in sync automatically, and aligns with StreamWeaver's existing reactive model.

### 7.1 State Machine

```
                            IDLE
                              |
                    [user clicks Generate]
                              |
                              v
                        GENERATING
                       /          \
          [agent pushes       [timeout 30s]
           option to state]        |
                  |                v
                  v            TIMED_OUT
           state updated           |
           re-render fires    [show toast]
                  |                |
          [all received]           v
                  |              IDLE
                  v
                IDLE
```

The critical difference from push-to-DOM: options are added to the state hash, which triggers a reactive re-render of the current view. The browser never receives raw HTML snippets via SSE -- it receives state-change notifications that cause the existing component tree to re-render.

### 7.2 State Storage

```ruby
# In app state hash:
state[:deck_generate] = {
  status: :idle,          # :idle | :generating | :timed_out
  slide_id: nil,          # Which slide is generating
  requested_count: 0,     # How many options requested
  received_count: 0,      # How many received so far
  prompt: nil,            # User's custom prompt
  started_at: nil         # For timeout tracking
}

# Generated options live in the slide's options array (NOT a separate SSE target):
state[:deck_slides]["arch"][:options] << {
  label: "Event-Driven",
  aside: "Decoupled via message bus",
  children: [{ type: :mermaid, code: "graph LR\n  Events-->Handler", compact: true }],
  generated: true  # Flag to distinguish from original options
}
# Adding to state triggers re-render -- DeckSlide component picks up new options
# automatically, and DeckSummary reflects them because it reads the same state.
```

### 7.3 Data Flow (Push-to-State)

```
Browser                     Server (Puma)              Agent Script
   |                            |                          |
   |--[click Generate]--------->|                          |
   |  POST /deck/generate       |                          |
   |  {slide_id, count, prompt} |                          |
   |                            |--[queue request]-------->|
   |                            |                          |
   |<-[update generate status]--|                          |
   |  state[:deck_generate]     |                          |
   |  status: :generating       |                          |
   |  (re-render shows          |                          |
   |   skeleton placeholders)   |                          |
   |                            |                          |
   |                            |<---[poll for requests]---|
   |                            |    GET /deck/pending     |
   |                            |                          |
   |                            |                     [agent generates
   |                            |                      option with LLM]
   |                            |                          |
   |                            |<--[push option to state]-|
   |                            |   POST /deck/add_option  |
   |                            |   {slide_id, option_data}|
   |                            |                          |
   |<-[SSE: state changed]-----|                          |
   |  re-render picks up new    |                          |
   |  option from state hash    |                          |
   |  skeleton count decreases  |                          |
   |  summary slide updates     |                          |
   |                            |                          |
   |  [repeat for each option]  |                          |
```

### 7.4 Server-Side Endpoints (New Routes)

```ruby
# In the SinatraApp (or as a Sinatra extension):

# User requests more options
post '/deck/generate' do
  slide_id = params[:slide_id]
  count = params[:count].to_i
  prompt = params[:prompt]
  session_id = session[:session_id]

  # Update generate status in state (triggers re-render with skeletons)
  state = session[:streamlit_state] ||= {}
  state[:deck_generate] = {
    status: :generating,
    slide_id: slide_id,
    requested_count: count,
    received_count: 0,
    prompt: prompt,
    started_at: Time.now.to_i
  }
  session[:streamlit_state] = state

  # Store in session-scoped thread-safe queue for agent polling.
  # Queue entries include session_id so stale requests from killed
  # agent processes don't persist across sessions.
  settings.generate_requests << {
    session_id: session_id,
    slide_id: slide_id,
    count: count,
    prompt: prompt,
    timestamp: Time.now
  }

  status 202
  { status: "generating", skeletons: count }.to_json
end

# Agent polls for pending generate requests
get '/deck/pending' do
  content_type :json
  session_id = params[:session_id]
  requests = settings.generate_requests
  # Only return requests matching this session; discard stale ones
  pending = requests.select { |r| r[:session_id] == session_id }
  requests.reject! { |r| r[:session_id] == session_id }
  { requests: pending }.to_json
end

# Agent pushes a generated option into state
post '/deck/add_option' do
  slide_id = params[:slide_id]
  option_data = JSON.parse(request.body.read, symbolize_names: true)

  state = session[:streamlit_state] ||= {}
  state[:deck_slides] ||= {}
  state[:deck_slides][slide_id] ||= { options: [] }
  state[:deck_slides][slide_id][:options] << option_data.merge(generated: true)

  # Update received count; reset status if all received
  gen = state[:deck_generate]
  if gen && gen[:slide_id] == slide_id
    gen[:received_count] += 1
    gen[:status] = :idle if gen[:received_count] >= gen[:requested_count]
  end

  session[:streamlit_state] = state

  # Trigger SSE re-render notification to connected browsers
  settings.streamer&.notify_state_change

  status 200
  { received: gen&.dig(:received_count) }.to_json
end
```

**Session-scoped queue cleanup:** When a session expires or a heartbeat timeout fires (see 7.7), all queue entries with that `session_id` are purged. This prevents stale requests from killed agent processes from accumulating.

### 7.5 Agent-Side Polling

```ruby
# The agent's deck script includes a generate-more handler:
Thread.new do
  loop do
    response = Net::HTTP.get(URI("#{url}/deck/pending?session_id=#{session_id}"))
    requests = JSON.parse(response)["requests"]

    requests.each do |req|
      # Agent calls LLM to generate options
      new_options = generate_options(req["slide_id"], req["count"], req["prompt"])

      # Push each option to server-side state (NOT directly to DOM)
      new_options.each do |opt|
        uri = URI("#{url}/deck/add_option")
        Net::HTTP.post(uri, {
          slide_id: req["slide_id"],
          label: opt[:label],
          aside: opt[:aside],
          children: opt[:children]  # Serialized component descriptions
        }.to_json, "Content-Type" => "application/json")
      end
    end

    sleep 1
  end
end
```

### 7.6 Timeout Handling

Client-side: the generating state drives skeleton display. If `state[:deck_generate][:status]` remains `:generating` for 30 seconds (checked via the `started_at` timestamp), the client triggers a state update to `:timed_out`, shows a toast, and restores the Generate button. Server-side: the `started_at` timestamp enables the agent to also detect stale requests and skip them.

### 7.7 Cancellation and Heartbeat

**Tab-close / beforeunload:** The browser sends a `beforeunload` beacon to `POST /deck/disconnect`. However, `beforeunload` is unreliable. The primary mechanism is a heartbeat.

**Heartbeat mechanism:** The browser pings `POST /heartbeat` every 5 seconds. If the server detects no heartbeat for 10 seconds (2x interval), it assumes the browser disconnected and:
1. Sets `state[:deck_generate][:status] = :idle`
2. Purges pending generate requests for that session from the queue
3. Marks the session as stale for cleanup

**Timeout:** `run_once!` accepts an optional `timeout:` parameter (default: `nil` = no timeout). When set, the server will auto-return a timeout result after the specified duration:

```ruby
result = app("My Deck") { ... }.run_once!(timeout: 300)  # 5 minute timeout
# result => { _timeout: true } if timed out
```

**Agent process crash:** If the agent process dies, it stops polling `/deck/pending`. The heartbeat mechanism on the browser side continues. Pending generate requests accumulate but are cleaned up when the session expires or when a new agent connects with a fresh session.

---

## 7A. State Ownership Table

This table documents what state lives where and how it stays in sync across client and server.

| State | Location | Sync Mechanism |
|-------|----------|----------------|
| Deck selections | Server (file-backed) | POST on select |
| Deck notes | Server (file-backed) | POST on blur/change |
| Current slide index | Client (Alpine.js) | URL hash + x-data |
| Generate status | Server state hash | SSE push on change |
| Theme preference | Client (localStorage) | Read on load |
| Keyboard shortcuts | Client (JS) | Static registration |

**File-backed state:** Deck selections and notes use file-backed server state (option B from Q1). Codex's argument about cookie overflow with user-generated notes was decisive -- a single long note can exceed the 4KB cookie limit. The session cookie stores a session ID; the full state is persisted to a JSON file in the session directory.

---

## 8. Data Flow Diagrams

### 8.1 Design Deck: Agent Creates Deck, User Selects, Agent Gets Results

```
Agent                     StreamWeaver              Browser              User
  |                           |                        |                   |
  |  write deck.rb            |                        |                   |
  |  ruby deck.rb             |                        |                   |
  |  (blocks on run_once!)    |                        |                   |
  |                           |  Puma starts           |                   |
  |                           |  open browser -------->|                   |
  |                           |                        | render slide 1    |
  |                           |                        |<---- views -------|
  |                           |                        |                   |
  |                           |                        |---- click opt --->|
  |                           |<-- Alpine x-model -----|  (client-side)    |
  |                           |                        |                   |
  |                           |                        |---- Next -------->|
  |                           |                        | render slide 2    |
  |                           |                        |                   |
  |                           |                        |---- submit ------>|
  |                           |<-- POST /action/submit |                   |
  |                           |                        |                   |
  |                           | state[:_result] set    |                   |
  |  run_once! unblocks       |                        |                   |
  |<-- JSON result -----------|                        |                   |
  |                           |  server shuts down     |                   |
  |                           |                        | window closes     |
  |  reads selections         |                        |                   |
```

### 8.2 Generate-More: User Requests, Agent Generates, State Updates (Push-to-State)

```
User          Browser              Server               Agent
  |               |                    |                    |
  | click Gen     |                    |                    |
  |-------------->| POST /deck/gen     |                    |
  |               |  {slide, count}    |                    |
  |               |------------------->|                    |
  |               |                    | queue request      |
  |               |<-- state change ---|                    |
  | sees shimmer  | re-render shows    |                    |
  |               | skeleton cards     |                    |
  |               |                    |<-- GET /pending ---|  (poll)
  |               |                    |--- {requests} ---->|
  |               |                    |                    |
  |               |                    |              [LLM generates]
  |               |                    |                    |
  |               |                    |<- POST /add_opt ---|
  |               |                    |   {slide, option}  |
  |               |                    | update state hash  |
  |               |<-- SSE: re-render -|                    |
  | sees option   | state has new opt  |                    |
  |               | component re-renders                    |
  |               | summary also updates                    |
```

### 8.3 Visual Explainer: Agent Generates Page, User Views

```
Agent                     StreamWeaver              Browser
  |                           |                        |
  | write page.rb             |                        |
  | ruby page.rb              |                        |
  |                           | Puma starts            |
  |                           | open browser --------->|
  |                           |                        | render full page
  |                           |                        | scroll spy active
  |                           |                        | theme toggle works
  |                           |                        |
  | (agent done, server       |                        |
  |  keeps running for user)  |                        |

  --- OR (static export) ---

  | write page.rb             |                        |
  | ruby page.rb              |                        |
  |                           | HtmlExporter.export    |
  |                           | writes review.html     |
  | open review.html -------->|                        |
  |                           |                        | render from file
```

---

## 9. CSS/JS Asset Strategy

### 9.1 External Libraries (CDN)

| Library | CDN URL | Used By |
|---------|---------|---------|
| Mermaid.js 11 | `cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs` | Mermaid |
| Mermaid ELK | `cdn.jsdelivr.net/npm/@mermaid-js/layout-elk/dist/mermaid-layout-elk.esm.min.mjs` | Mermaid (ELK layout) |
| Prism.js | `cdn.jsdelivr.net/npm/prismjs@1/prism.min.js` + autoloader | CodeBlock |
| Chart.js 4 | `cdn.jsdelivr.net/npm/chart.js@4` | Chart |
| Google Fonts | `fonts.googleapis.com` | Theme presets |

**Decision: CDN, not vendored.** Rationale:
1. StreamWeaver is a local dev tool, not a production web app -- CDN latency is acceptable
2. Self-contained HTML export preserves CDN links (they work offline if cached)
3. Vendoring would bloat the gem significantly
4. The existing AlpineJS + HTMX are already loaded from CDN

### 9.2 Custom JS Assets

StreamWeaver needs to serve custom JS files for:
- **Mermaid zoom engine** (~200 lines) -- zoom, pan, expand controls
- **Keyboard shortcuts** -- centralized registration with context awareness
- **Slide navigation** -- swap mode + scroll-snap mode logic
- **Deck selection** -- radio behavior, number key selection
- **Generate-more client** -- SSE listener, skeleton replacement

These are served from `lib/stream_weaver/assets/js/` via a new Sinatra route:

```ruby
get '/assets/js/:filename' do
  file = File.join(ASSETS_DIR, "js", params[:filename])
  halt 404 unless File.exist?(file)
  content_type 'application/javascript'
  File.read(file)
end
```

### 9.3 CSS Strategy

**Naming Convention:** All visual skills CSS classes MUST use the `sw-` prefix to prevent conflicts with user styles. Examples: `sw-mermaid-wrap`, `sw-code-block`, `sw-deck-option`, `sw-card--hero`. BEM-style modifiers use double-dash: `sw-component--variant`. This is already visible in the component examples throughout this document (e.g., `sw-mermaid--compact`, `sw-mermaid--zoom`, `sw-code-block`, `sw-card--elevated`).

StreamWeaver already has a CSS module (`StreamWeaver::CSS`) that generates the full stylesheet. New visual skills CSS is added as additional stylesheet sections:

```ruby
module StreamWeaver::CSS
  def self.visual_skills_css
    # Returns CSS for: mermaid containers, code blocks, depth tiers,
    # deck layouts, slide transitions, explainer typography, etc.
  end

  def self.full_stylesheet
    # Existing call -- augmented to include visual_skills_css
  end
end
```

For theme presets, CSS custom properties are injected via `<style>` blocks in the page head:

```css
:root {
  --sw-vs-font-display: 'Instrument Serif', serif;
  --sw-vs-font-body: 'Source Sans 3', sans-serif;
  --sw-vs-font-mono: 'JetBrains Mono', monospace;
  --sw-vs-accent: #c2825a;
  --sw-vs-surface-hero: rgba(194, 130, 90, 0.08);
  /* ... */
}
```

### 9.4 CDN Asset Declaration

Components declare which CDN assets they need via a `cdn_assets` method. The view collects all required assets and deduplicates:

```ruby
class Components::Mermaid < Components::Base
  def cdn_assets
    assets = [:mermaid]
    assets << :mermaid_elk if @layout == :elk
    assets
  end
end

# View (Phlex) collects:
def head_scripts
  required = collect_cdn_assets(@components).uniq
  required.each { |asset| render_cdn_script(asset) }
end
```

---

## 9A. Accessibility

Visual skills components must be usable with assistive technologies and keyboard-only navigation.

### ARIA Attributes

| Context | Attribute | Purpose |
|---------|-----------|---------|
| Generate-more region | `aria-live="polite"` | New options announced to screen readers without interrupting |
| Active slide in nav | `aria-current="step"` | Identifies the current slide in navigation controls |
| During generation | `aria-busy="true"` | Signals that content is loading/updating |
| Option cards grid | `role="radiogroup"` | Groups option cards as a radio selection |
| Individual option card | `role="radio"` + `aria-checked` | Each option is a selectable radio item |

### Focus Management

- **Slide navigation:** Focus is trapped within the active slide. When navigating to the next/previous slide, focus moves to the slide container.
- **Generate-more:** When new options appear (via state re-render), focus remains on the current element. Screen readers announce new options via `aria-live`.
- **Modal overlays** (CloseOverlay, ConfirmationBar): Focus is trapped within the overlay and restored to the triggering element on dismiss.
- **Keyboard navigation:** Covered by the KeyboardShortcuts component (Section 3.4). All interactive elements are reachable via Tab. Number keys for quick-select are a progressive enhancement, not a replacement for Tab+Enter.

---

## 9B. Scalability Limits

Soft limits trigger warnings in development mode. Hard limits are enforced and raise errors.

| Resource | Soft Limit | Hard Limit | Rationale |
|----------|-----------|------------|-----------|
| Slides per deck | 10 | 20 | DOM size degrades rendering performance |
| Options per slide | 6 | 12 | Grid layout breaks down; cognitive overload |
| Mermaid diagrams per page | 10 | 25 | Mermaid.js rendering time grows non-linearly |
| Total file size for HTML export | 2 MB | 10 MB | Browser memory; email attachment limits |
| Concurrent SSE connections | 1 | 1 | Puma single-worker limitation |

**Enforcement:** Soft limits log a warning via `StreamWeaver.logger.warn`. Hard limits raise `StreamWeaver::LimitExceededError` with a descriptive message. The `validate!` method on `DesignDeck` checks slide and option counts. The `HtmlExporter` checks file size. SSE connection count is enforced by the Streamer.

---

## 10. DSL Examples

### 10.1 Design Deck -- Full Example

```ruby
app "UI Component Library", theme: :dark do
  design_deck "Component Library Direction" do
    slide "palette", "Color Palette",
          context: "Choose the color direction for the design system" do
      option "Warm Earth Tones", recommended: true,
             aside: "Terracotta, sage, warm gray.\nCalm and professional." do
        code_block <<~CSS, lang: "css"
          :root {
            --primary: #c2825a;
            --surface: #f5f0eb;
          }
        CSS
      end

      option "Cool Ocean", aside: "Teal, slate, cool gray" do
        code_block <<~CSS, lang: "css"
          :root {
            --primary: #14b8a6;
            --surface: #f0f4f8;
          }
        CSS
      end

      option "Monochrome", aside: "Pure black, white, and grays" do
        code_block <<~CSS, lang: "css"
          :root {
            --primary: #111111;
            --surface: #fafafa;
          }
        CSS
      end
    end

    slide "layout", "Page Layout" do
      option "Sidebar Navigation" do
        mermaid <<~MERMAID, compact: true
          graph LR
            Sidebar-->Content
            Sidebar-->Footer
        MERMAID
      end
      option "Top Navigation" do
        mermaid <<~MERMAID, compact: true
          graph TD
            Navbar-->Content
            Content-->Footer
        MERMAID
      end
    end
  end
end
```

### 10.2 Visual Explainer -- Diff Review Page

```ruby
app "Diff Review: feature/auth", theme: :dark do
  theme_preset :editorial

  sidebar_toc sections: [
    { id: "summary", label: "Executive Summary" },
    { id: "architecture", label: "Module Architecture" },
    { id: "review", label: "Code Review" },
    { id: "risks", label: "Risk Assessment" }
  ]

  hero_section variant: :centered do
    header1 "Diff Review"
    text "main...feature/auth -- 14 files changed, +482 / -91"
    kpi_dashboard metrics: [
      { value: "14", label: "Files Changed" },
      { value: "+482", label: "Lines Added", color: :green },
      { value: "-91", label: "Lines Removed", color: :red }
    ]
  end

  ve_card depth: :hero, id: "summary" do
    header2 "Executive Summary"
    prose do
      md <<~MD
        This PR introduces JWT-based authentication, replacing the
        session-cookie approach. The **primary motivation** is enabling
        stateless horizontal scaling of the API tier.
      MD
    end
  end

  ve_card id: "architecture" do
    header2 "Module Architecture"
    mermaid <<~MERMAID, zoom: true
      graph TD
        AuthMiddleware-->JWTService
        JWTService-->TokenStore
        AuthMiddleware-->SessionFallback
    MERMAID
    legend items: [
      { color: "#22c55e", label: "New modules" },
      { color: "#eab308", label: "Modified" }
    ]
  end

  ve_card id: "review" do
    header2 "Code Review"

    callout variant: :success, title: "Good" do
      text "Clean separation of JWT logic into dedicated service class."
    end

    callout variant: :error, title: "Needs Fix" do
      text "Token refresh endpoint missing rate limiting."
      code_block <<~RUBY, lang: "ruby", file: "app/controllers/tokens_controller.rb"
        def refresh
          # TODO: add rate limiting
          new_token = JWTService.refresh(current_token)
          render json: { token: new_token }
        end
      RUBY
    end
  end

  ve_card depth: :elevated, id: "risks" do
    header2 "Risk Assessment"
    data_table headers: ["Risk", "Severity", "Mitigation"],
               rows: [
                 ["Token leakage via logs", "High", "Add log filtering"],
                 ["Clock skew on expiry", "Medium", "Use 30s grace period"]
               ]
  end
end
```

### 10.3 Visual Explainer -- Slide Deck

```ruby
app "API Gateway Redesign", theme: :dark do
  theme_preset :midnight_editorial

  slide_container mode: :scroll_snap, nav_dots: true, counter: true do
    slide "title", type: :title do
      header1 "API Gateway Redesign"
      text "Q2 2026 Architecture Proposal"
    end

    slide "problem", type: :split do
      comparison before_label: "Current", after_label: "Proposed" do
        before do
          mermaid "graph TD\n  Client-->Monolith-->DB", compact: true
        end
        after do
          mermaid "graph TD\n  Client-->Gateway-->Auth\n  Gateway-->Orders", compact: true
        end
      end
    end

    slide "metrics", type: :dashboard do
      kpi_dashboard metrics: [
        { value: "3x", label: "Throughput Increase" },
        { value: "50%", label: "Latency Reduction" },
        { value: "99.99%", label: "Target Uptime" }
      ]
    end

    slide "timeline", type: :content do
      header2 "Implementation Timeline"
      pipeline steps: [
        { label: "Phase 1", description: "Gateway MVP", status: :complete },
        { label: "Phase 2", description: "Auth migration", status: :active },
        { label: "Phase 3", description: "Traffic cutover", status: :pending }
      ]
    end
  end
end
```

---

## 11. Implementation Phases

Aligned with the analysis in `components.md`, ordered by dependency and value.

### Phase 1: Shared Foundation (Highest Value, Unblocks Everything)

| # | Component | Effort | Unblocks |
|---|-----------|--------|----------|
| 1 | `Mermaid` component + zoom JS | Medium | Both projects |
| 2 | `CodeBlock` component + Prism.js | Small | Both projects |
| 3 | Theme enhancements (presets, auto mode, CSS vars) | Medium | Both projects |
| 4 | `KeyboardShortcuts` system | Small | Deck navigation |
| 5 | `HtmlExporter` pipeline | Medium | Explainer output |
| 6 | CDN asset declaration + serving infrastructure | Small | All JS-dependent components |
| 7 | `ImageBlock` component | Small | Deck previews |

### Phase 2: Design Deck Core

| # | Component | Effort | Notes |
|---|-----------|--------|-------|
| 8 | `DesignDeck` + `DeckSlide` + `DeckOption` | Large | The deck shell |
| 9 | `SlideContainer` (:swap mode) | Medium | Slide navigation |
| 10 | `DeckSummary` auto-generated slide | Medium | Reads selection state |
| 11 | Selection state + radio behavior (JS) | Medium | Client-side Alpine.js |
| 12 | Deck-specific keyboard shortcuts | Small | Number keys, Enter, Escape |
| 13 | `ProgressIndicator` | Small | Nav progress bar |

### Phase 3: Generate-More Loop

| # | Component | Effort | Notes |
|---|-----------|--------|-------|
| 14 | `GenerateMoreControls` UI | Small | Button, input, dropdown |
| 15 | `SkeletonPlaceholder` | Small | Shimmer CSS animation |
| 16 | Generate request queue + `/deck/generate` + `/deck/pending` | Medium | Server routes |
| 17 | SSE option push integration | Medium | Feed + Streamer |
| 18 | Timeout handling (client + server) | Small | Toast on timeout |
| 19 | `ConfirmationBar` + `CloseOverlay` | Small | UX polish |

### Phase 4: Visual Explainer Core

| # | Component | Effort | Notes |
|---|-----------|--------|-------|
| 20 | `VeCard` with depth tiers | Small | CSS classes on a div |
| 21 | `DataTable` enhanced table | Medium | Sticky header, badges |
| 22 | `SidebarToc` with scroll spy | Medium | IntersectionObserver JS |
| 23 | `KpiDashboard` | Small | Grid of stat cards |
| 24 | `Callout` | Small | Colored border box |
| 25 | `Comparison` panels | Small | Side-by-side layout |
| 26 | `Pipeline` step flow | Small | CSS flexbox + arrows |
| 27 | `Chart` (Chart.js) | Medium | CDN, dark mode, data binding |

### Phase 5: Polish and Remaining

| # | Component | Effort | Notes |
|---|-----------|--------|-------|
| 28 | `SlideContainer` (:scroll_snap mode) | Medium | Explainer presentations |
| 29 | CSS-only helpers (prose, pullquote, hero_section, dir_tree, legend, flow_arrow, layout_toggle) | Small each | Thin DSL methods + CSS |
| 30 | `ModelSelector` | Medium | Model picker UI |
| 31 | Save/Load snapshot system | Medium | File I/O, localStorage |
| 32 | Animation choreography | Medium | Staggered reveals, CSS counters |
| 33 | Theme preset library (all presets) | Medium | Fonts, colors, curated combos |

---

## 12. Open Questions / Design Decisions Needed

### Q1: Deck State -- Server Session vs. Client-Side? **[RESOLVED: Option B]**

The existing StreamWeaver uses server-side session (cookies) for state. The design deck has a lot of state (selections, notes, dirty tracking). Cookie size limit is ~4KB.

**Options:**
- **A) Server-side session** -- fits existing pattern, but may hit cookie size limits with many slides/notes
- **B) Server-side with file-backed overflow** -- session stores an ID, full state in a file
- **C) Client-side localStorage** -- the original pi-design-deck approach, but breaks the StreamWeaver pattern

**Decision: Option B (file-backed state).** Codex's argument about cookie overflow with user-generated notes was decisive -- a single detailed note on one slide can exceed the 4KB cookie limit. The session cookie stores only a session ID; full deck state (selections, notes, generate status) is persisted to a JSON file in a session-scoped directory. See Section 7A (State Ownership Table) for the complete state location map.

### Q2: AlpineJS Adapter Extension vs. New Adapter Methods?

New components need rendering. Two approaches:
- **A) Add `render_mermaid`, `render_code_block`, etc. to `Adapter::Base` and `Adapter::AlpineJS`** -- follows existing pattern exactly
- **B) Components render themselves via Phlex, only delegate to adapter for interactive bits** -- less adapter bloat, but breaks the adapter abstraction

**Recommendation:** (A) for interactive components (those with Alpine.js state), (B) for pure display components (Mermaid, CodeBlock, VeCard just render HTML). This is already the implicit pattern: `Text`, `Header`, `Badge` all render in their own `render(view, state)` without adapter delegation. Only form controls delegate to the adapter.

### Q3: Generate-More -- Polling vs. Callback?

How does the agent learn that the user clicked "Generate"?

**Options:**
- **A) Agent polls `/deck/pending`** -- simple, works with any agent, but adds latency
- **B) Agent provides a callback URL/block** -- lower latency, but requires the agent script to run a mini HTTP server or use a callback mechanism
- **C) Agent monitors stdout** -- server prints generate requests to stdout, agent reads them

**Recommendation:** (A) polling. Simplicity wins. The agent script already runs in a loop (for `run_once!` it polls `result_container`). Adding a poll for generate requests is trivial. Latency of 1-2 seconds (poll interval) is acceptable for a "generate with LLM" operation that itself takes 5-15 seconds.

### Q4: Should the Deck Be an App Subclass?

**Options:**
- **A) DSL methods on App** (recommended above) -- `design_deck` is like `tabs` or `modal`
- **B) `DesignDeckApp < App`** -- a specialized subclass with deck-specific routes

**Recommendation:** (A). The deck needs a few custom routes (`/deck/generate`, `/deck/pending`), but these can be added to the SinatraApp conditionally (only when the app contains a DesignDeck component). Making it a subclass creates a parallel hierarchy that complicates the codebase.

### Q5: Shared Components in DisplayDSL vs. App Only?

Should `mermaid`, `code_block`, `chart` etc. be available in `DisplayDSL` (and thus in `FeedBuilder` for push updates) or only in `App`?

**Recommendation:** `DisplayDSL` for all display-only components. This means a `Feed` can push a mermaid diagram or code block into a running app, which is powerful for the generate-more loop. Only deck-specific interactive components (`design_deck`, `option`, etc.) belong on `App` alone.

### Q6: How to Handle Mermaid Re-rendering on SSE Push?

When a new option with a Mermaid diagram is pushed via SSE, the `<pre class="mermaid">` element needs to be processed by Mermaid.js. But Mermaid has already initialized.

**Options:**
- **A) Call `mermaid.run()` after each SSE DOM update** -- re-processes all unrendered diagrams
- **B) Use MutationObserver** to auto-detect new mermaid elements
- **C) Include a `<script>` tag in the pushed HTML that triggers rendering

**Recommendation:** (A). The SSE client-side handler already knows when it receives updates. Adding `mermaid.run({ nodes: [newElement] })` after DOM insertion is straightforward.

### Q7: Anti-Slop Enforcement -- Build-Time or Runtime?

The visual explainer spec forbids certain colors, fonts, and patterns. Should this be enforced?

**Options:**
- **A) Documentation only** -- trust the agent to follow the rules
- **B) Build-time validation** -- theme presets reject forbidden values
- **C) Runtime CSS override** -- a stylesheet that `!important`-overrides forbidden patterns

**Recommendation:** (A) for now. The anti-slop rules are guidance for the agent's prompt, not application logic. Theme presets inherently avoid slop by providing curated alternatives. If slop becomes a problem in practice, add (B) as a development-mode warning.

### Q8: Comparison Component -- Block Syntax

The `comparison` component needs two child regions. How to express this in the DSL?

**Options:**
- **A) Named blocks:**
  ```ruby
  comparison do
    before { mermaid "..." }
    after { mermaid "..." }
  end
  ```
- **B) Positional blocks:**
  ```ruby
  comparison do
    panel "Before" do mermaid "..." end
    panel "After" do mermaid "..." end
  end
  ```
- **C) Hash of content:**
  ```ruby
  comparison before: mermaid_html("..."), after: mermaid_html("...")
  ```

**Recommendation:** (A). Named blocks (`before`/`after`) are the most readable and follow the pattern of `trigger`/`menu` in the existing `dropdown` component.

### Q9: Explainer Slash Commands -- Where Do They Live? **[RESOLVED: Option C]**

The visual explainer has 8 slash commands that each gather different data before generating a page. These are agent-side behaviors, not StreamWeaver server logic.

**Options:**
- **A) Skills in StreamWeaver gem** -- `StreamWeaver::Skills::DiffReview`, etc.
- **B) Separate gem/tool** -- skills live outside StreamWeaver, call it as a library
- **C) Claude Code custom commands** -- the `/commands` directory, written in shell/Ruby

**Decision: Option C (Claude Code custom commands).** The DSL IS the API -- no skill wrapper classes in the gem. Agent glue code (slash commands) lives in `.claude/commands/` as shell/Ruby scripts. The data gathering (git diffs, file reading, codebase analysis) is agent-side work that doesn't belong in a rendering library. See Section 6.5 for details.
