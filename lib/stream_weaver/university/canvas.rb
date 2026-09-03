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
# as-is) with the review-only `tabs` rules trimmed. The mockup's separate
# step screen was built as-designed (step-1-canvas-push) and then folded
# back into an inline Details expansion on this same course list
# (single-mode, 2026-09-03, design-spec.md's "Revision note") -- most of
# that CSS lives on under `.uni-step__expansion`, below.
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

  # "Step N done -- pick up at step N+1." (or, on the last step, the
  # course-complete variant), rendered from `progress.last_done` on the
  # SAME re-push that wrote it -- not a bridge toast. A toast queued
  # alongside this push's HTML both arrive in one ~500ms poll response,
  # and the client unconditionally clears any toast the instant new HTML
  # lands (bridge_server.rb's poll()), so it never has a chance to paint.
  # Putting the message in the HTML itself has no such race.
  def self.mark_done_message(step_number, steps: StreamWeaver::University::Course::GETTING_STARTED_STEPS)
    total = steps.size
    if step_number.to_i >= total
      "Step #{step_number} done -- that's the whole course!"
    else
      "Step #{step_number} done -- pick up at step #{step_number.to_i + 1}."
    end
  end

  # A plain markdown bullet list from an array of lines -- what
  # "What you should see" renders as, both on the step screen and inline
  # on a course-list row (`md` turns this into the checked `.uni-payoff`
  # list via its own `- ` list syntax).
  def self.bullets(lines)
    lines.map { |line| "- #{line}" }.join("\n")
  end

  # "Re-run" once step `number`'s prompt has actually gone out before --
  # either it ever landed (requested_at, permanent, stamped only on a
  # :sent status) or the last click on this exact step was a failed/
  # degraded send (last_run, which requested_at never records). Shared by
  # the hero button and each step row's own primary button so the two can
  # never say different things about the same step -- round-6 UAT shipped
  # them as two separate inline copies, and the hero one was missed
  # entirely (Forrest, follow-up). Repeat (done steps) never calls this.
  def self.run_label(progress, last_run, number)
    ever_sent = progress.requested_at(number) || (last_run && last_run['step'].to_i == number)
    ever_sent ? "Re-run" : "Run"
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
    display: block;
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

  /* The row a Run/Repeat click just targeted, expanded in place --
     grid-column spans every track (the row's own 3-column grid otherwise
     auto-places a 4th child back into column 1, the 28px mark column).
     Indented to 43px (28px mark + 15px gap) so it lines up under the
     title/payoff text, not the mark. */
  .uni-step__expect {
    grid-column: 1 / -1;
    margin: 2px 0 4px 43px;
    padding-top: 10px;
    border-top: 1px dashed var(--uni-line-soft);
  }
  .uni-step__expect-label {
    display: block;
    font-size: 12px; font-weight: 700; letter-spacing: 0.06em;
    text-transform: uppercase; color: var(--uni-muted);
    margin-bottom: 6px;
  }
  @media (max-width: 620px) {
    .uni-step__expect { grid-column: 1 / -1; margin-left: 0; }
  }

  /* A row's full Details expansion -- why it matters, the prompt, the
     payoff checklist, Mark done + a next hint. Single-mode: this replaces
     the old separate step screen outright, so it reuses that screen's own
     content classes (.uni-label, .uni-prose, .uni-promptbox, .uni-payoff)
     rather than a second copy of them. Same grid-column / indent trick as
     .uni-step__expect, above, since it lives in the same 3-column row. */
  .uni-step__expansion {
    grid-column: 1 / -1;
    margin: 4px 0 4px 43px;
    padding-top: 14px;
    border-top: 1px dashed var(--uni-line-soft);
  }
  .uni-step__expansion > .uni-label:first-child { margin-top: 0; }
  .uni-step__expansion-foot {
    display: flex; align-items: center; gap: 14px; flex-wrap: wrap;
    margin-top: 22px;
  }
  @media (max-width: 620px) {
    .uni-step__expansion { grid-column: 1 / -1; margin-left: 0; }
  }

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

  /* The all-done recap -- what the resume band's congratulation opens
     onto. Same card, same body; the step rows below are untouched. */
  .uni-recap {
    padding: 4px 22px 22px;
    border-bottom: 1px solid var(--uni-line);
  }
  .uni-recap > .uni-label:first-child { margin-top: 0; }
  .uni-recap__foot {
    display: flex; align-items: center; gap: 14px;
    margin-top: 22px; flex-wrap: wrap;
  }

  /* The quiet "start over" escape hatch on the course list itself, for
     anyone resetting before finishing. Hidden once all_done, where the
     recap above offers the same action at its natural place instead. */
  .uni-reset { margin-top: 12px; text-align: right; }

  /* ---- Step Details expansion (single-mode: inline on a course-list row,
     not a separate screen -- these classes are what the old step screen's
     content used, kept as-is and reused by the expansion body below). --- */
  .uni-label {
    display: block;
    font-size: 15px; font-weight: 650; color: var(--uni-ink);
    letter-spacing: -0.005em; margin: 32px 0 11px;
  }
  .uni-prose { max-width: 66ch; font-size: 16px; line-height: 1.6; color: var(--uni-ink); }
  .uni-prose p { margin: 0 0 0.8em; }
  .uni-prose p:last-child { margin-bottom: 0; }

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
  /* A hanging indent (padding-left + absolutely positioned check), not a
     grid row -- a grid item split every inline child of the <li> onto its
     own auto-placed row (`.uni-payoff` items come from `md`, so a step
     whose text has any inline markdown -- a `code` span, say -- produces
     more than one child), and the auto-placed rows landed in the 20px
     icon column, wrapping that text one character per line. Position
     keeps the check glyph out of the flow entirely, so the <li> is back to
     one ordinary block wrapping however many inline children it has. */
  .uni-payoff li {
    position: relative;
    font-size: 15px; line-height: 1.5; color: var(--uni-ink);
    padding: 7px 0 7px 31px;
  }
  .uni-payoff li::before {
    content: ""; position: absolute; left: 0; top: 11px;
    width: 15px; height: 15px;
    background-color: var(--uni-done);
    -webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
            mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3.2 8.4l3.1 3.1 6.5-7'/%3E%3C/svg%3E");
    -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;
    -webkit-mask-size: contain; mask-size: contain;
  }

  /* The hint text next to Mark done, inside a row's expansion footer
     (.uni-step__expansion-foot, above) -- "Unlocks step N+1." or "That is
     the whole course." Also used, with .uni-foot__spacer, by the
     completion recap's own footer (.uni-recap__foot) -- kept here since
     the old step-screen-only .uni-foot container is gone, but these two
     were never step-screen-exclusive. */
  .uni-foot__hint { font-size: 14px; color: var(--uni-muted); }
  .uni-foot__spacer { flex: 1 1 auto; }

  @media (max-width: 700px) {
    body[class*="sw-layout-"] { padding-bottom: 150px; }
  }
  @media (max-width: 620px) {
    .uni-step { grid-template-columns: 28px 1fr; row-gap: 10px; }
    .uni-step > .uni-step__actions { grid-column: 2; justify-self: start; }
    .uni-resume__lead { font-size: 1.3rem; }
    .uni-recap__foot .uni-foot__spacer { display: none; }
  }

  @media (prefers-reduced-motion: reduce) {
    body * { transition-duration: 0.01ms !important; }
  }
CSS

_body = proc do
  use_theme :doc
  use_layout :default
  use_stylesheet _css

  # Without this marker, the adapter's showFeedback() replaces the whole
  # page with "✓ Submitted -- You can close this window" on the first click
  # of ANY button (adapter/alpinejs.rb, the else branch of the
  # #sw-canvas-continue lookup). That terminal screen is right for a
  # one-shot form and catastrophic for a control panel meant to be clicked
  # all session: it took out the entire course list on the first Run.
  # With the marker, a click shows this brief message instead, and the
  # listener's re-push swaps the real page back in.
  canvas_continue message: "Working..."

  steps = StreamWeaver::University::Course::GETTING_STARTED_STEPS
  total = steps.size
  progress = StreamWeaver::University::Progress.load
  states = StreamWeaver::University::Canvas.step_states(progress, steps: steps)
  done_count = progress.done_steps.count { |n| n <= total }
  current_number = steps.find { |s| states[s[:number]] == :current }&.dig(:number)
  all_done = done_count == total
  # Single-mode: there is exactly one screen. Which row (if any) renders
  # its full Details expansion inline comes straight off the ledger, same
  # as done/last_run -- which is also what makes a deep link work, since
  # whoever set this before the canvas was last (re)pushed gets that row
  # auto-expanded on load with no navigation step of its own.
  expanded_number = progress.expanded_step
  # Hoisted above the resume band (not just the run-notice band that reads
  # it below) because the course-list row loop also reads it -- a Run or
  # Repeat click expands that step's "What you should see" inline on its
  # row, right there next to the button the user just pressed.
  last_run = progress.last_run
  # Mutually exclusive with last_run -- mark_done!/record_run! each clear
  # the other, so at most one of the two notice bands below ever renders.
  last_done = progress.last_done

  topbar(wordmark: "StreamWeaver University") do
    theme_toggle mode: :auto
  end
  phrase "Learn StreamWeaver by running it. Every step is a real app that appears " \
         "in this pane while you stay in your terminal. Your progress is saved as you go, " \
         "so you can close this and pick up right where you left off, even after a reboot -- " \
         "reset any time from the link at the bottom of the list.",
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
            hero_label = StreamWeaver::University::Canvas.run_label(progress, last_run, run_number)
            button "#{hero_label} step #{run_number}", id: "hero-run-#{run_number}",
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

      # Mark-done's confirmation -- "Step N done -- pick up at step N+1."
      # -- reusing the same green/--sent band a successful Run gets.
      # Checked first: mark_done! clears last_run, so the two never both
      # have something to say, but last_done is the more specific read
      # when it's present. Rendered BEFORE the completion recap below on
      # purpose: this is the report of the click that just happened
      # (design-spec's "report band ... sits directly under the button
      # that produced it"), and on the step that finishes the course,
      # that click's own "that's the whole course!" line should read as
      # the lead-in to the recap, not a footnote under it.
      if last_done
        div(class: "uni-run-notice uni-run-notice--sent") do
          phrase StreamWeaver::University::Canvas.mark_done_message(last_done['step']),
                 class: "uni-run-notice__msg"
        end
      # What the last Run/Repeat click actually did. On anything but a
      # clean send the prompt itself is offered here with a copy button --
      # the degraded path's whole experience, and the fallback whenever the
      # recorded worker session has gone away (driver-worker-runner
      # criteria 4 and 5). The canvas never talks to iTerm; it reports what
      # the driver wrote to the ledger.
      elsif last_run
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

      # The completion recap -- what the resume band's "look at what's
      # next on the shelf" line points at once every step is done. Sits
      # inside this same course-list render (not a separate screen) so
      # "Run/Repeat stays available from the list" is true by
      # construction: the step rows below are untouched.
      if all_done
        div(class: "uni-recap") do
          phrase "What you learned", class: "uni-label"
          md steps.map { |s| "- **Step #{s[:number]}:** #{s[:payoff]}" }.join("\n"),
             class: "uni-payoff"

          phrase "Where to go next", class: "uni-label"
          md <<~MD, class: "uni-prose"
            - Browse the reference docs in `docs/`.
            - Run `streamweaver showcase` for a tour of every component.
            - Read worked examples in `examples/`.
            - Run `streamweaver tutorial` for the classic component-by-component walkthrough.
          MD

          div(class: "uni-recap__foot") do
            phrase "Run or Repeat any step below to go through it again.",
                   class: "uni-foot__hint"
            div(class: "uni-foot__spacer") {}
            button "Reset course", id: "reset-course", class: "uni-btn uni-btn--quiet"
          end
        end
      end

      steps.each do |step|
        number = step[:number]
        state = states[number]
        expanded = expanded_number == number
        run_label = StreamWeaver::University::Canvas.run_label(progress, last_run, number)
        div(class: "uni-step uni-step--#{state}") do
          div(class: "uni-step__mark") do
            if state == :done
              phrase "", class: "uni-i uni-i--check"
              phrase "Step #{number}, done", class: "uni-sr"
            else
              phrase number.to_s
              phrase(state == :current ? "Step #{number}, current step" : "Step #{number}, not started",
                     class: "uni-sr")
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
              button run_label, id: "run-#{number}", class: "uni-btn uni-btn--outline"
              button "Mark done", id: "mark-done-#{number}", class: "uni-btn uni-btn--quiet"
            else
              button run_label, id: "run-#{number}", class: "uni-btn uni-btn--quiet"
            end
            button expanded ? "Hide" : "Details", id: "view-#{number}", class: "uni-btn uni-btn--quiet"
          end
          # Expands exactly the row a Run/Repeat click just targeted, so
          # "what should this do" is answered right there without opening
          # Details -- last_run is what a click just wrote, and mark_done!
          # clears it, so this can never point at a step that was actually
          # finished instead of run. Skipped when the row's own full
          # Details expansion (below) is already open: that one repeats
          # "What you should see" itself, and showing both would say it
          # twice.
          if last_run && last_run['step'].to_i == number && !expanded
            div(class: "uni-step__expect") do
              phrase "What you should see", class: "uni-step__expect-label"
              md StreamWeaver::University::Canvas.bullets(step[:what_you_should_see]),
                 class: "uni-payoff"
            end
          end

          # Single-mode: "Details" expands THIS row in place -- why it
          # matters, the prompt with Run/Copy, the payoff checklist, and a
          # Mark done + next-step hint -- rather than navigating to a
          # separate step screen. Expanding one row collapses any other
          # (expanded_number holds at most one step), and there is nothing
          # to get "back" from: Hide (the same button, relabeled) closes
          # it in place.
          if expanded
            div(class: "uni-step__expansion") do
              phrase "Why this matters", class: "uni-label"
              md step[:why_it_matters], class: "uni-prose"

              div(class: "uni-promptbox") do
                div(class: "uni-promptbox__bar") do
                  phrase "The prompt your worker session receives"
                end
                phrase step[:prompt], class: "uni-prompt"
              end
              div(class: "uni-actions") do
                button "Run in worker session", id: "run-#{number}", class: "uni-btn uni-btn--run"
                copy_button "Copy prompt", text: step[:prompt],
                            copied_label: "Copied", class: "uni-btn uni-btn--outline"
              end

              phrase "What you should see", class: "uni-label"
              md StreamWeaver::University::Canvas.bullets(step[:what_you_should_see]),
                 class: "uni-payoff"

              div(class: "uni-step__expansion-foot") do
                button "Mark step #{number} done", id: "mark-done-#{number}", class: "uni-btn uni-btn--outline"
                if number < total
                  phrase "Unlocks step #{number + 1}.", class: "uni-foot__hint"
                else
                  phrase "That is the whole course.", class: "uni-foot__hint"
                end
              end
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

  # A second "Reset course" entry point, for anyone who wants to start
  # over before finishing -- the recap screen (above, `all_done`) offers
  # its own, so this one steps aside there rather than rendering the same
  # id: "reset-course" button twice on one page.
  unless all_done
    div(class: "uni-reset") do
      button "Reset course", id: "reset-course", class: "uni-btn uni-btn--quiet"
    end
  end
end

if respond_to?(:use_theme)
  # canvas-push / canvas-read: self is already a StreamWeaver::App
  instance_eval(&_body)
elsif __FILE__ == $PROGRAM_NAME
  require_relative "../../stream_weaver"
  app("StreamWeaver University") { instance_eval(&_body) }.run!
end
