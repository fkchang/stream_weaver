# Opal CSS/Theme Wiring — Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `streamweaver opal-build` produce fully styled apps — the same StreamWeaver theme system that server-rendered apps enjoy, delivered as a static `dist/sw-theme.css` file with no build tools required.

**Architecture:** The builder writes `dist/sw-theme.css` from Ruby CSS strings already in the gem (`CSS.full_stylesheet` + `Theme.visual_skills_css`). `OpalShell` gains three `<head>` additions in FOUC-safe order: dark mode script first, then Google Fonts CDN links, then `sw-theme.css`. `Adapter::Opal` adds `render_theme_preset` (no-op — preset baked at build time), `render_theme_toggle` (data-attribute button), and `render_theme_switcher` (no-op stub). `OpalBridge` adds a fourth delegated listener for `data-sw-action="toggle-theme"`.

**Tech Stack:** Ruby (build-time CSS extraction from existing gem methods), existing `Theme`, `Theme::Presets`, and `CSS` modules, no new dependencies.

---

## Background

Phase 1 Opal apps render correctly but ship unstyled — the browser sees raw HTML with no stylesheet. The StreamWeaver CSS lives entirely in Ruby as heredoc strings and is normally injected inline by `views.rb` during server-side rendering. For Opal builds, we extract it at build time (MRI) and write it as a separate cacheable file.

### How CSS works today (server-side)

`views.rb` injects into `<head>` at render time:
- `Theme::AutoMode.inline_script` — dark mode JS (runs first to prevent FOUC)
- Google Fonts CDN `<link>` tags (preconnect × 2 + stylesheet)
- A large inline `<style>` block via `CSS.full_stylesheet` (extracted from `views.rb` heredoc)
- `Theme.visual_skills_css` — semantic `--sw-*` CSS custom property tokens
- Per-component `render_theme_preset` calls inject CSS var overrides for the active preset

For Opal, all of this is handled at build time since there is no server render.

### Key gem APIs used

```ruby
# CSS content (returns String)
StreamWeaver::CSS.full_stylesheet          # main SW component CSS
StreamWeaver::Theme.visual_skills_css      # semantic --sw-* token CSS
StreamWeaver::CSS.animation_css            # sw-fade-in, sw-slide-in, table styles

# Theme presets
StreamWeaver::Theme::Presets.get(:editorial)                 # Hash or nil
StreamWeaver::Theme::Presets.available                       # [:editorial, :technical, ...]
StreamWeaver::Theme::Presets.generate_preset_css(:editorial) # CSS string; "" for unknown
StreamWeaver::Theme::Presets.google_fonts_url(preset_hash)   # Google Fonts URL string
# Note: Theme.google_fonts_url(*families_array) also exists but takes string family names,
# not a preset hash. Always use Theme::Presets.google_fonts_url for preset-based URLs.

# Dark mode
StreamWeaver::Theme::AutoMode.inline_script  # JS string; provides swToggleTheme()
```

Note: `CSS.animation_css` and `Theme::Presets.animations_css` (embedded inside `Theme.visual_skills_css`) are distinct animation sets — no duplication from including both.

---

## Design

### 1. OpalBuilder — new `write_theme_css` step

`OpalBuilder#call` gains a new step between `copy_morphdom` and `write_index_html`:

```ruby
def call
  FileUtils.mkdir_p(@output_dir)
  write_app_js
  copy_morphdom
  write_theme_css   # new
  write_index_html
end
```

`write_theme_css` assembles CSS from existing gem methods and writes `dist/sw-theme.css`:

```ruby
def write_theme_css
  css = StreamWeaver::CSS.full_stylesheet
  css += "\n" + StreamWeaver::Theme.visual_skills_css
  css += "\n" + StreamWeaver::CSS.animation_css
  if @theme
    unless StreamWeaver::Theme::Presets.get(@theme.to_sym)
      warn "[OpalBuilder] Unknown theme preset: #{@theme}"
    end
    css += "\n" + StreamWeaver::Theme::Presets.generate_preset_css(@theme.to_sym)
  end
  File.write(output_path("sw-theme.css"), css)
end
```

`generate_preset_css` returns `""` for unknown presets, so the warn + passthrough is safe.

`OpalBuilder.new` and `.build` gain a `theme:` keyword (default `nil`):

```ruby
def self.build(app_file, output_dir: "dist", title: nil, theme: nil)
  new(app_file, output_dir: output_dir, title: title, theme: theme).call
end

def initialize(app_file, output_dir: "dist", title: nil, theme: nil)
  # ... existing setup ...
  @theme = theme
end
```

`google_fonts_url_for_build` is a private method that returns the correct Google Fonts URL:

```ruby
def google_fonts_url_for_build
  if @theme && (preset = StreamWeaver::Theme::Presets.get(@theme.to_sym))
    StreamWeaver::Theme::Presets.google_fonts_url(preset)
  else
    # Default: Source Sans 3 + Crimson Pro (matches server-side CSS.google_fonts_html)
    "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap"
  end
end
```

**`dist/` output after build:**

| File | Contents |
|---|---|
| `app.js` | Compiled Ruby DSL (unchanged) |
| `morphdom.min.js` | DOM patching (unchanged) |
| `sw-theme.css` | Full StreamWeaver CSS + optional preset vars |
| `index.html` | Shell with all `<head>` links wired |

### 2. OpalShell — enriched `<head>`

`OpalShell.render` gains three new optional params:

```ruby
def self.render(
  title: "StreamWeaver App",
  app_js: "app.js",
  morphdom_js: nil,
  theme_css: nil,          # new: local CSS filename or nil
  google_fonts_url: nil,   # new: Google Fonts stylesheet URL or nil
  dark_mode_script: nil    # new: JS string or nil
)
```

The generated `<head>` uses FOUC-safe ordering — dark mode script runs before any CSS is parsed:

```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>#{title}</title>
  <!-- Dark mode script FIRST — prevents flash of wrong theme -->
  <script>#{dark_mode_script}</script>       <!-- only if dark_mode_script present -->
  <!-- Google Fonts — two preconnects + stylesheet (always together) -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="#{google_fonts_url}">   <!-- only if google_fonts_url present -->
  <!-- Theme CSS -->
  <link rel="stylesheet" href="#{theme_css}">          <!-- only if theme_css present -->
  <!-- morphdom -->
  <script src="#{morphdom_src}"></script>               <!-- only if morphdom_js present -->
</head>
```

When `google_fonts_url` is present, all three Google Fonts tags are emitted together (both preconnects + stylesheet). The preconnect URLs are fixed (`fonts.googleapis.com`, `fonts.gstatic.com`) — only the stylesheet URL is parameterised.

Each block is conditional on its param being non-nil. Existing tests need no changes.

`OpalBuilder#write_index_html` passes the new params:

```ruby
def write_index_html
  File.write(output_path("index.html"),
    OpalShell.render(
      title: @title,
      app_js: "app.js",
      morphdom_js: File.exist?(output_path("morphdom.min.js")) ? "morphdom.min.js" : nil,
      theme_css: File.exist?(output_path("sw-theme.css")) ? "sw-theme.css" : nil,
      google_fonts_url: google_fonts_url_for_build,
      dark_mode_script: StreamWeaver::Theme::AutoMode.inline_script
    ))
end
```

### 3. Adapter::Opal — theme methods

**`render_theme_preset`** — no-op. Preset CSS vars are baked into `sw-theme.css` at build time.

```ruby
def render_theme_preset(view, component, state)
  # Preset CSS vars are in dist/sw-theme.css, written at build time by OpalBuilder.
end
```

**`render_theme_toggle`** — emits a button with a `data-sw-action` attribute. No Ruby callback; the bridge handles it as a pure browser action calling `swToggleTheme()`.

```ruby
def render_theme_toggle(view, component, state)
  view.button(data_sw_action: "toggle-theme") { view.plain("🌓") }
end
```

**`render_theme_switcher`** — no-op stub. Runtime preset switching requires runtime CSS injection and is deferred to Phase 3. Without this stub, `NoMethodError` would be raised if a user calls `theme_switcher` in an Opal app.

```ruby
def render_theme_switcher(view, component, state)
  # Runtime preset switching not supported in Opal Phase 2. Deferred to Phase 3.
end
```

### 4. OpalBridge — `data-sw-action` listener

`OpalBridge#install` gains a fourth delegated listener alongside the existing three, inside the same `%x{}` block within `window.SWRuntime.start`:

```javascript
document.addEventListener('click', function(e) {
  var el = e.target.closest('[data-sw-action]');
  if (el && el.dataset.swAction === 'toggle-theme') {
    if (typeof swToggleTheme === 'function') swToggleTheme();
  }
});
```

`data-sw-action` is for browser-only static JS actions (no Ruby callback). This is distinct from `data-sw-invoke` (Ruby callbacks registered in OpalRuntime). The `typeof swToggleTheme === 'function'` guard prevents a crash if the dark mode script was not included.

### 5. CLI — `--theme PRESET` flag

`opal_build` in `cli.rb` gains a `--theme` flag using the existing hand-rolled arg parsing pattern (consistent with `--output`):

```ruby
theme = if args.include?('--theme')
  args[args.index('--theme') + 1]
end
StreamWeaver::Opal::Builder.build(file, output_dir: output_dir, theme: theme)
```

---

## What This Enables

After this change:

```bash
streamweaver opal-build hello_world.rb
# dist/ now has sw-theme.css — styled with Source Sans 3 + default color tokens

streamweaver opal-build dashboard.rb --theme editorial
# dist/sw-theme.css includes Crimson Pro + editorial color preset vars
```

A Phase 1 `hello_world` app built with this change will look like its server-rendered counterpart: correct fonts, colors, spacing, dark mode support, component styles.

---

## What This Does Not Cover

- **`render_theme_switcher`** — stubbed as no-op. Runtime preset switching deferred to Phase 3.
- **Offline fonts** — Google Fonts is CDN-loaded. Embedding fonts as base64 is deferred.
- **Custom registered themes** (`StreamWeaver.register_theme`) — require running user theme registration code at build time. Deferred.
- **Other adapter methods** (`render_tabs`, `render_table`, `mermaid`, `chartjs`) — separate Phase 2b spec.

---

## Testing

**`spec/opal/builder_spec.rb`** — add:
- writes `sw-theme.css` to output dir
- `sw-theme.css` contains `visual_skills_css` content
- `sw-theme.css` contains animation CSS content
- with `theme: :editorial`, `sw-theme.css` contains `"Instrument Serif"` (editorial display font — unique identifier for the preset CSS being applied)
- with unknown theme, warns to stderr and still writes sw-theme.css (without preset CSS)

**`spec/opal/shell_spec.rb`** — add:
- includes `<script>#{dark_mode_script}</script>` before CSS links when `dark_mode_script:` provided
- includes Google Fonts preconnect tags and stylesheet link when `google_fonts_url:` provided
- includes `<link rel="stylesheet" href="sw-theme.css">` when `theme_css:` provided
- omits all three when params are nil (backward compatibility)

**`spec/opal/adapter_opal_spec.rb`** — add:
- `render_theme_preset` renders nothing (empty output)
- `render_theme_toggle` emits a button with `data-sw-action="toggle-theme"`
- `render_theme_switcher` renders nothing (no-op stub)

**`spec/opal/bridge_spec.rb`** — add a documented-pending block for the `data-sw-action` listener (browser-only, wrapped in `:nocov:`):

```ruby
describe "data-sw-action toggle-theme listener" do
  it "is documented: clicking [data-sw-action=toggle-theme] calls swToggleTheme()" do
    # Browser-only — covered by OpalBridge#install (:nocov:).
    # Manually verified: button rendered by render_theme_toggle triggers swToggleTheme()
    # when dark_mode_script is present in the built index.html.
    pending "browser-only; not testable in MRI"
  end
end
```
