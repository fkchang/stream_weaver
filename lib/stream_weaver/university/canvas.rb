# frozen_string_literal: true

# StreamWeaver University -- the course-list canvas `streamweaver get-started`
# pushes (stories: course-list-canvas, progress-ledger).
#
# Dual-mode single file (shared-DSL pattern, same as
# docs/university/mockups/course_canvas_mockup.rb):
#   canvas:     streamweaver canvas-push university < lib/stream_weaver/university/canvas.rb
#   standalone: ruby lib/stream_weaver/university/canvas.rb
#
# `CLI.push_get_started_placeholder_canvas` pushes this file's own text
# (`File.read`) verbatim, the same "one string of Ruby, eval'd fresh on
# every push" contract canvas-push uses for a file piped over stdin. Every
# reference here uses `require` (not `require_relative`), because the bridge
# process evals the pushed text with no filename
# (lib/stream_weaver/canvas/bridge.rb `handle_push`), so relative resolution
# has nothing to resolve against -- only the `$LOAD_PATH`-relative absolute
# form works there.
#
# CSS and the body are local variables (`_css`, `_body`), not constants --
# matching the mockup's own convention. The whole file gets instance_eval'd
# fresh on every single push to the SAME long-running bridge process; a
# `CONST = ...` in that position would warn "already initialized constant"
# on the second push onward (harmless, but noisy in the bridge log). Local
# vars reassign silently; so does `def self.foo` (Ruby never warns on method
# redefinition), which is why `step_states` below is a method, not baked
# into the body.
#
# Visual design is docs/university/design-spec.md v2; CSS below is lifted
# verbatim from docs/university/mockups/course_canvas_mockup.rb (approved
# as-is) with the review-only `tabs`/step-screen rules trimmed -- the step
# screen itself is a future story's build (step-1-canvas-push and siblings).
#
# Buttons dispatch for real (default `submit: true`, `id:` not `key:`):
# App#button only derives a key-based id when a block or `action:` is
# present (lib/stream_weaver/app.rb `button`) -- a bare `key:` with neither
# falls back to a per-render counter, which isn't a stable target for a
# listener to parse a step number back out of. `id:` is always used
# verbatim (sanitized), so `id: "mark-done-3"` becomes a predictable
# `btn_mark_done_mark-done-3`. The mockup itself uses `submit: false` (fully
# decorative) because it is a review artifact, not the built app.

require 'stream_weaver/university/course'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/runner'

# Compact `A::B::C` form, not nested `module A; module B; module C`
# blocks -- deliberately. When this whole file's text is instance_eval'd as
# a STRING (canvas push / CLI.render_dsl_to_html; see the file header), a
# nested `module StreamWeaver; ...; end` reopening does NOT reopen the real
# top-level `StreamWeaver` -- instance_eval(String) makes the definee the
# caller's singleton class, so `module Foo` there *creates a new shadow
# constant on that singleton class* rather than finding the existing global
# one, and every later same-eval reference to `StreamWeaver::*` then
# resolves against that empty shadow instead. The compact form looks up
# `StreamWeaver::University` by ordinary constant resolution *before*
# opening `Canvas`, which finds the real module (already loaded by the
# `require`s above) and is safe in both this file's require'd-as-a-library
# use (specs) and its instance_eval'd-as-a-string use (the live push).
module StreamWeaver::University::Canvas
  # step[:number] => :done / :current / :todo, computed fresh from the
  # ledger every render -- design-spec section 6, items 4 & 8 (resume
  # band + rail + row marks all key off exactly these three values).
  def self.step_states(progress, steps: StreamWeaver::University::Course::GETTING_STARTED_STEPS)
    next_number = steps.find { |s| !progress.done?(s[:number]) }&.dig(:number)
    steps.each_with_object({}) do |step, memo|
      memo[step[:number]] = if progress.done?(step[:number])
                               :done
                             elsif step[:number] == next_number
                               :current
                             else
                               :todo
                             end
    end
  end
end

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
    --uni-next-bg:   #EFECE1;
    --uni-rail-track: #D6D1BF;

    --uni-ink:       var(--sw-color-text);
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

  body[class*="sw-layout-"] {
    max-width: 860px; margin: 0 auto;
    padding: 26px 24px 120px;
    background: var(--uni-page);
    font-size: 16px;
  }

  .uni-sr {
    position: absolute; width: 1px; height: 1px;
    margin: -1px; padding: 0; overflow: hidden;
    clip: rect(0 0 0 0); clip-path: inset(50%); white-space: nowrap;
  }
  #app-container {
    background: transparent; border: none; box-shadow: none;
    padding: 0; margin: 0;
  }

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
  .uni-i--lock {
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Crect x='3.3' y='6.9' width='9.4' height='6.6' rx='1.4'/%3E%3Cpath d='M5.6 6.9V5.1a2.4 2.4 0 0 1 4.8 0v1.8'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'%3E%3Crect x='3.3' y='6.9' width='9.4' height='6.6' rx='1.4'/%3E%3Cpath d='M5.6 6.9V5.1a2.4 2.4 0 0 1 4.8 0v1.8'/%3E%3C/svg%3E");
  }

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
  .uni-chip--done { background: var(--uni-done-bg); color: var(--uni-done); }
  .uni-chip--soon {
    display: inline-flex; align-items: center; gap: 5px;
    background: var(--uni-next-bg); color: var(--uni-next);
  }
  .uni-chip--soon .uni-i { font-size: 12px; }
  .uni-course__blurb {
    display: block; font-size: 14.5px; line-height: 1.5;
    color: var(--uni-muted); padding: 3px 20px 14px 41px;
    max-width: 70ch;
  }

  body .sw-card-body.uni-course__body { padding: 0; }

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

  .uni-rail { display: flex; align-items: center; gap: 13px; }
  .uni-rail__track { display: flex; align-items: center; gap: 5px; }
  .uni-rail__seg { width: 30px; height: 6px; border-radius: 3px; background: var(--uni-rail-track); }
  .uni-rail__seg--done { background: var(--uni-done); }
  .uni-rail__seg--current { background: var(--uni-now); width: 40px; }
  .uni-rail__label {
    font-size: 13px; font-weight: 600; color: var(--uni-muted);
    font-variant-numeric: tabular-nums;
  }

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
  .uni-step--todo .uni-step__mark {
    background: transparent; color: var(--uni-next);
    border: 1.5px solid var(--uni-next);
  }
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
  .uni-step__actions { display: flex; align-items: center; gap: 4px; }

  /* Report band for the last Run/Repeat click -- what the driver did, or
     why it refused to send. Sits between the resume band and the step
     rows so it's directly under the button that produced it. */
  .uni-run-notice {
    background: var(--uni-now-bg);
    border-bottom: 1px solid var(--uni-line);
    border-left: 3px solid var(--uni-now);
    padding: 15px 22px 16px;
  }
  /* Only one distinction matters visually -- it went out, or it didn't --
     so a status added later styles itself correctly by construction. */
  .uni-run-notice--degraded {
    background: var(--uni-next-bg);
    border-left-color: var(--uni-next);
  }
  .uni-run-notice--sent { border-left-color: var(--uni-done); background: var(--uni-done-bg); }
  .uni-run-notice__msg {
    display: block; max-width: 66ch;
    font-size: 14.5px; line-height: 1.5; font-weight: 600;
    color: var(--uni-ink); margin: 0;
  }
  .uni-run-notice__hint {
    display: block; max-width: 66ch;
    font-size: 13.5px; line-height: 1.5; color: var(--uni-muted);
    margin-top: 10px;
  }
  .uni-run-notice .sw-code-block { margin: 12px 0 0; }

  .uni-divider {
    display: flex; align-items: center; gap: 14px;
    margin: 38px 0 16px;
  }
  .uni-divider__label {
    font-size: 15px; font-weight: 650; color: var(--uni-ink);
    letter-spacing: -0.005em; flex: none;
  }
  .uni-divider__rule { height: 1px; background: var(--uni-line); flex: 1 1 auto; }

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

  @media (max-width: 700px) {
    body[class*="sw-layout-"] { padding-bottom: 150px; }
  }
  @media (max-width: 620px) {
    .uni-step { grid-template-columns: 28px 1fr; row-gap: 10px; }
    .uni-step > .uni-step__actions { grid-column: 2; justify-self: start; }
    .uni-resume__lead { font-size: 1.3rem; }
  }

  @media (prefers-reduced-motion: reduce) {
    body * { transition-duration: 0.01ms !important; }
  }
CSS

_body = proc do
  use_theme :doc
  use_layout :default
  use_stylesheet _css

  steps = StreamWeaver::University::Course::GETTING_STARTED_STEPS
  total = steps.size
  progress = StreamWeaver::University::Progress.load
  states = StreamWeaver::University::Canvas.step_states(progress, steps: steps)
  done_count = progress.done_steps.count { |n| n <= total }
  current_number = steps.find { |s| states[s[:number]] == :current }&.dig(:number)
  all_done = done_count == total

  topbar(wordmark: "StreamWeaver University") do
    theme_toggle mode: :auto
  end
  phrase "Learn StreamWeaver by running it. Every step is a real app that appears " \
         "in this pane while you stay in your terminal.",
         class: "uni-tagline"

  # ---- Getting Started: open, and holding its own state --------------------
  card(depth: :elevated, class: "uni-course") do
    card_header(class: "uni-course__bar") do
      div(class: "uni-course__dot") {}
      header2 "Getting Started", class: "uni-course__name"
      chip_label = if all_done
                     "Complete"
                   elsif done_count.zero?
                     "Not started"
                   else
                     "In progress"
                   end
      phrase chip_label, class: "uni-chip#{' uni-chip--done' if all_done}"
    end

    card_body(class: "uni-course__body") do
      div(class: "uni-resume") do
        if all_done
          phrase "All five steps done.", class: "uni-resume__lead"
          phrase "Nice work -- repeat any step below, or look at what's next on the shelf.",
                 class: "uni-resume__sub"
        elsif done_count.zero?
          phrase "Start with step 1.", class: "uni-resume__lead"
          phrase steps.first[:payoff], class: "uni-resume__sub"
        else
          current_step = steps.find { |s| s[:number] == current_number }
          phrase "Pick up at step #{current_number}.", class: "uni-resume__lead"
          phrase current_step[:payoff], class: "uni-resume__sub"
        end

        div(class: "uni-actions") do
          run_number = current_number || 1
          unless all_done
            button "Run step #{run_number}", id: "hero-run-#{run_number}",
                   class: "uni-btn uni-btn--run"
          end
          if done_count.positive? && !all_done
            repeat_number = [run_number - 1, 1].max
            button "Repeat step #{repeat_number}", id: "hero-repeat-#{repeat_number}",
                   class: "uni-btn uni-btn--quiet"
          end
        end

        div(class: "uni-rail") do
          div(class: "uni-rail__track") do
            steps.each do |step|
              seg_class = case states[step[:number]]
                          when :done then "uni-rail__seg uni-rail__seg--done"
                          when :current then "uni-rail__seg uni-rail__seg--current"
                          else "uni-rail__seg"
                          end
              div(class: seg_class) {}
            end
          end
          phrase "#{done_count} of #{total} done", class: "uni-rail__label"
        end
      end

      # What the last Run/Repeat click actually did. On anything but a
      # clean send the prompt itself is offered here with a copy button --
      # the degraded path's whole experience, and the fallback whenever the
      # recorded worker session has gone away (driver-worker-runner
      # criteria 4 and 5). The canvas never talks to iTerm; it reports what
      # the driver wrote to the ledger.
      last_run = progress.last_run
      if last_run
        status = last_run['status'].to_s
        run_step = last_run['step'].to_i
        run_sent = StreamWeaver::University::Runner.sent?(status)
        run_prompt = StreamWeaver::University::Course.prompt_for(run_step)

        div(class: "uni-run-notice uni-run-notice--#{run_sent ? 'sent' : 'degraded'}") do
          phrase StreamWeaver::University::Runner.message_for(status, run_step),
                 class: "uni-run-notice__msg"
          if !run_sent && run_prompt
            # The human gets the prompt as written -- line breaks and all.
            # Only the wire gets Runner.one_line's collapsed form, because
            # a clipboard paste has no keystroke-per-newline problem.
            code_block run_prompt, lang: "text", copy: true
            phrase "Copy it, then paste it into the terminal where your agent is " \
                   "running and press Enter.",
                   class: "uni-run-notice__hint"
          end
        end
      end

      steps.each do |step|
        number = step[:number]
        state = states[number]
        div(class: "uni-step uni-step--#{state}") do
          div(class: "uni-step__mark") do
            if state == :done
              phrase "", class: "uni-i uni-i--check"
              phrase "Step #{number}, done", class: "uni-sr"
            else
              phrase number.to_s
              phrase(state == :current ? ", current step" : ", not started", class: "uni-sr")
            end
          end
          div do
            header3 step[:title], class: "uni-step__title"
            phrase step[:payoff], class: "uni-step__payoff"
          end
          div(class: "uni-step__actions") do
            case state
            when :done
              button "Repeat", id: "repeat-#{number}", class: "uni-btn uni-btn--quiet"
            when :current
              button "Run", id: "run-#{number}", class: "uni-btn uni-btn--outline"
              button "Mark done", id: "mark-done-#{number}", class: "uni-btn uni-btn--quiet"
            else
              button "Run", id: "run-#{number}", class: "uni-btn uni-btn--quiet"
            end
          end
        end
      end
    end
  end

  # ---- The shelf: closed, dormant, no controls ------------------------------
  div(class: "uni-divider") do
    phrase "In the works", class: "uni-divider__label"
    div(class: "uni-divider__rule") {}
  end

  StreamWeaver::University::Course::FUTURE_COURSES.each do |course|
    card(depth: :recessed, class: "uni-course uni-course--dormant") do
      card_header(class: "uni-course__bar") do
        div(class: "uni-course__dot") {}
        header2 course[:name], class: "uni-course__name"
        div(class: "uni-chip uni-chip--soon") do
          phrase "", class: "uni-i uni-i--lock"
          phrase "Soon"
        end
      end
      phrase course[:blurb], class: "uni-course__blurb"
    end
  end

  md "Looking for the old component tour? Run `streamweaver tutorial` -- the classic " \
     "walkthrough of every component. Older than these courses, and being refreshed.",
     class: "uni-note"
end

if respond_to?(:use_theme)
  # canvas-push / canvas-read: self is already a StreamWeaver::App
  instance_eval(&_body)
elsif __FILE__ == $PROGRAM_NAME
  require_relative "../../stream_weaver"
  app("StreamWeaver University") { instance_eval(&_body) }.run!
end
