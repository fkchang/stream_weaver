# frozen_string_literal: true

module StreamWeaver
  module Components
    # The one stylesheet shared by every ide_* component, added once by
    # render_ide_shell. A Ruby constant rather than a css_path file:
    # css_path links are emitted only by the standalone AppView, while
    # inject_component_css also reaches the canvas (AppContentView). The
    # Opal adapter has no ide renderers yet.
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
          --sw-ide-titlebar-height: 48px;
          --sw-ide-tabstrip-height: 37px;
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
          height: var(--sw-ide-titlebar-height);
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

        .sw-ide-rail-right:focus {
          outline: none;
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
        .sw-ide-titlebar__link:hover,
        .sw-ide-titlebar__link:focus-visible {
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
        .sw-ide-titlebar__theme-toggle:hover,
        .sw-ide-titlebar__theme-toggle:focus-visible {
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
        a.sw-ide-statusbar__item:hover,
        a.sw-ide-statusbar__item:focus-visible {
          color: var(--ide-text, var(--sw-color-text));
          text-decoration: underline;
        }
        .sw-ide-titlebar__link:focus-visible,
        .sw-ide-titlebar__theme-toggle:focus-visible,
        a.sw-ide-statusbar__item:focus-visible,
        .sw-ide-shell__nav-toggle:focus-visible {
          outline: 2px solid var(--ide-accent, var(--sw-color-primary));
          outline-offset: 1px;
        }
        .sw-ide-statusbar__spacer {
          flex: 1;
        }

        /* Editor: tab strip (sticky inside the scrolling editor) and file
           sections */
        .sw-ide-tabstrip {
          position: sticky;
          top: 0;
          z-index: 1;
          flex: none;
          display: flex;
          align-items: stretch;
          box-sizing: border-box;
          height: var(--sw-ide-tabstrip-height);
          overflow-x: auto;
          overflow-y: hidden;
          scrollbar-width: none;
          background: var(--ide-header, var(--sw-color-bg-elevated));
        }
        .sw-ide-tabstrip::-webkit-scrollbar {
          display: none;
        }
        .sw-ide-tabstrip::after {
          content: "";
          flex: 1 1 0;
          min-width: 0;
          border-bottom: 1px solid var(--ide-border, var(--sw-color-border));
        }
        .sw-ide-tab {
          flex: none;
          display: flex;
          align-items: center;
          gap: 7px;
          padding: 0 12px;
          border-right: 1px solid var(--ide-border, var(--sw-color-border));
          border-bottom: 1px solid var(--ide-border, var(--sw-color-border));
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 12.5px;
          white-space: nowrap;
          color: var(--ide-muted, var(--sw-color-text-muted));
          text-decoration: none;
        }
        .sw-ide-tab:hover {
          background: var(--ide-hover, var(--sw-color-bg-hover));
          color: var(--ide-text, var(--sw-color-text));
          text-decoration: none;
        }
        .sw-ide-tab:focus-visible {
          outline: 2px solid var(--ide-accent, var(--sw-color-primary));
          outline-offset: -2px;
        }
        .sw-ide-tab__icon {
          flex: none;
          width: 14px;
          height: 14px;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-tab.sw-is-active {
          background: var(--ide-workspace, var(--sw-color-bg));
          border-bottom-color: var(--ide-workspace, var(--sw-color-bg));
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-tab.sw-is-active .sw-ide-tab__icon {
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-file-section {
          box-sizing: border-box;
          width: 100%;
          max-width: 860px;
          margin: 0 auto;
          padding: clamp(40px, 7vh, 84px) clamp(20px, 5vw, 56px);
          /* Lands just below the sticky tab strip; the scroll spy reads the
             strip's height for the top of its band too. */
          scroll-margin-top: var(--sw-ide-tabstrip-height);
        }
        .sw-ide-file-section:focus {
          outline: none;
        }
        .sw-ide-file-section + .sw-ide-file-section {
          border-top: 1px solid var(--ide-border, var(--sw-color-border));
        }
        .sw-ide-file-section__comment {
          margin: 0 0 18px;
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 12px;
          /* JetBrains Mono would draw "<!--" as an arrow */
          font-variant-ligatures: none;
          color: var(--ide-hint, var(--sw-color-text-light));
        }

        /* Right rail: tabs, file tree, terminal */
        .sw-ide-rail-tabs {
          display: flex;
          flex: none;
          align-items: center;
          gap: 18px;
          padding: 8px 16px;
          border-bottom: 1px solid var(--ide-border, var(--sw-color-border));
          font-size: 11.5px;
          font-weight: 500;
          letter-spacing: 0.5px;
          text-transform: uppercase;
        }
        .sw-ide-rail-tab {
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-rail-tab--active {
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-rail-tab--dim {
          cursor: help;
        }
        .sw-ide-filetree {
          display: flex;
          flex: 1;
          flex-direction: column;
          gap: 1px;
          min-height: 0;
          padding: 8px;
          overflow-y: auto;
          scrollbar-width: thin;
          scrollbar-color: var(--ide-border2, var(--sw-color-border-strong)) transparent;
        }
        .sw-ide-filetree__row {
          display: flex;
          flex: none;
          align-items: center;
          gap: 7px;
          padding: 4.5px 8px 4.5px calc(8px + var(--sw-ide-depth, 0) * 20px);
          border-radius: 4px;
          white-space: nowrap;
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 12.5px;
          color: var(--ide-muted, var(--sw-color-text-muted));
          text-decoration: none;
        }
        a.sw-ide-filetree__row:hover {
          background: var(--ide-hover, var(--sw-color-bg-hover));
          color: var(--ide-text, var(--sw-color-text));
          text-decoration: none;
        }
        a.sw-ide-filetree__row:focus-visible {
          outline: 2px solid var(--ide-accent, var(--sw-color-primary));
          outline-offset: -2px;
        }
        .sw-ide-filetree__icon {
          flex: none;
          width: 14px;
          height: 14px;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-filetree__row.sw-is-active {
          background: color-mix(in srgb, var(--ide-accent, var(--sw-color-primary)) 16%, transparent);
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-filetree__row.sw-is-active .sw-ide-filetree__icon {
          color: var(--ide-accent, var(--sw-color-primary));
        }
        .sw-ide-visually-hidden {
          position: absolute;
          width: 1px;
          height: 1px;
          margin: -1px;
          padding: 0;
          overflow: hidden;
          clip: rect(0 0 0 0);
          white-space: nowrap;
          border: 0;
        }
        .sw-ide-terminal {
          display: flex;
          flex: none;
          flex-direction: column;
          margin: 0;
          height: 375px;
          max-height: 47vh;
          border-top: 1px solid var(--ide-border2, var(--sw-color-border-strong));
        }
        .sw-ide-terminal__head {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 8px 12px;
          border-bottom: 1px solid var(--ide-border, var(--sw-color-border));
        }
        .sw-ide-terminal__label {
          font-size: 11px;
          font-weight: 500;
          letter-spacing: 0.5px;
          text-transform: uppercase;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-terminal__screen {
          flex: 1;
          min-height: 0;
          margin: 0;
          padding: 4px 14px 14px;
          overflow-y: auto;
          border: 0;
          border-radius: 0;
          background: transparent;
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 12px;
          line-height: 1.75;
          white-space: pre-wrap;
          word-break: break-all;
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-terminal__prompt {
          font-weight: 600;
          color: var(--ide-accent, var(--sw-color-primary));
        }
        .sw-ide-terminal__command {
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-terminal__output {
          color: var(--ide-hint, var(--sw-color-text-light));
        }

        /* Left rail: tree and note card */
        .sw-ide-tree {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }
        .sw-ide-tree__heading {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 2px 4px;
          font-size: 11px;
          font-weight: 500;
          letter-spacing: 0.5px;
          text-transform: uppercase;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-tree__action {
          display: inline-flex;
          padding: 0;
          border-radius: 4px;
          color: inherit;
        }
        .sw-ide-tree__action:hover,
        .sw-ide-tree__action:focus-visible {
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-tree__rows {
          display: flex;
          flex-direction: column;
          gap: 1px;
        }
        .sw-ide-tree__row {
          display: flex;
          align-items: center;
          gap: 6px;
          padding: 5px 8px 5px calc(8px + var(--sw-ide-depth, 0) * 18px);
          border-radius: 4px;
          overflow: hidden;
          white-space: nowrap;
          color: var(--ide-muted, var(--sw-color-text-muted));
          text-decoration: none;
        }
        .sw-ide-tree__icon {
          flex: none;
          width: 14px;
          height: 14px;
          line-height: 14px;
          text-align: center;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-tree__label {
          overflow: hidden;
          text-overflow: ellipsis;
        }
        .sw-ide-tree__row--active {
          color: var(--ide-text, var(--sw-color-text));
        }
        a.sw-ide-tree__row:hover,
        a.sw-ide-tree__row:focus-visible {
          background: var(--ide-hover, var(--sw-color-bg-hover));
          color: var(--ide-text, var(--sw-color-text));
          text-decoration: none;
        }
        .sw-ide-tree__row--selected,
        a.sw-ide-tree__row--selected:hover {
          background: color-mix(in srgb, var(--ide-accent, var(--sw-color-primary)) 16%, transparent);
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-tree__row--selected .sw-ide-tree__icon {
          color: var(--ide-accent, var(--sw-color-primary));
        }
        .sw-ide-tree__row--disabled {
          color: var(--ide-hint, var(--sw-color-text-light));
          cursor: default;
        }
        .sw-ide-tree__tag {
          flex: none;
          margin-left: auto;
          padding: 1px 6px;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: var(--ide-elevated, var(--sw-color-bg-card));
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 9.5px;
          font-weight: 500;
          letter-spacing: 0.4px;
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-note[x-cloak] {
          display: none !important;
        }
        .sw-ide-note {
          margin: auto 8px 8px;
          padding: 12px;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: var(--ide-header, var(--sw-color-bg-card));
        }
        .sw-ide-note__icon {
          width: 24px;
          height: 24px;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-note__body {
          margin-top: 8px;
          font-size: 14px;
          line-height: 1.5;
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-note__body > * {
          margin: 0;
        }
        .sw-ide-note__dismiss {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          margin-top: 12px;
          padding: 10px 18px;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: transparent;
          color: var(--ide-text, var(--sw-color-text));
          font: inherit;
          font-weight: 500;
          cursor: pointer;
        }
        .sw-ide-note__dismiss:hover {
          background: var(--ide-hover, var(--sw-color-bg-hover));
          border-color: var(--ide-muted, var(--sw-color-text-muted));
        }
        a.sw-ide-tree__row:focus-visible,
        .sw-ide-tree__action:focus-visible,
        .sw-ide-note__dismiss:focus-visible {
          outline: 2px solid var(--ide-accent, var(--sw-color-primary));
          outline-offset: 1px;
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
        .sw-ide-shell__nav-toggle:hover,
        .sw-ide-shell__nav-toggle:focus-visible {
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
          .sw-ide-shell:has(> .sw-ide-shell__nav-toggle) .sw-ide-titlebar {
            padding-right: 58px;
          }
          /* Rail and backdrop start below the titlebar, so the nav toggle
             stays visible and can close the rail it opened. */
          .sw-ide-rail-right {
            position: fixed;
            top: var(--sw-ide-titlebar-height);
            right: 0;
            bottom: 0;
            z-index: 60;
            width: min(380px, 85vw);
            border-left: 1px solid var(--ide-border2, var(--sw-color-border-strong));
            box-shadow: var(--ide-shadow, var(--sw-shadow-xl));
            transform: translateX(100%);
            visibility: hidden;
            transition: transform 0.2s, visibility 0s linear 0.2s;
          }
          /* Visible at once on open, so the shell can focus the rail on the
             next tick; hidden only after the slide-out on close. */
          .sw-ide-shell--rail-open .sw-ide-rail-right {
            transform: none;
            visibility: visible;
            transition: transform 0.2s, visibility 0s;
          }
          .sw-ide-shell__nav-toggle {
            display: inline-flex;
          }
          .sw-ide-shell--rail-open .sw-ide-shell__backdrop {
            display: block;
            position: fixed;
            inset: var(--sw-ide-titlebar-height) 0 0 0;
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

        /* ===========================================
           Landing-page content: hero, pills, buttons, cards, transcript.
           Plain divs with these classes; no component behind them.
           =========================================== */
        .sw-ide-editor > .sw-ide-file-section:last-child {
          /* Tall enough that the last tab can scroll to the top. */
          min-height: calc(100vh - var(--sw-ide-tabstrip-height));
        }
        .sw-ide-h2 {
          margin: 0 0 12px;
          padding: 0;
          border: 0;
          font-size: clamp(28px, 4vw, 40px);
          font-weight: 700;
          letter-spacing: -0.02em;
          line-height: 1.15;
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-lead {
          margin: 0 0 var(--sw-spacing-lg, 24px);
          font-size: 17px;
          line-height: 1.55;
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-hero__title {
          margin: 18px 0 8px;
          font-size: clamp(44px, 8vw, 84px);
          font-weight: 700;
          letter-spacing: -0.04em;
          line-height: 1;
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-hero__tagline {
          margin: 0 0 14px;
          font-size: clamp(20px, 2.6vw, 28px);
          font-weight: 600;
          line-height: 1.25;
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-hero__lede {
          max-width: 620px;
          margin: 0 0 var(--sw-spacing-lg, 24px);
          font-size: 17px;
          line-height: 1.6;
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-hero__meta {
          margin: 22px 0 0;
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 12px;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-pills {
          display: flex;
          flex-wrap: wrap;
          gap: var(--sw-spacing-sm, 8px);
        }
        .sw-ide-pill {
          padding: 3px 10px;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 999px;
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 11px;
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-pill p,
        .sw-ide-card__icon p,
        .sw-ide-transcript__label p,
        .sw-ide-transcript__line p,
        .sw-ide-transcript__choice p,
        .sw-ide-transcript__cta p {
          margin: 0;
          color: inherit;
        }
        .sw-ide-h3 {
          margin: var(--sw-spacing-lg, 24px) 0 var(--sw-spacing-sm, 8px);
        }
        .sw-ide-actions {
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
        }
        .sw-ide-btn {
          display: inline-flex;
          align-items: center;
          padding: 11px 20px;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: transparent;
          color: var(--ide-text, var(--sw-color-text));
          font-weight: 500;
          text-decoration: none;
        }
        .sw-ide-btn:hover {
          background: var(--ide-hover, var(--sw-color-bg-hover));
        }
        .sw-ide-btn--primary {
          border-color: var(--ide-accent, var(--sw-color-primary));
          background: var(--ide-accent, var(--sw-color-primary));
          color: var(--ide-on-accent, #fff);
        }
        .sw-ide-btn--primary:hover {
          background: var(--ide-accent-hover, var(--sw-color-primary-hover));
        }
        .sw-ide-btn:focus-visible {
          outline: 2px solid var(--ide-accent, var(--sw-color-primary));
          outline-offset: 2px;
        }
        .sw-ide-beat {
          margin: 0 0 var(--sw-spacing-lg, 24px);
        }
        .sw-ide-beat h3 {
          margin: 0 0 6px;
          font-size: 20px;
          font-weight: 600;
        }
        .sw-ide-beat p {
          margin: 0;
          line-height: 1.6;
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-cards {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
          gap: 14px;
          margin: 0 0 var(--sw-spacing-xl, 32px);
        }
        .sw-ide-card {
          padding: var(--sw-spacing-md, 16px) 18px;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: var(--ide-header, var(--sw-color-bg-card));
        }
        .sw-ide-card__head {
          display: flex;
          align-items: center;
          gap: var(--sw-spacing-sm, 8px);
          margin-bottom: 8px;
        }
        .sw-ide-card__head h3 {
          margin: 0;
          font-size: 15px;
          font-weight: 600;
        }
        .sw-ide-card__icon {
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 13px;
          color: var(--ide-accent, var(--sw-color-primary));
        }
        .sw-ide-card > p {
          margin: 0;
          font-size: 14px;
          line-height: 1.6;
          color: var(--ide-muted, var(--sw-color-text-muted));
        }
        .sw-ide-transcript {
          display: grid;
          gap: 14px;
          margin: 0 0 var(--sw-spacing-lg, 24px);
        }
        .sw-ide-transcript__panel {
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: var(--ide-header, var(--sw-color-bg-card));
          overflow: hidden;
        }
        .sw-ide-transcript__label {
          padding: 6px 14px;
          border-bottom: 1px solid var(--ide-border, var(--sw-color-border));
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 11px;
          letter-spacing: 0.4px;
          color: var(--ide-hint, var(--sw-color-text-light));
        }
        .sw-ide-transcript__body {
          padding: 12px 14px;
          font-family: var(--ide-font-mono, var(--sw-font-mono));
          font-size: 13px;
          line-height: 1.6;
          color: var(--ide-text, var(--sw-color-text));
        }
        .sw-ide-transcript__line {
          white-space: pre-wrap;
        }
        .sw-ide-transcript__line--out {
          color: var(--ide-green, var(--sw-color-success));
        }
        .sw-ide-transcript__panel--page .sw-ide-transcript__body {
          font-family: var(--ide-font-sans, var(--sw-font-body));
          background: var(--ide-workspace, var(--sw-color-bg));
        }
        .sw-ide-transcript__panel--page h3 {
          margin: 0 0 10px;
          font-size: 16px;
        }
        .sw-ide-transcript__choices {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 10px;
          margin-bottom: 12px;
        }
        .sw-ide-transcript__choice {
          padding: 14px;
          border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
          border-radius: 4px;
          background: var(--ide-header, var(--sw-color-bg-card));
        }
        .sw-ide-transcript__cta {
          display: inline-block;
          padding: 8px 16px;
          border-radius: 4px;
          background: var(--ide-accent, var(--sw-color-primary));
          color: var(--ide-on-accent, #fff);
          font-weight: 500;
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
