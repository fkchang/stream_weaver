# Opal CSS/Theme Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `streamweaver opal-build` produce fully styled static apps by writing `dist/sw-theme.css` at build time and wiring Google Fonts, dark mode script, and theme toggle into the generated `index.html`.

**Architecture:** `OpalBuilder` gains a `write_theme_css` step that assembles CSS from existing gem methods (`CSS.full_stylesheet`, `Theme.visual_skills_css`, `CSS.animation_css`) and an optional `--theme PRESET` flag that appends preset CSS vars. `OpalShell` gains three new optional `<head>` params in FOUC-safe order (dark mode script → fonts → theme CSS). `Adapter::Opal` adds three theme render methods. `OpalBridge` adds a fourth delegated listener for `data-sw-action="toggle-theme"`.

**Tech Stack:** Ruby, existing `StreamWeaver::CSS`, `StreamWeaver::Theme`, `StreamWeaver::Theme::Presets`, `StreamWeaver::Theme::AutoMode` modules. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-04-30-opal-css-theme-wiring-design.md`

---

## File Map

| File | Change |
|---|---|
| `lib/stream_weaver/opal/shell.rb` | Add `theme_css:`, `google_fonts_url:`, `dark_mode_script:` params |
| `lib/stream_weaver/opal/builder.rb` | Add `theme:` option, `write_theme_css` step, `google_fonts_url_for_build` |
| `lib/stream_weaver/adapter/opal.rb` | Add `render_theme_preset`, `render_theme_toggle`, `render_theme_switcher` |
| `lib/stream_weaver/opal/bridge.rb` | Add `data-sw-action` delegated listener |
| `lib/stream_weaver/cli.rb` | Add `--theme PRESET` flag to `opal_build` |
| `spec/opal/shell_spec.rb` | Add tests for new params |
| `spec/opal/builder_spec.rb` | Add tests for `write_theme_css` and `--theme` |
| `spec/opal/adapter_opal_spec.rb` | Add tests for three theme methods |
| `spec/opal/bridge_spec.rb` | Create with pending test for `data-sw-action` |

---

## Task 1: OpalShell — enriched `<head>` params

**Files:**
- Modify: `lib/stream_weaver/opal/shell.rb`
- Test: `spec/opal/shell_spec.rb`

The shell currently accepts `title:`, `app_js:`, `morphdom_js:`. Add three new optional params that each conditionally add content to `<head>`. FOUC-safe ordering: dark mode script first, then fonts, then theme CSS, then morphdom.

- [ ] **Step 1: Write failing tests**

Add to `spec/opal/shell_spec.rb` inside the existing `describe ".render"` block:

```ruby
describe "dark_mode_script:" do
  it "includes inline script tag when provided" do
    html = described_class.render(title: "T", app_js: "app.js", dark_mode_script: "var x=1;")
    expect(html).to include("<script>var x=1;</script>")
  end

  it "omits script tag when nil" do
    html = described_class.render(title: "T", app_js: "app.js", dark_mode_script: nil)
    expect(html).not_to include("<script>var x=1;</script>")
  end
end

describe "google_fonts_url:" do
  it "includes preconnect and stylesheet links when provided" do
    html = described_class.render(title: "T", app_js: "app.js",
                                  google_fonts_url: "https://fonts.example.com/css2?family=Foo")
    expect(html).to include('href="https://fonts.googleapis.com"')
    expect(html).to include('href="https://fonts.gstatic.com"')
    expect(html).to include('href="https://fonts.example.com/css2?family=Foo"')
  end

  it "omits font links when nil" do
    html = described_class.render(title: "T", app_js: "app.js", google_fonts_url: nil)
    expect(html).not_to include("fonts.googleapis.com")
  end
end

describe "theme_css:" do
  it "includes stylesheet link when provided" do
    html = described_class.render(title: "T", app_js: "app.js", theme_css: "sw-theme.css")
    expect(html).to include('<link rel="stylesheet" href="sw-theme.css">')
  end

  it "omits stylesheet link when nil" do
    html = described_class.render(title: "T", app_js: "app.js", theme_css: nil)
    expect(html).not_to include("sw-theme.css")
  end
end

describe "head ordering (FOUC prevention)" do
  it "places dark_mode_script before stylesheet links" do
    html = described_class.render(
      title: "T", app_js: "app.js",
      dark_mode_script: "var dm=1;",
      google_fonts_url: "https://fonts.example.com",
      theme_css: "sw-theme.css"
    )
    dm_pos    = html.index("<script>var dm=1;</script>")
    fonts_pos = html.index("fonts.example.com")
    css_pos   = html.index("sw-theme.css")
    expect(dm_pos).to be < fonts_pos
    expect(fonts_pos).to be < css_pos
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bundle exec rspec spec/opal/shell_spec.rb -f d
```

Expected: new examples fail with argument or content errors.

- [ ] **Step 3: Implement — extend `OpalShell.render`**

Replace `lib/stream_weaver/opal/shell.rb` with:

```ruby
# frozen_string_literal: true

module StreamWeaver
  module Opal
    class OpalShell
      MORPHDOM_CDN = "https://unpkg.com/morphdom@2.7.4/dist/morphdom.min.js"

      # title, app_js, morphdom_js, theme_css, google_fonts_url are build-time
      # developer-supplied values — not user input. No escaping applied.
      # dark_mode_script is sourced from Theme::AutoMode.inline_script (gem code).
      def self.render(title: "StreamWeaver App", app_js: "app.js", morphdom_js: nil,
                      theme_css: nil, google_fonts_url: nil, dark_mode_script: nil)
        morphdom_src = morphdom_js || MORPHDOM_CDN
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{title}</title>
          #{dark_mode_tag(dark_mode_script)}#{google_fonts_tags(google_fonts_url)}#{theme_css_tag(theme_css)}  <script src="#{morphdom_src}"></script>
          </head>
          <body>
            <div id="sw-app"></div>
            <script src="#{app_js}"></script>
            <script>
              document.addEventListener("DOMContentLoaded", function() {
                SWRuntime.start();
              });
            </script>
          </body>
          </html>
        HTML
      end

      def self.dark_mode_tag(script)
        return "" unless script
        "  <script>#{script}</script>\n"
      end
      private_class_method :dark_mode_tag

      def self.google_fonts_tags(url)
        return "" unless url
        <<~HTML.gsub(/^/, "  ")
          <link rel="preconnect" href="https://fonts.googleapis.com">
          <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
          <link rel="stylesheet" href="#{url}">
        HTML
      end
      private_class_method :google_fonts_tags

      def self.theme_css_tag(filename)
        return "" unless filename
        "  <link rel=\"stylesheet\" href=\"#{filename}\">\n"
      end
      private_class_method :theme_css_tag
    end
  end
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
bundle exec rspec spec/opal/shell_spec.rb -f d
```

Expected: all examples pass including existing ones.

- [ ] **Step 5: Run full suite to confirm no regressions**

```bash
bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 6: Commit**

```bash
git add lib/stream_weaver/opal/shell.rb spec/opal/shell_spec.rb
git commit -m "feat(opal): OpalShell — theme_css, google_fonts_url, dark_mode_script params"
```

---

## Task 2: OpalBuilder — `write_theme_css` and `theme:` option

**Files:**
- Modify: `lib/stream_weaver/opal/builder.rb`
- Test: `spec/opal/builder_spec.rb`

Add `theme:` keyword to `OpalBuilder`, a `write_theme_css` private step, and wire the new shell params in `write_index_html`.

- [ ] **Step 1: Write failing tests**

Add to `spec/opal/builder_spec.rb` inside the existing `describe ".build"` block:

```ruby
it "writes sw-theme.css" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  described_class.build(app_file, output_dir: out)
  expect(File.exist?(File.join(out, "sw-theme.css"))).to be true
end

it "sw-theme.css contains visual_skills_css content" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  described_class.build(app_file, output_dir: out)
  css = File.read(File.join(out, "sw-theme.css"))
  expect(css).to include("--sw-bg")   # from Theme.visual_skills_css
end

it "sw-theme.css contains animation CSS" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  described_class.build(app_file, output_dir: out)
  css = File.read(File.join(out, "sw-theme.css"))
  expect(css).to include("sw-fade-in")  # from CSS.animation_css
end

it "with theme: :editorial, sw-theme.css contains Instrument Serif" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  described_class.build(app_file, output_dir: out, theme: :editorial)
  css = File.read(File.join(out, "sw-theme.css"))
  expect(css).to include("Instrument Serif")
end

it "with unknown theme, warns to stderr and still writes sw-theme.css" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  expect {
    described_class.build(app_file, output_dir: out, theme: :nonexistent_theme)
  }.to output(/Unknown theme preset/).to_stderr
  expect(File.exist?(File.join(out, "sw-theme.css"))).to be true
end

it "index.html links to sw-theme.css" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  described_class.build(app_file, output_dir: out)
  html = File.read(File.join(out, "index.html"))
  expect(html).to include('href="sw-theme.css"')
end

it "index.html includes Google Fonts link" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  described_class.build(app_file, output_dir: out)
  html = File.read(File.join(out, "index.html"))
  expect(html).to include("fonts.googleapis.com")
end

it "index.html includes dark mode script" do
  app_file = File.join(@tmpdir, "app.rb")
  File.write(app_file, app_content)
  out = File.join(@tmpdir, "dist")
  described_class.build(app_file, output_dir: out)
  html = File.read(File.join(out, "index.html"))
  expect(html).to include("swToggleTheme")
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bundle exec rspec spec/opal/builder_spec.rb -f d
```

Expected: new examples fail (no `sw-theme.css`, no font/theme content in HTML).

- [ ] **Step 3: Implement — extend `OpalBuilder`**

Replace `lib/stream_weaver/opal/builder.rb` with:

```ruby
# frozen_string_literal: true
require "fileutils"
require "opal"
require_relative "shell"

module StreamWeaver
  module Opal
    class OpalBuilder
      DEFAULT_GOOGLE_FONTS_URL =
        "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600" \
        "&family=Source+Sans+3:wght@400;500;600;700&display=swap"

      def self.build(app_file, output_dir: "dist", title: nil, theme: nil)
        new(app_file, output_dir: output_dir, title: title, theme: theme).call
      end

      def initialize(app_file, output_dir: "dist", title: nil, theme: nil)
        @app_file   = app_file
        @output_dir = output_dir
        @title      = title || derive_title
        @theme      = theme
        @lib_root   = File.expand_path(File.join(__dir__, "../.."))
        @stubs_root = File.join(__dir__, "stubs")
      end

      def call
        FileUtils.mkdir_p(@output_dir)
        write_app_js
        copy_morphdom
        write_theme_css
        write_index_html
      end

      private

      def write_app_js
        File.write(output_path("app.js"), compile.to_s)
      end

      def copy_morphdom
        src = File.join(@stubs_root, "morphdom.min.js")
        FileUtils.cp(src, output_path("morphdom.min.js")) if File.exist?(src)
      end

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

      def compile
        builder = build_opal_bundle
        builder.build_str(stripped_source, File.basename(@app_file))
      end

      def build_opal_bundle
        ::Opal::Builder.new(missing_require_severity: :ignore).tap do |b|
          b.append_paths(@stubs_root)
          b.append_paths(@lib_root)
          b.build("opal")
          build_stdlib(b)
          b.build("stream_weaver/opal_entry")
        end
      end

      def build_stdlib(builder)
        %w[set cgi json digest].each do |lib|
          builder.build(lib)
        rescue => e
          warn "[OpalBuilder] Could not build stdlib '#{lib}': #{e.message}"
        end
      end

      def stripped_source
        File.read(@app_file)
          .gsub(/^\s*require_relative\s+['"][^'"]+['"]\s*$/, "")
          .gsub(/^\s*require\s+['"]stream_weaver['"]\s*$/, "")
      end

      def output_path(filename)
        File.join(@output_dir, filename)
      end

      def derive_title
        File.basename(@app_file, ".rb").tr("_-", " ").split.map(&:capitalize).join(" ")
      end

      def google_fonts_url_for_build
        if @theme && (preset = StreamWeaver::Theme::Presets.get(@theme.to_sym))
          StreamWeaver::Theme::Presets.google_fonts_url(preset)
        else
          DEFAULT_GOOGLE_FONTS_URL
        end
      end
    end
  end
end
```

Add these requires unconditionally at the top of the replacement file (the builder runs in MRI, not inside Opal, so the gem classes must be explicitly required):

```ruby
require "stream_weaver/css"
require "stream_weaver/theme"
require "stream_weaver/theme/presets"
require "stream_weaver/theme/auto_mode"
```

Place them after `require_relative "shell"` and before `module StreamWeaver`.

- [ ] **Step 4: Run builder tests**

```bash
bundle exec rspec spec/opal/builder_spec.rb -f d
```

Expected: all pass.

- [ ] **Step 5: Run full suite**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/stream_weaver/opal/builder.rb spec/opal/builder_spec.rb
git commit -m "feat(opal): OpalBuilder writes sw-theme.css, wires fonts + dark mode into shell"
```

---

## Task 3: Adapter::Opal — theme render methods

**Files:**
- Modify: `lib/stream_weaver/adapter/opal.rb`
- Test: `spec/opal/adapter_opal_spec.rb`

Add `render_theme_preset` (no-op), `render_theme_toggle` (data-attribute button), and `render_theme_switcher` (no-op stub). Without these, any Opal app that calls `theme_preset`, `theme_toggle`, or `theme_switcher` raises `NotImplementedError` or `NoMethodError`.

- [ ] **Step 1: Write failing tests**

Add to `spec/opal/adapter_opal_spec.rb`:

```ruby
describe "#render_theme_preset" do
  it "is a no-op — emits nothing (preset CSS baked in by builder)" do
    adapter.render_theme_preset(view, double("ThemePreset"), state)
    expect(view.to_html).to eq("")
  end
end

describe "#render_theme_toggle" do
  it "renders a button with data-sw-action=toggle-theme" do
    adapter.render_theme_toggle(view, double("ThemeToggle"), state)
    html = view.to_html
    expect(html).to include('<button')
    expect(html).to include('data-sw-action="toggle-theme"')
  end

  it "does not use onclick or any inline JS" do
    adapter.render_theme_toggle(view, double("ThemeToggle"), state)
    expect(view.to_html).not_to include("onclick")
  end
end

describe "#render_theme_switcher" do
  it "is a no-op — runtime preset switching deferred to Phase 3" do
    adapter.render_theme_switcher(view, double("ThemeSwitcher"), state)
    expect(view.to_html).to eq("")
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bundle exec rspec spec/opal/adapter_opal_spec.rb -f d
```

Expected: three new examples fail with `NotImplementedError` or `NoMethodError`.

- [ ] **Step 3: Implement — add three methods to `Adapter::Opal`**

Add inside `class Opal < Base` in `lib/stream_weaver/adapter/opal.rb`, after `render_cdn_scripts`:

```ruby
# Overrides Base — preset CSS vars are in dist/sw-theme.css, written at build time.
def render_theme_preset(view, component, state)
end

# Overrides Base — emits a button that calls swToggleTheme() via OpalBridge data-sw-action listener.
def render_theme_toggle(view, component, state)
  view.button(data_sw_action: "toggle-theme") { view.plain("🌓") }
end

# Stub — runtime preset switching requires runtime CSS injection. Deferred to Phase 3.
def render_theme_switcher(view, component, state)
end
```

- [ ] **Step 4: Run adapter tests**

```bash
bundle exec rspec spec/opal/adapter_opal_spec.rb -f d
```

Expected: all pass.

- [ ] **Step 5: Run full suite**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/stream_weaver/adapter/opal.rb spec/opal/adapter_opal_spec.rb
git commit -m "feat(opal): Adapter::Opal — render_theme_preset no-op, render_theme_toggle, render_theme_switcher stub"
```

---

## Task 4: OpalBridge — `data-sw-action` delegated listener

**Files:**
- Modify: `lib/stream_weaver/opal/bridge.rb`
- Create: `spec/opal/bridge_spec.rb`

Add a fourth delegated click listener for `[data-sw-action="toggle-theme"]` that calls `swToggleTheme()`. This is browser-only code wrapped in `:nocov:`. The spec file documents the expected behavior as a pending test.

- [ ] **Step 1: Create bridge spec with documented-pending test**

Create `spec/opal/bridge_spec.rb`:

```ruby
# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/bridge"
require "stream_weaver/opal/runtime"
require "stream_weaver/adapter/opal"

RSpec.describe StreamWeaver::Opal::OpalBridge do
  describe "#install" do
    it "returns without error in MRI (defined?(::Opal) is nil)" do
      adapter = StreamWeaver::Adapter::Opal.new
      runtime = StreamWeaver::Opal::OpalRuntime.new(adapter: adapter)
      bridge = described_class.new(runtime)
      expect { bridge.install }.not_to raise_error
    end

    describe "data-sw-action toggle-theme listener" do
      it "is documented: clicking [data-sw-action=toggle-theme] calls swToggleTheme()" do
        # Browser-only — OpalBridge#install is wrapped in :nocov:.
        # Manually verified: render_theme_toggle emits data-sw-action="toggle-theme".
        # OpalBridge adds a delegated click listener that calls swToggleTheme() when
        # that attribute is found. swToggleTheme() is provided by Theme::AutoMode.inline_script
        # injected into index.html <head> by OpalBuilder.
        pending "browser-only; not testable in MRI"
      end
    end
  end
end
```

- [ ] **Step 2: Run to confirm it passes (one pending, one passing)**

```bash
bundle exec rspec spec/opal/bridge_spec.rb -f d
```

Expected: 1 pass ("returns without error"), 1 pending.

- [ ] **Step 3: Replace the entire `OpalBridge#install` method**

Replace the full `install` method in `lib/stream_weaver/opal/bridge.rb` with the version below, which adds the fourth listener for `data-sw-action` after the existing `change` listener:

```ruby
# :nocov:
return unless defined?(::Opal)
runtime = @runtime
%x{
  window.SWRuntime = {
    start: function() {
      #{runtime.render_and_patch}
      document.addEventListener('click', function(e) {
        var el = e.target.closest('[data-sw-invoke]');
        if (el) #{runtime.invoke_and_patch(`el.dataset.swInvoke`)};
      });
      document.addEventListener('input', function(e) {
        var key = e.target.dataset && e.target.dataset.swUpdate;
        if (key) #{runtime.update_and_patch(`key`, `e.target.value`)};
      });
      document.addEventListener('change', function(e) {
        var key = e.target.dataset && e.target.dataset.swToggle;
        if (key) #{runtime.update_and_patch(`key`, `e.target.checked`)};
      });
      document.addEventListener('click', function(e) {
        var el = e.target.closest('[data-sw-action]');
        if (el && el.dataset.swAction === 'toggle-theme') {
          if (typeof swToggleTheme === 'function') swToggleTheme();
        }
      });
    }
  };
}
# :nocov:
```

- [ ] **Step 4: Run bridge spec**

```bash
bundle exec rspec spec/opal/bridge_spec.rb -f d
```

Expected: 1 pass, 1 pending (no failures).

- [ ] **Step 5: Run full suite**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/stream_weaver/opal/bridge.rb spec/opal/bridge_spec.rb
git commit -m "feat(opal): OpalBridge — data-sw-action delegated listener for theme toggle"
```

---

## Task 5: CLI — `--theme PRESET` flag

**Files:**
- Modify: `lib/stream_weaver/cli.rb`

Add `--theme PRESET` flag to the `opal_build` command using the existing hand-rolled arg parsing pattern (consistent with `--output`).

- [ ] **Step 1: Locate the `opal_build` method**

The method starts around line 971 in `lib/stream_weaver/cli.rb`. It currently ends with:

```ruby
StreamWeaver::Opal::OpalBuilder.build(file, output_dir: output_dir)
puts "Built to #{output_dir}/"
puts "Open #{output_dir}/index.html in a browser or deploy to GitHub Pages."
```

- [ ] **Step 2: Add `--theme` parsing and pass to builder**

Replace those final three lines (the `OpalBuilder.build` call and the two `puts`) with:

```ruby
theme = if args.include?('--theme')
  val = args[args.index('--theme') + 1]
  if val.nil? || val.start_with?('--')
    $stderr.puts "Error: --theme requires a preset name (e.g. --theme editorial)"
    exit 1
  end
  val
end
StreamWeaver::Opal::OpalBuilder.build(file, output_dir: output_dir, theme: theme&.to_sym)
puts "Built to #{output_dir}/"
puts "Open #{output_dir}/index.html in a browser or deploy to GitHub Pages."
```

Also update the help text for `opal-build` to mention `--theme`:

Find the line containing `opal-build` in the help output and add `[--theme PRESET]` to the usage example and add a line like:
```
  --theme PRESET    Apply named theme preset CSS (e.g. editorial, technical)
```

- [ ] **Step 3: Run full suite to confirm no regressions**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 4: Manual smoke test**

```bash
streamweaver opal-build examples/basic/hello_world.rb --output /tmp/sw-themed-test
open /tmp/sw-themed-test/index.html
```

Verify:
- Page has fonts (Source Sans 3)
- Page has StreamWeaver colors (not browser defaults)
- Dark mode toggle works if app includes `theme_toggle`

```bash
streamweaver opal-build examples/basic/hello_world.rb --output /tmp/sw-editorial --theme editorial
open /tmp/sw-editorial/index.html
```

Verify: editorial fonts (Instrument Serif for headings).

- [ ] **Step 5: Commit**

```bash
git add lib/stream_weaver/cli.rb
git commit -m "feat(opal): CLI opal-build -- --theme PRESET flag"
```

---

## Task 6: Push and verify

- [ ] **Step 1: Run full suite one final time**

```bash
bundle exec rspec
```

Expected: all pass, no failures.

- [ ] **Step 2: Push**

```bash
git pull --rebase
git push
```

Expected: clean push.
