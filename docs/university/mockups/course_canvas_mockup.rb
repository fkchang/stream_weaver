# streamweaver-doc: v1
#
# StreamWeaver University — course canvas mockup (story: course-canvas-design)
#
# Two screens of the app `streamweaver get-started` lands on:
#   1. Course list  — Getting Started (enabled, 5 steps) + the shelf of future courses
#   2. Step screen  — one step: why it matters, the exact prompt, Run / Copy, payoff, done
#
# Dual-mode single file (shared-DSL pattern):
#   canvas :  streamweaver canvas-push university-design < docs/university/mockups/course_canvas_mockup.rb
#   standalone: ruby docs/university/mockups/course_canvas_mockup.rb
#
# Everything visual rides `--sw-*` tokens from the :doc theme, so the dark
# variant needs zero dark-mode rules of its own. Buttons are `submit: false`
# (display-only) — this is a mockup, not the built app.

# ---------------------------------------------------------------------------
# One stylesheet. Targets sw- hooks (docs/theming-hooks.md) plus `uni-` classes
# for the handful of elements that have no component. Inlined as literal CSS
# rather than a sibling .css file because canvas-push has no route to serve a
# referenced asset across processes (see App#use_stylesheet, stream_weaver-9uk).
# ---------------------------------------------------------------------------
_css = <<~CSS
  body {
    /* Derived tokens — every one resolves through the :doc theme, light + dark */
    --uni-ink:        var(--sw-color-text);
    --uni-muted:      var(--sw-color-text-muted);
    --uni-hair:       var(--sw-color-border);
    --uni-rule:       var(--sw-color-border-strong);
    --uni-accent:     var(--sw-color-accent);
    --uni-accent-bg:  var(--sw-color-accent-light);
    /* white on blue in light, near-black on pale blue in dark — one rule, both legible */
    --uni-on-accent:  var(--sw-color-secondary-foreground);
    --uni-surface:    var(--sw-color-bg-elevated);
    --uni-step:       120ms cubic-bezier(0.16, 1, 0.3, 1);
  }

  /* Chrome neutralization — the course canvas IS the page, not a card inside
     one. Holds the same reading column whether the host set sw-layout-fluid
     (canvas) or sw-layout-default (standalone). */
  body[class*="sw-layout-"] {
    max-width: 840px; margin: 0 auto;
    padding: 30px 26px 90px;
    background: var(--sw-color-bg);
  }
  #app-container {
    background: transparent; border: none; box-shadow: none;
    padding: 0; margin: 0;
  }

  /* Browser surfaces the design still owns */
  body ::selection {
    background: color-mix(in srgb, var(--uni-accent) 22%, transparent);
    color: var(--uni-ink);
  }
  body *:focus-visible {
    outline: 2px solid var(--uni-accent);
    outline-offset: 2px;
    border-radius: 3px;
  }
  body { scrollbar-width: thin; scrollbar-color: var(--uni-rule) transparent; }
  body ::-webkit-scrollbar { width: 10px; height: 10px; }
  body ::-webkit-scrollbar-thumb {
    background: var(--uni-rule); border-radius: 6px;
    border: 3px solid var(--sw-color-bg);
  }
  body ::-webkit-scrollbar-track { background: transparent; }

  /* Drawn icon set — one family, 1.6 stroke, masked so it inherits currentColor */
  .uni-i {
    display: inline-block; width: 1em; height: 1em;
    background-color: currentColor; flex: none;
    -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;
    -webkit-mask-position: center; mask-position: center;
    -webkit-mask-size: contain; mask-size: contain;
  }
  .uni-i--check {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
  }
  .uni-i--play {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M5.1 3.3l7.4 4.35a.4.4 0 0 1 0 .7L5.1 12.7A.4.4 0 0 1 4.5 12.35V3.65a.4.4 0 0 1 .6-.35z' fill='%23000'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M5.1 3.3l7.4 4.35a.4.4 0 0 1 0 .7L5.1 12.7A.4.4 0 0 1 4.5 12.35V3.65a.4.4 0 0 1 .6-.35z' fill='%23000'/%3E%3C/svg%3E");
  }
  .uni-i--repeat {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M13.1 8a5.1 5.1 0 1 1-1.68-3.78'/%3E%3Cpath d='M13.3 2.9v2.6h-2.6'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M13.1 8a5.1 5.1 0 1 1-1.68-3.78'/%3E%3Cpath d='M13.3 2.9v2.6h-2.6'/%3E%3C/svg%3E");
  }
  .uni-i--back {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12.4 8H4'/%3E%3Cpath d='M7.6 4.4L4 8l3.6 3.6'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12.4 8H4'/%3E%3Cpath d='M7.6 4.4L4 8l3.6 3.6'/%3E%3C/svg%3E");
  }

  /* ---- App chrome ------------------------------------------------------- */
  body .sw-topbar {
    border-bottom: 1px solid var(--uni-hair);
    padding: 0 0 12px;
    margin-bottom: 34px;
    background: transparent;
  }
  body .sw-topbar-wordmark {
    font-family: var(--sw-font-body);
    font-size: 12px; font-weight: 600;
    letter-spacing: 0.075em; text-transform: uppercase;
    color: var(--uni-muted);
  }
  body .sw-topbar-crumb,
  body .sw-topbar-separator { font-size: 12px; color: var(--uni-muted); }
  body .sw-topbar-crumb--active { color: var(--uni-ink); font-weight: 600; }

  /* theme_toggle ships an emoji icon + a "System/Dark/Light" word. The course
     canvas wants a quiet 26px control, so the label is dropped and the two
     x-show icon spans are re-drawn from the same masked-SVG family as the rest
     of the page (span 1 = dark/moon, span 2 = light/sun). */
  body .sw-theme-toggle__label { display: none; }
  body .sw-theme-toggle__btn {
    background: transparent; border: 1px solid var(--uni-hair);
    border-radius: 5px; padding: 5px; box-shadow: none;
    color: var(--uni-muted); line-height: 0;
    transition: border-color var(--uni-step), color var(--uni-step);
  }
  body .sw-theme-toggle__btn:hover { border-color: var(--uni-accent); color: var(--uni-accent); }
  body .sw-theme-toggle__icon {
    display: inline-block; width: 15px; height: 15px; font-size: 0;
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

  /* ---- Hero: the one thing to do next ----------------------------------- */
  .uni-hero { margin: 0 0 30px; }
  .uni-hero__lead {
    font-family: var(--sw-font-display);
    font-size: clamp(1.7rem, 4.2vw, 2.05rem);
    font-weight: 600; line-height: 1.14;
    letter-spacing: -0.018em;
    text-wrap: balance;
    color: var(--uni-ink);
    margin: 0 0 6px;
  }
  .uni-hero__sub {
    display: block; max-width: 60ch;
    font-size: 15px; line-height: 1.55; color: var(--uni-muted);
    margin-bottom: 20px;
  }
  .uni-actions { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; margin-bottom: 22px; }

  /* ---- Buttons ---------------------------------------------------------- */
  body .sw-button.uni-btn {
    display: inline-flex; align-items: center; gap: 7px;
    font-family: var(--sw-font-body);
    font-size: 13.5px; font-weight: 600; line-height: 1;
    padding: 9px 15px; border-radius: 5px;
    border: 1px solid transparent; background: transparent;
    box-shadow: none; text-transform: none;
    color: var(--uni-ink); cursor: pointer;
    transition: background var(--uni-step), color var(--uni-step), border-color var(--uni-step);
  }
  body .sw-button.uni-btn .uni-i { font-size: 14px; }
  body .sw-button.uni-btn--run {
    background: var(--uni-accent); color: var(--uni-on-accent);
    padding: 11px 19px; font-size: 14px;
  }
  body .sw-button.uni-btn--run:hover { background: var(--sw-color-primary-hover); }
  body .sw-button.uni-btn--outline {
    border-color: var(--uni-rule); color: var(--uni-ink);
  }
  body .sw-button.uni-btn--outline:hover { border-color: var(--uni-accent); color: var(--uni-accent); }
  body .sw-button.uni-btn--quiet {
    color: var(--uni-muted); font-weight: 500; padding: 7px 11px;
    border-color: color-mix(in srgb, var(--uni-rule) 45%, transparent);
  }
  body .sw-button.uni-btn--quiet:hover { color: var(--uni-accent); background: var(--uni-accent-bg); }

  /* ---- Progress rail ---------------------------------------------------- */
  .uni-rail { display: flex; align-items: center; gap: 12px; margin-bottom: 40px; }
  .uni-rail__track { display: flex; align-items: center; gap: 5px; }
  .uni-rail__seg {
    width: 26px; height: 4px; border-radius: 2px;
    background: var(--uni-hair);
  }
  .uni-rail__seg--done { background: var(--uni-accent); opacity: 0.55; }
  .uni-rail__seg--current { background: var(--uni-accent); width: 34px; }
  .uni-rail__label {
    font-size: 12px; font-weight: 500; color: var(--uni-muted);
    font-variant-numeric: tabular-nums;
  }

  /* ---- Section labels --------------------------------------------------- */
  .uni-micro {
    display: block;
    font-size: 11px; font-weight: 700; letter-spacing: 0.1em;
    text-transform: uppercase; color: var(--uni-muted);
    margin: 34px 0 10px;
  }
  .uni-micro:first-child { margin-top: 0; }

  /* ---- Step list -------------------------------------------------------- */
  .uni-steps { border-top: 1px solid var(--uni-hair); margin-bottom: 8px; }
  .uni-step {
    display: grid;
    grid-template-columns: 16px 1.6ch 1fr auto;
    align-items: center;
    gap: 0 13px;
    padding: 13px 14px;
    border-bottom: 1px solid var(--uni-hair);
  }
  .uni-step__mark {
    width: 15px; height: 15px; border-radius: 50%;
    border: 1.5px solid var(--uni-rule);
    display: flex; align-items: center; justify-content: center;
    color: transparent;
  }
  .uni-step__mark .uni-i { font-size: 11px; }
  .uni-step--done .uni-step__mark {
    background: var(--uni-accent); border-color: var(--uni-accent);
    color: var(--uni-on-accent);
  }
  .uni-step--current .uni-step__mark {
    border-color: var(--uni-accent); border-width: 4.5px;
  }
  .uni-step__num {
    font-size: 13px; font-weight: 500; color: var(--uni-muted);
    font-variant-numeric: tabular-nums; text-align: right;
  }
  /* h2 for a correct document outline; the theme's h2 rule (display face,
     1.45rem, section underline) is not what a list row wants. */
  body .uni-step__title {
    font-family: var(--sw-font-body);
    font-size: 14.5px; font-weight: 600; line-height: 1.3;
    color: var(--uni-ink); margin: 0 0 2px;
    border-bottom: none; padding-bottom: 0;
  }
  .uni-step__payoff {
    display: block; font-size: 13px; line-height: 1.45;
    color: var(--uni-muted); max-width: 56ch;
  }
  .uni-step--current { background: var(--uni-accent-bg); }
  .uni-step--current .uni-step__num { color: var(--uni-accent); font-weight: 600; }
  .uni-step--done .uni-step__title { font-weight: 500; color: var(--uni-muted); }

  /* ---- Shelf: courses not built yet ------------------------------------- */
  .uni-shelf { border-top: 1px solid var(--uni-hair); }
  .uni-shelf__row {
    display: grid; grid-template-columns: minmax(0, 15ch) 1fr;
    gap: 4px 20px; padding: 11px 10px;
    border-bottom: 1px solid var(--uni-hair);
  }
  .uni-shelf__name { font-size: 14px; font-weight: 600; color: var(--uni-muted); }
  .uni-shelf__blurb { font-size: 13px; line-height: 1.45; color: var(--uni-muted); }
  @media (max-width: 560px) {
    .uni-shelf__row { grid-template-columns: 1fr; }
  }

  /* ---- Footer note ------------------------------------------------------ */
  .uni-note {
    margin-top: 26px; padding-top: 18px;
    border-top: 1px solid var(--uni-hair);
    font-size: 13px; line-height: 1.6; color: var(--uni-muted);
    max-width: 68ch;
  }
  .uni-note code {
    font-family: var(--sw-font-mono); font-size: 12.5px;
    background: var(--uni-surface); border: 1px solid var(--uni-hair);
    border-radius: 3px; padding: 1.5px 5px; color: var(--uni-ink);
  }

  /* ---- Step screen ------------------------------------------------------ */
  .uni-stepline {
    display: flex; align-items: baseline; justify-content: space-between;
    gap: 16px; margin-bottom: 14px;
  }
  .uni-back {
    display: inline-flex; align-items: center; gap: 6px;
    font-size: 12.5px; font-weight: 500; color: var(--uni-muted);
    text-decoration: none;
  }
  .uni-back:hover { color: var(--uni-accent); }
  .uni-count { font-size: 12px; color: var(--uni-muted); font-variant-numeric: tabular-nums; }
  .uni-title {
    font-family: var(--sw-font-display);
    font-size: clamp(1.7rem, 4.2vw, 2.05rem);
    font-weight: 600; line-height: 1.14; letter-spacing: -0.018em;
    text-wrap: balance; color: var(--uni-ink); margin: 0 0 24px;
  }
  .uni-prose { max-width: 66ch; font-size: 15px; line-height: 1.62; color: var(--uni-ink); }
  .uni-prose p { margin: 0 0 0.85em; }
  .uni-prose p:last-child { margin-bottom: 0; }

  .uni-prompt {
    display: block;
    font-family: var(--sw-font-mono);
    font-size: 12.5px; line-height: 1.62;
    white-space: pre-wrap;
    color: var(--uni-ink);
    background: var(--uni-surface);
    border: 1px solid var(--uni-hair);
    border-radius: 5px;
    padding: 15px 17px;
    margin-bottom: 16px;
    overflow-x: auto;
  }

  .uni-payoff ul { list-style: none; padding: 0; margin: 0; max-width: 64ch; }
  .uni-payoff li {
    display: grid; grid-template-columns: 18px 1fr; gap: 10px;
    font-size: 14px; line-height: 1.5; color: var(--uni-ink);
    padding: 7px 0;
  }
  .uni-payoff li::before {
    content: ""; margin-top: 5px;
    width: 13px; height: 13px;
    background-color: var(--uni-accent);
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
    -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;
    -webkit-mask-size: contain; mask-size: contain;
  }

  .uni-done { margin-top: 34px; padding-top: 20px; border-top: 1px solid var(--uni-hair); }

  /* ---- Review chrome: the two screens live behind tabs ------------------ */
  body .sw-tabs-list, body .sw-tab-list {
    margin-bottom: 26px;
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
    # Screen 1 — Course list
    # =====================================================================
    tab "Course list" do
      topbar(wordmark: "StreamWeaver University") do
        theme_toggle mode: :auto
      end

      div(class: "uni-hero") do
        header1 "Pick up at step 3.", class: "uni-hero__lead"
        phrase "One form, two modes — the same six lines of DSL, running live and blocking.",
               class: "uni-hero__sub"
      end

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

      phrase "Getting Started", class: "uni-micro"

      div(class: "uni-steps") do
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
              phrase("", class: "uni-i uni-i--check") if state == :done
            end
            phrase num, class: "uni-step__num"
            div do
              header2 title, class: "uni-step__title"
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

      phrase "Courses in the works", class: "uni-micro"

      div(class: "uni-shelf") do
        [
          ["Docs deep dive", "Org export, gists, and the reader extension, end to end."],
          ["Canvas modes", "Stateful, blocking, and streaming — when to reach for each."],
          ["Skills and panels", "Teach your agent to drive the canvas without you."]
        ].each do |name, blurb|
          div(class: "uni-shelf__row") do
            phrase name, class: "uni-shelf__name"
            phrase blurb, class: "uni-shelf__blurb"
          end
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

      div(class: "uni-stepline") do
        div(class: "uni-back") do
          phrase "", class: "uni-i uni-i--back"
          phrase "All steps"
        end
        phrase "Step 3 of 5", class: "uni-count"
      end

      header1 "One form, two modes", class: "uni-title"

      phrase "Why this matters", class: "uni-micro"
      md "Terminal tools make you pick one: a form that stays live, or a prompt that " \
         "blocks until you answer. StreamWeaver runs the same form both ways.\n\n" \
         "You will write it once, change the call that consumes it, and watch the " \
         "behaviour flip. That is the thing a TUI cannot do.",
         class: "uni-prose"

      phrase "The prompt your worker session receives", class: "uni-micro"
      phrase _step3_prompt, class: "uni-prompt"

      div(class: "uni-actions") do
        button "Run in worker session", submit: false, key: "step-run", class: "uni-btn uni-btn--run"
        copy_button "Copy prompt", text: _step3_prompt,
                    copied_label: "Copied", class: "uni-btn uni-btn--outline"
      end

      phrase "What you should see", class: "uni-micro"
      md "- Click a different option and the page re-renders in place. Nothing blocks.\n" \
         "- The second version freezes your terminal until you click, then prints your answer as JSON.\n" \
         "- Same six lines of DSL. Only the call that consumes the form changed.",
         class: "uni-payoff"

      div(class: "uni-done") do
        button "Mark step 3 done", submit: false, key: "step-done", class: "uni-btn uni-btn--outline"
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
