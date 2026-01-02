# StreamWeaver Charts Design

**Date**: 2026-01-02
**Status**: Approved
**Context**: Spin-off from cultiv-os/cultiv-ai daily-brief timing instrumentation work

## Overview

Add chart visualization components to StreamWeaver, following Streamlit's data-first philosophy while maintaining StreamWeaver's minimal-dependency ethos.

### Goals

1. Composable chart primitives (not a pre-built dashboard)
2. External data pattern (charts read files, don't bloat session)
3. Chart.js via CDN, lazy-loaded only when charts are used
4. Path toward Streamlit-like API as Ruby DataFrame ecosystem matures

## Components

| Component | Purpose | Primary Use |
|-----------|---------|-------------|
| `bar_chart` | Horizontal/vertical bars | Phase breakdown, comparisons |
| `line_chart` | Trend lines | Time series, progress |
| `stacked_bar_chart` | Segmented bars | Distribution across runs |
| `sparkline` | Minimal line (no axes) | Compact trends |
| `hbar_chart` | Horizontal bar shorthand | Quick horizontal bars |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  StreamWeaver App                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │  bar_chart file: "timing.yaml", path: "..."     │   │
│  └─────────────────────────────────────────────────┘   │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Components::BarChart                            │   │
│  │  - Loads data (file or inline)                  │   │
│  │  - Normalizes to labels/values                  │   │
│  └─────────────────────────────────────────────────┘   │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │  AlpineJS Adapter                                │   │
│  │  - Renders <canvas> with Chart.js config        │   │
│  │  - Lazy-loads Chart.js CDN on first chart       │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## API Design

### Data Input Options (Priority Order)

```ruby
# 1. File with dot-path (recommended for external data)
bar_chart file: "~/metrics/timing.yaml", path: "entries.-1.phases"

# 2. File with block transform (complex extraction)
bar_chart file: "timing.yaml" do |data|
  data[:entries].last[:phases]
end

# 3. Inline hash (quick/simple)
bar_chart data: { calendar: 45, news: 120, tasks: 30 }

# 4. Explicit labels/values (full control)
bar_chart labels: %w[Calendar News Tasks],
          values: [45, 120, 30]

# 5. State-bound (when data is already in state)
bar_chart data: :timing_phases  # reads state[:timing_phases]
```

### Common Options (All Chart Types)

```ruby
bar_chart data: timing,
          title: "Phase Breakdown",        # Optional header
          height: "300px",                 # CSS height (default: 250px)
          horizontal: true,                # Bar direction (default: false)
          colors: ["#c45b28", "#4a90d9"],  # Custom palette
          show_legend: false,              # Hide legend (default: auto)
          show_values: true                # Display values on bars
```

### Chart-Specific Options

```ruby
# Line chart
line_chart data: trends,
           fill: true,          # Area fill under line
           smooth: true,        # Curved vs straight lines
           points: false        # Hide data points

# Stacked bar
stacked_bar_chart data: runs,
                  stack: true,      # true (stacked) or false (grouped)
                  normalize: false  # Percentage mode (100% bars)
```

### DSL Methods

```ruby
app "Dashboard" do
  bar_chart data: { a: 1, b: 2 }      # Vertical bars
  hbar_chart data: { a: 1, b: 2 }     # Horizontal bars (shorthand)
  line_chart data: [1, 2, 3, 4]       # Simple array = sequential x
  sparkline data: [1, 2, 3, 4]        # Minimal line (no axes/labels)
  stacked_bar_chart data: complex_data
end
```

## Implementation Details

### Chart.js Integration (Lazy Loading)

```ruby
# In views.rb - only include when charts are present
def chart_js_assets
  return unless @app.has_charts?

  script(src: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js",
         defer: true)
end
```

### Component Class Pattern

```ruby
class BarChart < Base
  attr_reader :labels, :values, :options

  def initialize(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
    @data = data
    @file = file
    @path = path
    @labels = labels
    @values = values
    @transform_block = block
    @options = options
  end

  def resolve_data(state)
    if @file
      raw = load_file(@file)
      raw = @transform_block ? @transform_block.call(raw) : extract_path(raw, @path)
      normalize_hash(raw)
    elsif @data.is_a?(Symbol)
      normalize_hash(state[@data])
    elsif @data.is_a?(Hash)
      normalize_hash(@data)
    else
      { labels: @labels, values: @values }
    end
  end

  def render(view, state)
    view.adapter.render_bar_chart(view, self, state)
  end
end
```

### File Loading & Path Extraction

```ruby
# Supports YAML, JSON, expanding ~
def load_file(path)
  expanded = File.expand_path(path)
  case File.extname(expanded)
  when '.yaml', '.yml' then YAML.safe_load_file(expanded, symbolize_names: true)
  when '.json' then JSON.parse(File.read(expanded), symbolize_keys: true)
  else raise "Unsupported file type: #{path}"
  end
end

# Dot-path extraction: "entries.-1.phases"
def extract_path(data, path)
  return data unless path
  path.split('.').reduce(data) do |obj, key|
    case key
    when /^-?\d+$/ then obj[key.to_i]  # Array index
    else obj[key.to_sym] rescue obj[key]  # Hash key
    end
  end
end
```

## Example: Timing Dashboard

```ruby
# examples/charts/timing_dashboard.rb
require 'stream_weaver'

TIMING_FILE = File.expand_path("~/cultiv-os/metrics/brief-timing.yaml")

app "Daily Brief Timing", layout: :wide do
  header2 "Performance Dashboard"

  # Latest run breakdown
  card do
    header3 "Latest Run"
    hbar_chart file: TIMING_FILE,
               path: "entries.-1.phases",
               title: "Phase Breakdown (seconds)",
               show_values: true,
               colors: ["#c45b28"]
  end

  columns widths: ['50%', '50%'] do
    column do
      card do
        header3 "Total Duration Trend"
        line_chart file: TIMING_FILE do |data|
          data[:entries].last(14).map { |e| e[:wall_clock_seconds] }
        end
      end
    end

    column do
      card do
        header3 "News-Wait Over Time"
        sparkline file: TIMING_FILE do |data|
          data[:entries].last(14).map { |e| e[:phases][:"news-wait"] }
        end
      end
    end
  end

  # Historical comparison
  card do
    header3 "Last 7 Runs by Phase"
    stacked_bar_chart file: TIMING_FILE do |data|
      data[:entries].last(7).map do |entry|
        { label: entry[:date], **entry[:phases] }
      end
    end
  end
end.run!
```

## Implementation Plan

| Phase | What | Why First |
|-------|------|-----------|
| **1** | `BarChart` component + adapter | Most useful, validates pattern |
| **2** | Chart.js CDN lazy-loading in views.rb | Required for any chart |
| **3** | File loading + dot-path extraction | Core data pattern |
| **4** | `LineChart` + `sparkline` | Second most useful |
| **5** | `StackedBarChart` | More complex data shape |
| **6** | Example dashboard | Proves composition works |
| **7** | Tests | Ensure stability |

## Files to Create/Modify

| File | Action |
|------|--------|
| `lib/stream_weaver/components.rb` | Add BarChart, LineChart, StackedBarChart classes |
| `lib/stream_weaver/adapter/alpinejs.rb` | Add render methods for each chart type |
| `lib/stream_weaver/views.rb` | Add conditional Chart.js CDN include |
| `lib/stream_weaver/app.rb` | Add DSL methods |
| `examples/charts/timing_dashboard.rb` | New example |
| `spec/components/charts_spec.rb` | New test file |

## Design Decisions

### Why Chart.js via CDN?
- Zero build step (fits StreamWeaver's philosophy)
- Apps without charts pay no cost
- Well-documented, handles edge cases (scaling, tooltips, animation)

### Why file-based data loading?
- Session storage has limits (~4KB cookies, memory for server-side)
- Timing data already lives in external YAML
- Pattern: session for UI state, external for data

### Why explicit API first?
- Ruby hashes lack Pandas-style metadata
- Can evolve toward Streamlit-like inference later
- Optional DataFrame support (ruby-polars, Rover) when gems present

## Future Considerations

- **DataFrame support**: Detect ruby-polars/Rover, enable richer data inference
- **Auto-refresh**: `refresh: 30` option to re-read files periodically
- **Dashboard creator UI**: Visual tool for composing charts (ultrathink later)
