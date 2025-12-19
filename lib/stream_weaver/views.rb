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
      def initialize(app, state, adapter, is_agentic = false)
        @app = app
        @state = state
        @adapter = adapter
        @is_agentic = is_agentic
      end

      def view_template
        doctype
        html do
          head do
            title { @app.title }
            # Inject adapter-specific CDN scripts using Phlex methods
            @adapter.render_cdn_scripts(self)
            # Google Fonts: Source Sans 3 (humanist sans - readable with character)
            link(rel: "preconnect", href: "https://fonts.googleapis.com")
            link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: "anonymous")
            link(rel: "stylesheet", href: "https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;500;600;700&display=swap")
            style do
              raw(safe(<<~CSS))
                /* ===========================================
                   StreamWeaver CSS - "Warm Industrial" Theme
                   A distinctive, craft-inspired aesthetic
                   =========================================== */
                :root {
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

                  /* Spacing - More Generous */
                  --sw-spacing-xs: 0.5rem;
                  --sw-spacing-sm: 0.75rem;
                  --sw-spacing-md: 1.25rem;
                  --sw-spacing-lg: 2rem;
                  --sw-spacing-xl: 3rem;
                  --sw-spacing-2xl: 4rem;

                  /* Border Radius - Confident, not overly rounded */
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

                  /* Transitions - Smooth, deliberate */
                  --sw-transition-fast: 120ms ease-out;
                  --sw-transition: 200ms ease-out;
                  --sw-transition-slow: 350ms ease-out;

                  /* Tooltip */
                  --sw-tooltip-bg: #292524;
                  --sw-tooltip-text: #fafaf9;

                  /* Term highlighting */
                  --sw-term-color: var(--sw-color-primary);
                  --sw-term-bg-hover: var(--sw-color-primary-light);
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
                  border-left: 3px solid var(--sw-color-primary);
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
          body(class: "sw-layout-#{@app.layout}") do
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
    end

    # Partial view for HTMX updates (just the app-container content)
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
