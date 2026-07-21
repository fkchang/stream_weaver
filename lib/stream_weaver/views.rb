# frozen_string_literal: true

require 'phlex'
require 'json'

module StreamWeaver
  module Views
    # Full page view for initial load (includes <html>, <head>, <body>)
    class AppView < Phlex::HTML
      attr_reader :adapter, :app
      attr_reader :current_fragment_id

      # @param app [StreamWeaver::App] The app instance
      # @param state [Hash] The current state
      # @param adapter [StreamWeaver::Adapter::Base] The adapter for rendering
      # @param is_agentic [Boolean] Whether running in agentic mode
      # @param session_theme [Symbol, nil] Theme override from session
      def initialize(app, state, adapter, is_agentic = false, session_theme: nil)
        @app = app
        @state = state
        @adapter = adapter
        @is_agentic = is_agentic
        @session_theme = session_theme
        @scripts = app.scripts
        @stylesheets = app.stylesheets
      end

      def view_template
        # Render the body content first so that any component CSS injected
        # along the way (adapter#inject_component_css) lands in
        # @component_css_registry before <head> is built below -- <head>
        # must come first in document order, but which components (and thus
        # which CSS) will render is only known by actually rendering them
        # (stream_weaver-1lo). Captured rather than appended directly so it
        # can be replayed into <body> after <head> is emitted.
        body_html = capture { render_page_body }

        doctype
        html do
          head do
            # Pins cascade layer order before any framework CSS is emitted
            # (stream_weaver-oeo). All framework CSS lives in this one named
            # layer; any unlayered user stylesheet always wins the cascade
            # regardless of specificity or document order, so the
            # stream_weaver-1lo hoist-to-<head> trick below is now belt-and-
            # suspenders rather than the only thing making user CSS win.
            style { raw(safe("@layer #{StreamWeaver::CSS::LAYER_NAME};")) }

            title { @app.title }
            meta(charset: "utf-8")
            meta(name: "viewport", content: "width=device-width, initial-scale=1")
            # Favicon (emoji or URL)
            if (fav = @app.favicon_href)
              link(rel: "icon", href: fav)
            end
            # Inject adapter-specific CDN scripts using Phlex methods
            @adapter.render_cdn_scripts(self)

            # Framework-injected component CSS (collected during the body
            # render above), before user stylesheets: below -- so that at
            # equal specificity, user stylesheets win on document order
            # instead of always losing to the framework's own rule
            # (stream_weaver-1lo). Also wrapped in the shared layer
            # (stream_weaver-oeo) so this ordering is now a nicety, not a
            # requirement -- an unlayered user rule wins even if it lands
            # earlier in the document.
            unless component_css_registry.empty?
              style { raw(safe(StreamWeaver::CSS.layer_wrap(component_css_registry.values.join("\n")))) }
            end

            # Add custom stylesheets
            @stylesheets.each do |href|
              link(rel: "stylesheet", href: href)
            end

            # Add custom scripts
            @scripts.each do |src|
              script(src: src)
            end

            # Component-scoped CSS/JS (declared via css/css_path/js_path class macros)
            render_component_assets

            # Chart.js CDN - only load when charts are present
            if @app.has_charts?
              script(src: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js")
            end

            # SSE client for streaming push updates (when app has stream block or timers)
            if (@app.stream_block || @app.has_timers?) && @adapter.respond_to?(:render_sse_client)
              @adapter.render_sse_client(self)
            end

            # URL routing: popstate handler for browser back/forward
            if @app.routes && @adapter.respond_to?(:render_routing_scripts)
              @adapter.render_routing_scripts(self)
            end

            # Google Fonts: Source Sans 3 + Crimson Pro (for document theme) + any app-declared fonts
            link(rel: "preconnect", href: "https://fonts.googleapis.com")
            link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: "anonymous")
            link(rel: "stylesheet", href: "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap")
            if @app.fonts.any?
              custom_href = Fonts.google_fonts_href(@app.fonts)
              link(rel: "stylesheet", href: custom_href) if custom_href
            end
            style do
              raw(safe(StreamWeaver::CSS.layer_wrap(self.class.master_theme_css)))
            end

            # Visual Skills CSS foundation (--sw-* semantic tokens)
            style do
              raw(safe(StreamWeaver::CSS.layer_wrap(StreamWeaver::Theme.visual_skills_css)))
            end

            # Dark mode: check localStorage / system preference, apply .dark on <html>
            # Also provides swToggleTheme() / swGetTheme() for auto-mode support
            script do
              theme_toggle = @app.components.find { |c| c.is_a?(Components::ThemeToggle) }
              raw(safe(StreamWeaver::Theme::AutoMode.inline_script(default_mode: theme_toggle&.mode || :auto)))
            end
          end
          body(class: body_classes) do
            raw(safe(body_html))
          end
        end
      end

      # Everything that lives inside <body> -- extracted so view_template
      # can render it once via `capture` (see the comment there) and replay
      # the resulting string after <head> is built.
      def render_page_body
        # Custom theme CSS (for registered themes)
        render_custom_theme_css

        # Theme overrides as inline CSS
        render_theme_overrides if @app.theme_overrides.any?

        layout_entry = @app.layout_entry
        if layout_entry&.dig(:exclusive) && layout_entry[:render_block]
          instance_exec(&layout_entry[:render_block])
        else
          # Skip the chrome's own h1 when the app already renders its
          # leading content as a header1 -- otherwise the page doubles up
          # (FAC-9u2).
          first_content = @app.components.first
          own_leading_h1 = first_content.is_a?(Components::Header) && first_content.level == 1
          h1 { @app.title } unless own_leading_h1
          # Merge adapter-specific container attributes with container id
          div(id: "app-container", "data-sw-state-version" => @app.render_state.state_version,
              **@adapter.container_attributes(@state)) do
            render_components
          end
        end
      end

      # Collects component CSS registered via adapter#inject_component_css
      # during the body render, keyed so re-registering the same key is a
      # no-op (cross-instance dedup within one page render).
      def component_css_registry
        @component_css_registry ||= {}
      end

      def register_component_css(key, css)
        component_css_registry[key] = css
      end

      def with_fragment(id)
        previous = @current_fragment_id
        @current_fragment_id = id
        yield
      ensure
        @current_fragment_id = previous
      end

      def self.master_theme_css
        <<~CSS
                /* ===========================================
                   shadcn Token Layer
                   Bridge: tokens fall back to --sw-* vars,
                   so register_theme still works.
                   =========================================== */
                :root {
                  --background: var(--sw-color-bg, oklch(1 0 0));
                  --foreground: var(--sw-color-text, oklch(0.145 0 0));
                  --card: var(--sw-color-bg-card, oklch(1 0 0));
                  --card-foreground: var(--sw-color-text, oklch(0.145 0 0));
                  --popover: var(--sw-color-bg-card, oklch(1 0 0));
                  --popover-foreground: var(--sw-color-text, oklch(0.145 0 0));
                  --primary: var(--sw-color-primary, oklch(0.205 0 0));
                  --primary-foreground: oklch(0.985 0 0);
                  --secondary: var(--sw-color-secondary, oklch(0.97 0 0));
                  --secondary-foreground: var(--sw-color-secondary-foreground, oklch(0.205 0 0));
                  --muted: var(--sw-color-bg-elevated, oklch(0.97 0 0));
                  --muted-foreground: var(--sw-color-text-muted, oklch(0.556 0 0));
                  --accent: var(--sw-color-accent, oklch(0.97 0 0));
                  --accent-foreground: oklch(0.205 0 0);
                  --destructive: oklch(0.577 0.245 27.325);
                  --destructive-foreground: #fff;
                  --border: var(--sw-color-border, oklch(0.922 0 0));
                  --input: var(--sw-color-border, oklch(0.922 0 0));
                  --ring: oklch(0.708 0 0);
                  --radius: var(--sw-radius-md, 0.5rem);
                  --warning: hsl(38 92% 50%);
                  --warning-foreground: #fff;
                  --success: hsl(142 71% 45%);
                  --success-foreground: #fff;
                  --info: hsl(217 91% 60%);
                  --info-foreground: #fff;
                }

                /* Re-bridge on body: the --sw-color-* tokens these vars fall back to
                   are themselves declared on body (body.sw-theme-*, theme_overrides:,
                   html.dark body -- see below), which is a descendant of :root/<html>.
                   A custom property's var() fallback resolves against what's in scope
                   AT THE ELEMENT declaring it, so the :root block above can never see
                   a per-theme override made on body -- it's always stuck on its own
                   fallback. Redeclaring here, on body itself, lets these tokens see
                   whatever --sw-color-* body ends up with (default theme, a custom
                   registered theme, or an app's theme_overrides:) instead of only ever
                   reflecting the light default (stream_weaver-9u2). */
                body {
                  --background: var(--sw-color-bg, oklch(1 0 0));
                  --foreground: var(--sw-color-text, oklch(0.145 0 0));
                  --card: var(--sw-color-bg-card, oklch(1 0 0));
                  --card-foreground: var(--sw-color-text, oklch(0.145 0 0));
                  --popover: var(--sw-color-bg-card, oklch(1 0 0));
                  --popover-foreground: var(--sw-color-text, oklch(0.145 0 0));
                  --primary: var(--sw-color-primary, oklch(0.205 0 0));
                  --secondary: var(--sw-color-secondary, oklch(0.97 0 0));
                  --secondary-foreground: var(--sw-color-secondary-foreground, oklch(0.205 0 0));
                  --muted: var(--sw-color-bg-elevated, oklch(0.97 0 0));
                  --muted-foreground: var(--sw-color-text-muted, oklch(0.556 0 0));
                  --accent: var(--sw-color-accent, oklch(0.97 0 0));
                  --border: var(--sw-color-border, oklch(0.922 0 0));
                  --input: var(--sw-color-border, oklch(0.922 0 0));
                  --radius: var(--sw-radius-md, 0.5rem);
                }

                .dark {
                  --background: oklch(0.145 0 0);
                  --foreground: oklch(0.985 0 0);
                  --card: oklch(0.205 0 0);
                  --card-foreground: oklch(0.985 0 0);
                  --popover: oklch(0.205 0 0);
                  --popover-foreground: oklch(0.985 0 0);
                  --primary: oklch(0.922 0 0);
                  --primary-foreground: oklch(0.205 0 0);
                  --secondary: oklch(0.269 0 0);
                  --secondary-foreground: oklch(0.985 0 0);
                  --muted: oklch(0.269 0 0);
                  --muted-foreground: oklch(0.708 0 0);
                  --accent: oklch(0.269 0 0);
                  --accent-foreground: oklch(0.985 0 0);
                  --destructive: oklch(0.704 0.191 22.216);
                  --destructive-foreground: oklch(0.985 0 0);
                  --border: oklch(1 0 0 / 10%);
                  --input: oklch(1 0 0 / 15%);
                  --ring: oklch(0.556 0 0);
                  --warning: hsl(38 92% 60%);
                  --warning-foreground: hsl(38 92% 10%);
                  --success: hsl(142 71% 55%);
                  --success-foreground: hsl(142 71% 10%);
                  --info: hsl(217 91% 70%);
                  --info-foreground: hsl(217 91% 10%);
                }

                /* Dark mode: override sw-color-* tokens to match shadcn dark values.
                   html.dark body beats body.sw-theme-* specificity (0-1-2 vs 0-1-1). */
                html.dark body {
                  --sw-color-bg: oklch(0.145 0 0);
                  --sw-color-bg-card: oklch(0.205 0 0);
                  --sw-color-bg-elevated: oklch(0.269 0 0);
                  --sw-color-text: oklch(0.985 0 0);
                  --sw-color-text-muted: oklch(0.708 0 0);
                  --sw-color-text-light: oklch(0.556 0 0);
                  --sw-color-border: oklch(1 0 0 / 10%);
                  --sw-color-border-strong: oklch(1 0 0 / 15%);
                  --sw-color-border-focus: var(--sw-color-primary);
                  --sw-shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.3);
                  --sw-shadow-md: 0 4px 8px rgba(0, 0, 0, 0.4);
                  --sw-shadow-lg: 0 8px 16px rgba(0, 0, 0, 0.5);
                  --sw-shadow-xl: 0 12px 24px rgba(0, 0, 0, 0.6);
                  --sw-shadow-inner: inset 0 1px 2px rgba(0, 0, 0, 0.2);
                }

                /* shadcn base resets */
                body { background-color: var(--background); color: var(--foreground); }

                .sw-focus-ring:focus-visible {
                  outline: none;
                  box-shadow: 0 0 0 2px var(--background), 0 0 0 4px var(--ring);
                }

                /* ===========================================
                   StreamWeaver CSS - Multi-Theme System
                   =========================================== */

                /* Base variables (shared across all themes) */
                :root {
                  /* Transitions - Smooth, deliberate */
                  --sw-transition-fast: 120ms ease-out;
                  --sw-transition: 200ms ease-out;
                  --sw-transition-slow: 350ms ease-out;

                  /* Tooltip */
                  --sw-tooltip-bg: #292524;
                  --sw-tooltip-text: #fafaf9;
                }

                /* ===========================================
                   Theme: Default (Warm Industrial)
                   Distinctive, craft-inspired aesthetic
                   =========================================== */
                body.sw-theme-default {
                  /* Typography - Source Sans 3: humanist, readable, distinctive */
                  --sw-font-display: 'Source Sans 3', system-ui, sans-serif;
                  --sw-font-body: 'Source Sans 3', system-ui, sans-serif;
                  --sw-font-family: var(--sw-font-body);
                  --sw-font-size-base: 17px;
                  --sw-font-size-sm: 15px;
                  --sw-font-size-lg: 19px;
                  --sw-font-size-xl: 24px;
                  --sw-line-height: 1.6;

                  /* Colors - High Contrast with Warm Accent
                     Amber/brass, not terracotta/orange -- the previous burnt-orange
                     (#c2410c) sat close enough to browser validation-error red that
                     it read as a warning state on cards rather than a brand accent. */
                  --sw-color-primary: #a16207;        /* Brass/ochre */
                  --sw-color-primary-hover: #854d0e;  /* Deeper brass */
                  --sw-color-primary-light: #fef3c7;  /* Warm pale tint */
                  --sw-color-primary-glow: rgba(161, 98, 7, 0.12);

                  /* Colors - High Contrast Neutrals */
                  --sw-color-text: #111111;           /* Near black - high contrast */
                  --sw-color-text-muted: #444444;     /* Dark gray - still readable */
                  --sw-color-text-light: #888888;     /* Placeholder gray */
                  --sw-color-bg: #f2ede4;             /* Warm light tan -- was #f8f8f8, nearly
                                                          indistinguishable from the white card
                                                          background below; this gives visible
                                                          page/card separation */
                  --sw-color-bg-card: #ffffff;
                  --sw-color-bg-elevated: #f3f3f3;   /* Subtle elevation */
                  --sw-color-border: #e0e0e0;        /* Clean border */
                  --sw-color-border-strong: #cccccc;
                  --sw-color-border-focus: var(--sw-color-primary);

                  /* Colors - Secondary */
                  --sw-color-secondary: #333333;
                  --sw-color-secondary-hover: #1a1a1a;
                  --sw-color-secondary-foreground: #ffffff;

                  /* Colors - Accent (teal for links/highlights) */
                  --sw-color-accent: #0d9488;
                  --sw-color-accent-light: #e6fffa;

                  /* Spacing -- was "Generous" (1.25/2/3/4rem), measured ~21% taller
                     than :doc for identical Dashboard content at the same viewport
                     width with no proportional benefit -- tightened to be close to
                     :doc's own scale while keeping a touch more room than dashboard
                     (which is deliberately the densest theme). */
                  --sw-spacing-xs: 0.375rem;
                  --sw-spacing-sm: 0.5rem;
                  --sw-spacing-md: 1rem;
                  --sw-spacing-lg: 1.5rem;
                  --sw-spacing-xl: 2rem;
                  --sw-spacing-2xl: 3rem;

                  /* Border Radius */
                  --sw-radius-sm: 3px;
                  --sw-radius-md: 6px;
                  --sw-radius-lg: 10px;
                  --sw-radius-xl: 16px;

                  /* Shadows - Deep, warm */
                  --sw-shadow-sm: 0 1px 2px rgba(28, 25, 23, 0.04), 0 1px 3px rgba(28, 25, 23, 0.06);
                  --sw-shadow-md: 0 4px 8px -2px rgba(28, 25, 23, 0.08), 0 2px 4px -1px rgba(28, 25, 23, 0.04);
                  --sw-shadow-lg: 0 12px 24px -4px rgba(28, 25, 23, 0.12), 0 4px 8px -2px rgba(28, 25, 23, 0.06);
                  --sw-shadow-xl: 0 20px 40px -8px rgba(28, 25, 23, 0.16), 0 8px 16px -4px rgba(28, 25, 23, 0.08);
                  --sw-shadow-inner: inset 0 1px 2px rgba(28, 25, 23, 0.06);

                  /* Card styling */
                  --sw-card-border-left: 3px solid var(--sw-color-primary);

                  /* Term highlighting */
                  --sw-term-color: var(--sw-color-primary);
                  --sw-term-bg-hover: var(--sw-color-primary-light);
                }

                /* Default-specific adjustments.
                   h1/h3 are already identical to :doc's (both fall through to the
                   shared, theme-unaware base rules -- rem against a fixed 16px
                   root, not var(--sw-font-size-base)). h2 was the one real gap:
                   :doc already has its own tuned override (1.45rem = 23.2px) but
                   default never got one, so it fell through to the generic 1.625rem
                   (26px) instead -- match :doc's value so both themes share one
                   coherent heading scale instead of only mostly agreeing. */
                body.sw-theme-default h2 {
                  font-size: 1.45rem;
                }

                /* ===========================================
                   Theme: Dashboard (Data Dense)
                   Optimized for data tables, metrics, scanning
                   =========================================== */
                body.sw-theme-dashboard {
                  /* Typography - Tighter, more compact */
                  --sw-font-display: 'Source Sans 3', system-ui, sans-serif;
                  --sw-font-body: 'Source Sans 3', system-ui, sans-serif;
                  --sw-font-family: var(--sw-font-body);
                  --sw-font-size-base: 15px;
                  --sw-font-size-sm: 13px;
                  --sw-font-size-lg: 17px;
                  --sw-font-size-xl: 21px;
                  --sw-line-height: 1.5;

                  /* Colors - Same palette, cleaner */
                  --sw-color-primary: #a16207;
                  --sw-color-primary-hover: #854d0e;
                  --sw-color-primary-light: #fef3c7;
                  --sw-color-primary-glow: rgba(161, 98, 7, 0.08);

                  --sw-color-text: #111111;
                  --sw-color-text-muted: #555555;
                  --sw-color-text-light: #888888;
                  --sw-color-bg: #fafafa;
                  --sw-color-bg-card: #ffffff;
                  --sw-color-bg-elevated: #f5f5f5;
                  --sw-color-border: #e5e5e5;
                  --sw-color-border-strong: #d0d0d0;
                  --sw-color-border-focus: var(--sw-color-primary);

                  --sw-color-secondary: #333333;
                  --sw-color-secondary-hover: #1a1a1a;
                  --sw-color-secondary-foreground: #ffffff;

                  --sw-color-accent: #0d9488;
                  --sw-color-accent-light: #e6fffa;

                  /* Spacing - Reduced for density */
                  --sw-spacing-xs: 0.3125rem;
                  --sw-spacing-sm: 0.4375rem;
                  --sw-spacing-md: 0.75rem;
                  --sw-spacing-lg: 1.125rem;
                  --sw-spacing-xl: 1.5rem;
                  --sw-spacing-2xl: 2.25rem;

                  /* Table/callout density -- tighter than the 0.75rem/1rem shared default,
                     since "Data Dense" is this theme's whole reason to exist */
                  --sw-table-header-padding: 6px 10px;
                  --sw-table-cell-padding: 7px 10px;
                  --sw-callout-padding: 10px 14px;

                  /* Border Radius - Slightly smaller */
                  --sw-radius-sm: 2px;
                  --sw-radius-md: 4px;
                  --sw-radius-lg: 6px;
                  --sw-radius-xl: 10px;

                  /* Shadows - Minimal */
                  --sw-shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.04);
                  --sw-shadow-md: 0 2px 4px rgba(0, 0, 0, 0.06);
                  --sw-shadow-lg: 0 4px 8px rgba(0, 0, 0, 0.08);
                  --sw-shadow-xl: 0 8px 16px rgba(0, 0, 0, 0.1);
                  --sw-shadow-inner: inset 0 1px 2px rgba(0, 0, 0, 0.04);

                  /* Card styling - No accent bar */
                  --sw-card-border-left: 1px solid var(--sw-color-border);

                  --sw-term-color: var(--sw-color-primary);
                  --sw-term-bg-hover: var(--sw-color-primary-light);
                }

                /* Dashboard-specific adjustments */
                body.sw-theme-dashboard h2 {
                  font-size: 1.25rem;
                  margin-top: var(--sw-spacing-lg);
                  margin-bottom: var(--sw-spacing-sm);
                }

                body.sw-theme-dashboard .score-table th,
                body.sw-theme-dashboard .score-table td {
                  padding: 6px 10px;
                }

                /* ===========================================
                   Theme: Document (Reading Optimized)
                   Long-form reading, focus mode, elegant
                   =========================================== */
                body.sw-theme-document {
                  /* Typography - Serif, larger, generous line height */
                  --sw-font-display: 'Source Sans 3', system-ui, sans-serif;
                  --sw-font-body: 'Crimson Pro', Georgia, 'Times New Roman', serif;
                  --sw-font-family: var(--sw-font-body);
                  --sw-font-size-base: 19px;
                  --sw-font-size-sm: 16px;
                  --sw-font-size-lg: 22px;
                  --sw-font-size-xl: 28px;
                  --sw-line-height: 1.85;

                  /* Colors - Warm paper tones */
                  --sw-color-primary: #6b7280;        /* Muted gray-blue */
                  --sw-color-primary-hover: #4b5563;
                  --sw-color-primary-light: #f3f4f6;
                  --sw-color-primary-glow: rgba(107, 114, 128, 0.1);

                  --sw-color-text: #1a1a1a;
                  --sw-color-text-muted: #4a4a4a;
                  --sw-color-text-light: #7a7a7a;
                  --sw-color-bg: #faf8f5;             /* Warm paper */
                  --sw-color-bg-card: #ffffff;
                  --sw-color-bg-elevated: #f5f3f0;
                  --sw-color-border: #e8e4df;
                  --sw-color-border-strong: #d8d4cf;
                  --sw-color-border-focus: var(--sw-color-primary);

                  --sw-color-secondary: #4a4a4a;
                  --sw-color-secondary-hover: #2a2a2a;
                  --sw-color-secondary-foreground: #ffffff;

                  --sw-color-accent: #2563eb;
                  --sw-color-accent-light: #eff6ff;

                  /* Spacing - More generous for reading */
                  --sw-spacing-xs: 0.5rem;
                  --sw-spacing-sm: 0.875rem;
                  --sw-spacing-md: 1.5rem;
                  --sw-spacing-lg: 2.5rem;
                  --sw-spacing-xl: 4rem;
                  --sw-spacing-2xl: 5rem;

                  /* Border Radius - Softer */
                  --sw-radius-sm: 4px;
                  --sw-radius-md: 8px;
                  --sw-radius-lg: 12px;
                  --sw-radius-xl: 20px;

                  /* Shadows - Very subtle */
                  --sw-shadow-sm: none;
                  --sw-shadow-md: 0 1px 3px rgba(0, 0, 0, 0.04);
                  --sw-shadow-lg: 0 2px 6px rgba(0, 0, 0, 0.06);
                  --sw-shadow-xl: 0 4px 12px rgba(0, 0, 0, 0.08);
                  --sw-shadow-inner: none;

                  /* Card styling - No accent, subtle */
                  --sw-card-border-left: none;

                  --sw-term-color: var(--sw-color-accent);
                  --sw-term-bg-hover: var(--sw-color-accent-light);
                }

                /* Document-specific adjustments
                   The 720px cap is a prose reading-width, so it's scoped off of
                   body:not(:has(.sw-app-shell)) -- an app_shell page manages its
                   own width via its sidebar+main grid, and capping the whole body
                   at 720px squeezes that grid down to a sliver (e.g. two 1fr chart
                   columns collapsing to ~180px each instead of filling the content
                   pane), well below what a plain document's max-width shouldn't
                   ever apply to. */
                body.sw-theme-document:not(:has(.sw-app-shell)) {
                  max-width: 720px;
                }

                /* #app-container re-applies --sw-spacing-xl as its own padding on top
                   of body's --sw-spacing-xl padding (see the shared `body` and
                   `#app-container` rules above). Document theme's --sw-spacing-xl
                   (4rem) is the largest of any theme, so that doubling costs 128px
                   of width off the top -- fine for prose, but enough to squeeze an
                   app_shell's sidebar+main grid down until 2-column chart layouts
                   lose bars/points to an undersized canvas. Halve the inner layer
                   only in the app_shell case; the outer body padding alone still
                   gives comfortable page margins. */
                body.sw-theme-document:has(.sw-app-shell) #app-container {
                  padding: calc(var(--sw-spacing-xl) / 2);
                }

                body.sw-theme-document p {
                  margin-bottom: 1.5em;
                }

                body.sw-theme-document h1, body.sw-theme-document h2,
                body.sw-theme-document h3, body.sw-theme-document h4 {
                  font-family: var(--sw-font-display);
                }

                body.sw-theme-document h2 {
                  margin-top: 3rem;
                }

                body.sw-theme-document .card {
                  border-left: none;
                  border: 1px solid var(--sw-color-border);
                }

                /* ===========================================
                   Theme: Doc (Anthropic-artifact editorial)
                   Compact editorial — Charter serif headers, system sans body
                   =========================================== */
                body.sw-theme-doc {
                  --sw-font-display: Charter, 'Bitstream Charter', 'Sitka Text', Cambria, Georgia, serif;
                  --sw-font-body: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif;
                  --sw-font-family: var(--sw-font-body);
                  --sw-font-mono: 'SFMono-Regular', 'SF Mono', 'Cascadia Code', Menlo, 'Courier New', monospace;
                  --sw-font-size-base: 15px;
                  --sw-font-size-sm: 13px;
                  --sw-font-size-lg: 17px;
                  --sw-font-size-xl: 22px;
                  --sw-line-height: 1.65;

                  /* Colors — artifact-exact palette */
                  --sw-color-primary: #1E4ED8;
                  --sw-color-primary-hover: #1a3fb0;
                  --sw-color-primary-light: #EEF2FF;
                  --sw-color-primary-glow: rgba(30, 78, 216, 0.1);

                  --sw-color-text: #181714;
                  --sw-color-text-muted: #6B6860;
                  --sw-color-text-light: #A09D96;
                  --sw-color-bg: #F5F4EF;
                  --sw-color-bg-card: #EDECE6;
                  --sw-color-bg-elevated: #ECEAE3;
                  --sw-color-border: #E0DED6;
                  --sw-color-border-strong: #C8C6BE;
                  --sw-color-border-focus: var(--sw-color-primary);

                  --sw-color-secondary: #6B6860;
                  --sw-color-secondary-hover: #4a4845;
                  --sw-color-secondary-foreground: #ffffff;

                  --sw-color-accent: #1E4ED8;
                  --sw-color-accent-light: #EEF2FF;

                  /* Spacing — compact editorial */
                  --sw-spacing-xs: 0.25rem;
                  --sw-spacing-sm: 0.5rem;
                  --sw-spacing-md: 1rem;
                  --sw-spacing-lg: 1.5rem;
                  --sw-spacing-xl: 2rem;
                  --sw-spacing-2xl: 3.25rem;

                  /* Border Radius — minimal */
                  --sw-radius-sm: 2px;
                  --sw-radius-md: 4px;
                  --sw-radius-lg: 6px;
                  --sw-radius-xl: 8px;

                  /* Shadows — near-flat */
                  --sw-shadow-sm: none;
                  --sw-shadow-md: 0 1px 2px rgba(0, 0, 0, 0.04);
                  --sw-shadow-lg: 0 2px 4px rgba(0, 0, 0, 0.06);
                  --sw-shadow-xl: 0 4px 8px rgba(0, 0, 0, 0.08);
                  --sw-shadow-inner: none;

                  /* Card — no accent left border */
                  --sw-card-border-left: none;

                  /* Shared-component density tokens — let render_table/callout_css read
                     theme-owned values via normal CSS cascade instead of !important */
                  --sw-table-header-padding: 8px 12px;
                  --sw-table-cell-padding: 9px 12px;
                  --sw-callout-padding: 14px 16px;

                  --sw-term-color: var(--sw-color-accent);
                  --sw-term-bg-hover: var(--sw-color-accent-light);
                }

                /* Doc theme — dark mode overrides (data-sw-theme="dark" lives on <html>).
                   Colors only — type/spacing/radius/shadow cascade from the light block above. */
                html[data-sw-theme="dark"] body.sw-theme-doc {
                  --sw-color-primary: #6699FF;
                  --sw-color-primary-hover: #8AB0FF;
                  --sw-color-primary-light: #1B2740;
                  --sw-color-primary-glow: rgba(102, 153, 255, 0.15);

                  --sw-color-text: #ECEAE3;
                  --sw-color-text-muted: #A8A399;
                  --sw-color-text-light: #716C61;
                  --sw-color-bg: #1A1714;
                  --sw-color-bg-card: #232019;
                  --sw-color-bg-elevated: #2A251F;
                  --sw-color-border: #3A352D;
                  --sw-color-border-strong: #4A453B;
                  --sw-color-border-focus: var(--sw-color-primary);

                  --sw-color-secondary: #A8A399;
                  --sw-color-secondary-hover: #C5C0B5;
                  --sw-color-secondary-foreground: #1A1714;

                  --sw-color-accent: #6699FF;
                  --sw-color-accent-light: #1B2740;
                }

                /* Doc theme — serif section headers at artifact-exact size */
                body.sw-theme-doc h2 {
                  font-family: var(--sw-font-display);
                  font-size: 1.45rem;
                }

                /* Doc apps render flat component lists (no <section> wrappers) —
                   the section boundary marker is .sw-doc-section-header, so the
                   artifact's section { margin-bottom: 52px } becomes margin-top here.
                   Adjacent-sibling margin collapsing yields max(prev, 52px) = 52px,
                   same effective gap as the artifact. */
                body.sw-theme-doc .sw-doc-section-header {
                  margin-top: 52px;
                }

                /* render_table/callout_css now read --sw-table-header-padding /
                   --sw-table-cell-padding / --sw-callout-padding (set in the doc theme
                   variable block above) via normal CSS custom-property cascade — no
                   !important needed since it's no longer a specificity fight, just a
                   token lookup. Remaining rules here are cosmetic details the token
                   system doesn't cover yet. */
                body.sw-theme-doc .sw-table {
                  font-size: .875rem;
                }
                body.sw-theme-doc .sw-table th {
                  font-size: 11px;
                }
                body.sw-theme-doc .sw-table td:first-child {
                  white-space: nowrap;
                }

                /* ===========================================
                   Base Styles
                   =========================================== */
                *, *::before, *::after {
                  box-sizing: border-box;
                }

                /* Allow overflow with scrollbar when needed */
                html {
                  overflow-x: auto;
                }

                body {
                  font-family: var(--sw-font-body);
                  font-size: var(--sw-font-size-base);
                  line-height: var(--sw-line-height);
                  color: var(--sw-color-text);
                  margin: 0;
                  padding: 0;
                  background: var(--sw-color-bg);
                  -webkit-font-smoothing: antialiased;
                  -moz-osx-font-smoothing: grayscale;
                  min-height: 100vh;
                }

                /* Layout modes */
                body[class*="sw-layout-"] { margin: 0 auto; padding: var(--sw-spacing-xl); }
                body.sw-layout-default { max-width: 900px; }
                body.sw-layout-wide { max-width: 1100px; }
                body.sw-layout-full { max-width: 1400px; }
                body.sw-layout-fluid { max-width: 100%; padding-left: var(--sw-spacing-xl); padding-right: var(--sw-spacing-xl); }

                /* chrome: false gets a minimal padding baseline so content isn't
                   glued to the viewport edge -- still just one low-specificity
                   class rule, easily overridden to zero by an app's own CSS
                   (FAC-9u2). */
                body.sw-chromeless { padding: var(--sw-spacing-lg); }

                /* Page title outside container */
                body > h1 {
                  font-size: 2.5rem;
                  font-weight: 700;
                  color: var(--sw-color-text);
                  letter-spacing: -0.02em;
                  margin: 0 0 var(--sw-spacing-lg) 0;
                }

                body[class*="sw-layout-"] > #app-container {
                  background: var(--sw-color-bg-card);
                  padding: var(--sw-spacing-xl);
                  border-radius: var(--sw-radius-lg);
                  box-shadow: var(--sw-shadow-md);
                  border: 1px solid var(--sw-color-border);
                  overflow-x: auto;
                  word-wrap: break-word;
                  overflow-wrap: break-word;
                }

                /* ===========================================
                   Typography - Clean, Scannable Hierarchy
                   =========================================== */
                h1, h2, h3, h4, h5, h6 {
                  font-family: var(--sw-font-body);
                  font-weight: 600;
                  letter-spacing: -0.01em;
                  color: var(--sw-color-text);
                }

                h1 {
                  font-size: 2.25rem;
                  font-weight: 700;
                  margin-top: 0;
                  margin-bottom: var(--sw-spacing-lg);
                }

                h2 {
                  font-size: 1.625rem;
                  font-weight: 600;
                  margin-top: var(--sw-spacing-xl);
                  margin-bottom: var(--sw-spacing-md);
                  padding-bottom: var(--sw-spacing-sm);
                  border-bottom: 2px solid var(--sw-color-border);
                }

                h3 {
                  font-size: 1.25rem;
                  font-weight: 600;
                  margin-top: var(--sw-spacing-lg);
                  margin-bottom: var(--sw-spacing-sm);
                }

                h4 {
                  font-size: 1.2rem;
                  font-weight: 700;
                  margin-top: var(--sw-spacing-md);
                  margin-bottom: var(--sw-spacing-xs);
                }

                h5 {
                  font-size: 1.1rem;
                  font-weight: 700;
                  margin-top: var(--sw-spacing-md);
                  margin-bottom: var(--sw-spacing-xs);
                }

                h6 {
                  font-size: 1rem;
                  font-weight: 700;
                  text-transform: uppercase;
                  letter-spacing: 0.05em;
                  color: var(--sw-color-text-muted);
                  margin-top: var(--sw-spacing-md);
                  margin-bottom: var(--sw-spacing-xs);
                }

                p {
                  color: var(--sw-color-text-muted);
                  line-height: var(--sw-line-height);
                  margin: 0 0 var(--sw-spacing-md) 0;
                  word-wrap: break-word;
                  overflow-wrap: break-word;
                }

                ul, ol {
                  margin: 0 0 var(--sw-spacing-md) 1.25rem;
                  color: var(--sw-color-text-muted);
                  line-height: var(--sw-line-height);
                }

                li {
                  margin-bottom: 0.3125rem;
                }

                li:last-child {
                  margin-bottom: 0;
                }

                /* Handle long URLs and strings */
                a, code, pre {
                  word-wrap: break-word;
                  overflow-wrap: break-word;
                  word-break: break-word;
                }

                /* Inline code -- monospace fonts render optically larger than body
                   text at the same declared size, so scale down to match */
                code {
                  font-size: .825em;
                  background: var(--sw-surface-elevated, #ECEAE3);
                  padding: 1px 5px;
                  border-radius: 3px;
                }

                pre code, .sw-code-block__pre code {
                  font-size: inherit;
                  background: none;
                  padding: 0;
                }

                /* Strong text */
                strong, b {
                  font-weight: 600;
                  color: var(--sw-color-text);
                }

                p + input, p + select, p + textarea {
                  margin-top: var(--sw-spacing-xs);
                }

                p:has(+ input), p:has(+ select), p:has(+ textarea) {
                  margin-bottom: var(--sw-spacing-xs);
                  font-weight: 500;
                  color: var(--sw-color-text);
                }

                /* ===========================================
                   Form Controls - Refined Inputs
                   =========================================== */
                input[type="text"], input[type="email"], select, textarea {
                  padding: var(--sw-spacing-md);
                  margin: var(--sw-spacing-sm) 0 var(--sw-spacing-md) 0;
                  border: 1px solid var(--input);
                  border-radius: var(--radius);
                  font-size: var(--sw-font-size-base);
                  font-family: var(--sw-font-body);
                  width: 100%;
                  background: var(--background);
                  color: var(--foreground);
                  box-shadow: var(--sw-shadow-inner);
                  transition:
                    border-color var(--sw-transition),
                    box-shadow var(--sw-transition),
                    background-color var(--sw-transition);
                }

                input[type="text"]:hover, input[type="email"]:hover, select:hover, textarea:hover {
                  border-color: var(--sw-color-border-strong);
                }

                input[type="text"]:focus, input[type="email"]:focus, select:focus, textarea:focus {
                  outline: none;
                  border-color: var(--ring);
                  box-shadow:
                    0 0 0 2px var(--background),
                    0 0 0 4px var(--ring);
                }

                input[type="text"]::placeholder, input[type="email"]::placeholder, textarea::placeholder {
                  color: var(--muted-foreground);
                  font-style: italic;
                }

                textarea {
                  resize: vertical;
                  min-height: 100px;
                  line-height: 1.5;
                }

                /* Visible label wrapper for text_field/text_area/select/chip_group
                   (FAC-9u2 -- these silently dropped label: before). */
                .sw-field {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-xs);
                }

                .sw-field__label {
                  font-size: var(--sw-font-size-sm);
                  font-weight: 600;
                  color: var(--sw-color-text);
                }

                .sw-field input, .sw-field select, .sw-field textarea, .sw-field .sw-chip-group {
                  margin-top: 0;
                }

                /* ===========================================
                   App Header - Full-width header bar
                   =========================================== */
                .sw-app-header {
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                  padding: var(--sw-spacing-md) var(--sw-spacing-lg);
                  margin: calc(-1 * var(--sw-spacing-xl)) calc(-1 * var(--sw-spacing-xl)) var(--sw-spacing-lg) calc(-1 * var(--sw-spacing-xl));
                  font-family: var(--sw-font-body);
                }

                .sw-app-header-brand {
                  display: flex;
                  align-items: baseline;
                  gap: var(--sw-spacing-sm);
                }

                .sw-app-header-title {
                  font-size: var(--sw-font-size-lg);
                  font-weight: 600;
                }

                .sw-app-header-subtitle {
                  font-size: var(--sw-font-size-sm);
                  opacity: 0.7;
                }

                .sw-app-header-actions {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-sm);
                }

                /* Header variants */
                .sw-app-header-dark {
                  background: var(--card);
                  color: var(--card-foreground);
                }

                .sw-app-header-dark .sw-app-header-subtitle {
                  color: var(--muted-foreground);
                }

                .sw-app-header-dark button,
                .sw-app-header-dark .btn {
                  background: transparent;
                  border: 1px solid rgba(255, 255, 255, 0.3);
                  color: #ffffff;
                  margin: 0;
                }

                .sw-app-header-dark button:hover,
                .sw-app-header-dark .btn:hover {
                  background: rgba(255, 255, 255, 0.1);
                  border-color: rgba(255, 255, 255, 0.5);
                }

                .sw-app-header-light {
                  background: var(--sw-color-bg-elevated);
                  color: var(--sw-color-text);
                  border-bottom: 1px solid var(--sw-color-border);
                }

                .sw-app-header-primary {
                  background: var(--sw-color-primary);
                  color: #ffffff;
                }

                .sw-app-header-primary button,
                .sw-app-header-primary .btn {
                  background: rgba(255, 255, 255, 0.2);
                  border: none;
                  color: #ffffff;
                  margin: 0;
                }

                .sw-app-header-primary button:hover,
                .sw-app-header-primary .btn:hover {
                  background: rgba(255, 255, 255, 0.3);
                }

                /* ===========================================
                   Buttons - Bold, Confident
                   =========================================== */
                button, .btn {
                  display: inline-flex;
                  align-items: center;
                  justify-content: center;
                  gap: var(--sw-spacing-xs);
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  margin: var(--sw-spacing-sm) var(--sw-spacing-sm) var(--sw-spacing-sm) 0;
                  border: none;
                  border-radius: var(--radius);
                  font-family: var(--sw-font-body);
                  font-size: var(--sw-font-size-sm);
                  font-weight: 600;
                  letter-spacing: 0.01em;
                  cursor: pointer;
                  white-space: nowrap;
                  transition:
                    background var(--sw-transition),
                    color var(--sw-transition),
                    transform var(--sw-transition-fast),
                    box-shadow var(--sw-transition);
                  position: relative;
                  overflow: hidden;
                }

                button:hover {
                  transform: translateY(-1px);
                }

                button:active {
                  transform: translateY(0) scale(0.98);
                }

                /* Primary */
                .btn-primary {
                  background: var(--primary);
                  color: var(--primary-foreground);
                  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
                }

                .btn-primary:hover {
                  opacity: 0.9;
                }

                /* Secondary */
                .btn-secondary {
                  background: var(--secondary);
                  color: var(--secondary-foreground);
                  border: 1px solid var(--border);
                }

                .btn-secondary:hover {
                  opacity: 0.85;
                }

                /* Destructive */
                .btn-destructive {
                  background: var(--destructive);
                  color: var(--destructive-foreground);
                }

                .btn-destructive:hover {
                  opacity: 0.9;
                }

                /* Outline */
                .btn-outline {
                  background: transparent;
                  color: var(--foreground);
                  border: 1px solid var(--border);
                }

                .btn-outline:hover {
                  background: var(--accent);
                  color: var(--accent-foreground);
                }

                /* Ghost */
                .btn-ghost {
                  background: transparent;
                  color: var(--foreground);
                }

                .btn-ghost:hover {
                  background: var(--accent);
                  color: var(--accent-foreground);
                }

                /* Quiet -- minimal chrome, for inline row/table actions (rivet grammar) */
                .btn-quiet {
                  background: transparent;
                  box-shadow: none;
                  color: var(--foreground);
                  font-weight: 500;
                }

                .btn-quiet:hover {
                  background: var(--accent);
                  color: var(--accent-foreground);
                }

                /* Size: sm -- compact, for inline table actions */
                .btn-sm {
                  padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                  font-size: var(--sw-font-size-sm);
                  font-weight: 500;
                }

                /* Table action cells: inline row of buttons instead of stacked (FAC-9u2) */
                .sw-table__actions {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-xs);
                  flex-wrap: wrap;
                }

                /* Button focus states */
                button:focus-visible {
                  outline: none;
                  box-shadow:
                    0 0 0 2px var(--background),
                    0 0 0 4px var(--ring);
                }

                /* Button loading state (HTMX hx-disabled-elt or manual disable) */
                button:disabled, button.htmx-request {
                  opacity: 0.65;
                  cursor: not-allowed;
                  transform: none;
                  pointer-events: none;
                }

                button:disabled::after, button.htmx-request:not(.sw-no-loading-indicator)::after {
                  content: "";
                  position: absolute;
                  top: 50%;
                  left: 50%;
                  width: 0.85em;
                  height: 0.85em;
                  margin-top: -0.425em;
                  margin-left: -0.425em;
                  border: 2px solid currentColor;
                  border-top-color: transparent;
                  border-radius: 50%;
                  opacity: 0;
                  animation:
                    sw-btn-spinner-appear 0ms 300ms forwards,
                    sw-spin 0.7s 300ms linear infinite;
                }

                @keyframes sw-btn-spinner-appear {
                  to { opacity: 1; }
                }

                /* Swap-target busy treatment during in-flight requests (FAC-P1.5).
                   Delay-in via transition-delay so fast responses never flicker;
                   undimming (class removed) is immediate. */
                #app-container {
                  transition: opacity var(--sw-transition-fast, 120ms) ease-out;
                }

                #app-container.htmx-request {
                  opacity: 0.85;
                  transition-delay: 150ms;
                }

                /* ===========================================
                   Checkbox & Labels
                   =========================================== */
                label {
                  display: flex;
                  align-items: center;
                  margin: var(--sw-spacing-md) 0;
                  cursor: pointer;
                  user-select: none;
                  color: var(--sw-color-text);
                }

                input[type="checkbox"] {
                  margin-right: var(--sw-spacing-sm);
                  width: 18px;
                  height: 18px;
                  cursor: pointer;
                  accent-color: var(--sw-color-primary);
                }

                select {
                  cursor: pointer;
                }

                /* ===========================================
                   Radio Group
                   =========================================== */
                .radio-group {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-sm);
                  margin: var(--sw-spacing-sm) 0 var(--sw-spacing-md) 0;
                }

                .radio-option {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-sm);
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  cursor: pointer;
                  transition: background-color var(--sw-transition), border-color var(--sw-transition);
                  margin: 0;
                }

                .radio-option:hover {
                  background-color: var(--sw-color-bg);
                  border-color: var(--sw-color-text-light);
                }

                .radio-option input[type="radio"] {
                  margin: 0;
                  cursor: pointer;
                  accent-color: var(--sw-color-primary);
                }

                .radio-option input[type="radio"]:checked + span {
                  font-weight: 500;
                  color: var(--sw-color-primary);
                }

                /* ===========================================
                   Checkbox Group
                   =========================================== */
                .checkbox-group {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-sm);
                  margin: var(--sw-spacing-sm) 0 var(--sw-spacing-md) 0;
                }

                .checkbox-group-actions {
                  display: flex;
                  gap: var(--sw-spacing-sm);
                  margin-bottom: var(--sw-spacing-sm);
                }

                .checkbox-group-actions .btn-sm {
                  padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                  font-size: var(--sw-font-size-sm);
                }

                .checkbox-item {
                  display: flex;
                  align-items: flex-start;
                  gap: var(--sw-spacing-sm);
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  cursor: pointer;
                  transition: background-color var(--sw-transition), border-color var(--sw-transition);
                  margin: 0;
                }

                .checkbox-item:hover {
                  background-color: var(--sw-color-bg);
                  border-color: var(--sw-color-text-light);
                }

                .checkbox-item input[type="checkbox"] {
                  margin: 0;
                  margin-top: 2px;
                  cursor: pointer;
                  accent-color: var(--sw-color-primary);
                  flex-shrink: 0;
                }

                .checkbox-item input[type="checkbox"]:checked ~ p {
                  color: var(--sw-color-primary);
                }

                /* ===========================================
                   Card - Clean, Elevated
                   =========================================== */
                .card {
                  background: var(--card);
                  color: var(--card-foreground);
                  border: 1px solid var(--border);
                  border-left: var(--sw-card-border-left);
                  border-radius: calc(var(--radius) + 4px);
                  padding: var(--sw-spacing-lg);
                  margin-bottom: var(--sw-spacing-md);
                  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
                  overflow: hidden;
                  word-wrap: break-word;
                  overflow-wrap: break-word;
                  max-width: 100%;
                }

                /* Cards using the header/body sub-component pattern manage their
                   own padding so the header's shaded band can reach the card's
                   edges flush against its rounded corners. */
                .card:has(> .card-header) {
                  padding: 0;
                }

                .card h3 {
                  margin-top: 0;
                  margin-bottom: var(--sw-spacing-sm);
                  color: var(--card-foreground);
                }

                /* Card sub-components */
                .card-header {
                  padding: 1.5rem 1.5rem 0;
                  margin-bottom: 0;
                  border-bottom: none;
                }

                .card-header h1, .card-header h2, .card-header h3,
                .card-header h4, .card-header h5, .card-header h6 {
                  margin: 0;
                }

                .card-header--badged {
                  display: flex;
                  align-items: center;
                  gap: 12px;
                  padding: 14px 18px;
                  background: var(--sw-surface-elevated, #EDECE6);
                  border-bottom: 1px solid var(--sw-border, #E0DED6);
                }

                .card-header__badge {
                  font-family: var(--sw-font-mono, 'SFMono-Regular', 'Cascadia Code', monospace);
                  font-size: 11px;
                  font-weight: 600;
                  color: var(--sw-accent);
                  background: color-mix(in oklch, var(--sw-accent) 12%, transparent);
                  padding: 2px 7px;
                  border-radius: 3px;
                  flex-shrink: 0;
                }

                .card-header__title {
                  font-weight: 600;
                  font-size: .95rem;
                }

                .card-header__meta {
                  font-size: .8rem;
                  color: var(--sw-text-dim);
                  margin-left: auto;
                  white-space: nowrap;
                }

                .card-body {
                  padding: 1.5rem;
                  padding-top: 0;
                  overflow-x: auto;
                }

                .card-body > *:first-child {
                  margin-top: 0;
                }

                .card-body > *:last-child {
                  margin-bottom: 0;
                }

                .card-footer {
                  padding: 0 1.5rem 1.5rem;
                  margin-top: 0;
                  border-top: 1px solid var(--border);
                  display: flex;
                  justify-content: flex-end;
                  gap: var(--sw-spacing-sm);
                }

                .card-footer button {
                  margin: 0;
                }

                /* ===========================================
                   Stack Components (VStack / HStack)
                   =========================================== */
                .sw-vstack {
                  display: flex;
                  flex-direction: column;
                }

                .sw-hstack {
                  display: flex;
                  flex-direction: row;
                  flex-wrap: wrap;
                }

                /* Alignment classes */
                .sw-align-start { align-items: flex-start; }
                .sw-align-center { align-items: center; }
                .sw-align-end { align-items: flex-end; }
                .sw-align-stretch { align-items: stretch; }

                /* Justify classes (for hstack mainly) */
                .sw-justify-start { justify-content: flex-start; }
                .sw-justify-center { justify-content: center; }
                .sw-justify-end { justify-content: flex-end; }
                .sw-justify-between { justify-content: space-between; }

                /* Divider support for stacks */
                .sw-vstack.sw-divider > *:not(:last-child) {
                  border-bottom: 1px solid var(--sw-color-border);
                  padding-bottom: inherit;
                }

                .sw-hstack.sw-divider > *:not(:last-child) {
                  border-right: 1px solid var(--sw-color-border);
                  padding-right: inherit;
                }

                /* ===========================================
                   Grid Component
                   =========================================== */
                .sw-grid {
                  display: grid;
                }

                /* Responsive grid - mobile first */
                @media (max-width: 639px) {
                  .sw-grid[data-cols-sm] { grid-template-columns: repeat(var(--sw-grid-cols-sm, 1), 1fr); }
                }

                @media (min-width: 640px) and (max-width: 1023px) {
                  .sw-grid[data-cols-md] { grid-template-columns: repeat(var(--sw-grid-cols-md, 2), 1fr); }
                }

                @media (min-width: 1024px) {
                  .sw-grid[data-cols-lg] { grid-template-columns: repeat(var(--sw-grid-cols-lg, 3), 1fr); }
                }

                /* ===========================================
                   Tabs Component
                   =========================================== */
                .sw-tabs {
                  margin: var(--sw-spacing-md) 0;
                }

                .sw-tabs-list {
                  display: flex;
                  gap: var(--sw-spacing-xs);
                  border-bottom: 2px solid var(--border);
                  margin-bottom: var(--sw-spacing-md);
                }

                .sw-tab-trigger {
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  border: none;
                  background: transparent;
                  font-family: var(--sw-font-body);
                  font-size: var(--sw-font-size-base);
                  font-weight: 500;
                  color: var(--muted-foreground);
                  cursor: pointer;
                  /* Only transition color on hover, not border/active state - prevents flash during HTMX swaps */
                  transition: color var(--sw-transition);
                  position: relative;
                  margin: 0;
                  margin-bottom: -2px;
                }

                .sw-tab-trigger:hover {
                  color: var(--foreground);
                  transform: none;
                }

                .sw-tab-trigger.sw-tab-active {
                  color: var(--foreground);
                  background: var(--background);
                  border-bottom: 2px solid var(--foreground);
                }

                .sw-tab-panel {
                  padding: var(--sw-spacing-sm) 0;
                }

                /* Tabs Variants */
                .sw-tabs-enclosed .sw-tabs-list {
                  border-bottom: none;
                  gap: 0;
                }

                .sw-tabs-enclosed .sw-tab-trigger {
                  border: 1px solid transparent;
                  border-bottom: none;
                  border-radius: var(--sw-radius-md) var(--sw-radius-md) 0 0;
                  background: var(--sw-color-bg-elevated);
                  margin-bottom: -1px;
                }

                .sw-tabs-enclosed .sw-tab-trigger.sw-tab-active {
                  background: var(--sw-color-bg-card);
                  border-color: var(--sw-color-border);
                  border-bottom-color: var(--sw-color-bg-card);
                }

                .sw-tabs-enclosed .sw-tab-panel {
                  border: 1px solid var(--sw-color-border);
                  border-radius: 0 var(--sw-radius-md) var(--sw-radius-md) var(--sw-radius-md);
                  padding: var(--sw-spacing-md);
                  background: var(--sw-color-bg-card);
                }

                .sw-tabs-soft-rounded .sw-tabs-list {
                  border-bottom: none;
                  background: var(--muted);
                  padding: var(--sw-spacing-xs);
                  border-radius: var(--sw-radius-lg);
                }

                .sw-tabs-soft-rounded .sw-tab-trigger {
                  border-radius: var(--radius);
                  margin-bottom: 0;
                }

                .sw-tabs-soft-rounded .sw-tab-trigger.sw-tab-active {
                  background: var(--background);
                  box-shadow: var(--sw-shadow-sm);
                  border-bottom: none;
                }

                /* ===========================================
                   Breadcrumbs Component
                   =========================================== */
                .sw-breadcrumbs {
                  margin: var(--sw-spacing-sm) 0;
                }

                .sw-breadcrumbs-list {
                  display: flex;
                  align-items: center;
                  flex-wrap: wrap;
                  list-style: none;
                  padding: 0;
                  margin: 0;
                  gap: var(--sw-spacing-xs);
                }

                .sw-breadcrumb-item {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-xs);
                }

                .sw-breadcrumb-separator {
                  color: var(--sw-color-text-light);
                  font-size: var(--sw-font-size-sm);
                }

                .sw-breadcrumb-link {
                  color: var(--sw-color-primary);
                  text-decoration: none;
                  font-size: var(--sw-font-size-sm);
                  transition: color var(--sw-transition);
                }

                .sw-breadcrumb-link:hover {
                  color: var(--sw-color-primary-hover);
                  text-decoration: underline;
                }

                .sw-breadcrumb-current {
                  color: var(--sw-color-text-muted);
                  font-size: var(--sw-font-size-sm);
                }

                /* ===========================================
                   Navbar Component
                   =========================================== */
                .sw-navbar {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-xs);
                  padding: var(--sw-spacing-xs) var(--sw-spacing-md);
                  background: var(--sw-color-bg-elevated);
                  border-bottom: 1px solid var(--border);
                  margin-bottom: var(--sw-spacing-md);
                }

                .sw-navbar-item {
                  padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                  color: var(--sw-color-text-muted);
                  text-decoration: none;
                  border-radius: var(--sw-radius-sm);
                  font-size: var(--sw-font-size-sm);
                  transition: color var(--sw-transition), background var(--sw-transition);
                }

                .sw-navbar-item:hover {
                  color: var(--sw-color-text);
                  background: var(--muted);
                }

                .sw-navbar-item-active {
                  font-weight: 600;
                  color: var(--sw-color-text);
                  cursor: default;
                }

                .sw-navbar-item__close {
                  margin-left: 0.35em;
                  opacity: 0.65;
                  font-weight: 400;
                }

                /* ===========================================
                   Dropdown/Menu Component
                   =========================================== */
                .sw-dropdown {
                  position: relative;
                  display: inline-block;
                }

                .sw-dropdown-trigger {
                  cursor: pointer;
                }

                .sw-dropdown-menu {
                  position: absolute;
                  top: 100%;
                  left: 0;
                  z-index: 100;
                  min-width: 180px;
                  margin-top: var(--sw-spacing-xs);
                  padding: var(--sw-spacing-xs) 0;
                  background: var(--popover);
                  color: var(--popover-foreground);
                  border: 1px solid var(--border);
                  border-radius: var(--radius);
                  box-shadow: var(--sw-shadow-lg);
                }

                .sw-menu-item {
                  display: block;
                  width: 100%;
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  border: none;
                  background: transparent;
                  font-family: var(--sw-font-body);
                  font-size: var(--sw-font-size-sm);
                  font-weight: 400;
                  color: var(--sw-color-text);
                  text-align: left;
                  cursor: pointer;
                  transition: background var(--sw-transition);
                  margin: 0;
                }

                .sw-menu-item:hover {
                  background: var(--accent);
                  color: var(--accent-foreground);
                  transform: none;
                }

                .sw-menu-item-destructive {
                  color: var(--destructive);
                }

                .sw-menu-item-destructive:hover {
                  background: color-mix(in oklch, var(--destructive) 10%, transparent);
                }

                .sw-menu-divider {
                  margin: var(--sw-spacing-xs) 0;
                  border: none;
                  border-top: 1px solid var(--sw-color-border);
                }

                /* Dropdown transitions */
                .sw-transition-enter { transition: all var(--sw-transition); }
                .sw-transition-enter-start { opacity: 0; transform: translateY(-4px); }
                .sw-transition-enter-end { opacity: 1; transform: translateY(0); }
                .sw-transition-leave { transition: all var(--sw-transition-fast); }
                .sw-transition-leave-start { opacity: 1; transform: translateY(0); }
                .sw-transition-leave-end { opacity: 0; transform: translateY(-4px); }

                /* ===========================================
                   Modal Component
                   =========================================== */
                .sw-modal-wrapper {
                  position: relative;
                }

                .sw-modal-backdrop {
                  position: fixed;
                  inset: 0;
                  background: rgba(0, 0, 0, 0.5);
                  z-index: 999;
                }

                .sw-modal {
                  position: fixed;
                  top: 50%;
                  left: 50%;
                  transform: translate(-50%, -50%);
                  z-index: 1000;
                  background: var(--popover);
                  color: var(--popover-foreground);
                  border: 1px solid var(--border);
                  border-radius: var(--sw-radius-lg);
                  box-shadow: var(--sw-shadow-xl);
                  max-height: 90vh;
                  overflow: hidden;
                  display: flex;
                  flex-direction: column;
                }

                /* Modal sizes */
                .sw-modal-sm { width: min(400px, 90vw); }
                .sw-modal-md { width: min(560px, 90vw); }
                .sw-modal-lg { width: min(800px, 90vw); }
                .sw-modal-xl { width: min(1140px, 95vw); }

                .sw-modal-header {
                  display: flex;
                  align-items: center;
                  justify-content: space-between;
                  padding: var(--sw-spacing-md) var(--sw-spacing-lg);
                  border-bottom: 1px solid var(--border);
                  flex-shrink: 0;
                }

                .sw-modal-title {
                  margin: 0;
                  font-size: 1.25rem;
                  font-weight: 600;
                  color: var(--sw-color-text);
                }

                .sw-modal-close {
                  background: transparent;
                  border: none;
                  font-size: 1.5rem;
                  line-height: 1;
                  color: var(--sw-color-text-muted);
                  cursor: pointer;
                  padding: 0;
                  margin: 0;
                  width: 32px;
                  height: 32px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  border-radius: var(--sw-radius-sm);
                  transition: background var(--sw-transition), color var(--sw-transition);
                }

                .sw-modal-close:hover {
                  background: var(--sw-color-bg-elevated);
                  color: var(--sw-color-text);
                  transform: none;
                }

                .sw-modal-close-only {
                  position: absolute;
                  top: var(--sw-spacing-sm);
                  right: var(--sw-spacing-sm);
                }

                .sw-modal-body {
                  padding: var(--sw-spacing-lg);
                  overflow-y: auto;
                  flex: 1;
                }

                .sw-modal-body > *:first-child {
                  margin-top: 0;
                }

                .sw-modal-body > *:last-child {
                  margin-bottom: 0;
                }

                .sw-modal-footer {
                  display: flex;
                  justify-content: flex-end;
                  gap: var(--sw-spacing-sm);
                  padding: var(--sw-spacing-md) var(--sw-spacing-lg);
                  border-top: 1px solid var(--border);
                  background: var(--muted);
                  flex-shrink: 0;
                }

                .sw-modal-footer button {
                  margin: 0;
                }

                /* Modal transitions */
                .sw-transition-fade-enter { transition: opacity var(--sw-transition); }
                .sw-transition-fade-enter-start { opacity: 0; }
                .sw-transition-fade-enter-end { opacity: 1; }
                .sw-transition-fade-leave { transition: opacity var(--sw-transition-fast); }
                .sw-transition-fade-leave-start { opacity: 1; }
                .sw-transition-fade-leave-end { opacity: 0; }

                .sw-transition-modal-enter { transition: all var(--sw-transition); }
                .sw-transition-modal-enter-start { opacity: 0; transform: translate(-50%, -50%) scale(0.95); }
                .sw-transition-modal-enter-end { opacity: 1; transform: translate(-50%, -50%) scale(1); }
                .sw-transition-modal-leave { transition: all var(--sw-transition-fast); }
                .sw-transition-modal-leave-start { opacity: 1; transform: translate(-50%, -50%) scale(1); }
                .sw-transition-modal-leave-end { opacity: 0; transform: translate(-50%, -50%) scale(0.95); }

                /* ===========================================
                   Alert Component
                   =========================================== */
                .sw-alert {
                  display: flex;
                  align-items: flex-start;
                  gap: var(--sw-spacing-sm);
                  padding: var(--sw-spacing-md);
                  margin: var(--sw-spacing-md) 0;
                  border-radius: var(--sw-radius-md);
                  border: 1px solid;
                }

                .sw-alert-icon {
                  flex-shrink: 0;
                  font-size: 1.25rem;
                  line-height: 1;
                }

                .sw-alert-content {
                  flex: 1;
                  min-width: 0;
                }

                .sw-alert-title {
                  display: block;
                  margin-bottom: var(--sw-spacing-xs);
                  font-weight: 600;
                }

                .sw-alert-dismiss {
                  flex-shrink: 0;
                  background: transparent;
                  border: none;
                  font-size: 1.25rem;
                  line-height: 1;
                  cursor: pointer;
                  opacity: 0.6;
                  padding: 0;
                  margin: 0;
                  width: 24px;
                  height: 24px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  border-radius: var(--sw-radius-sm);
                  transition: opacity var(--sw-transition), background var(--sw-transition);
                }

                .sw-alert-dismiss:hover {
                  opacity: 1;
                  background: rgba(0, 0, 0, 0.1);
                  transform: none;
                }

                /* Alert variants */
                .sw-alert-info {
                  background: color-mix(in oklch, var(--info) 10%, transparent);
                  border-color: color-mix(in oklch, var(--info) 30%, transparent);
                  color: var(--info);
                }
                .sw-alert-info .sw-alert-icon { color: var(--info); }

                .sw-alert-success {
                  background: color-mix(in oklch, var(--success) 10%, transparent);
                  border-color: color-mix(in oklch, var(--success) 30%, transparent);
                  color: var(--success);
                }
                .sw-alert-success .sw-alert-icon { color: var(--success); }

                .sw-alert-warning {
                  background: color-mix(in oklch, var(--warning) 10%, transparent);
                  border-color: color-mix(in oklch, var(--warning) 30%, transparent);
                  color: var(--warning);
                }
                .sw-alert-warning .sw-alert-icon { color: var(--warning); }

                .sw-alert-error {
                  background: color-mix(in oklch, var(--destructive) 10%, transparent);
                  border-color: color-mix(in oklch, var(--destructive) 30%, transparent);
                  color: var(--destructive);
                }
                .sw-alert-error .sw-alert-icon { color: var(--destructive); }

                /* ===========================================
                   Toast Component (Multi-toast Stack)
                   =========================================== */
                .sw-toast-container {
                  position: fixed;
                  z-index: 1100;
                  pointer-events: none;
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-sm);
                  max-height: 100vh;
                  overflow: hidden;
                }

                .sw-toast-container > * {
                  pointer-events: auto;
                }

                .sw-toast-top-right { top: var(--sw-spacing-lg); right: var(--sw-spacing-lg); }
                .sw-toast-top-left { top: var(--sw-spacing-lg); left: var(--sw-spacing-lg); }
                .sw-toast-bottom-right { bottom: var(--sw-spacing-lg); right: var(--sw-spacing-lg); flex-direction: column-reverse; }
                .sw-toast-bottom-left { bottom: var(--sw-spacing-lg); left: var(--sw-spacing-lg); flex-direction: column-reverse; }

                .sw-toast {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-sm);
                  min-width: 280px;
                  max-width: 420px;
                  padding: var(--sw-spacing-md);
                  background: var(--card);
                  color: var(--card-foreground);
                  border-radius: var(--radius);
                  box-shadow: var(--sw-shadow-xl);
                  border: 1px solid var(--border);
                }

                .sw-toast-icon {
                  flex-shrink: 0;
                  font-size: 1.25rem;
                  line-height: 1;
                }

                .sw-toast-message {
                  flex: 1;
                  min-width: 0;
                  font-size: var(--sw-font-size-sm);
                }

                .sw-toast-dismiss {
                  flex-shrink: 0;
                  background: transparent;
                  border: none;
                  font-size: 1rem;
                  line-height: 1;
                  cursor: pointer;
                  opacity: 0.5;
                  padding: 0;
                  margin: 0;
                  width: 20px;
                  height: 20px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  border-radius: var(--sw-radius-sm);
                  transition: opacity var(--sw-transition);
                }

                .sw-toast-dismiss:hover {
                  opacity: 1;
                  transform: none;
                }

                /* Toast variants */
                .sw-toast-info .sw-toast-icon { color: var(--info); }
                .sw-toast-success .sw-toast-icon { color: var(--success); }
                .sw-toast-warning .sw-toast-icon { color: var(--warning); }
                .sw-toast-error .sw-toast-icon { color: var(--destructive); }

                /* Toast transitions */
                .sw-transition-toast-enter { transition: all var(--sw-transition); }
                .sw-transition-toast-enter-start { opacity: 0; transform: translateX(100%); }
                .sw-transition-toast-enter-end { opacity: 1; transform: translateX(0); }
                .sw-transition-toast-leave { transition: all var(--sw-transition); }
                .sw-transition-toast-leave-start { opacity: 1; transform: translateX(0); }
                .sw-transition-toast-leave-end { opacity: 0; transform: translateX(100%); }

                /* ===========================================
                   Progress Bar Component
                   =========================================== */
                .sw-progress {
                  position: relative;
                  height: 8px;
                  background: var(--muted);
                  border-radius: var(--sw-radius-sm);
                  overflow: hidden;
                  margin: var(--sw-spacing-sm) 0;
                }

                .sw-progress-bar {
                  height: 100%;
                  background: var(--primary);
                  border-radius: var(--sw-radius-sm);
                  transition: width 0.3s ease;
                }

                .sw-progress-label {
                  position: absolute;
                  right: var(--sw-spacing-xs);
                  top: 50%;
                  transform: translateY(-50%);
                  font-size: 10px;
                  font-weight: 600;
                  color: var(--sw-color-text);
                  text-shadow: 0 0 2px var(--sw-color-bg-card);
                }

                /* Progress variants */
                .sw-progress-success .sw-progress-bar { background: var(--success); }
                .sw-progress-warning .sw-progress-bar { background: var(--warning); }
                .sw-progress-error .sw-progress-bar { background: var(--destructive); }

                /* Animated progress */
                .sw-progress-animated .sw-progress-bar {
                  background-image: linear-gradient(
                    45deg,
                    rgba(255, 255, 255, 0.15) 25%,
                    transparent 25%,
                    transparent 50%,
                    rgba(255, 255, 255, 0.15) 50%,
                    rgba(255, 255, 255, 0.15) 75%,
                    transparent 75%,
                    transparent
                  );
                  background-size: 1rem 1rem;
                  animation: sw-progress-stripes 1s linear infinite;
                }

                @keyframes sw-progress-stripes {
                  0% { background-position: 1rem 0; }
                  100% { background-position: 0 0; }
                }

                /* ===========================================
                   Spinner Component
                   =========================================== */
                .sw-spinner-container {
                  display: inline-flex;
                  align-items: center;
                  gap: var(--sw-spacing-sm);
                }

                .sw-spinner {
                  border: 2px solid var(--sw-color-border);
                  border-top-color: var(--sw-color-primary);
                  border-radius: 50%;
                  animation: sw-spin 0.8s linear infinite;
                }

                .sw-spinner-sm { width: 16px; height: 16px; }
                .sw-spinner-md { width: 24px; height: 24px; }
                .sw-spinner-lg { width: 40px; height: 40px; border-width: 3px; }

                .sw-spinner-label {
                  font-size: var(--sw-font-size-sm);
                  color: var(--sw-color-text-muted);
                }

                @keyframes sw-spin {
                  to { transform: rotate(360deg); }
                }

                /* ===========================================
                   Theme Switcher Component
                   =========================================== */
                .sw-theme-switcher {
                  display: inline-flex;
                  align-items: center;
                  gap: var(--sw-spacing-sm);
                }

                .sw-theme-switcher-fixed {
                  position: fixed;
                  top: var(--sw-spacing-md);
                  right: var(--sw-spacing-md);
                  z-index: 1000;
                }

                .sw-theme-switcher-label {
                  font-size: var(--sw-font-size-sm);
                  color: var(--sw-color-text-muted);
                  font-weight: 500;
                }

                .sw-theme-switcher-dropdown {
                  position: relative;
                }

                .sw-theme-switcher-trigger {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-xs);
                  padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                  background: var(--sw-color-bg-card);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  font-size: var(--sw-font-size-sm);
                  color: var(--sw-color-text);
                  cursor: pointer;
                  transition: border-color var(--sw-transition), box-shadow var(--sw-transition);
                }

                .sw-theme-switcher-trigger:hover {
                  border-color: var(--sw-color-border-strong);
                  transform: none;
                }

                .sw-theme-switcher-trigger:focus {
                  outline: none;
                  border-color: var(--sw-color-primary);
                  box-shadow: 0 0 0 2px var(--sw-color-primary-glow);
                }

                .sw-theme-switcher-arrow {
                  font-size: 10px;
                  color: var(--sw-color-text-muted);
                }

                .sw-theme-switcher-menu {
                  position: absolute;
                  top: 100%;
                  right: 0;
                  margin-top: var(--sw-spacing-xs);
                  min-width: 180px;
                  background: var(--sw-color-bg-card);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  box-shadow: var(--sw-shadow-lg);
                  overflow: hidden;
                  z-index: 1001;
                }

                .sw-theme-switcher-option {
                  display: flex;
                  flex-direction: column;
                  align-items: flex-start;
                  width: 100%;
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  background: transparent;
                  border: none;
                  text-align: left;
                  cursor: pointer;
                  transition: background var(--sw-transition-fast);
                }

                .sw-theme-switcher-option:hover {
                  background: var(--sw-color-bg-elevated);
                  transform: none;
                }

                .sw-theme-switcher-option-label {
                  font-size: var(--sw-font-size-sm);
                  font-weight: 500;
                  color: var(--sw-color-text);
                }

                .sw-theme-switcher-option-desc {
                  font-size: 12px;
                  color: var(--sw-color-text-muted);
                }

                /* ===========================================
                   Lesson Text & Terms (Educational Content)
                   =========================================== */
                .lesson-text {
                  position: relative;
                  line-height: 1.8;
                  font-size: var(--sw-font-size-lg);
                  color: var(--sw-color-text);
                }

                .sw-term, .term {
                  text-decoration: underline;
                  text-decoration-style: dotted;
                  text-decoration-color: var(--sw-term-color);
                  text-underline-offset: 3px;
                  cursor: help;
                  color: var(--sw-term-color);
                  font-weight: 500;
                  padding: 0 2px;
                  border-radius: var(--sw-radius-sm);
                  transition: background-color var(--sw-transition), color var(--sw-transition);
                }

                .sw-term:hover, .sw-term:focus,
                .term:hover, .term:focus {
                  background-color: var(--sw-term-bg-hover);
                  outline: none;
                }

                /* ===========================================
                   Tooltip
                   =========================================== */
                .sw-tooltip, .tooltip {
                  position: fixed;
                  transform: translateX(-50%) translateY(-100%);
                  background: var(--sw-tooltip-bg);
                  color: var(--sw-tooltip-text);
                  padding: var(--sw-spacing-md);
                  border-radius: var(--sw-radius-md);
                  font-size: var(--sw-font-size-sm);
                  max-width: 350px;
                  box-shadow: var(--sw-shadow-lg);
                  z-index: 1000;
                  cursor: pointer;
                  white-space: normal;
                  word-wrap: break-word;
                }

                .sw-tooltip::after, .tooltip::after {
                  content: '';
                  position: absolute;
                  top: 100%;
                  left: 50%;
                  transform: translateX(-50%);
                  border: 8px solid transparent;
                  border-top-color: var(--sw-tooltip-bg);
                }

                .tooltip-content {
                  line-height: 1.5;
                }

                .tooltip-hint {
                  font-size: 12px;
                  color: #94a3b8;
                  margin-top: var(--sw-spacing-sm);
                  font-style: italic;
                }

                /* ===========================================
                   Collapsible - Refined Accordion
                   =========================================== */
                .collapsible {
                  margin: var(--sw-spacing-md) 0;
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-lg);
                  overflow: hidden;
                  transition: box-shadow var(--sw-transition);
                }

                .collapsible:hover {
                  box-shadow: var(--sw-shadow-sm);
                }

                .collapsible-header {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-sm);
                  padding: var(--sw-spacing-md) var(--sw-spacing-lg);
                  background: var(--sw-color-bg-elevated);
                  cursor: pointer;
                  transition: background var(--sw-transition);
                  user-select: none;
                }

                .collapsible-header:hover {
                  background: var(--sw-color-border);
                }

                .collapsible-icon {
                  font-size: 10px;
                  color: var(--sw-color-primary);
                  width: 16px;
                  height: 16px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  background: var(--sw-color-primary-light);
                  border-radius: var(--sw-radius-sm);
                  transition: transform var(--sw-transition);
                }

                .collapsible-label {
                  font-family: var(--sw-font-body);
                  font-weight: 600;
                  font-size: var(--sw-font-size-sm);
                  color: var(--sw-color-text);
                  letter-spacing: 0.01em;
                }

                .collapsible-content {
                  padding: var(--sw-spacing-lg);
                  border-top: 1px solid var(--sw-color-border);
                  line-height: var(--sw-line-height);
                  background: var(--sw-color-bg-card);
                }

                /* ===========================================
                   Scroll Box
                   =========================================== */
                .sw-scroll-box {
                  position: relative;
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  padding: var(--sw-spacing-md);
                  background: var(--sw-color-bg-card);
                  transition: box-shadow var(--sw-transition);
                  scrollbar-width: thin;
                  scrollbar-color: var(--sw-color-border-strong) transparent;
                  -webkit-mask-image: linear-gradient(to bottom, black calc(100% - 28px), transparent 100%);
                  mask-image: linear-gradient(to bottom, black calc(100% - 28px), transparent 100%);
                }

                .sw-scroll-box::-webkit-scrollbar { width: 6px; }
                .sw-scroll-box::-webkit-scrollbar-track { background: transparent; }
                .sw-scroll-box::-webkit-scrollbar-thumb {
                  background: var(--sw-color-border-strong);
                  border-radius: var(--sw-radius-sm);
                }
                .sw-scroll-box::-webkit-scrollbar-thumb:hover {
                  background: var(--sw-color-text-muted);
                }

                /* ===========================================
                   Score Table
                   =========================================== */
                .score-table {
                  width: 100%;
                  border-collapse: collapse;
                  margin: 12px 0;
                  font-size: var(--sw-font-size-sm);
                }

                .score-table th,
                .score-table td {
                  padding: 8px 12px;
                  text-align: left;
                  border-bottom: 1px solid var(--sw-color-border);
                }

                .score-table th {
                  background: var(--sw-color-bg);
                  font-weight: 600;
                  color: var(--sw-color-text);
                }

                .score-cell {
                  font-weight: bold;
                  text-align: center !important;
                  border-radius: var(--sw-radius-sm);
                  width: 60px;
                }

                .score-high {
                  background: #d4edda;
                  color: #155724;
                }

                .score-medium {
                  background: #fff3cd;
                  color: #856404;
                }

                .score-low {
                  background: #f8d7da;
                  color: #721c24;
                }

                .score-meaning {
                  color: var(--sw-color-text-muted);
                  font-style: italic;
                }

                /* ===========================================
                   Status Badge

                   "status-badge"/"status-badge-*" are the legacy,
                   unprefixed hooks (still styled for back-compat --
                   deprecated, removed at 1.0; this generic name is the
                   exact collision stream_weaver-lyb was filed for).
                   "sw-status-badge"/"sw-status-badge--*"/"sw-status-badge__*"
                   are the documented stable hooks (stream_weaver-oeo).
                   =========================================== */
                .status-badge, .sw-status-badge {
                  display: inline-flex;
                  align-items: center;
                  gap: var(--sw-spacing-xs);
                  padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                  border-radius: var(--sw-radius-sm);
                  font-size: var(--sw-font-size-sm);
                  margin: var(--sw-spacing-xs) var(--sw-spacing-sm) var(--sw-spacing-xs) 0;
                }

                .status-badge-strong, .sw-status-badge--strong {
                  background-color: rgba(16, 185, 129, 0.1);
                  color: #059669;
                }

                .status-badge-maybe, .sw-status-badge--maybe {
                  background-color: rgba(245, 158, 11, 0.1);
                  color: #d97706;
                }

                .status-badge-skip, .sw-status-badge--skip {
                  background-color: rgba(239, 68, 68, 0.1);
                  color: #dc2626;
                }

                .status-badge-icon, .sw-status-badge__icon {
                  font-size: 1em;
                }

                .status-badge-label, .sw-status-badge__label {
                  font-weight: 600;
                }

                .status-badge-reasoning, .sw-status-badge__reasoning {
                  color: var(--sw-color-text-muted);
                }

                /* ===========================================
                   Tag Buttons
                   =========================================== */
                .tag-buttons {
                  display: flex;
                  flex-wrap: wrap;
                  gap: var(--sw-spacing-xs);
                  margin: var(--sw-spacing-sm) 0;
                }

                .tag-btn {
                  padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-sm);
                  background: var(--sw-color-bg-card);
                  color: var(--sw-color-text);
                  font-size: var(--sw-font-size-sm);
                  cursor: pointer;
                  transition: all var(--sw-transition);
                  margin: 0;
                }

                .tag-btn:hover {
                  border-color: var(--sw-color-primary);
                  background: rgba(59, 130, 246, 0.05);
                }

                .tag-btn-selected {
                  border-color: var(--sw-color-primary);
                  background: var(--sw-color-primary);
                  color: white;
                }

                .tag-buttons-destructive .tag-btn:hover {
                  border-color: #dc2626;
                  background: rgba(220, 38, 38, 0.05);
                }

                .tag-buttons-destructive .tag-btn-selected {
                  border-color: #dc2626;
                  background: #dc2626;
                  color: white;
                }

                /* ===========================================
                   External Link Button
                   =========================================== */
                .external-link-btn {
                  display: inline-flex;
                  align-items: center;
                  gap: var(--sw-spacing-xs);
                  text-decoration: none;
                }

                .external-link-btn::after {
                  content: "↗";
                  font-size: 0.8em;
                }

                /* ===========================================
                   Columns Layout
                   =========================================== */
                .sw-columns {
                  display: flex;
                  gap: var(--sw-spacing-md);
                  align-items: flex-start;
                }

                .sw-column {
                  min-width: 0; /* Prevent flex items from overflowing */
                }

                .sw-column p {
                  margin: var(--sw-spacing-xs) 0;
                  color: var(--sw-color-text);
                }

                /* Monica-style sidebar sections */
                .sw-column.sidebar-facts {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-sm);
                }

                /* "sidebar-section" is the legacy, unprefixed name (still
                   styled for back-compat -- deprecated, removed at 1.0;
                   this generic name is the exact collision stream_weaver-lyb
                   was filed for, e.g. a real app's own ".sidebar-section").
                   "sw-sidebar-section" is the documented stable hook
                   (stream_weaver-oeo) -- apply it via `class: "sw-sidebar-section"`
                   on any div/text call; there is no dedicated component for
                   this utility class. */
                .sidebar-section, .sw-sidebar-section {
                  background: var(--sw-color-bg-card);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  padding: var(--sw-spacing-md);
                }

                .sidebar-section h4, .sw-sidebar-section h4 {
                  margin: 0 0 var(--sw-spacing-xs) 0;
                  color: var(--sw-color-text-muted);
                  font-size: 11px;
                  font-weight: 600;
                  text-transform: uppercase;
                  letter-spacing: 0.05em;
                }

                .sidebar-section p, .sw-sidebar-section p {
                  margin: 0;
                  color: var(--sw-color-text);
                  font-size: var(--sw-font-size-sm);
                }

                .sidebar-section a, .sw-sidebar-section a {
                  color: var(--sw-color-primary);
                  text-decoration: none;
                }

                .sidebar-section a:hover, .sw-sidebar-section a:hover {
                  text-decoration: underline;
                }

                /* Responsive: Stack columns on mobile */
                @media (max-width: 640px) {
                  .sw-columns {
                    flex-direction: column;
                  }

                  .sw-column {
                    flex: none !important;
                    width: 100% !important;
                  }
                }

                /* ===========================================
                   Utilities
                   =========================================== */
                .todo-item {
                  padding: var(--sw-spacing-sm);
                  margin: var(--sw-spacing-xs) 0;
                  background: var(--sw-color-bg);
                  border-radius: var(--sw-radius-sm);
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                }

                /* Alpine.js cloak */
                [x-cloak] {
                  display: none !important;
                }

                /* ===========================================
                   Hover Effects (for div hover_class)
                   =========================================== */
                .sw-hover-highlight {
                  background: var(--sw-color-primary) !important;
                  color: white !important;
                  border-color: var(--sw-color-primary) !important;
                }

                .sw-hover-lift {
                  transform: translateY(-4px);
                  box-shadow: var(--sw-shadow-lg);
                }

                .sw-hover-glow {
                  box-shadow: 0 0 20px var(--sw-color-primary);
                  border-color: var(--sw-color-primary);
                }

                /* Demo/example box for hover demonstrations */
                .hover-demo-box {
                  padding: 2rem;
                  border: 2px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  text-align: center;
                  transition: all 0.2s ease;
                  background: var(--sw-color-bg-card);
                }

                /* Mobile touch support */
                @media (hover: none) {
                  .sw-term, .term {
                    cursor: pointer;
                  }
                }

                /* ===========================================
                   Animations - Subtle, Non-distracting
                   =========================================== */
                @keyframes fadeIn {
                  from { opacity: 0; }
                  to { opacity: 1; }
                }

                /* Gentle page load */
                #app-container {
                  animation: fadeIn 0.3s ease-out;
                }

                /* Reduce motion for accessibility */
                @media (prefers-reduced-motion: reduce) {
                  *, *::before, *::after {
                    animation-duration: 0.01ms !important;
                    animation-iteration-count: 1 !important;
                    transition-duration: 0.01ms !important;
                  }
                }

                /* ===========================================
                   Code Editor (CodeMirror 5)
                   =========================================== */
                .sw-code-editor-wrapper {
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  overflow: hidden;
                }

                .sw-code-editor-wrapper .CodeMirror {
                  height: 100%;
                  font-family: 'Monaco', 'Menlo', 'Consolas', 'Liberation Mono', monospace;
                  font-size: 14px;
                  line-height: 1.5;
                }

                .sw-code-editor-wrapper .CodeMirror-gutters {
                  background: var(--sw-color-bg);
                  border-right: 1px solid var(--sw-color-border);
                }

                .sw-code-editor-wrapper .CodeMirror-linenumber {
                  color: var(--sw-color-text-muted);
                }

                /* ===========================================
                   Embedded Mode - Disable standalone styles
                   Add class="sw-embedded" to body to use minimal styles
                   =========================================== */
                body.sw-embedded {
                  max-width: none;
                  margin: 0;
                  padding: 0;
                  background: transparent;
                }

                body.sw-embedded #app-container {
                  background: transparent;
                  padding: 0;
                  border-radius: 0;
                  box-shadow: none;
                }

                /* ===========================================
                   Dashboard Components (Cabinet Control style)
                   =========================================== */

                /* Status Dot - Colored indicator with optional glow */
                .sw-status-dot {
                  display: inline-block;
                  border-radius: 50%;
                  flex-shrink: 0;
                }

                .sw-status-dot-sm { width: 6px; height: 6px; }
                .sw-status-dot-md { width: 10px; height: 10px; }
                .sw-status-dot-lg { width: 14px; height: 14px; }

                .sw-status-dot-red {
                  background: var(--destructive);
                  box-shadow: 0 0 8px color-mix(in oklch, var(--destructive) 40%, transparent);
                }
                .sw-status-dot-yellow {
                  background: var(--warning);
                  box-shadow: 0 0 8px color-mix(in oklch, var(--warning) 40%, transparent);
                }
                .sw-status-dot-green {
                  background: var(--success);
                  box-shadow: 0 0 8px color-mix(in oklch, var(--success) 40%, transparent);
                }
                .sw-status-dot-gray {
                  background: var(--muted-foreground);
                  opacity: 0.6;
                }

                .sw-status-dot-pulse {
                  animation: sw-pulse 2s ease-in-out infinite;
                }

                @keyframes sw-pulse {
                  0%, 100% { opacity: 1; transform: scale(1); }
                  50% { opacity: 0.7; transform: scale(1.1); }
                }

                /* Badge - Count/label pills */
                .sw-badge {
                  display: inline-flex;
                  align-items: center;
                  justify-content: center;
                  font-family: 'JetBrains Mono', 'Monaco', 'Consolas', monospace;
                  font-weight: 600;
                  border-radius: 10px;
                  white-space: nowrap;
                }

                .sw-badge-sm { font-size: 0.65rem; padding: 0.15rem 0.4rem; }
                .sw-badge-md { font-size: 0.75rem; padding: 0.2rem 0.5rem; }

                .sw-badge-default {
                  background: var(--muted);
                  color: var(--muted-foreground);
                }
                .sw-badge-danger {
                  background: var(--destructive);
                  color: var(--destructive-foreground);
                }
                .sw-badge-warning {
                  background: var(--warning);
                  color: var(--warning-foreground);
                }
                .sw-badge-success {
                  background: var(--success);
                  color: var(--success-foreground);
                }
                .sw-badge-info {
                  background: var(--info);
                  color: var(--info-foreground);
                }

                /* Stat Display - Large number with label */
                .sw-stat {
                  text-align: center;
                }

                .sw-stat-sm .sw-stat-value { font-size: 1.25rem; }
                .sw-stat-md .sw-stat-value { font-size: 1.5rem; }
                .sw-stat-lg .sw-stat-value { font-size: 2rem; }

                .sw-stat-value {
                  font-family: 'JetBrains Mono', 'Monaco', 'Consolas', monospace;
                  font-weight: 600;
                  line-height: 1.2;
                }

                .sw-stat-value-default { color: var(--foreground); }
                .sw-stat-value-blue { color: #58a6ff; }
                .sw-stat-value-purple { color: #a371f7; }
                .sw-stat-value-green { color: #3fb950; }
                .sw-stat-value-red { color: #f85149; }
                .sw-stat-value-yellow { color: #d29922; }

                .sw-stat-label {
                  font-size: 0.65rem;
                  text-transform: uppercase;
                  letter-spacing: 0.05em;
                  color: var(--muted-foreground);
                  margin-top: 0.25rem;
                }

                /* Type Tag - Activity type badges */
                .sw-type-tag {
                  display: inline-block;
                  font-size: 0.65rem;
                  text-transform: uppercase;
                  letter-spacing: 0.05em;
                  padding: 0.2rem 0.5rem;
                  border-radius: 4px;
                  font-weight: 500;
                  white-space: nowrap;
                }

                .sw-type-tag-blue {
                  background: rgba(88, 166, 255, 0.15);
                  color: #58a6ff;
                }
                .sw-type-tag-green {
                  background: rgba(63, 185, 80, 0.15);
                  color: #3fb950;
                }
                .sw-type-tag-red {
                  background: rgba(248, 81, 73, 0.15);
                  color: #f85149;
                }
                .sw-type-tag-purple {
                  background: rgba(163, 113, 247, 0.15);
                  color: #a371f7;
                }
                .sw-type-tag-yellow {
                  background: rgba(210, 153, 34, 0.15);
                  color: #d29922;
                }
                .sw-type-tag-gray {
                  background: rgba(139, 148, 158, 0.15);
                  color: #8b949e;
                }

                /* Pulse Indicator - Animated status with label */
                .sw-pulse-indicator {
                  display: inline-flex;
                  align-items: center;
                  gap: 0.5rem;
                  font-family: 'JetBrains Mono', 'Monaco', 'Consolas', monospace;
                  font-size: 0.8rem;
                  color: var(--muted-foreground);
                }

                .sw-pulse-dot {
                  width: 8px;
                  height: 8px;
                  border-radius: 50%;
                  animation: sw-pulse 2s ease-in-out infinite;
                }

                .sw-pulse-dot-green { background: #3fb950; }
                .sw-pulse-dot-red { background: #f85149; }
                .sw-pulse-dot-yellow { background: #d29922; }
                .sw-pulse-dot-blue { background: #58a6ff; }

                .sw-pulse-label {
                  color: var(--muted-foreground);
                }

                /* Priority Item - Escalation-style with colored border */
                .sw-priority-item {
                  background: var(--sw-color-bg-elevated, #f5f5f5);
                  border-radius: 8px;
                  padding: 1rem;
                  border-left: 3px solid;
                  cursor: pointer;
                  transition: all 0.2s ease;
                }

                .sw-priority-item:hover {
                  transform: translateX(4px);
                }

                .sw-priority-critical { border-left-color: #f85149; }
                .sw-priority-urgent { border-left-color: #d29922; }
                .sw-priority-high { border-left-color: #58a6ff; }
                .sw-priority-normal { border-left-color: #3fb950; }
                .sw-priority-low { border-left-color: #8b949e; }

                .sw-priority-label {
                  font-size: 0.6rem;
                  text-transform: uppercase;
                  letter-spacing: 0.08em;
                  font-weight: 600;
                  margin-bottom: 0.5rem;
                }

                .sw-priority-critical .sw-priority-label { color: #f85149; }
                .sw-priority-urgent .sw-priority-label { color: #d29922; }
                .sw-priority-high .sw-priority-label { color: #58a6ff; }
                .sw-priority-normal .sw-priority-label { color: #3fb950; }
                .sw-priority-low .sw-priority-label { color: #8b949e; }

                .sw-priority-title {
                  font-size: 0.85rem;
                  font-weight: 500;
                  margin: 0 0 0.35rem 0;
                  color: var(--sw-color-text, #111);
                }

                .sw-priority-description {
                  font-size: 0.75rem;
                  color: var(--sw-color-text-muted, #666);
                  line-height: 1.4;
                  margin: 0 0 0.5rem 0;
                }

                .sw-priority-meta {
                  display: flex;
                  align-items: center;
                  justify-content: space-between;
                  font-size: 0.7rem;
                  color: var(--sw-color-text-muted, #888);
                }

                .sw-priority-meta-right {
                  color: #58a6ff;
                  font-weight: 500;
                }

                /* Activity Item - Time + title + summary + type */
                .sw-activity-item {
                  padding: 1rem;
                  display: grid;
                  grid-template-columns: auto 1fr auto;
                  gap: 1rem;
                  align-items: start;
                  border-bottom: 1px solid var(--sw-color-border, #e0e0e0);
                  transition: background 0.15s ease;
                }

                .sw-activity-item:hover {
                  background: var(--sw-color-bg-elevated, #f5f5f5);
                }

                .sw-activity-item:last-child {
                  border-bottom: none;
                }

                .sw-activity-time {
                  font-family: 'JetBrains Mono', 'Monaco', 'Consolas', monospace;
                  font-size: 0.7rem;
                  color: var(--sw-color-text-muted, #888);
                  white-space: nowrap;
                  padding-top: 0.15rem;
                }

                .sw-activity-content {
                  min-width: 0;
                }

                .sw-activity-title {
                  font-size: 0.9rem;
                  font-weight: 500;
                  margin: 0 0 0.25rem 0;
                  color: var(--sw-color-text, #111);
                }

                .sw-activity-summary {
                  font-size: 0.8rem;
                  color: var(--sw-color-text-muted, #666);
                  line-height: 1.4;
                  margin: 0;
                }

                /* ===========================================
                   Timeline Event (Run Viewer style)
                   =========================================== */

                .sw-timeline-event {
                  padding: 6px 10px;
                  border-radius: 4px;
                  cursor: pointer;
                  display: flex;
                  flex-wrap: wrap;
                  align-items: center;
                  gap: 8px;
                  border-left: 3px solid transparent;
                  font-family: ui-monospace, 'SF Mono', Menlo, Consolas, monospace;
                  font-size: 13px;
                }

                .sw-timeline-event:hover {
                  background: var(--sw-color-bg-hover, #2a2a4a);
                }

                .sw-timeline-event__idx {
                  color: #555;
                  width: 24px;
                  text-align: right;
                  flex-shrink: 0;
                }

                .sw-timeline-event__badge {
                  display: inline-block;
                  width: 100px;
                  padding: 1px 6px;
                  border-radius: 3px;
                  text-align: center;
                  font-size: 11px;
                  flex-shrink: 0;
                }

                .sw-timeline-event__ts {
                  color: #666;
                  flex-shrink: 0;
                }

                .sw-timeline-event__label {
                  color: #ccc;
                }

                .sw-timeline-event__detail {
                  width: 100%;
                  padding: 10px 0 6px 36px;
                }

                .sw-timeline-event__field {
                  margin-bottom: 4px;
                }

                .sw-timeline-event__field-key {
                  color: #aaa;
                }

                .sw-timeline-event__field-value pre {
                  margin: 4px 0 4px 12px;
                  padding: 8px;
                  background: #0d0d1a;
                  border-radius: 4px;
                  overflow-x: auto;
                  white-space: pre-wrap;
                }

                /* Type: phase — cyan */
                .sw-timeline-event--phase {
                  border-left-color: #00bcd4;
                }
                .sw-timeline-event--phase .sw-timeline-event__badge {
                  background: #0e3a3f;
                  color: #00bcd4;
                }

                /* Type: snapshot — yellow */
                .sw-timeline-event--snapshot {
                  border-left-color: #ffc107;
                }
                .sw-timeline-event--snapshot .sw-timeline-event__badge {
                  background: #3f3500;
                  color: #ffc107;
                }

                /* Type: intervention — purple */
                .sw-timeline-event--intervention {
                  border-left-color: #ce93d8;
                }
                .sw-timeline-event--intervention .sw-timeline-event__badge {
                  background: #3a1a44;
                  color: #ce93d8;
                }

                /* Type: timeout — red */
                .sw-timeline-event--timeout {
                  border-left-color: #ef5350;
                }
                .sw-timeline-event--timeout .sw-timeline-event__badge {
                  background: #3f0e0e;
                  color: #ef5350;
                }

                /* Type: guard — red */
                .sw-timeline-event--guard {
                  border-left-color: #ef5350;
                }
                .sw-timeline-event--guard .sw-timeline-event__badge {
                  background: #3f0e0e;
                  color: #ef5350;
                }

                /* Type: final — green */
                .sw-timeline-event--final {
                  border-left-color: #66bb6a;
                }
                .sw-timeline-event--final .sw-timeline-event__badge {
                  background: #0e3f12;
                  color: #66bb6a;
                }

                /* ===========================================
                   Layout Components (Cabinet Control style)
                   =========================================== */

                /* App Shell - Two-column layout */
                .sw-app-shell {
                  display: grid;
                  gap: var(--sw-shell-gap, 1.5rem);
                  min-height: 100vh;
                }

                .sw-app-shell-sidebar-right {
                  grid-template-columns: 1fr var(--sw-shell-sidebar-width, 320px);
                }

                .sw-app-shell-sidebar-left {
                  grid-template-columns: var(--sw-shell-sidebar-width, 320px) 1fr;
                }

                .sw-app-shell-sidebar-left .sw-app-shell-sidebar {
                  order: -1;
                }

                .sw-app-shell-main {
                  min-width: 0;
                }

                .sw-app-shell-sidebar {
                  min-width: 0;
                }

                /* Sidebar */
                .sw-sidebar {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-md, 1rem);
                }

                .sw-sidebar-sticky {
                  position: sticky;
                  top: var(--sw-spacing-lg, 1.5rem);
                  max-height: calc(100vh - var(--sw-spacing-xl, 3rem));
                  overflow-y: auto;
                }

                .sw-sidebar-header {
                  display: flex;
                  align-items: center;
                  justify-content: space-between;
                  margin-bottom: var(--sw-spacing-sm, 0.5rem);
                }

                .sw-sidebar-title {
                  font-size: 0.85rem;
                  font-weight: 600;
                  text-transform: uppercase;
                  letter-spacing: 0.05em;
                  color: var(--muted-foreground);
                  margin: 0;
                }

                .sw-sidebar-content {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-sm, 0.5rem);
                }

                /* Main Content */
                .sw-main-content {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-md, 1rem);
                }

                /* Expandable Card */
                .sw-expandable-card {
                  background: var(--sw-color-bg-elevated, #f5f5f5);
                  border: 1px solid var(--sw-color-border, #e0e0e0);
                  border-radius: var(--sw-radius-lg, 10px);
                  overflow: hidden;
                  transition: box-shadow 0.2s ease, transform 0.2s ease;
                }

                .sw-expandable-card:hover {
                  box-shadow: var(--sw-shadow-md, 0 4px 8px rgba(0,0,0,0.1));
                  transform: translateY(-2px);
                }

                .sw-expandable-card-header {
                  display: flex;
                  align-items: center;
                  gap: 0.75rem;
                  padding: 1rem 1.25rem;
                  cursor: pointer;
                  user-select: none;
                }

                .sw-expandable-card-titles {
                  flex: 1;
                  min-width: 0;
                }

                .sw-expandable-card-title {
                  font-size: 1rem;
                  font-weight: 600;
                  margin: 0;
                  color: var(--sw-color-text, #111);
                }

                .sw-expandable-card-subtitle {
                  font-size: 0.8rem;
                  color: var(--sw-color-text-muted, #666);
                  margin: 0.25rem 0 0 0;
                }

                .sw-expandable-card-chevron {
                  font-size: 0.7rem;
                  color: var(--sw-color-text-muted, #888);
                  transition: transform 0.2s ease;
                }

                .sw-expandable-card-body {
                  padding: 0 1.25rem 1.25rem 1.25rem;
                  border-top: 1px solid var(--sw-color-border, #e0e0e0);
                }

                /* Transition classes for Alpine.js */
                .sw-transition-enter {
                  transition: all 0.2s ease-out;
                }
                .sw-transition-enter-start {
                  opacity: 0;
                  transform: translateY(-0.5rem);
                }
                .sw-transition-enter-end {
                  opacity: 1;
                  transform: translateY(0);
                }
                .sw-transition-leave {
                  transition: all 0.15s ease-in;
                }
                .sw-transition-leave-start {
                  opacity: 1;
                }
                .sw-transition-leave-end {
                  opacity: 0;
                }

                /* Responsive: Stack on smaller screens */
                @media (max-width: 900px) {
                  .sw-app-shell {
                    grid-template-columns: 1fr !important;
                  }

                  .sw-app-shell-sidebar {
                    order: 0 !important;
                  }

                  .sw-sidebar-sticky {
                    position: static;
                    max-height: none;
                  }
                }

                /* ===========================================
                   Mobile Responsive
                   =========================================== */

                /* Tablet */
                @media (max-width: 900px) {
                  body {
                    padding: var(--sw-spacing-sm);
                  }

                  h1 { font-size: 1.75rem; }
                  h2 { font-size: 1.35rem; }
                  h3 { font-size: 1.15rem; }
                }

                /* Phone */
                @media (max-width: 640px) {
                  body {
                    padding: var(--sw-spacing-xs);
                  }

                  .card {
                    border-radius: 0;
                    padding: var(--sw-spacing-md);
                  }

                  .sw-scroll-box {
                    padding: var(--sw-spacing-sm);
                  }

                  h1 { font-size: 1.5rem; }
                  h2 { font-size: 1.25rem; }
                  h3 { font-size: 1.1rem; }

                  /* Tabs: horizontal scroll */
                  .sw-tabs-list {
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                    scrollbar-width: none;
                    flex-wrap: nowrap;
                  }
                  .sw-tabs-list::-webkit-scrollbar {
                    display: none;
                  }
                  .sw-tab-trigger {
                    white-space: nowrap;
                    flex-shrink: 0;
                    padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                    font-size: var(--sw-font-size-sm);
                    min-height: 44px;
                  }

                  /* HStacks: tighter gap */
                  .sw-hstack {
                    gap: var(--sw-spacing-xs);
                  }

                  /* Grid: single column override */
                  .sw-grid {
                    grid-template-columns: 1fr !important;
                  }

                  /* Forms: prevent iOS auto-zoom, 44px touch targets */
                  input[type="text"],
                  input[type="email"],
                  select,
                  textarea {
                    font-size: 16px;
                    min-height: 44px;
                  }
                  button, .btn {
                    min-height: 44px;
                  }

                  /* Modals: full-screen on phones */
                  .sw-modal {
                    width: 100vw !important;
                    max-width: 100vw !important;
                    height: 100vh;
                    max-height: 100vh;
                    border-radius: 0;
                    margin: 0;
                  }

                  /* Toasts: full-width at top */
                  .sw-toast-container {
                    left: 0 !important;
                    right: 0 !important;
                    top: 0 !important;
                    bottom: auto !important;
                    width: 100%;
                    padding: var(--sw-spacing-xs);
                  }
                  .sw-toast {
                    border-radius: 0;
                  }

                  /* Tables: horizontal scroll */
                  .score-table {
                    display: block;
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                  }
                }

                /* ===========================================
                   Dark Theme (Cabinet Control style)
                   =========================================== */
                body.sw-theme-dark {
                  --sw-font-display: 'Outfit', 'Source Sans 3', system-ui, sans-serif;
                  --sw-font-body: 'Outfit', 'Source Sans 3', system-ui, sans-serif;
                  --sw-font-family: var(--sw-font-body);
                  --sw-font-mono: 'JetBrains Mono', 'Monaco', 'Consolas', monospace;
                  --sw-font-size-base: 15px;
                  --sw-font-size-sm: 13px;
                  --sw-font-size-lg: 17px;
                  --sw-font-size-xl: 21px;
                  --sw-line-height: 1.5;

                  /* Dark color palette */
                  --sw-color-bg-deep: #0a0e14;
                  --sw-color-bg: #0a0e14;
                  --sw-color-bg-card: #131820;
                  --sw-color-bg-elevated: #1a2029;
                  --sw-color-bg-hover: #242d3a;
                  --sw-color-border: #2a3544;
                  --sw-color-text: #e6edf3;
                  --sw-color-text-muted: #8b949e;
                  --sw-color-text-light: #565d66;

                  /* Accent colors */
                  --sw-color-primary: #58a6ff;
                  --sw-color-primary-hover: #79b8ff;
                  --sw-color-primary-light: rgba(88, 166, 255, 0.1);
                  --sw-color-primary-glow: rgba(88, 166, 255, 0.2);
                  --sw-color-accent: #a371f7;
                  --sw-color-accent-light: rgba(163, 113, 247, 0.1);

                  /* Status colors */
                  --sw-color-status-red: #f85149;
                  --sw-color-status-yellow: #d29922;
                  --sw-color-status-green: #3fb950;

                  /* Secondary */
                  --sw-color-secondary: #8b949e;
                  --sw-color-secondary-hover: #adbac7;
                  --sw-color-secondary-foreground: #0a0e14;

                  /* Spacing */
                  --sw-spacing-xs: 0.375rem;
                  --sw-spacing-sm: 0.5rem;
                  --sw-spacing-md: 0.875rem;
                  --sw-spacing-lg: 1.25rem;
                  --sw-spacing-xl: 1.75rem;
                  --sw-spacing-2xl: 2.5rem;

                  /* Border radius */
                  --sw-radius-sm: 4px;
                  --sw-radius-md: 6px;
                  --sw-radius-lg: 10px;
                  --sw-radius-xl: 12px;

                  /* Shadows */
                  --sw-shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.3);
                  --sw-shadow-md: 0 4px 8px rgba(0, 0, 0, 0.4);
                  --sw-shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.5);
                  --sw-shadow-xl: 0 12px 32px rgba(0, 0, 0, 0.6);
                  --sw-shadow-inner: inset 0 1px 2px rgba(0, 0, 0, 0.2);

                  /* Card styling */
                  --sw-card-border-left: 3px solid var(--sw-color-accent);

                  /* Term highlighting */
                  --sw-term-color: var(--sw-color-primary);
                  --sw-term-bg-hover: var(--sw-color-primary-light);
                }

                /* Dark theme base styles */
                body.sw-theme-dark {
                  background: var(--sw-color-bg-deep);
                  color: var(--sw-color-text);
                }

                body.sw-theme-dark[class*="sw-layout-"] > #app-container {
                  background: var(--sw-color-bg-card);
                  border-color: var(--sw-color-border);
                }

                body.sw-theme-dark h1,
                body.sw-theme-dark h2,
                body.sw-theme-dark h3,
                body.sw-theme-dark h4 {
                  color: var(--sw-color-text);
                }

                body.sw-theme-dark h2 {
                  border-bottom-color: var(--sw-color-border);
                }

                body.sw-theme-dark input[type="text"],
                body.sw-theme-dark input[type="email"],
                body.sw-theme-dark select,
                body.sw-theme-dark textarea {
                  background: var(--sw-color-bg-elevated);
                  border-color: var(--sw-color-border);
                  color: var(--sw-color-text);
                }

                body.sw-theme-dark input[type="text"]:focus,
                body.sw-theme-dark input[type="email"]:focus,
                body.sw-theme-dark select:focus,
                body.sw-theme-dark textarea:focus {
                  background: var(--sw-color-bg-hover);
                  border-color: var(--sw-color-primary);
                }

                body.sw-theme-dark .btn-primary {
                  background: var(--sw-color-primary);
                  color: white;
                }

                body.sw-theme-dark .btn-secondary {
                  background: var(--sw-color-bg-elevated);
                  color: var(--sw-color-text);
                  border-color: var(--sw-color-border);
                }

                /* Dark theme dashboard components */
                body.sw-theme-dark .sw-badge-default {
                  background: var(--sw-color-bg-hover);
                  color: var(--sw-color-text-muted);
                }

                body.sw-theme-dark .sw-priority-item {
                  background: var(--sw-color-bg-elevated);
                }

                body.sw-theme-dark .sw-priority-item:hover {
                  background: var(--sw-color-bg-hover);
                }

                body.sw-theme-dark .sw-activity-item:hover {
                  background: var(--sw-color-bg-hover);
                }

                body.sw-theme-dark .sw-activity-item {
                  border-bottom-color: var(--sw-color-border);
                }

                /* Dark theme layout components */
                body.sw-theme-dark .sw-expandable-card {
                  background: var(--sw-color-bg-elevated);
                  border-color: var(--sw-color-border);
                }

                body.sw-theme-dark .sw-expandable-card:hover {
                  background: var(--sw-color-bg-hover);
                }

                body.sw-theme-dark .sw-expandable-card-body {
                  border-top-color: var(--sw-color-border);
                }

                /* Expandable card highlight (e.g. current timeline slot) */
                .sw-expandable-card--highlight {
                  border-left: 4px solid var(--sw-color-primary, #3b82f6);
                  background: color-mix(in srgb, var(--sw-color-primary, #3b82f6) 5%, var(--sw-color-bg-elevated, #f5f5f5));
                }

                body.sw-theme-dark .sw-expandable-card--highlight {
                  background: color-mix(in srgb, var(--sw-color-primary, #3b82f6) 8%, var(--sw-color-bg-elevated));
                }
        CSS
      end

      private

      # Render all components
      def render_components
        @app.components.each do |component|
          component.render(self, @state)
        end

        # Add submit button for agentic mode
        render_agentic_submit_button if @is_agentic
      end

      # Render the submit button for agentic mode
      def render_agentic_submit_button
        div(style: "margin-top: 30px; padding-top: 20px; border-top: 2px solid #e0e0e0;") do
          p(style: "color: #666; font-size: 14px;") { "Submit this form to return data to the calling agent:" }
          button(
            type: "button",
            class: "btn btn-primary",
            style: "background: #28a745; font-weight: bold;",
            "hx-post" => "/submit",
            "hx-include" => @adapter.input_selector
          ) { "🤖 Submit to Agent" }
        end
      end

      # Generate body classes for layout and theme.
      # Exclusive layouts supply their own body_classes; the sw-layout-* class is omitted.
      def body_classes
        effective_theme = @session_theme || @app.theme
        theme_class = "sw-theme-#{effective_theme}"

        layout_entry = @app.layout_entry
        if layout_entry&.dig(:exclusive)
          extra = layout_entry[:body_classes].join(" ")
          [extra, theme_class].reject(&:empty?).join(" ")
        else
          "sw-layout-#{@app.layout} #{theme_class}"
        end
      end

      # Get the effective theme (session override or app default)
      def effective_theme
        @session_theme || @app.theme
      end

      # Render inline CSS for theme overrides.
      #
      # Scoped to body.sw-theme-<active theme> rather than a bare `body`
      # selector: every built-in theme's own CSS uses that same
      # body.sw-theme-<name> selector (specificity 0-1-1), which always
      # beats a plain `body {}` (0-0-1) regardless of source order. Matching
      # the selector's specificity means the tie is broken by cascade order
      # instead -- this block is emitted in <body>, after the built-in
      # theme's own block in <head>, so it wins (stream_weaver-ckz; same
      # technique as the `html.dark body` dark-mode override above).
      def render_theme_overrides
        warn_unknown_theme_override_tokens
        css_vars = @app.theme_overrides.map do |key, value|
          css_var = key.to_s.tr('_', '-')
          # Add sw- prefix if not present
          css_var = "sw-#{css_var}" unless css_var.start_with?('sw-')
          "--#{css_var}: #{value};"
        end.join("\n  ")

        style do
          raw(safe(StreamWeaver::CSS.layer_wrap("body.sw-theme-#{effective_theme} { #{css_vars} }")))
        end
      end

      def warn_unknown_theme_override_tokens
        unknown = @app.theme_overrides.keys.reject { |key| Theme::VARIABLE_SCHEMA.key?(key.to_sym) }
        return if unknown.empty?

        warn "StreamWeaver: Unknown theme override token(s) #{unknown.map(&:inspect).join(', ')} -- " \
             "no matching entry in Theme::VARIABLE_SCHEMA, so this override is emitted as a raw --sw- custom property " \
             "that no built-in styling reads."
      end

      # Render CSS for custom registered themes
      def render_custom_theme_css
        theme_name = effective_theme
        # Only render if it's a custom theme (not built-in)
        return if StreamWeaver::App::BUILT_IN_THEMES.include?(theme_name)

        custom_theme = StreamWeaver.get_theme(theme_name)
        return unless custom_theme

        style do
          raw(safe(StreamWeaver::CSS.layer_wrap(custom_theme.to_css)))
        end
      end

      # Emit CSS/JS declared via the css/css_path/js_path class macros on component classes.
      # Deduped by component class so multiple instances only emit their assets once.
      # Also collects from layout slots and emits the layout's own css_path if registered.
      def render_component_assets
        all_components = @app.components + (@app.layout_slots || {}).values.flatten

        # Layout-level CSS file
        layout_entry = @app.layout_entry
        if layout_entry&.dig(:css_path)
          path = layout_entry[:css_path]
          key  = ComponentAssets.file_key(path)
          link(rel: "stylesheet", href: "/sw-asset/#{key}/#{File.basename(path)}")
        end

        css_strings, css_paths, js_paths = ComponentAssets.collect(all_components)

        css_strings.each { |css| style { raw(safe(css)) } }
        css_paths.each do |path|
          key = ComponentAssets.file_key(path)
          link(rel: "stylesheet", href: "/sw-asset/#{key}/#{File.basename(path)}")
        end
        js_paths.each do |path|
          key = ComponentAssets.file_key(path)
          script(src: "/sw-asset/#{key}/#{File.basename(path)}")
        end
      end

      # Render all components in a named layout slot.
      # Used inside register_layout render blocks.
      def render_slot(name)
        ((@app.layout_slots || {})[name] || []).each { |c| c.render(self, @state) }
      end

      # Emit the main reactive content region (#app-container).
      # Use this inside a register_layout render block to place the reactive app content.
      def main_content_region
        div(id: "app-container", "data-sw-state-version" => @app.render_state.state_version,
            **@adapter.container_attributes(@state)) do
          render_components
        end
      end
    end

    # Partial view for HTMX updates (just the app-container content)
    # Includes state data for Alpine.js reinitialization after HTMX swap
    class AppContentView < Phlex::HTML
      attr_reader :adapter, :app
      attr_reader :current_fragment_id

      # @param app [StreamWeaver::App] The app instance
      # @param state [Hash] The current state
      # @param adapter [StreamWeaver::Adapter::Base] The adapter for rendering
      # @param is_agentic [Boolean] Whether running in agentic mode
      def initialize(app, state, adapter, is_agentic = false)
        @app = app
        @state = state
        @adapter = adapter
        @is_agentic = is_agentic
      end

      def view_template
        # Include fresh state data for Alpine.js reinitialization
        # This allows JavaScript to update the outer container's x-data after HTMX swap
        # See: Alpine.js Defer Mutations Pattern in adapter/alpinejs.rb
        state_json_data = @state.transform_keys(&:to_s)
        state_json_data["_sw_version"] = @app.render_state.state_version
        if @app.respond_to?(:transient_keys) && @app.transient_keys.any?
          state_json_data["_transient"] = @app.transient_keys.map(&:to_s)
        end
        state_json = JSON.generate(state_json_data)
        script(type: "application/json", id: "sw-state-data") { raw safe(state_json) }

        @app.components.each do |component|
          component.render(self, @state)
        end

        # Add submit button for agentic mode
        render_agentic_submit_button if @is_agentic
      end

      def with_fragment(id)
        previous = @current_fragment_id
        @current_fragment_id = id
        yield
      ensure
        @current_fragment_id = previous
      end

      private

      # Render the submit button for agentic mode
      def render_agentic_submit_button
        div(style: "margin-top: 30px; padding-top: 20px; border-top: 2px solid #e0e0e0;") do
          p(style: "color: #666; font-size: 14px;") { "Submit this form to return data to the calling agent:" }
          button(
            type: "button",
            class: "btn btn-primary",
            style: "background: #28a745; font-weight: bold;",
            "hx-post" => "/submit",
            "hx-include" => @adapter.input_selector
          ) { "🤖 Submit to Agent" }
        end
      end
    end

    # Shared by FragmentContentView and RowSwapView: renders one declared
    # `updates:` fragment as an OOB element. Row-granular narrowing
    # (stream_weaver-95k) applies independently per extra -- a toolbar button
    # whose own fragment has nothing to narrow can still narrow an extra
    # fragment's table (the common "Add" button outside the table, `updates:`
    # pointing at the table's fragment, is exactly this shape). Falls back to
    # the full-fragment OOB swap (pre-existing FAC-P1 behavior) whenever
    # `swap` is nil -- i.e. that extra's mutation wasn't provably row-local.
    # OOB elements always use htmx's native swap styles (plain innerHTML/
    # outerHTML), never an extension-only style like "morph:innerHTML" --
    # htmx core's own hx-swap-oob scanning doesn't dispatch through swap-style
    # extensions, so those are silently skipped in a real browser
    # (stream_weaver-e4p). Morph stays available for the PRIMARY target only.
    module ExtraFragmentRendering
      def render_extra(fragment, swap)
        return render_row_oob(swap) if swap

        div(id: fragment.id, "hx-swap-oob" => "innerHTML") do
          with_fragment(fragment.id) { fragment.children.each { |child| child.render(self, @state) } }
        end
      end

      def render_row_oob(swap)
        table = swap[:table]
        case swap[:kind]
        when :edit
          adapter.render_table_row(self, table.resolved_rows[swap[:idx]], swap[:idx], table.table_options, @state, table.dom_id,
                                    extra_attrs: { "hx-swap-oob" => "outerHTML" })
        when :delete
          tr(id: swap[:row_dom_id], "hx-swap-oob" => "delete")
        when :create
          adapter.render_table_row(self, table.resolved_rows[swap[:idx]], swap[:idx], table.table_options, @state, table.dom_id,
                                    extra_attrs: { "hx-swap-oob" => "beforeend:##{table.dom_id} tbody" })
        end
      end
    end

    class FragmentContentView < AppContentView
      include ExtraFragmentRendering

      # @param extra_swaps [Array<Hash, nil>] One row-swap analysis (or nil) per
      #   entry in `updates:`, positionally aligned (stream_weaver-95k)
      def initialize(app, state, adapter, fragment, updates: [], extra_swaps: [], state_patch:)
        super(app, state, adapter, false)
        @fragment = fragment
        @updates = updates
        @extra_swaps = extra_swaps
        @state_patch = state_patch
      end

      def view_template
        with_fragment(@fragment.id) { @fragment.children.each { |child| child.render(self, @state) } }
        @updates.each_with_index { |fragment, i| render_extra(fragment, @extra_swaps[i]) }
        raw safe(StatePatchView.new(@state_patch).call)
      end
    end

    # Row-granular counterpart to FragmentContentView (stream_weaver-95k): renders
    # just the mutated row's content (or nothing, for a delete) instead of the
    # whole fragment. The caller retargets/reswaps the *primary* content via
    # HX-Retarget/HX-Reswap response headers (InteractionRunner picks the row's
    # own id, or the table's tbody, as the target) rather than hx-swap-oob on the
    # primary content itself -- that reuses the exact header mechanism the runner
    # already has for full-view fallback, and keeps the primary swap composable
    # with htmx's normal target/swap-style handling (morph, delete, beforeend)
    # instead of hand-rolling those semantics via OOB attributes.
    # Declared `updates:` extras and the state patch still need hx-swap-oob,
    # since they are never part of the (retargeted) primary swap zone.
    class RowSwapView < AppContentView
      include ExtraFragmentRendering

      # @param app [StreamWeaver::App] The app instance
      # @param state [Hash] The current state
      # @param adapter [StreamWeaver::Adapter::Base] The adapter for rendering
      # @param updates [Array<Components::Fragment>] Declared `updates:` fragments, rendered OOB
      # @param extra_swaps [Array<Hash, nil>] One row-swap analysis (or nil) per entry in `updates:`
      # @param state_patch [Hash] The state patch (see InteractionRunner#state_patch)
      # @param primary [Proc, nil] Renders the primary (retargeted) content into the view; nil for a delete (empty body)
      def initialize(app, state, adapter, updates:, state_patch:, extra_swaps: [], primary: nil)
        super(app, state, adapter, false)
        @updates = updates
        @extra_swaps = extra_swaps
        @state_patch = state_patch
        @primary = primary
      end

      def view_template
        @primary&.call(self)
        @updates.each_with_index { |fragment, i| render_extra(fragment, @extra_swaps[i]) }
        raw safe(StatePatchView.new(@state_patch, true).call)
      end
    end

    class StatePatchView < Phlex::HTML
      # `oob` is positional, not a keyword arg: existing call sites pass the
      # patch hash bare (`StatePatchView.new(set: ..., delete: ..., version: ...)`),
      # relying on Ruby folding an un-braced trailing hash into the sole
      # positional `patch` param. Declaring `oob:` as a keyword instead would
      # make Ruby try to parse that call's hash as keyword arguments (it isn't).
      def initialize(patch, oob = false)
        @patch = patch
        @oob = oob
      end

      def view_template
        json = JSON.generate(@patch).gsub("<", "\\u003c")
        attrs = { type: "application/json", id: "sw-state-patch" }
        # RowSwapView's primary swap zone is a row/tbody, not the fragment, so
        # the patch script can't ride along inside the primary content like it
        # does for FragmentContentView -- it needs its own OOB delivery.
        # beforeend into #app-container (not an id-match OOB swap) so this
        # doesn't depend on a `#sw-state-patch` element already existing in
        # the DOM (stream_weaver-95k).
        attrs["hx-swap-oob"] = "beforeend:#app-container" if @oob
        script(**attrs) { raw safe(json) }
      end
    end
  end
end
