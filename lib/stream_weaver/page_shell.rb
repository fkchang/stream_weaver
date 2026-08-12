# frozen_string_literal: true

require_relative "css"
require_relative "views"
require_relative "theme"

module StreamWeaver
  # Framework-CSS <head> block, currently used by the canvas
  # (Canvas::BridgeServer). Extracted from BridgeServer#render_canvas_page,
  # which is the correct reference implementation (stream_weaver-oeo fixed
  # its cascade-layer bug: CANVAS_CSS must be layer-wrapped alongside
  # master_theme_css/visual_skills_css, or it silently outranks them).
  #
  # Canvas::Reader and Export::HtmlExporter do NOT use this yet -- that's
  # stream_weaver-csf and stream_weaver-65z, not this commit. The point of
  # extracting it now is so those two can call the same ordering instead of
  # re-deriving it, once they're wired up -- see stream_weaver-mdc.
  #
  # Deliberately narrow scope: only the framework <style> blocks plus
  # optional user CSS. Body-class computation (session theme overrides,
  # chrome: false, exclusive-layout registry entries), <title>/favicon, CDN
  # scripts, and chrome/widgets all stay with each caller -- this is NOT a
  # canonical replacement for AppView's full standalone shell.
  module PageShell
    # Canvas-specific CSS (moved verbatim from Canvas::BridgeServer::SW_STYLES,
    # kept there as an alias since Canvas::Reader's only remaining direct
    # reference to it is by that name).
    CANVAS_CSS = <<~CSS
      /* Note: --sw-color and --sw-spacing family tokens are intentionally
         NOT declared at :root here -- they come from AppView.master_theme_css's
         body.sw-theme-{name} block, which is always rendered alongside this
         constant (see render_canvas_page). A :root-level declaration would be
         visible to getComputedStyle(document.documentElement), shadowing the
         body-scoped theme-aware value (and its dark variant) that things like
         sw-mermaid-zoom.js's getThemeVariables() read directly off <html>. */

      /* Base styles */
      *, *::before, *::after { box-sizing: border-box; }
      body {
        font-family: 'Source Sans 3', system-ui, sans-serif;
        font-size: 17px;
        line-height: 1.7;
        margin: 0;
        padding: var(--sw-spacing-md);
        background: var(--sw-color-bg);
        color: var(--sw-color-text);
      }
      #app-container {
        margin: 0 auto;
        background: var(--sw-color-bg-card);
        border-radius: var(--sw-radius-md);
        padding: var(--sw-spacing-lg);
        box-shadow: var(--sw-shadow-sm);
      }
      body.sw-layout-default #app-container { max-width: 900px; }
      body.sw-layout-wide    #app-container { max-width: 1100px; }
      body.sw-layout-full    #app-container { max-width: 1400px; }
      body.sw-layout-fluid   #app-container { max-width: 100%; }
      h1, h2, h3, h4, h5, h6 { margin: 0 0 var(--sw-spacing-md) 0; line-height: 1.3; }
      h1 { font-size: 2rem; }
      h2 { font-size: 1.5rem; }
      h3 { font-size: 1.25rem; }
      p { margin: 0 0 var(--sw-spacing-md) 0; }
      hr { border: none; border-top: 1px solid var(--sw-color-border); margin: var(--sw-spacing-lg) 0; }

      /* Card component */
      .card {
        background: var(--sw-color-bg-card);
        border: 1px solid var(--sw-color-border);
        border-left: var(--sw-card-border-left);
        border-radius: var(--sw-radius-md);
        padding: var(--sw-spacing-lg);
        margin-bottom: var(--sw-spacing-md);
        box-shadow: var(--sw-shadow-sm);
      }
      .card h3 {
        margin-top: 0;
        margin-bottom: var(--sw-spacing-sm);
        color: var(--sw-color-text);
      }
      .card-header {
        padding-bottom: var(--sw-spacing-sm);
        margin-bottom: var(--sw-spacing-md);
        border-bottom: 1px solid var(--sw-color-border);
      }
      .card-header h1, .card-header h2, .card-header h3,
      .card-header h4, .card-header h5, .card-header h6 { margin: 0; }
      .card-body > *:first-child { margin-top: 0; }
      .card-body > *:last-child { margin-bottom: 0; }
      .card-footer {
        padding-top: var(--sw-spacing-sm);
        margin-top: var(--sw-spacing-md);
        border-top: 1px solid var(--sw-color-border);
        display: flex;
        justify-content: flex-end;
        gap: var(--sw-spacing-sm);
      }
      .card-footer button { margin: 0; }

      /* Columns layout */
      .sw-columns {
        display: flex;
        gap: var(--sw-spacing-lg);
        margin-bottom: var(--sw-spacing-md);
      }
      .sw-column { flex: 1; min-width: 0; }
      @media (max-width: 768px) {
        .sw-columns { flex-direction: column; }
      }

      /* Buttons */
      .btn {
        display: inline-block;
        padding: 10px 20px;
        border: none;
        border-radius: var(--sw-radius-md);
        cursor: pointer;
        font-size: 16px;
        font-weight: 500;
        transition: background-color 150ms ease;
      }
      .btn:hover { filter: brightness(0.95); }
      .btn-primary {
        background: var(--sw-color-primary);
        color: white;
      }
      .btn-primary:hover { background: var(--sw-color-primary-hover); }
      .btn-secondary {
        background: #e5e5e5;
        color: var(--sw-color-text);
      }
      .btn-secondary:hover { background: #d5d5d5; }

      /* Form elements */
      .radio-group { display: flex; flex-direction: column; gap: 8px; margin-bottom: var(--sw-spacing-md); }
      .radio-option { display: flex; align-items: center; gap: 8px; cursor: pointer; }
      .checkbox-wrapper { display: flex; align-items: flex-start; gap: 8px; margin-bottom: var(--sw-spacing-sm); }
      .checkbox-wrapper input[type="checkbox"] {
        width: 18px;
        height: 18px;
        margin: 2px 0 0 0;
        cursor: pointer;
      }
      .checkbox-wrapper label { cursor: pointer; flex: 1; }
      input[type="text"], textarea {
        width: 100%;
        padding: 10px;
        border: 1px solid var(--sw-color-border);
        border-radius: var(--sw-radius-md);
        font-size: 16px;
        box-sizing: border-box;
      }
      input[type="text"]:focus, textarea:focus {
        outline: none;
        border-color: var(--sw-color-primary);
        box-shadow: 0 0 0 2px var(--sw-color-primary-light);
      }

      /* Markdown rendering */
      strong, b { font-weight: 600; }
      code {
        background: var(--sw-color-bg-elevated);
        padding: 2px 6px;
        border-radius: var(--sw-radius-sm);
        font-size: 0.9em;
      }

      /* Canvas waiting state */
      .sw-canvas-waiting {
        text-align: center;
        padding: 60px 40px;
        color: #666;
      }
      .sw-canvas-logo {
        color: var(--sw-color-primary);
        margin-bottom: 16px;
      }
      .sw-canvas-waiting h1 {
        font-size: 24px;
        font-weight: 600;
        color: var(--sw-color-text);
        margin-bottom: 24px;
      }
      .sw-canvas-spinner {
        width: 40px;
        height: 40px;
        border: 3px solid #e0e0e0;
        border-top-color: var(--sw-color-primary);
        border-radius: 50%;
        margin: 0 auto 20px;
        animation: sw-spin 1s linear infinite;
      }
      @keyframes sw-spin {
        to { transform: rotate(360deg); }
      }
      @keyframes sw-toast-in {
        from { opacity: 0; transform: translateX(-50%) translateY(-20px); }
        to { opacity: 1; transform: translateX(-50%) translateY(0); }
      }
      .sw-canvas-status {
        font-size: 18px;
        color: #444;
        margin-bottom: 24px;
      }
      .sw-canvas-info { margin-bottom: 32px; }
      .sw-canvas-session code {
        background: #f0f0f0;
        padding: 4px 12px;
        border-radius: 4px;
        font-size: 14px;
        font-weight: 500;
      }
      .sw-canvas-ready {
        font-size: 14px;
        color: #888;
        margin-top: 8px;
      }
      .sw-canvas-tip {
        background: #f8f8f8;
        border-radius: 8px;
        padding: 16px;
        margin-top: 24px;
      }
      .sw-canvas-tip p {
        margin: 0 0 8px 0;
        font-size: 14px;
        color: #666;
      }
      .sw-canvas-tip code {
        display: block;
        background: #fff;
        border: 1px solid #e0e0e0;
        padding: 8px 12px;
        border-radius: 4px;
        font-size: 13px;
        color: #333;
      }

      /* Progress bar */
      .sw-progress {
        width: 100%;
        height: 20px;
        background: #e5e7eb;
        border-radius: 10px;
        overflow: hidden;
        position: relative;
        margin-bottom: var(--sw-spacing-md);
      }
      .sw-progress-bar {
        height: 100%;
        background: var(--sw-color-primary);
        border-radius: 10px;
        transition: width 0.3s ease;
      }
      .sw-progress-label {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        font-size: 12px;
        font-weight: 600;
        color: #333;
      }
      .sw-progress-success .sw-progress-bar { background: #10b981; }
      .sw-progress-warning .sw-progress-bar { background: #f59e0b; }
      .sw-progress-error .sw-progress-bar { background: #ef4444; }
      .sw-progress-animated .sw-progress-bar {
        background-image: linear-gradient(
          45deg, rgba(255,255,255,0.15) 25%, transparent 25%,
          transparent 50%, rgba(255,255,255,0.15) 50%,
          rgba(255,255,255,0.15) 75%, transparent 75%, transparent
        );
        background-size: 1rem 1rem;
        animation: sw-progress-stripes 1s linear infinite;
      }
      @keyframes sw-progress-stripes {
        from { background-position: 1rem 0; }
        to { background-position: 0 0; }
      }

      /* Spinner */
      .sw-spinner-container {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: var(--sw-spacing-sm);
      }
      .sw-spinner {
        border: 2px solid #e0e0e0;
        border-top-color: var(--sw-color-primary);
        border-radius: 50%;
        animation: sw-spin 0.8s linear infinite;
      }
      .sw-spinner-sm { width: 16px; height: 16px; }
      .sw-spinner-md { width: 24px; height: 24px; }
      .sw-spinner-lg { width: 40px; height: 40px; border-width: 3px; }
      .sw-spinner-label {
        font-size: 14px;
        color: var(--sw-color-text-muted);
      }

      /* Status dots */
      .sw-status-dot {
        display: inline-block;
        border-radius: 50%;
        flex-shrink: 0;
      }
      .sw-status-dot-sm { width: 6px; height: 6px; }
      .sw-status-dot-md { width: 10px; height: 10px; }
      .sw-status-dot-lg { width: 14px; height: 14px; }
      .sw-status-dot-red { background: #ef4444; box-shadow: 0 0 6px rgba(239, 68, 68, 0.5); }
      .sw-status-dot-yellow { background: #f59e0b; box-shadow: 0 0 6px rgba(245, 158, 11, 0.5); }
      .sw-status-dot-green { background: #10b981; box-shadow: 0 0 6px rgba(16, 185, 129, 0.5); }
      .sw-status-dot-gray { background: #9ca3af; }
      .sw-status-dot-pulse { animation: sw-pulse 1.5s ease-in-out infinite; }
      @keyframes sw-pulse {
        0%, 100% { opacity: 1; transform: scale(1); }
        50% { opacity: 0.6; transform: scale(1.1); }
      }

      /* Status dot with label wrapper */
      .sw-status-dot-wrapper {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 4px;
      }
      .sw-status-dot-label {
        font-size: 12px;
        color: var(--sw-color-text-muted);
      }

      /* Activity items */
      .sw-activity-item {
        display: flex;
        gap: 12px;
        padding: 8px 0;
        border-bottom: 1px solid var(--sw-color-border);
      }
      .sw-activity-item:last-child { border-bottom: none; }
      .sw-activity-time {
        font-size: 12px;
        color: var(--sw-color-text-muted);
        min-width: 40px;
      }
      .sw-activity-content { flex: 1; }
      .sw-activity-title { font-weight: 500; }

      /* Alerts */
      .sw-alert {
        padding: var(--sw-spacing-md);
        border-radius: var(--sw-radius-md);
        margin-bottom: var(--sw-spacing-md);
        border-left: 4px solid;
      }
      .sw-alert-info { background: #eff6ff; border-color: #3b82f6; }
      .sw-alert-success { background: #f0fdf4; border-color: #10b981; }
      .sw-alert-warning { background: #fffbeb; border-color: #f59e0b; }
      .sw-alert-error { background: #fef2f2; border-color: #ef4444; }
      .sw-alert-title {
        font-weight: 600;
        margin-bottom: 4px;
      }

      /* Badges */
      .sw-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        padding: 2px 8px;
        border-radius: 12px;
        font-size: 12px;
        font-weight: 600;
      }
      .sw-badge-default { background: #e5e7eb; color: #374151; }
      .sw-badge-info { background: #dbeafe; color: #1d4ed8; }
      .sw-badge-success { background: #d1fae5; color: #047857; }
      .sw-badge-warning { background: #fef3c7; color: #b45309; }
      .sw-badge-danger { background: #fee2e2; color: #b91c1c; }

      /* Collapsible */
      .sw-collapsible { margin-bottom: var(--sw-spacing-md); }
      .sw-collapsible-trigger {
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
        padding: 8px;
        background: var(--sw-color-bg-elevated);
        border-radius: var(--sw-radius-md);
        font-weight: 500;
      }
      .sw-collapsible-trigger:hover { background: #e5e5e5; }
      .sw-collapsible-content {
        padding: var(--sw-spacing-md);
        border: 1px solid var(--sw-color-border);
        border-top: none;
        border-radius: 0 0 var(--sw-radius-md) var(--sw-radius-md);
      }

      /* HStack/VStack */
      .sw-hstack {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
      }
      .sw-hstack-xs { gap: 4px; }
      .sw-hstack-sm { gap: 8px; }
      .sw-hstack-md { gap: 16px; }
      .sw-hstack-lg { gap: 24px; }
      .sw-hstack-xl { gap: 32px; }
      .sw-vstack {
        display: flex;
        flex-direction: column;
      }
      .sw-vstack-none { gap: 0; }
      .sw-vstack-xs { gap: 4px; }
      .sw-vstack-sm { gap: 8px; }
      .sw-vstack-md { gap: 16px; }

      /* Table */
      .sw-table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: var(--sw-spacing-md);
      }
      .sw-table th, .sw-table td {
        padding: 10px 12px;
        text-align: left;
        border-bottom: 1px solid var(--sw-color-border);
      }
      .sw-table th {
        font-weight: 600;
        background: var(--sw-color-bg-elevated);
      }
      .sw-table-striped tr:nth-child(even) td {
        background: var(--sw-color-bg-elevated);
      }
      .sw-table-sortable th {
        cursor: pointer;
      }
      .sw-table-sortable th:hover {
        background: #e0e0e0;
      }

      /* Toast notifications */
      .sw-toast {
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        padding: 12px 40px 12px 16px;
        border-radius: var(--sw-radius-md);
        font-size: 14px;
        font-weight: 500;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        z-index: 10000;
        animation: sw-toast-in 0.3s ease-out;
        max-width: 90%;
      }
      .sw-toast-message { display: inline; }
      .sw-toast-close {
        position: absolute;
        right: 8px;
        top: 50%;
        transform: translateY(-50%);
        background: none;
        border: none;
        font-size: 20px;
        cursor: pointer;
        opacity: 0.7;
        padding: 4px 8px;
        line-height: 1;
      }
      .sw-toast-close:hover { opacity: 1; }
      .sw-toast-info {
        background: #dbeafe;
        color: #1e40af;
        border: 1px solid #93c5fd;
      }
      .sw-toast-success {
        background: #d1fae5;
        color: #065f46;
        border: 1px solid #6ee7b7;
      }
      .sw-toast-warning {
        background: #fef3c7;
        color: #92400e;
        border: 1px solid #fcd34d;
      }
      .sw-toast-error {
        background: #fee2e2;
        color: #991b1b;
        border: 1px solid #fca5a5;
      }
    CSS

    class << self
      # The framework <style> blocks, in the cascade order that matters:
      # layer pin first, then CANVAS_CSS/master_theme_css/visual_skills_css
      # all sharing that layer so unlayered user CSS (see #user_css_html)
      # always wins regardless of specificity or document order.
      #
      # @param extra_layers [Array<String>] layer names pinned after
      #   "stream-weaver" (still below unlayered user CSS, but lets a caller
      #   add its own higher-priority-than-framework layer -- concretely,
      #   the reader's chrome styling in stream_weaver-csf, the next commit
      #   to call this).
      # @return [String] HTML <style> tags
      def framework_css_html(extra_layers: [])
        layers = [StreamWeaver::CSS::LAYER_NAME, *extra_layers].join(", ")
        <<~HTML
          <style>@layer #{layers};</style>
          <style>#{StreamWeaver::CSS.layer_wrap(CANVAS_CSS)}</style>
          <style>#{StreamWeaver::CSS.layer_wrap(StreamWeaver::Views::AppView.master_theme_css)}</style>
          <style>#{StreamWeaver::CSS.layer_wrap(StreamWeaver::Theme.visual_skills_css)}</style>
        HTML
      end

      # User-authored inline CSS, always UNLAYERED so it outranks every
      # framework rule regardless of specificity or document order (the
      # cascade-layers contract StreamWeaver::CSS::LAYER_NAME documents).
      # Emit this after #framework_css_html.
      #
      # @param inline_stylesheets [Array<String>] raw CSS content
      # @return [String] HTML <style> tags
      def user_css_html(inline_stylesheets: [])
        inline_stylesheets.map { |css| "<style>#{css}</style>" }.join("\n")
      end
    end
  end
end
