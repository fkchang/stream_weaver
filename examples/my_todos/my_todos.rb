#!/usr/bin/env ruby
# frozen_string_literal: true

# My Todos -- StreamWeaver parity PROOF against the learnhotwire.com course's
# Rails app (github.com/learnhotwire/rails), Turbo Frames chapter.
#
# Rule: ZERO custom JavaScript in app code. No script tags, no inline JS, no
# hand-written Alpine. Only DSL verbs and CSS. All four chapter features --
# inline editing, search, hover cards, infinite scroll -- work end to end
# under that rule, on the primitives shipped by this epic (strict-ids keying,
# deferred/lazy fragments). This app started as a spike (SDRD: build to
# discover); docs/research/streamweaver-way-spike-findings.md is the full
# history, now with every recorded stumble resolved or re-filed.
#
#   SW_NO_OPEN=1 ruby examples/my_todos/my_todos.rb
#
# Findings doc: docs/research/streamweaver-way-spike-findings.md

require_relative '../../lib/stream_weaver'
require_relative 'store'

# The chapter's hover card is "three lines of CSS, no JavaScript": the frame is
# display:none until :hover flips it to display:block, and Turbo's
# loading="lazy" IntersectionObserver fires the fetch at exactly that moment.
# StreamWeaver gets both halves -- the CSS reveal, plus `fragment(...,
# lazy: true)`'s own visibility-triggered fetch. See feature 3 below.
HOVERCARD_CSS = <<~CSS
  .hovercard { position: relative; display: inline-block; cursor: help; }
  .hovercard .hovercard-panel {
    display: none; position: absolute; top: 1.6em; left: 0; z-index: 50;
    min-width: 15rem;
  }
  .hovercard:hover .hovercard-panel { display: block; }
  .todo-row { padding: 0.15rem 0; }
  .spike-gap { border-left: 3px solid #d97706; padding-left: 0.75rem; }
CSS

# Only `:title` -- the StreamWeaver equivalent of the course's narrow
# `Projects::NamesController` with `params.expect(project: [:name])`. `form_for`
# coerces exactly the fields listed here and nothing else, so a submit through
# this form cannot reach `:completed` (app.rb#form_for_coerce). That is the
# "edit safe" half of the chapter's demo, enforced by construction rather than
# by remembering to pass the right `url:`.
TITLE_ONLY = [StreamWeaver::Field.new(:title, :string, {})].freeze

FEATURE_PATHS = {
  inline_edit: '/',
  search: '/search',
  hover_cards: '/hover-cards',
  infinite_scroll: '/infinite-scroll'
}.freeze

# routing.md Pitfall 1: every parser branch merges on top of this so a
# feature-local key set by an earlier request cannot leak into a later view.
VIEW_RESET = { editing_id: nil }.freeze

# The Russian doll, in Turbo's actual shape: the page the reader is ON renders
# inline in whatever response we are already writing, and only the NEXT page is
# wrapped in a lazy fragment. Rails does exactly this -- a frame around the
# current page's rows, plus a separate `loading: :lazy` frame for `@pagy.next`.
# Page N+1 does not exist in the DOM -- and never fetches -- until page N has
# been scrolled past. That recursion is the whole of the pagination logic: no
# scroll handler, no page counter in state (llms.txt "Recipe: infinite scroll,
# as nested fragments").
#
# Do NOT wrap page `number` itself in the lazy fragment. A deferred block is
# skipped on the shell render, so that shape serves HTML with zero rows in it;
# it only LOOKS right because page 1's placeholder lands in the initial viewport
# and the observer fires immediately.
def scroll_todos_page(number)
  TodoStore.page(number).each { |t| text "#{t[:completed] ? '☑' : '☐'}  #{t[:title]}" }

  # The guard is the chapter's `@pagy.next` check: without it Rails renders a
  # frame with a blank id and the chain dead-ends in "Content missing".
  nxt = number + 1
  return if TodoStore.page(nxt).empty?

  fragment(:"todos_page_#{nxt}", lazy: true, placeholder: 'Loading…') do
    scroll_todos_page(nxt)
  end
end

app 'My Todos', layout: :wide do
  use_stylesheet HOVERCARD_CSS

  route_with(
    parser: lambda do |path|
      base = path.to_s.split('?').first
      feature = FEATURE_PATHS.key(base.empty? ? '/' : base)
      feature ? VIEW_RESET.merge(feature: feature) : nil
    end,
    builder: lambda do |current_state|
      base = FEATURE_PATHS[current_state[:feature]&.to_sym] || '/'
      # Search is a GET filter, so the query belongs in the URL -- the same
      # reason the chapter uses `method: :get` for its search form.
      query = current_state[:query].to_s
      if current_state[:feature]&.to_sym == :search && !query.strip.empty?
        "#{base}?query=#{CGI.escape(query)}"
      else
        base
      end
    end
  )

  state[:feature] ||= :inline_edit

  navbar do
    nav_item 'Inline editing',  href: '/',                active: state[:feature] == :inline_edit
    nav_item 'Search',          href: '/search',          active: state[:feature] == :search
    nav_item 'Hover cards',     href: '/hover-cards',     active: state[:feature] == :hover_cards
    nav_item 'Infinite scroll', href: '/infinite-scroll', active: state[:feature] == :infinite_scroll
  end

  fragment(:flash) { flash_messages }

  case state[:feature].to_sym
  # ==========================================================================
  # 1. Inline editing
  #
  # Rails: two `turbo_frame_tag @project, :edit_name` frames -- one wrapping the
  # display <h1>, one wrapping the edit form -- that swap by matching dom_id.
  # StreamWeaver: one `fragment` per row, keyed by record id, whose body
  # branches on `state[:editing_id]`. Every interactive element rendered inside
  # a fragment is auto-scoped to it (adapter/alpinejs.rb#htmx_attrs), so the
  # Edit button and the form submit both swap just this row.
  # ==========================================================================
  when :inline_edit
    header1 'My Todos'
    md 'Click **Edit** on a row: the row becomes a title-only form in place. ' \
       'The completed checkbox is rendered *outside* the form -- watch that it ' \
       'survives the save.'

    TodoStore.all.first(6).each do |todo|
      fragment("todo-#{todo[:id]}") do
        div class: 'todo-row' do
          if state[:editing_id].to_s == todo[:id]
            text "#{todo[:completed] ? '☑' : '☐'}  (editing)"
            form_for(
              store: TodoStore,
              fields: TITLE_ONLY,
              name: :"todo_#{todo[:id]}_form",
              record: todo,
              on_success: ->(_id) { state[:editing_id] = nil }
            ) { submit_label 'Save' }
            button('Cancel', style: :secondary, key: "cancel-#{todo[:id]}") do |s|
              s[:editing_id] = nil
            end
          else
            hstack spacing: :sm do
              text "#{todo[:completed] ? '☑' : '☐'}  #{todo[:title]}"
              button('Edit', style: :secondary, key: "edit-#{todo[:id]}") do |s|
                s[:editing_id] = todo[:id]
              end
            end
          end
        end
      end
    end

  # ==========================================================================
  # 2. Search
  #
  # Rails: the form sits OUTSIDE the results frame and names it with
  # `data: {turbo_frame: :todos}`; a Stimulus `autosubmit` controller turns
  # keystrokes into `requestSubmit()`.
  # StreamWeaver: `text_field` auto-submits on input with no controller at all.
  # Both arrangements below now filter correctly -- the fragment-scoped param
  # merge bug the spike found is fixed (InteractionRunner merges posted state
  # before every scoped rebuild; see spec/live_input_fragment_wiring_spec.rb
  # and spec/deferred_fragments_spec.rb's regression coverage). What's left is
  # a genuine trade-off, not a break: shown in both arrangements below.
  # ==========================================================================
  when :search
    header1 'Search'
    alert(variant: :success) do
      text 'WORKS -- submit-as-you-type is free in both arrangements below, ' \
           'with no custom JavaScript.'
      text 'A is the Rails layout (field outside the results): swaps the whole ' \
           'app body, so it costs more bytes but the field never re-renders ' \
           'itself. B moves the field inside the fragment for a scoped morph ' \
           '-- fewer bytes, and focus/caret survive the morph -- at the cost ' \
           'of the field re-rendering itself on every keystroke.'
    end

    header3 'A. Rails arrangement -- field outside the results region'
    text_field :query, placeholder: 'Filter todos…', label: 'Search (outside)'
    fragment(:search_results_outside) do
      results = TodoStore.search(state[:query])
      text "#{results.length} of #{TodoStore.all.length} todos"
      results.first(8).each { |t| text "• #{t[:title]}" }
    end

    div(style: 'height:24px') { }

    header3 'B. StreamWeaver arrangement -- field inside the results fragment'
    fragment(:search_results_inside) do
      text_field :query_inside, placeholder: 'Filter todos…', label: 'Search (inside)'
      results = TodoStore.search(state[:query_inside])
      text "#{results.length} of #{TodoStore.all.length} todos"
      results.first(8).each { |t| text "• #{t[:title]}" }
    end

    div class: 'spike-gap' do
      header3 'The remaining trade-off'
      md 'Both arrangements filter correctly now. What StreamWeaver still ' \
         'lacks is a `data-turbo-frame` equivalent: `text_field` never passes ' \
         '`sw_updates:` to `htmx_attrs`, so an input can only target its own ' \
         'enclosing fragment (B) or `#app-container` (A) -- it cannot name a ' \
         'sibling fragment from outside it. `text_field :query, updates: ' \
         ':results` is accepted and silently ignored (a real gap, tracked, ' \
         'not fixed by this story). Until that lands, A pays the whole-body ' \
         'swap and B pays the self-re-render -- pick per feature which cost ' \
         'you\'d rather carry.'
    end

  # ==========================================================================
  # 3. Hover cards
  #
  # Rails: `turbo_frame_tag todo.user, :hovercard, src: ..., loading: :lazy`
  # inside a `div.hovercard`. CSS reveals it; `loading=lazy` means the fetch
  # only happens because the reveal made it visible.
  # StreamWeaver: `fragment(..., lazy: true)` is the same two-part interlock --
  # CSS does the revealing, `hx-trigger="intersect once"` does the fetching,
  # and it never fires while the card is `display: none`.
  # ==========================================================================
  when :hover_cards
    header1 'Hover cards'
    alert(variant: :success) do
      text 'WORKS -- CSS reveals the card, and revealing it is what fires the ' \
           'fetch. Nothing has fetched until the pointer arrives.'
      text 'Boot with SW_HOVERCARD_DELAY=1.5 and hover a name: the shell above ' \
           'already rendered; only the hovered card pays the 1.5s, once.'
    end

    TodoStore.all.first(6).each do |todo|
      user = UserStore.find(todo[:user_id])
      div class: 'todo-row' do
        hstack spacing: :sm do
          text "#{todo[:completed] ? '☑' : '☐'}  #{todo[:title]} —"
          # Keyed by the todo, not the user: the chapter (38:52) demos two todos
          # sharing an assignee emitting the same frame id twice. The fragment
          # name below carries that same rule -- key by what is unique per
          # position on the page (the todo), not by what the content is about
          # (the user) -- per llms.txt "Interactive IDs and keying".
          div class: 'hovercard' do
            text user[:name]
            div class: 'hovercard-panel' do
              fragment(:"hovercard_#{todo[:id]}", lazy: true, placeholder: 'Loading…') do
                UserStore.delay
                card do
                  header3 user[:name]
                  text user[:role]
                  text "#{TodoStore.all.count { |t| t[:user_id] == user[:id] }} todos"
                end
              end
            end
          end
        end
      end
    end

    div class: 'spike-gap' do
      header3 'How it works now'
      md 'Each card is its own `fragment(:"hovercard_#{todo[:id]}", lazy: ' \
         'true)`. The CSS wrapper hides it (`display: none`), so the fragment' \
         '\'s IntersectionObserver never fires -- no request goes out. Hovering ' \
         'flips the CSS to `display: block`, which is what makes the fragment ' \
         'visible, which is what fires the fetch. It fetches exactly once: ' \
         'hover away and back, and the content that already landed stays put, ' \
         'no second request. Six cards, zero eager cost.'
    end

  # ==========================================================================
  # 4. Infinite scroll
  #
  # Rails: nested "Russian doll" frames -- each response renders the CURRENT
  # page's rows inline and appends page N+1's placeholder frame, already
  # `loading: :lazy`, so scrolling to the bottom fetches the next page and
  # nothing is ever removed from the DOM.
  # StreamWeaver: the same shape, with `fragment(..., lazy: true)` around the
  # NEXT page only -- see `scroll_todos_page` above. No button, no scroll
  # listener, no page counter in state: scrolling to page N's bottom is what
  # makes page N+1's fragment visible, which is what fetches it.
  # ==========================================================================
  when :infinite_scroll
    header1 'Infinite scroll'
    alert(variant: :success) do
      text 'WORKS -- scroll-to-load-more, nested "Russian doll" fragments, ' \
           'each fetch sends exactly its own page.'
    end

    scroll_todos_page(1)

    div class: 'spike-gap' do
      header3 'How it works now'
      md 'The page you are ON renders inline; only the NEXT page is wrapped in ' \
         '`fragment(:"todos_page_N+1", lazy: true)`. So this shell already ' \
         'carries page 1\'s ten rows plus exactly one placeholder — view source ' \
         'and the rows are really there, which is the same progressive-' \
         'enhancement guarantee Rails gives you. Page N+1 is not in the DOM -- ' \
         'and has not fetched -- until scrolling reveals its placeholder. Each ' \
         'response carries only that page\'s rows (`TodoStore.page(n)`), not ' \
         'everything loaded so far: a constant per-page payload where the old ' \
         'click-driven version grew with every click. Wrapping page N itself in ' \
         'the lazy fragment is the tempting shape and it is wrong -- the block ' \
         'is skipped on the shell render, so the served HTML has no rows at ' \
         'all, and it only looks right because page 1\'s placeholder starts in ' \
         'the viewport. See findings doc, feature 4 resolution for the measured ' \
         'byte counts.'
    end
  end
end.run!
