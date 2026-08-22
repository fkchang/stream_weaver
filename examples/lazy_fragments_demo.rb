#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual-verification harness for LAZY fragments
# (`fragment ..., defer: true, lazy: true`) -- Turbo's `loading="lazy"`.
#
# A lazy fragment is a deferred fragment whose fetch waits until the element is
# VISIBLE, whatever made it visible: scrolling to it, or a CSS rule flipping an
# ancestor from display:none to display:block. It fetches exactly once. There is
# no JavaScript in this file -- the trigger is `hx-trigger="intersect once"`,
# backed by the browser's own IntersectionObserver.
#
#   SW_NO_OPEN=1 STREAMWEAVER_PORT=4641 ruby examples/lazy_fragments_demo.rb
#
# Then, with devtools' Network tab open and filtered to `update`:
#
#   1. On load, ZERO fetches fire. Every panel below is either off-screen or
#      CSS-hidden.
#   2. Hover the card in section 1 and HOLD -> exactly one fetch, and the card
#      fills in. Move away and hover again -> no second fetch.
#   3. Scroll to section 2 -> one fetch when the panel enters the viewport.
#   4. Keep scrolling through section 3 -> one fetch per page, in order, each
#      page's tail carrying the next page's placeholder. Each fetch re-runs its
#      ancestors' blocks, so page N takes N * SW_LAZY_DELAY -- the pages getting
#      progressively slower is the nesting cost, not a stall.
#   5. Click "Re-render the page" -> every panel returns to its placeholder and
#      re-arms, but still waits for visibility rather than refetching at once.
#
# SW_LAZY_DELAY overrides the per-fragment sleep (default 1.0s), so the
# placeholder is on screen long enough to see.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "stream_weaver"

DELAY = (ENV["SW_LAZY_DELAY"] || "1.0").to_f
PAGES = 4

def slow_work(label)
  sleep DELAY
  "#{label} rendered by the server at #{Time.now.strftime('%H:%M:%S.%L')}"
end

# The Russian doll: each page's content ends with the NEXT page's lazy
# placeholder, so the pages materialize one at a time as the reader scrolls and
# the app never has to know how many there are up front.
#
# NOTE: page 1 is deliberately lazy here TOO, so this demo's "zero fetches on
# load" check holds — that exercises the primitive, not the Turbo parity shape.
# For a real feed, render the current page's rows in the shell and lazy-wrap
# only the NEXT page — see the streamweaver-way skill's infinite-scroll recipe.
def scroll_page(number)
  fragment :"page_#{number}", lazy: true, placeholder: -> { spinner(size: :sm, label: "Loading page #{number}…") } do
    text slow_work("Page #{number}")
    div(class: "lazy-demo-filler") { text "(page #{number} content, scroll on)" }
    scroll_page(number + 1) if number < PAGES
  end
end

app "Lazy Fragments" do
  use_stylesheet <<~CSS
    /* Section 1 -- the zero-JS hover card. CSS alone flips the popup from
       display:none to display:block; that is what fires the fetch. */
    .lazy-demo-hover-host { position: relative; display: inline-block; }
    .lazy-demo-hover-label {
      border-bottom: 2px dotted var(--sw-accent, #0d9488);
      cursor: help;
      font-weight: 600;
    }
    .lazy-demo-hover-card {
      display: none;
      position: absolute;
      top: 1.6rem;
      left: 0;
      z-index: 20;
      min-width: 22rem;
      padding: 0.75rem 1rem;
      background: var(--sw-surface, #ffffff);
      color: var(--sw-text, #111111);
      border: 1px solid var(--sw-border, #e0e0e0);
      border-radius: 6px;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.18);
    }
    .lazy-demo-hover-host:hover .lazy-demo-hover-card { display: block; }

    /* Pushes the later sections below the fold so scrolling is what reveals
       them. */
    .lazy-demo-spacer {
      height: 90vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--sw-text-dim, #444444);
      border: 1px dashed var(--sw-border, #e0e0e0);
      border-radius: 6px;
      margin: 1.5rem 0;
    }
    .lazy-demo-filler {
      height: 55vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--sw-text-dim, #444444);
      background: var(--sw-surface-elevated, #f3f3f3);
      border-radius: 6px;
      margin: 0.75rem 0;
    }
  CSS

  header1 "Lazy fragments"
  md "Every panel on this page sleeps #{DELAY}s inside its block. **None of them " \
     "has fetched yet.** A lazy fragment holds its fetch until the element is " \
     "visible. Open devtools' Network tab, filter to `update`, and watch the " \
     "count stay at zero until you hover or scroll."
  text "Shell rendered at #{Time.now.strftime('%H:%M:%S.%L')}"

  header3 "1. Hover card: CSS-hidden, so it never fetches until it is shown"
  md "The popup below is `display: none` until `:hover` flips it. No JavaScript " \
     "is involved on either side: CSS makes it visible, the IntersectionObserver " \
     "notices, htmx fetches once."
  div(class: "lazy-demo-hover-host") do
    div(class: "lazy-demo-hover-label") { text "Hover me for the account summary" }
    div(class: "lazy-demo-hover-card") do
      fragment :hovercard, lazy: true, placeholder: "Fetching summary…" do
        text slow_work("Hover card")
        text "Hover away and back: this does not fetch again."
      end
    end
  end

  header3 "2. Below the fold: fetches when scrolled into the viewport"
  div(class: "lazy-demo-spacer") { text "↓ keep scrolling ↓" }
  fragment :below_fold, lazy: true, placeholder: -> { spinner(size: :sm, label: "Waiting to be seen…") } do
    text slow_work("Below-the-fold panel")
  end

  header3 "3. Infinite scroll: #{PAGES} pages of Russian dolls"
  md "Each page's block ends by declaring the next page as its own lazy " \
     "fragment, so page N+1 does not exist in the DOM until page N has landed " \
     "and been scrolled past. This is the whole of the pagination logic."
  scroll_page(1)

  header3 "4. Full re-render: re-arms, but stays lazy"
  md "This button swaps the whole app container. Every panel above returns to " \
     "its placeholder and re-arms; the ones still off-screen or hidden wait " \
     "rather than fetching immediately, which is what makes this different from " \
     "a plain `defer: true`."
  button "Re-render the page" do |s|
    s[:renders] = s[:renders].to_i + 1
  end
  text "Full re-renders so far: #{state[:renders].to_i}"
end.run!
