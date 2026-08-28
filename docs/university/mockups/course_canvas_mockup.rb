# streamweaver-doc: v1
#
# StreamWeaver University — course canvas mockup (story: course-canvas-design)
#
# Two screens of the app `streamweaver get-started` lands on:
#   1. Course list  — a shelf of course panels. Getting Started is open and holds
#                     its own state (resume line, rail, 5 steps). Future courses
#                     are closed, dormant panels with no controls.
#   2. Step screen  — one step: why it matters, the exact prompt, Run / Copy,
#                     payoff, done.
#
# Dual-mode single file (shared-DSL pattern):
#   canvas :  streamweaver canvas-push university-design < docs/university/mockups/course_canvas_mockup.rb
#   standalone: ruby docs/university/mockups/course_canvas_mockup.rb
#
# v2 (revision after UAT): the resume state moved INSIDE the Getting Started
# panel, surfaces replaced hairlines, the type scale went up, and a three-colour
# state language (done / now / next) replaced the single blue. Buttons are
# `submit: false` (display-only) — this is a mockup, not the built app.

# ---------------------------------------------------------------------------
# One stylesheet. Targets sw- hooks (docs/theming-hooks.md) plus `uni-` classes
# for the handful of elements that have no component. Inlined as literal CSS
# rather than a sibling .css file because canvas-push has no route to serve a
# referenced asset across processes (see App#use_stylesheet, stream_weaver-9uk).
#
# Unlike v1, this sheet carries an explicit dark block. Riding only --sw-* meant
# every surface collapsed onto one flat paper tone; a control panel needs the
# page and the panel to be different grounds, and that is a two-value decision
# per theme. The dark block hangs off the same selector the :doc theme uses for
# its own dark palette, so the two flip on exactly the same signal.
# ---------------------------------------------------------------------------
_css = <<~CSS
  body {
    /* ---- Grounds: the page is the room, panels are the instruments ------- */
    --uni-page:      #E7E4D9;
    --uni-panel:     #FDFCF9;
    --uni-bar:       #F3F1E8;
    --uni-sunk:      #F1EFE6;
    --uni-line:      #D6D2C4;
    --uni-line-soft: #E6E3D7;

    /* ---- State language: one triad, used identically everywhere ---------- */
    --uni-done:      #17754A;
    --uni-done-bg:   #E2F0E8;
    --uni-now:       var(--sw-color-accent);
    --uni-now-bg:    #E5ECFC;
    --uni-next:      #6E6959;
    /* Chip ground is separate from the rail track: the chip carries text and
       must clear 4.5:1, the track is a container behind the filled segments. */
    --uni-next-bg:   #EFECE1;
    --uni-rail-track: #D6D1BF;

    --uni-ink:       var(--sw-color-text);
    /* Darker than --sw-color-text-muted (#6B6860), which is only 4.37:1 on the
       page ground — the tagline and dormant blurbs sit there. */
    --uni-muted:     #5F5C54;
    --uni-on-solid:  #ffffff;
    --uni-step:      130ms cubic-bezier(0.16, 1, 0.3, 1);
  }

  html[data-sw-theme="dark"] body {
    --uni-page:      #131110;
    --uni-panel:     #221F1A;
    --uni-bar:       #2A2620;
    --uni-sunk:      #1B1815;
    --uni-line:      #383327;
    --uni-line-soft: #2C2821;

    --uni-done:      #57C98A;
    --uni-done-bg:   #17301F;
    --uni-now-bg:    #1C2946;
    --uni-next:      #9A9285;
    --uni-next-bg:   #2C2821;
    --uni-rail-track: #322D25;
    --uni-muted:     var(--sw-color-text-muted);
    --uni-on-solid:  #131110;
  }

  /* Chrome neutralization — the course canvas IS the page, not a card inside
     one. Holds the same column whether the host set sw-layout-fluid (canvas)
     or sw-layout-default (standalone). */
  /* Bottom padding is a safe area, not slack: the canvas host floats its own
     "Save as doc" control over the bottom-right corner, and at narrow widths it
     otherwise lands on the last line of content. */
  body[class*="sw-layout-"] {
    max-width: 860px; margin: 0 auto;
    padding: 26px 24px 120px;
    background: var(--uni-page);
    font-size: 16px;
  }

  /* Visually hidden, still announced — the done mark replaces its number with a
     glyph, so without this a screen reader gets nothing for a completed step. */
  .uni-sr {
    position: absolute; width: 1px; height: 1px;
    margin: -1px; padding: 0; overflow: hidden;
    clip: rect(0 0 0 0); clip-path: inset(50%); white-space: nowrap;
  }
  #app-container {
    background: transparent; border: none; box-shadow: none;
    padding: 0; margin: 0;
  }

  /* Browser surfaces the design still owns */
  body ::selection {
    background: color-mix(in srgb, var(--uni-now) 24%, transparent);
    color: var(--uni-ink);
  }
  body *:focus-visible {
    outline: 2px solid var(--uni-now);
    outline-offset: 2px;
    border-radius: 4px;
  }
  body { scrollbar-width: thin; scrollbar-color: var(--uni-line) transparent; }
  body ::-webkit-scrollbar { width: 11px; height: 11px; }
  body ::-webkit-scrollbar-thumb {
    background: var(--uni-line); border-radius: 6px;
    border: 3px solid var(--uni-page);
  }
  body ::-webkit-scrollbar-track { background: transparent; }

  /* Drawn icon set — one family, masked so it inherits currentColor */
  .uni-i {
    display: inline-block; width: 1em; height: 1em;
    background-color: currentColor; flex: none;
    -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;
    -webkit-mask-position: center; mask-position: center;
    -webkit-mask-size: contain; mask-size: contain;
  }
  .uni-i--check {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
  }
  .uni-i--play {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M5.1 3.3l7.4 4.35a.4.4 0 0 1 0 .7L5.1 12.7A.4.4 0 0 1 4.5 12.35V3.65a.4.4 0 0 1 .6-.35z' fill='%23000'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M5.1 3.3l7.4 4.35a.4.4 0 0 1 0 .7L5.1 12.7A.4.4 0 0 1 4.5 12.35V3.65a.4.4 0 0 1 .6-.35z' fill='%23000'/%3E%3C/svg%3E");
  }
  .uni-i--repeat {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M13.1 8a5.1 5.1 0 1 1-1.68-3.78'/%3E%3Cpath d='M13.3 2.9v2.6h-2.6'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M13.1 8a5.1 5.1 0 1 1-1.68-3.78'/%3E%3Cpath d='M13.3 2.9v2.6h-2.6'/%3E%3C/svg%3E");
  }
  .uni-i--back {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12.4 8H4'/%3E%3Cpath d='M7.6 4.4L4 8l3.6 3.6'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12.4 8H4'/%3E%3Cpath d='M7.6 4.4L4 8l3.6 3.6'/%3E%3C/svg%3E");
  }
  .uni-i--lock {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Crect x='3.3' y='6.9' width='9.4' height='6.6' rx='1.4'/%3E%3Cpath d='M5.6 6.9V5.1a2.4 2.4 0 0 1 4.8 0v1.8'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Crect x='3.3' y='6.9' width='9.4' height='6.6' rx='1.4'/%3E%3Cpath d='M5.6 6.9V5.1a2.4 2.4 0 0 1 4.8 0v1.8'/%3E%3C/svg%3E");
  }

  /* ---- App band: says what this is, in one glance ----------------------- */
  body .sw-topbar {
    border-bottom: none;
    padding: 0; margin: 0 0 8px;
    background: transparent;
  }
  body .sw-topbar-wordmark {
    font-family: var(--sw-font-display);
    font-size: 27px; font-weight: 600;
    letter-spacing: -0.015em; text-transform: none;
    color: var(--uni-ink);
  }
  body .sw-topbar-crumb,
  body .sw-topbar-separator { font-size: 14px; color: var(--uni-muted); }
  body .sw-topbar-crumb--active { color: var(--uni-ink); font-weight: 650; }
  .uni-tagline {
    display: block; max-width: 62ch;
    font-size: 15px; line-height: 1.55; color: var(--uni-muted);
    margin: 0 0 30px;
  }

  /* theme_toggle ships an emoji glyph + a "System/Dark/Light" word. The panel
     wants a quiet 30px control, so the label is dropped and the two x-show icon
     spans are re-drawn from the same masked-SVG family as the rest of the page
     (span 1 = dark/moon, span 2 = light/sun). */
  body .sw-theme-toggle__label { display: none; }
  body .sw-theme-toggle__btn {
    background: var(--uni-panel); border: 1px solid var(--uni-line);
    border-radius: 7px; padding: 7px; box-shadow: none;
    color: var(--uni-muted); line-height: 0;
    transition: border-color var(--uni-step), color var(--uni-step);
  }
  body .sw-theme-toggle__btn:hover { border-color: var(--uni-now); color: var(--uni-now); }
  body .sw-theme-toggle__icon {
    display: inline-block; width: 16px; height: 16px; font-size: 0;
    background-color: currentColor;
    -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;
    -webkit-mask-position: center; mask-position: center;
    -webkit-mask-size: contain; mask-size: contain;
  }
  body .sw-theme-toggle__icon:nth-of-type(1) {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M13.4 9.6A5.8 5.8 0 0 1 6.4 2.6a5.8 5.8 0 1 0 7 7z'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M13.4 9.6A5.8 5.8 0 0 1 6.4 2.6a5.8 5.8 0 1 0 7 7z'/%3E%3C/svg%3E");
  }
  body .sw-theme-toggle__icon:nth-of-type(2) {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Ccircle cx='8' cy='8' r='3.1'/%3E%3Cpath d='M8 1.2v1.6M8 13.2v1.6M1.2 8h1.6M13.2 8h1.6M3.2 3.2l1.1 1.1M11.7 11.7l1.1 1.1M12.8 3.2l-1.1 1.1M4.3 11.7l-1.1 1.1'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Ccircle cx='8' cy='8' r='3.1'/%3E%3Cpath d='M8 1.2v1.6M8 13.2v1.6M1.2 8h1.6M13.2 8h1.6M3.2 3.2l1.1 1.1M11.7 11.7l1.1 1.1M12.8 3.2l-1.1 1.1M4.3 11.7l-1.1 1.1'/%3E%3C/svg%3E");
  }

  /* ---- Course panel ----------------------------------------------------- */
  body .sw-card.uni-course {
    background: var(--uni-panel);
    border: 1px solid var(--uni-line);
    border-left: 1px solid var(--uni-line);
    border-radius: 12px;
    padding: 0; margin: 0 0 14px;
    box-shadow: 0 1px 2px rgba(24, 23, 20, 0.05), 0 6px 18px -10px rgba(24, 23, 20, 0.16);
    overflow: hidden;
  }
  html[data-sw-theme="dark"] body .sw-card.uni-course {
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.35), 0 8px 22px -12px rgba(0, 0, 0, 0.6);
  }
  body .sw-card.uni-course--dormant {
    background: transparent;
    border-color: var(--uni-line);
    box-shadow: none;
  }

  /* Title bar — the panel names itself at a size nobody scrolls past */
  body .sw-card-header.uni-course__bar {
    display: flex; align-items: center; gap: 12px;
    background: var(--uni-bar);
    border-bottom: 1px solid var(--uni-line);
    padding: 16px 22px; margin: 0;
  }
  body .uni-course--dormant .sw-card-header.uni-course__bar {
    background: transparent; border-bottom: none;
    padding: 13px 20px 0;
  }
  body .sw-card.uni-course--dormant { margin-bottom: 10px; }
  .uni-course__dot {
    width: 9px; height: 9px; border-radius: 50%; flex: none;
    background: var(--uni-now);
    box-shadow: 0 0 0 3.5px color-mix(in srgb, var(--uni-now) 20%, transparent);
  }
  .uni-course--dormant .uni-course__dot {
    background: transparent; border: 1.5px solid var(--uni-next);
    box-shadow: none;
  }
  body.sw-theme-doc h2.uni-course__name {
    font-family: var(--sw-font-body);
    font-size: 20px; font-weight: 700; line-height: 1.2;
    letter-spacing: -0.012em; color: var(--uni-ink);
    margin: 0; padding: 0; border-bottom: none; flex: 1 1 auto;
  }
  body.sw-theme-doc .uni-course--dormant h2.uni-course__name {
    font-size: 18px; font-weight: 650; color: var(--uni-muted);
  }
  .uni-chip {
    font-size: 11.5px; font-weight: 700; letter-spacing: 0.07em;
    text-transform: uppercase; padding: 5px 9px; border-radius: 5px;
    flex: none; white-space: nowrap;
    background: var(--uni-now-bg); color: var(--uni-now);
  }
  .uni-chip--soon {
    display: inline-flex; align-items: center; gap: 5px;
    background: var(--uni-next-bg); color: var(--uni-next);
  }
  .uni-chip--soon .uni-i { font-size: 12px; }
  /* Aligned to the course name, not the card edge — the dot column is a gutter */
  .uni-course__blurb {
    display: block; font-size: 14.5px; line-height: 1.5;
    color: var(--uni-muted); padding: 3px 20px 14px 41px;
    max-width: 70ch;
  }

  body .sw-card-body.uni-course__body { padding: 0; }

  /* ---- Resume band: course state, inside the course --------------------- */
  .uni-resume {
    background: var(--uni-sunk);
    border-bottom: 1px solid var(--uni-line);
    padding: 22px 22px 20px;
  }
  .uni-resume__lead {
    font-family: var(--sw-font-display);
    font-size: clamp(1.35rem, 3.4vw, 1.55rem);
    font-weight: 600; line-height: 1.16; letter-spacing: -0.016em;
    text-wrap: balance; color: var(--uni-ink); margin: 0 0 5px;
  }
  .uni-resume__sub {
    display: block; max-width: 58ch;
    font-size: 15px; line-height: 1.5; color: var(--uni-muted);
    margin-bottom: 18px;
  }
  .uni-actions { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
  .uni-resume .uni-actions { margin-bottom: 20px; }

  /* ---- Buttons: three weights, one ladder ------------------------------- */
  body .sw-button.uni-btn {
    display: inline-flex; align-items: center; gap: 7px;
    font-family: var(--sw-font-body);
    font-size: 14px; font-weight: 650; line-height: 1;
    padding: 10px 15px; border-radius: 7px;
    border: 1px solid transparent; background: transparent;
    box-shadow: none; text-transform: none;
    color: var(--uni-ink); cursor: pointer;
    transition: background var(--uni-step), color var(--uni-step),
                border-color var(--uni-step), transform var(--uni-step);
  }
  body .sw-button.uni-btn .uni-i { font-size: 14px; }
  body .sw-button.uni-btn--run {
    background: var(--uni-now); color: var(--uni-on-solid);
    padding: 12px 20px; font-size: 15px; font-weight: 650;
    box-shadow: 0 1px 2px color-mix(in srgb, var(--uni-now) 30%, transparent);
  }
  body .sw-button.uni-btn--run:hover {
    background: var(--sw-color-primary-hover); transform: translateY(-1px);
  }
  body .sw-button.uni-btn--outline {
    border-color: var(--uni-line); background: var(--uni-panel);
    color: var(--uni-ink);
  }
  body .sw-button.uni-btn--outline:hover { border-color: var(--uni-now); color: var(--uni-now); }
  body .sw-button.uni-btn--quiet {
    color: var(--uni-muted); font-weight: 600;
    padding: 9px 12px; font-size: 13.5px;
  }
  body .sw-button.uni-btn--quiet:hover { color: var(--uni-now); background: var(--uni-now-bg); }

  /* ---- Progress rail: position in a sequence, not a percentage ---------- */
  .uni-rail { display: flex; align-items: center; gap: 13px; }
  .uni-rail__track { display: flex; align-items: center; gap: 5px; }
  .uni-rail__seg { width: 30px; height: 6px; border-radius: 3px; background: var(--uni-rail-track); }
  .uni-rail__seg--done { background: var(--uni-done); }
  .uni-rail__seg--current { background: var(--uni-now); width: 40px; }
  .uni-rail__label {
    font-size: 13px; font-weight: 600; color: var(--uni-muted);
    font-variant-numeric: tabular-nums;
  }

  /* ---- Step rows -------------------------------------------------------- */
  .uni-step {
    display: grid;
    grid-template-columns: 28px 1fr auto;
    align-items: center;
    gap: 0 15px;
    padding: 15px 22px;
    border-bottom: 1px solid var(--uni-line-soft);
    transition: background var(--uni-step);
  }
  .uni-step:last-child { border-bottom: none; }
  .uni-step__mark {
    width: 28px; height: 28px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    font-size: 13.5px; font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
  .uni-step--done .uni-step__mark {
    background: var(--uni-done); color: var(--uni-on-solid);
  }
  .uni-step--done .uni-step__mark .uni-i { font-size: 16px; }
  .uni-step--current .uni-step__mark {
    background: var(--uni-now); color: var(--uni-on-solid);
    box-shadow: 0 0 0 4px color-mix(in srgb, var(--uni-now) 18%, transparent);
  }
  /* Solid ring, not a tint: at 50% the boundary fell under 3:1 */
  .uni-step--todo .uni-step__mark {
    background: transparent; color: var(--uni-next);
    border: 1.5px solid var(--uni-next);
  }
  /* h3, not h2: a step is nested under its course's h2 name */
  body.sw-theme-doc h3.uni-step__title {
    font-family: var(--sw-font-body);
    font-size: 17px; font-weight: 650; line-height: 1.28;
    letter-spacing: -0.008em; color: var(--uni-ink);
    margin: 0 0 3px; padding: 0; border-bottom: none;
  }
  .uni-step__payoff {
    display: block; font-size: 14.5px; line-height: 1.45;
    color: var(--uni-muted); max-width: 54ch;
  }
  .uni-step--current { background: var(--uni-now-bg); }
  body.sw-theme-doc .uni-step--done h3.uni-step__title {
    color: var(--uni-muted); font-weight: 600;
  }

  /* ---- Shelf divider ---------------------------------------------------- */
  .uni-divider {
    display: flex; align-items: center; gap: 14px;
    margin: 38px 0 16px;
  }
  .uni-divider__label {
    font-size: 15px; font-weight: 650; color: var(--uni-ink);
    letter-spacing: -0.005em; flex: none;
  }
  .uni-divider__rule { height: 1px; background: var(--uni-line); flex: 1 1 auto; }

  /* ---- Tutorial pointer ------------------------------------------------- */
  .uni-note {
    margin-top: 30px; padding: 16px 20px;
    background: var(--uni-sunk);
    border: 1px solid var(--uni-line-soft);
    border-radius: 10px;
    font-size: 14.5px; line-height: 1.6; color: var(--uni-muted);
    max-width: 74ch;
  }
  .uni-note code {
    font-family: var(--sw-font-mono); font-size: 13.5px;
    background: var(--uni-panel); border: 1px solid var(--uni-line);
    border-radius: 4px; padding: 2px 6px; color: var(--uni-ink);
  }

  /* ---- Step screen ------------------------------------------------------ */
  .uni-context {
    display: flex; align-items: center; gap: 14px; flex-wrap: wrap;
    margin-bottom: 16px;
  }
  .uni-back {
    display: inline-flex; align-items: center; gap: 7px;
    font-size: 14px; font-weight: 600; color: var(--uni-muted);
    background: var(--uni-panel); border: 1px solid var(--uni-line);
    border-radius: 7px; padding: 8px 13px; text-decoration: none;
    transition: color var(--uni-step), border-color var(--uni-step);
  }
  .uni-back:hover { color: var(--uni-now); border-color: var(--uni-now); }
  .uni-context__spacer { flex: 1 1 auto; }
  .uni-count {
    font-size: 13px; font-weight: 600; color: var(--uni-muted);
    font-variant-numeric: tabular-nums;
  }

  body .sw-card-header.uni-step__bar { gap: 14px; align-items: center; }
  .uni-step__mark--hero {
    background: var(--uni-now); color: var(--uni-on-solid);
    width: 34px; height: 34px; font-size: 15px;
    box-shadow: 0 0 0 4px color-mix(in srgb, var(--uni-now) 18%, transparent);
  }
  body.sw-theme-doc h1.uni-title {
    font-family: var(--sw-font-display);
    font-size: clamp(1.6rem, 4vw, 1.95rem);
    font-weight: 600; line-height: 1.15; letter-spacing: -0.018em;
    text-wrap: balance; color: var(--uni-ink);
    margin: 0; padding: 0; border-bottom: none; flex: 1 1 auto;
  }

  .uni-section { padding: 0 22px; }
  .uni-section:first-child { padding-top: 24px; }
  .uni-section:last-of-type { padding-bottom: 8px; }
  /* Section rhythm: a label owns the space above it, not below it */
  .uni-label {
    display: block;
    font-size: 15px; font-weight: 650; color: var(--uni-ink);
    letter-spacing: -0.005em; margin: 32px 0 11px;
  }
  .uni-section:first-child > .uni-label { margin-top: 0; }
  .uni-prose { max-width: 66ch; font-size: 16px; line-height: 1.6; color: var(--uni-ink); }
  .uni-prose p { margin: 0 0 0.8em; }
  .uni-prose p:last-child { margin-bottom: 0; }

  /* The prompt is a payload, so it gets a payload's chrome: labelled bar,
     sunk ground, monospace only where it is doing verbatim work. */
  .uni-promptbox {
    border: 1px solid var(--uni-line); border-radius: 9px;
    background: var(--uni-sunk); overflow: hidden; margin: 30px 0 18px;
  }
  .uni-promptbox__bar {
    display: flex; align-items: center; justify-content: space-between; gap: 12px;
    background: var(--uni-bar); border-bottom: 1px solid var(--uni-line);
    padding: 9px 15px;
    font-size: 12px; font-weight: 700; letter-spacing: 0.06em;
    text-transform: uppercase; color: var(--uni-muted);
  }
  .uni-prompt {
    display: block;
    font-family: var(--sw-font-mono);
    font-size: 13px; line-height: 1.65;
    white-space: pre-wrap; color: var(--uni-ink);
    padding: 16px 17px; overflow-x: auto;
  }

  .uni-payoff ul { list-style: none; padding: 0; margin: 0; max-width: 64ch; }
  .uni-payoff li {
    display: grid; grid-template-columns: 20px 1fr; gap: 11px;
    font-size: 15px; line-height: 1.5; color: var(--uni-ink);
    padding: 7px 0;
  }
  .uni-payoff li::before {
    content: ""; margin-top: 4px;
    width: 15px; height: 15px;
    background-color: var(--uni-done);
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
    -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;
    -webkit-mask-size: contain; mask-size: contain;
  }

  .uni-foot {
    display: flex; align-items: center; gap: 14px;
    background: var(--uni-sunk); border-top: 1px solid var(--uni-line);
    padding: 16px 22px; margin-top: 22px;
  }
  .uni-foot__hint { font-size: 14px; color: var(--uni-muted); }
  .uni-foot__spacer { flex: 1 1 auto; }
  @media (max-width: 620px) {
    .uni-foot { flex-wrap: wrap; }
    .uni-foot__spacer { display: none; }
  }

  /* ---- Review chrome: the two screens live behind tabs ------------------ */
  body .sw-tabs-list, body .sw-tab-list { margin-bottom: 28px; }

  @media (max-width: 700px) {
    body[class*="sw-layout-"] { padding-bottom: 150px; }
  }
  @media (max-width: 620px) {
    .uni-step { grid-template-columns: 28px 1fr; row-gap: 10px; }
    .uni-step > .sw-button { grid-column: 2; justify-self: start; }
    .uni-resume__lead { font-size: 1.3rem; }
  }

  @media (prefers-reduced-motion: reduce) {
    body * { transition-duration: 0.01ms !important; }
  }
CSS

# The literal payload the canvas sends to the worker session. Shown verbatim on
# the step screen — no hidden prompt, no paraphrase.
_step3_prompt = <<~PROMPT.strip
  Using stream_weaver, write a small app with a radio_group and a button
  that stores the choice in state and keeps rendering after each click.
  Run it and click through it.

  Then show me the same form driven by `canvas-wait`, so the script blocks
  until I answer and prints my answer as JSON in the terminal.
PROMPT

_body = proc do
  use_theme :doc
  use_layout :default
  use_stylesheet _css

  tabs :screen, variant: :line do
    # =====================================================================
    # Screen 1 — Course list. Every course is a panel; course state lives
    # inside its own panel, never above the shelf.
    # =====================================================================
    tab "Course list" do
      topbar(wordmark: "StreamWeaver University") do
        theme_toggle mode: :auto
      end
      phrase "Learn StreamWeaver by running it. Every step is a real app that appears " \
             "in this pane while you stay in your terminal.",
             class: "uni-tagline"

      # ---- Getting Started: open, and holding its own state --------------
      card(depth: :elevated, class: "uni-course") do
        card_header(class: "uni-course__bar") do
          div(class: "uni-course__dot") {}
          header2 "Getting Started", class: "uni-course__name"
          phrase "In progress", class: "uni-chip"
        end

        card_body(class: "uni-course__body") do
          div(class: "uni-resume") do
            phrase "Pick up at step 3.", class: "uni-resume__lead"
            phrase "One form, two modes — the same six lines of DSL, running live and blocking.",
                   class: "uni-resume__sub"

            div(class: "uni-actions") do
              button "Run step 3", submit: false, key: "hero-run", class: "uni-btn uni-btn--run"
              button "Repeat step 2", submit: false, key: "hero-repeat", class: "uni-btn uni-btn--quiet"
            end

            div(class: "uni-rail") do
              div(class: "uni-rail__track") do
                div(class: "uni-rail__seg uni-rail__seg--done") {}
                div(class: "uni-rail__seg uni-rail__seg--done") {}
                div(class: "uni-rail__seg uni-rail__seg--current") {}
                div(class: "uni-rail__seg") {}
                div(class: "uni-rail__seg") {}
              end
              phrase "2 of 5 done", class: "uni-rail__label"
            end
          end

          steps = [
            ["1", "A card in your pane",
             "Push a card to the canvas beside your terminal without writing any HTML.", :done],
            ["2", "Six lines of Ruby",
             "Run a real app and watch the block re-run on every click.", :done],
            ["3", "One form, two modes",
             "The same form stays live, or blocks and waits for one answer.", :current],
            ["4", "A doc that writes itself",
             "Watch a script append sections, then save the result as a document.", :todo],
            ["5", "Take the doc with you",
             "Export to org, drop it in a gist, read it anywhere.", :todo]
          ]

          steps.each do |num, title, payoff, state|
            div(class: "uni-step uni-step--#{state}") do
              div(class: "uni-step__mark") do
                if state == :done
                  phrase "", class: "uni-i uni-i--check"
                  phrase "Step #{num}, done", class: "uni-sr"
                else
                  phrase num
                  phrase(state == :current ? ", current step" : ", not started", class: "uni-sr")
                end
              end
              div do
                header3 title, class: "uni-step__title"
                phrase payoff, class: "uni-step__payoff"
              end
              case state
              when :done
                button "Repeat", submit: false, key: "rep-#{num}", class: "uni-btn uni-btn--quiet"
              when :current
                button "Run", submit: false, key: "run-#{num}", class: "uni-btn uni-btn--outline"
              else
                button "Run", submit: false, key: "run-#{num}", class: "uni-btn uni-btn--quiet"
              end
            end
          end
        end
      end

      # ---- The shelf: closed, dormant, no controls -----------------------
      div(class: "uni-divider") do
        phrase "In the works", class: "uni-divider__label"
        div(class: "uni-divider__rule") {}
      end

      [
        ["Docs deep dive", "Org export, gists, and the reader extension, end to end."],
        ["Canvas modes", "Stateful, blocking, and streaming — when to reach for each."],
        ["Skills and panels", "Teach your agent to drive the canvas without you."]
      ].each do |name, blurb|
        card(depth: :recessed, class: "uni-course uni-course--dormant") do
          card_header(class: "uni-course__bar") do
            div(class: "uni-course__dot") {}
            header2 name, class: "uni-course__name"
            div(class: "uni-chip uni-chip--soon") do
              phrase "", class: "uni-i uni-i--lock"
              phrase "Soon"
            end
          end
          phrase blurb, class: "uni-course__blurb"
        end
      end

      md "Looking for the old component tour? Run `streamweaver tutorial` — the classic " \
         "walkthrough of every component. Older than these courses, and being refreshed.",
         class: "uni-note"
    end

    # =====================================================================
    # Screen 2 — Step screen
    # =====================================================================
    tab "Step screen" do
      topbar(wordmark: "StreamWeaver University", breadcrumbs: ["Getting Started", "Step 3"]) do
        theme_toggle mode: :auto
      end
      phrase "Learn StreamWeaver by running it. Every step is a real app that appears " \
             "in this pane while you stay in your terminal.",
             class: "uni-tagline"

      div(class: "uni-context") do
        div(class: "uni-back") do
          phrase "", class: "uni-i uni-i--back"
          phrase "All steps"
        end
        div(class: "uni-rail") do
          div(class: "uni-rail__track") do
            div(class: "uni-rail__seg uni-rail__seg--done") {}
            div(class: "uni-rail__seg uni-rail__seg--done") {}
            div(class: "uni-rail__seg uni-rail__seg--current") {}
            div(class: "uni-rail__seg") {}
            div(class: "uni-rail__seg") {}
          end
          phrase "2 of 5 done", class: "uni-rail__label"
        end
        div(class: "uni-context__spacer") {}
        phrase "Step 3 of 5", class: "uni-count"
      end

      card(depth: :elevated, class: "uni-course") do
        card_header(class: "uni-course__bar uni-step__bar") do
          div(class: "uni-step__mark uni-step__mark--hero") { phrase "3" }
          header1 "One form, two modes", class: "uni-title"
        end

        card_body(class: "uni-course__body") do
          div(class: "uni-section") do
            phrase "Why this matters", class: "uni-label"
            md "Terminal tools make you pick one: a form that stays live, or a prompt that " \
               "blocks until you answer. StreamWeaver runs the same form both ways.\n\n" \
               "You will write it once, change the call that consumes it, and watch the " \
               "behaviour flip. That is the thing a TUI cannot do.",
               class: "uni-prose"
          end

          div(class: "uni-section") do
            div(class: "uni-promptbox") do
              div(class: "uni-promptbox__bar") do
                phrase "The prompt your worker session receives"
              end
              phrase _step3_prompt, class: "uni-prompt"
            end

            div(class: "uni-actions") do
              button "Run in worker session", submit: false, key: "step-run",
                     class: "uni-btn uni-btn--run"
              copy_button "Copy prompt", text: _step3_prompt,
                          copied_label: "Copied", class: "uni-btn uni-btn--outline"
            end
          end

          div(class: "uni-section") do
            phrase "What you should see", class: "uni-label"
            md "- Click a different option and the page re-renders in place. Nothing blocks.\n" \
               "- The second version freezes your terminal until you click, then prints your answer as JSON.\n" \
               "- Same six lines of DSL. Only the call that consumes the form changed.",
               class: "uni-payoff"
          end

          # Two exits, deliberately unequal: marking done is the one that writes
          # the ledger, so it keeps the outlined weight; moving on without
          # finishing is allowed but quiet.
          div(class: "uni-foot") do
            button "Mark step 3 done", submit: false, key: "step-done",
                   class: "uni-btn uni-btn--outline"
            phrase "Unlocks step 4.", class: "uni-foot__hint"
            div(class: "uni-foot__spacer") {}
            button "Next: step 4", submit: false, key: "step-next",
                   class: "uni-btn uni-btn--quiet"
          end
        end
      end
    end
  end
end

if respond_to?(:use_theme)
  # canvas-push / canvas-read: self is already a StreamWeaver::App
  instance_eval(&_body)
elsif __FILE__ == $PROGRAM_NAME
  require_relative "../../../lib/stream_weaver"
  app("StreamWeaver University") { instance_eval(&_body) }.run!
end
