# frozen_string_literal: true

module StreamWeaver
  module Components
    # The one stylesheet shared by every ide_* component. A Ruby constant
    # rather than a css_path file: css_path links are emitted only by the
    # standalone AppView, while inject_component_css reaches the canvas
    # (AppContentView) and the Opal build too.
    #
    # Colours and fonts come from the :ide theme's --ide-* tokens, with
    # --sw-* fallbacks so the shell still reads under any other theme.
    module Ide
      CSS = <<~CSS
        /* ===========================================
           IDE shell: titlebar / left | editor | right / statusbar
           =========================================== */
        html body:has(.sw-ide-shell) {
          margin: 0;
          padding: 0;
          max-width: none;
          overflow: hidden;
          background: var(--ide-chrome, var(--sw-color-bg));
        }
        html body #app-container:has(> .sw-ide-shell) {
          padding: 0;
          border: 0;
          border-radius: 0;
          box-shadow: none;
          background: transparent;
          overflow: visible;
          animation: none;
        }

        .sw-ide-shell {
          display: grid;
          height: 100dvh;
          grid-template-columns: 220px minmax(0, 1fr) 380px;
          grid-template-rows: auto minmax(0, 1fr) auto;
          grid-template-areas:
            "titlebar titlebar titlebar"
            "left center right"
            "status status status";
          background: var(--ide-chrome, var(--sw-color-bg));
          color: var(--ide-text, var(--sw-color-text));
          font-family: var(--ide-font-sans, var(--sw-font-body));
          font-size: 14px;
          line-height: 1.6;
          overflow: hidden;
        }

        .sw-ide-titlebar {
          grid-area: titlebar;
          display: flex;
          align-items: center;
          gap: 14px;
          min-width: 0;
          min-height: 48px;
          padding: 8px 14px;
          background: var(--ide-chrome, var(--sw-color-bg-elevated));
          border-bottom: 1px solid var(--ide-border2, var(--sw-color-border-strong));
        }

        .sw-ide-rail-left {
          grid-area: left;
          display: flex;
          flex-direction: column;
          gap: 10px;
          min-height: 0;
          padding: 12px;
          overflow-y: auto;
          border-right: 1px solid var(--ide-border, var(--sw-color-border));
        }

        .sw-ide-editor {
          grid-area: center;
          display: flex;
          flex-direction: column;
          min-width: 0;
          min-height: 0;
          overflow-y: auto;
          background: var(--ide-workspace, var(--sw-color-bg));
        }

        .sw-ide-rail-right {
          grid-area: right;
          display: flex;
          flex-direction: column;
          min-height: 0;
          overflow: hidden;
          background: var(--ide-chrome, var(--sw-color-bg-elevated));
          border-left: 1px solid var(--ide-border, var(--sw-color-border));
        }

        .sw-ide-statusbar {
          grid-area: status;
          display: flex;
          align-items: center;
          gap: 18px;
          min-height: 28px;
          padding: 5px 16px;
          overflow: hidden;
          white-space: nowrap;
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 11px;
          color: var(--ide-hint, var(--sw-color-text-light));
          background: var(--ide-chrome, var(--sw-color-bg-elevated));
          border-top: 1px solid var(--ide-border2, var(--sw-color-border-strong));
        }

        /* Titlebar parts */
        .sw-ide-titlebar__logo {
          display: inline-flex;
          flex: none;
          align-items: center;
          color: var(--ide-accent, var(--sw-color-primary));
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-weight: 700;
        }
        .sw-ide-titlebar__logo > * {
          margin: 0;
        }
        .sw-ide-titlebar__scope {
          display: flex;
          align-items: center;
          gap: 14px;
          min-width: 0;
          font-size: 13px;
          white-space: nowrap;
        }
        .sw-ide-titlebar__crumbs,
        .sw-ide-titlebar__branch {
          display: flex;
          align-items: center;
          gap: 4px;
          padding-left: 14px;
          border-left: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          font-family: var(--ide-font-mono, var(--sw-font-mono));
        }
        .sw-ide-titlebar__crumb,
        .sw-ide-titlebar__crumb-sep {
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-titlebar__crumb--current {
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-titlebar__branch {
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-titlebar__branch-icon {
          width: 14px;
          height: 14px;
        }
        .sw-ide-titlebar__actions {
          display: flex;
          align-items: center;
          gap: 10px;
          margin-left: auto;
        }
        .sw-ide-titlebar__link {
          display: inline-flex;
          align-items: center;
          gap: 7px;
          padding: 6px 8px;
          border-radius: 4px;
          font-size: 13px;
          color: var(--ide-muted, var(--sw-color-text-muted));
          text-decoration: none;
        }
        .sw-ide-titlebar__link:hover {
          background: var(--ide-hover, var(--sw-color-bg-hover));
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-titlebar__link-icon {
          width: 16px;
          height: 16px;
          line-height: 16px;
          text-align: center;
        }
        .sw-ide-titlebar__theme-toggle {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          width: 32px;
          height: 32px;
          padding: 0;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: transparent;
          color: var(--ide-muted, var(--sw-color-text-muted));
          cursor: pointer;
        }
        .sw-ide-titlebar__theme-toggle:hover {
          background: var(--ide-hover, var(--sw-color-bg-hover));
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-titlebar__theme-icon {
          width: 16px;
          height: 16px;
        }
        .sw-ide-titlebar__theme-icon--sun {
          display: none;
        }
        html.dark .sw-ide-titlebar__theme-icon--sun {
          display: block;
        }
        html.dark .sw-ide-titlebar__theme-icon--moon {
          display: none;
        }

        /* Statusbar items */
        .sw-ide-statusbar__item {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          color: inherit;
          text-decoration: none;
        }
        a.sw-ide-statusbar__item:hover {
          color: var(--ide-text, var(--sw-color-text));
          text-decoration: underline;
        }
        .sw-ide-statusbar__spacer {
          flex: 1;
        }

        .sw-ide-rail-left,
        .sw-ide-editor {
          scrollbar-width: thin;
          scrollbar-color: var(--ide-border2, var(--sw-color-border-strong)) transparent;
        }

        /* Nav toggle: sits at the right end of the titlebar row, shown only
           when the right rail is off-canvas. */
        .sw-ide-shell__nav-toggle {
          display: none;
          grid-area: titlebar;
          justify-self: end;
          align-self: center;
          z-index: 1;
          align-items: center;
          justify-content: center;
          width: 30px;
          height: 30px;
          margin-right: 14px;
          padding: 0;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: var(--ide-elevated, var(--sw-color-bg-card));
          color: var(--ide-muted, var(--sw-color-text-muted));
          cursor: pointer;
        }
        .sw-ide-shell__nav-toggle:hover {
          background: var(--ide-hover, var(--sw-color-bg-hover));
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-shell__nav-toggle svg {
          width: 16px;
          height: 16px;
        }

        .sw-ide-shell__backdrop {
          display: none;
        }

        @media (max-width: 1180px) {
          .sw-ide-shell {
            grid-template-columns: 200px minmax(0, 1fr);
            grid-template-areas:
              "titlebar titlebar"
              "left center"
              "status status";
          }
          .sw-ide-titlebar {
            padding-right: 58px;
          }
          .sw-ide-rail-right {
            position: fixed;
            top: 0;
            right: 0;
            bottom: 0;
            z-index: 60;
            width: min(380px, 85vw);
            border-left: 1px solid var(--ide-border2, var(--sw-color-border-strong));
            box-shadow: var(--ide-shadow, var(--sw-shadow-xl));
            transform: translateX(100%);
            visibility: hidden;
            transition: transform 0.2s, visibility 0.2s;
          }
          .sw-ide-shell--rail-open .sw-ide-rail-right {
            transform: none;
            visibility: visible;
          }
          .sw-ide-shell__nav-toggle {
            display: inline-flex;
          }
          .sw-ide-shell--rail-open .sw-ide-shell__backdrop {
            display: block;
            position: fixed;
            inset: 0;
            z-index: 50;
            background: rgba(0, 0, 0, 0.45);
          }
        }

        @media (max-width: 840px) {
          .sw-ide-shell {
            grid-template-columns: minmax(0, 1fr);
            grid-template-areas:
              "titlebar"
              "center"
              "status";
          }
          .sw-ide-rail-left {
            display: none;
          }
          .sw-ide-titlebar__branch {
            display: none;
          }
          .sw-ide-statusbar {
            flex-wrap: wrap;
            white-space: normal;
          }
        }

        @media (max-width: 560px) {
          .sw-ide-titlebar__scope,
          .sw-ide-titlebar__link-label {
            display: none;
          }
        }

        @media (prefers-reduced-motion: reduce) {
          .sw-ide-rail-right {
            transition: none;
          }
        }
      CSS
    end
  end
end
