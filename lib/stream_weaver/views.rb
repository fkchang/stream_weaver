# frozen_string_literal: true

require 'phlex'
require 'json'

module StreamWeaver
  module Views
    # Full page view for initial load (includes <html>, <head>, <body>)
    class AppView < Phlex::HTML
      attr_reader :adapter

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
        doctype
        html do
          head do
            title { @app.title }
            # Inject adapter-specific CDN scripts using Phlex methods
            @adapter.render_cdn_scripts(self)

            # Add custom stylesheets
            @stylesheets.each do |href|
              link(rel: "stylesheet", href: href)
            end

            # Add custom scripts
            @scripts.each do |src|
              script(src: src)
            end

            # Google Fonts: Source Sans 3 + Crimson Pro (for document theme)
            link(rel: "preconnect", href: "https://fonts.googleapis.com")
            link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: "anonymous")
            link(rel: "stylesheet", href: "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap")
            style do
              raw(safe(<<~CSS))
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
                  --sw-line-height: 1.7;

                  /* Colors - High Contrast with Warm Accent */
                  --sw-color-primary: #c2410c;        /* Terracotta/burnt orange */
                  --sw-color-primary-hover: #9a3412;  /* Deeper terracotta */
                  --sw-color-primary-light: #fff7ed; /* Very light warm tint */
                  --sw-color-primary-glow: rgba(194, 65, 12, 0.12);

                  /* Colors - High Contrast Neutrals */
                  --sw-color-text: #111111;           /* Near black - high contrast */
                  --sw-color-text-muted: #444444;     /* Dark gray - still readable */
                  --sw-color-text-light: #888888;     /* Placeholder gray */
                  --sw-color-bg: #f8f8f8;             /* Clean light gray */
                  --sw-color-bg-card: #ffffff;
                  --sw-color-bg-elevated: #f3f3f3;   /* Subtle elevation */
                  --sw-color-border: #e0e0e0;        /* Clean border */
                  --sw-color-border-strong: #cccccc;
                  --sw-color-border-focus: var(--sw-color-primary);

                  /* Colors - Secondary */
                  --sw-color-secondary: #333333;
                  --sw-color-secondary-hover: #1a1a1a;

                  /* Colors - Accent (teal for links/highlights) */
                  --sw-color-accent: #0d9488;
                  --sw-color-accent-light: #e6fffa;

                  /* Spacing - Generous */
                  --sw-spacing-xs: 0.5rem;
                  --sw-spacing-sm: 0.75rem;
                  --sw-spacing-md: 1.25rem;
                  --sw-spacing-lg: 2rem;
                  --sw-spacing-xl: 3rem;
                  --sw-spacing-2xl: 4rem;

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
                  --sw-color-primary: #c2410c;
                  --sw-color-primary-hover: #9a3412;
                  --sw-color-primary-light: #fff7ed;
                  --sw-color-primary-glow: rgba(194, 65, 12, 0.08);

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

                  --sw-color-accent: #0d9488;
                  --sw-color-accent-light: #e6fffa;

                  /* Spacing - Reduced for density */
                  --sw-spacing-xs: 0.375rem;
                  --sw-spacing-sm: 0.5rem;
                  --sw-spacing-md: 0.875rem;
                  --sw-spacing-lg: 1.25rem;
                  --sw-spacing-xl: 1.75rem;
                  --sw-spacing-2xl: 2.5rem;

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

                /* Document-specific adjustments */
                body.sw-theme-document {
                  max-width: 720px;
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
                  margin: 0 auto;
                  padding: var(--sw-spacing-xl);
                  background: var(--sw-color-bg);
                  -webkit-font-smoothing: antialiased;
                  -moz-osx-font-smoothing: grayscale;
                  min-height: 100vh;
                }

                /* Layout modes */
                body.sw-layout-default { max-width: 900px; }
                body.sw-layout-wide { max-width: 1100px; }
                body.sw-layout-full { max-width: 1400px; }
                body.sw-layout-fluid { max-width: 100%; padding-left: var(--sw-spacing-xl); padding-right: var(--sw-spacing-xl); }

                /* Page title outside container */
                body > h1 {
                  font-size: 2.5rem;
                  font-weight: 700;
                  color: var(--sw-color-text);
                  letter-spacing: -0.02em;
                  margin: 0 0 var(--sw-spacing-lg) 0;
                }

                #app-container {
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
                  margin: var(--sw-spacing-sm) 0 var(--sw-spacing-md) 0;
                  word-wrap: break-word;
                  overflow-wrap: break-word;
                }

                /* Handle long URLs and strings */
                a, code, pre {
                  word-wrap: break-word;
                  overflow-wrap: break-word;
                  word-break: break-word;
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
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  font-size: var(--sw-font-size-base);
                  font-family: var(--sw-font-body);
                  width: 100%;
                  background: var(--sw-color-bg-card);
                  color: var(--sw-color-text);
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
                  border-color: var(--sw-color-primary);
                  box-shadow:
                    var(--sw-shadow-inner),
                    0 0 0 3px var(--sw-color-primary-glow);
                  background: #fff;
                }

                input[type="text"]::placeholder, input[type="email"]::placeholder, textarea::placeholder {
                  color: var(--sw-color-text-light);
                  font-style: italic;
                }

                textarea {
                  resize: vertical;
                  min-height: 100px;
                  line-height: 1.5;
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
                  background: #1a1a1a;
                  color: #ffffff;
                }

                .sw-app-header-dark .sw-app-header-subtitle {
                  color: #aaaaaa;
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
                  border-radius: var(--sw-radius-md);
                  font-family: var(--sw-font-body);
                  font-size: var(--sw-font-size-sm);
                  font-weight: 600;
                  letter-spacing: 0.01em;
                  cursor: pointer;
                  white-space: nowrap;
                  transition:
                    background var(--sw-transition),
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

                /* Primary - Terracotta with depth */
                .btn-primary {
                  background: linear-gradient(
                    135deg,
                    var(--sw-color-primary) 0%,
                    var(--sw-color-primary-hover) 100%
                  );
                  color: white;
                  box-shadow:
                    0 2px 4px rgba(194, 65, 12, 0.2),
                    0 4px 8px rgba(194, 65, 12, 0.15);
                }

                .btn-primary:hover {
                  background: linear-gradient(
                    135deg,
                    #d9520f 0%,
                    var(--sw-color-primary-hover) 100%
                  );
                  box-shadow:
                    0 4px 8px rgba(194, 65, 12, 0.25),
                    0 8px 16px rgba(194, 65, 12, 0.2);
                }

                /* Secondary - Slate with subtle style */
                .btn-secondary {
                  background: var(--sw-color-bg-elevated);
                  color: var(--sw-color-text);
                  border: 1px solid var(--sw-color-border-strong);
                  box-shadow: var(--sw-shadow-sm);
                }

                .btn-secondary:hover {
                  background: var(--sw-color-border);
                  border-color: var(--sw-color-text-light);
                }

                /* Button focus states */
                button:focus-visible {
                  outline: none;
                  box-shadow:
                    0 0 0 2px var(--sw-color-bg-card),
                    0 0 0 4px var(--sw-color-primary);
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
                  background: var(--sw-color-bg-card);
                  border: 1px solid var(--sw-color-border);
                  border-left: var(--sw-card-border-left);
                  border-radius: var(--sw-radius-md);
                  padding: var(--sw-spacing-lg);
                  margin-bottom: var(--sw-spacing-md);
                  box-shadow: var(--sw-shadow-sm);
                  overflow-x: auto;
                  word-wrap: break-word;
                  overflow-wrap: break-word;
                  max-width: 100%;
                }

                .card h3 {
                  margin-top: 0;
                  margin-bottom: var(--sw-spacing-sm);
                  color: var(--sw-color-text);
                }

                /* Card sub-components */
                .card-header {
                  padding-bottom: var(--sw-spacing-sm);
                  margin-bottom: var(--sw-spacing-md);
                  border-bottom: 1px solid var(--sw-color-border);
                }

                .card-header h1, .card-header h2, .card-header h3,
                .card-header h4, .card-header h5, .card-header h6 {
                  margin: 0;
                }

                .card-body {
                  /* Default body styling - inherits card padding */
                }

                .card-body > *:first-child {
                  margin-top: 0;
                }

                .card-body > *:last-child {
                  margin-bottom: 0;
                }

                .card-footer {
                  padding-top: var(--sw-spacing-sm);
                  margin-top: var(--sw-spacing-md);
                  border-top: 1px solid var(--sw-color-border);
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
                  border-bottom: 2px solid var(--sw-color-border);
                  margin-bottom: var(--sw-spacing-md);
                }

                .sw-tab-trigger {
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  border: none;
                  background: transparent;
                  font-family: var(--sw-font-body);
                  font-size: var(--sw-font-size-base);
                  font-weight: 500;
                  color: var(--sw-color-text-muted);
                  cursor: pointer;
                  /* Only transition color on hover, not border/active state - prevents flash during HTMX swaps */
                  transition: color var(--sw-transition);
                  position: relative;
                  margin: 0;
                  margin-bottom: -2px;
                }

                .sw-tab-trigger:hover {
                  color: var(--sw-color-text);
                  transform: none;
                }

                .sw-tab-trigger.sw-tab-active {
                  color: var(--sw-color-primary);
                  border-bottom: 2px solid var(--sw-color-primary);
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
                  background: var(--sw-color-bg-elevated);
                  padding: var(--sw-spacing-xs);
                  border-radius: var(--sw-radius-lg);
                }

                .sw-tabs-soft-rounded .sw-tab-trigger {
                  border-radius: var(--sw-radius-md);
                  margin-bottom: 0;
                }

                .sw-tabs-soft-rounded .sw-tab-trigger.sw-tab-active {
                  background: var(--sw-color-bg-card);
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
                  background: var(--sw-color-bg-card);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
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
                  background: var(--sw-color-bg-elevated);
                  transform: none;
                }

                .sw-menu-item-destructive {
                  color: #dc2626;
                }

                .sw-menu-item-destructive:hover {
                  background: rgba(220, 38, 38, 0.1);
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
                  background: var(--sw-color-bg-card);
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
                  border-bottom: 1px solid var(--sw-color-border);
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
                  border-top: 1px solid var(--sw-color-border);
                  background: var(--sw-color-bg-elevated);
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
                  background: rgba(59, 130, 246, 0.1);
                  border-color: rgba(59, 130, 246, 0.3);
                  color: #1e40af;
                }
                .sw-alert-info .sw-alert-icon { color: #3b82f6; }

                .sw-alert-success {
                  background: rgba(16, 185, 129, 0.1);
                  border-color: rgba(16, 185, 129, 0.3);
                  color: #065f46;
                }
                .sw-alert-success .sw-alert-icon { color: #10b981; }

                .sw-alert-warning {
                  background: rgba(245, 158, 11, 0.1);
                  border-color: rgba(245, 158, 11, 0.3);
                  color: #92400e;
                }
                .sw-alert-warning .sw-alert-icon { color: #f59e0b; }

                .sw-alert-error {
                  background: rgba(239, 68, 68, 0.1);
                  border-color: rgba(239, 68, 68, 0.3);
                  color: #991b1b;
                }
                .sw-alert-error .sw-alert-icon { color: #ef4444; }

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
                  background: var(--sw-color-bg-card);
                  border-radius: var(--sw-radius-md);
                  box-shadow: var(--sw-shadow-xl);
                  border: 1px solid var(--sw-color-border);
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
                .sw-toast-info .sw-toast-icon { color: #3b82f6; }
                .sw-toast-success .sw-toast-icon { color: #10b981; }
                .sw-toast-warning .sw-toast-icon { color: #f59e0b; }
                .sw-toast-error .sw-toast-icon { color: #ef4444; }

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
                  background: var(--sw-color-bg-elevated);
                  border-radius: var(--sw-radius-sm);
                  overflow: hidden;
                  margin: var(--sw-spacing-sm) 0;
                }

                .sw-progress-bar {
                  height: 100%;
                  background: var(--sw-color-primary);
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
                .sw-progress-success .sw-progress-bar { background: #10b981; }
                .sw-progress-warning .sw-progress-bar { background: #f59e0b; }
                .sw-progress-error .sw-progress-bar { background: #ef4444; }

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
                   =========================================== */
                .status-badge {
                  display: inline-flex;
                  align-items: center;
                  gap: var(--sw-spacing-xs);
                  padding: var(--sw-spacing-xs) var(--sw-spacing-sm);
                  border-radius: var(--sw-radius-sm);
                  font-size: var(--sw-font-size-sm);
                  margin: var(--sw-spacing-xs) var(--sw-spacing-sm) var(--sw-spacing-xs) 0;
                }

                .status-badge-strong {
                  background-color: rgba(16, 185, 129, 0.1);
                  color: #059669;
                }

                .status-badge-maybe {
                  background-color: rgba(245, 158, 11, 0.1);
                  color: #d97706;
                }

                .status-badge-skip {
                  background-color: rgba(239, 68, 68, 0.1);
                  color: #dc2626;
                }

                .status-badge-icon {
                  font-size: 1em;
                }

                .status-badge-label {
                  font-weight: 600;
                }

                .status-badge-reasoning {
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

                .sidebar-section {
                  background: var(--sw-color-bg-card);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  padding: var(--sw-spacing-md);
                }

                .sidebar-section h4 {
                  margin: 0 0 var(--sw-spacing-xs) 0;
                  color: var(--sw-color-text-muted);
                  font-size: 11px;
                  font-weight: 600;
                  text-transform: uppercase;
                  letter-spacing: 0.05em;
                }

                .sidebar-section p {
                  margin: 0;
                  color: var(--sw-color-text);
                  font-size: var(--sw-font-size-sm);
                }

                .sidebar-section a {
                  color: var(--sw-color-primary);
                  text-decoration: none;
                }

                .sidebar-section a:hover {
                  text-decoration: underline;
                }

                /* Responsive: Stack columns on mobile */
                @media (max-width: 768px) {
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
              CSS
            end
          end
          body(class: body_classes) do
            # Custom theme CSS (for registered themes)
            render_custom_theme_css

            # Theme overrides as inline CSS
            render_theme_overrides if @app.theme_overrides.any?

            h1 { @app.title }
            # Merge adapter-specific container attributes with container id
            div(id: "app-container", **@adapter.container_attributes(@state)) do
              render_components
            end
          end
        end
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

      # Generate body classes for layout and theme
      def body_classes
        effective_theme = @session_theme || @app.theme
        "sw-layout-#{@app.layout} sw-theme-#{effective_theme}"
      end

      # Get the effective theme (session override or app default)
      def effective_theme
        @session_theme || @app.theme
      end

      # Render inline CSS for theme overrides
      def render_theme_overrides
        css_vars = @app.theme_overrides.map do |key, value|
          css_var = key.to_s.tr('_', '-')
          # Add sw- prefix if not present
          css_var = "sw-#{css_var}" unless css_var.start_with?('sw-')
          "--#{css_var}: #{value};"
        end.join("\n  ")

        style do
          raw(safe("body { #{css_vars} }"))
        end
      end

      # Render CSS for custom registered themes
      def render_custom_theme_css
        theme_name = effective_theme
        # Only render if it's a custom theme (not built-in)
        return if StreamWeaver::App::BUILT_IN_THEMES.include?(theme_name)

        custom_theme = StreamWeaver.get_theme(theme_name)
        return unless custom_theme

        style do
          raw(safe(custom_theme.to_css))
        end
      end
    end

    # Partial view for HTMX updates (just the app-container content)
    # Includes state data for Alpine.js reinitialization after HTMX swap
    class AppContentView < Phlex::HTML
      attr_reader :adapter

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
        state_json = JSON.generate(@state.transform_keys(&:to_s))
        script(type: "application/json", id: "sw-state-data") { raw safe(state_json) }

        @app.components.each do |component|
          component.render(self, @state)
        end

        # Add submit button for agentic mode
        render_agentic_submit_button if @is_agentic
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
  end
end
