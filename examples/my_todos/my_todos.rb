#!/usr/bin/env ruby
# frozen_string_literal: true

# My Todos -- StreamWeaver parity spike against the learnhotwire.com course's
# Rails app (github.com/learnhotwire/rails), Turbo Frames chapter.
#
# Rule of the spike: ZERO custom JavaScript in app code. No script tags, no
# inline JS, no hand-written Alpine. Only DSL verbs and CSS. Where a feature
# cannot be built inside that rule, the app says so on screen and
# docs/research/streamweaver-way-spike-findings.md records exactly where it
# broke.
#
#   SW_NO_OPEN=1 ruby examples/my_todos/my_todos.rb
#
# Findings doc: docs/research/streamweaver-way-spike-findings.md

require_relative '../../lib/stream_weaver'
require_relative 'store'

# The chapter's hover card is "three lines of CSS, no JavaScript": the frame is
# display:none until :hover flips it to display:block, and Turbo's
# loading="lazy" IntersectionObserver fires the fetch at exactly that moment.
# StreamWeaver gets the CSS half; see feature 3 in the findings doc for the half
# it does not get.
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
  state[:page] ||= 1

  navbar do
    nav_item 'Inline editing',  href: '/',                active: state[:feature] == :inline_edit
    nav_item 'Search',          href: '/search',          active: state[:feature] == :search
    nav_item 'Hover cards',     href: '/hover-cards',     active: state[:feature] == :hover_cards
    nav_item 'Infinite scroll', href: '/infinite-scroll', active: state[:feature] == :infinite_scroll
  end

  fragment(:flash) { }

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
  # StreamWeaver: `text_field` auto-submits on input with no controller at all,
  # but it has no equivalent of `data-turbo-frame` -- see the two arrangements
  # below and feature 2 in the findings doc.
  # ==========================================================================
  when :search
    header1 'Search'
    alert(variant: :warning) do
      text 'PARTIAL -- submit-as-you-type is free, but an input cannot name a ' \
           'sibling fragment.'
      text 'A below is the Rails layout (field outside the results); it swaps the ' \
           'whole app body. B moves the field inside the fragment to get a scoped ' \
           'swap, at the cost of the field re-rendering itself on every keystroke.'
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
      header3 'Where it breaks'
      md '`text_field` never passes `sw_updates:` to `htmx_attrs`, so an input ' \
         'targets its own enclosing fragment or `#app-container` -- there is no ' \
         '`data-turbo-frame` equivalent. Worse, `text_field :query, updates: ' \
         ':results` is accepted and silently ignored. See findings doc, feature 2.'
    end

  # ==========================================================================
  # 3. Hover cards  -- EXPECTED GAP
  #
  # Rails: `turbo_frame_tag todo.user, :hovercard, src: ..., loading: :lazy`
  # inside a `div.hovercard`. CSS reveals it; `loading=lazy` means the fetch
  # only happens because the reveal made it visible.
  # StreamWeaver: the CSS reveal works. The lazy fetch has no primitive, so
  # every card below is rendered eagerly, in the same request as the list.
  # ==========================================================================
  when :hover_cards
    header1 'Hover cards'
    alert(variant: :warning) do
      text 'PARTIAL -- CSS reveal works, lazy fetch does not exist.'
      text 'Every card below was rendered eagerly with the list. Boot with ' \
           'SW_HOVERCARD_DELAY=1.5 to feel what the missing laziness costs.'
    end

    TodoStore.all.first(6).each do |todo|
      user = UserStore.find(todo[:user_id])
      div class: 'todo-row' do
        hstack spacing: :sm do
          text "☐  #{todo[:title]} —"
          # Keyed by the todo, not the user: the chapter (38:52) demos two todos
          # sharing an assignee emitting the same frame id twice. StreamWeaver
          # has no dom_id helper, so the convention is hand-applied here.
          div class: 'hovercard' do
            text user[:name]
            div class: 'hovercard-panel' do
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

    div class: 'spike-gap' do
      header3 'Where it breaks'
      md 'No DSL verb defers a region until it becomes visible. `tabs lazy: true` ' \
         'is click-triggered (and deprecated), `every` is post-load, and `defer` ' \
         'is an unimplemented no-op that silently drops its block. See findings ' \
         'doc, feature 3.'
    end

  # ==========================================================================
  # 4. Infinite scroll  -- EXPECTED GAP
  #
  # Rails: nested "Russian doll" frames -- page N's response contains page N+1's
  # placeholder frame, already `loading: :lazy`, so scrolling to the bottom
  # fetches the next page and nothing is ever removed from the DOM.
  # StreamWeaver: no nested lazy frames and no visibility trigger, so this
  # degrades to a click-driven "Load more" that re-sends every row loaded so far.
  # ==========================================================================
  when :infinite_scroll
    header1 'Infinite scroll'
    alert(variant: :warning) do
      text 'DEGRADED -- click-to-load-more, not scroll-to-load-more.'
    end

    fragment(:todo_pages) do
      page = state[:page].to_i
      loaded = TodoStore.through_page(page)
      loaded.each { |t| text "#{t[:completed] ? '☑' : '☐'}  #{t[:title]}" }
      text "Showing #{loaded.length} of #{TodoStore.all.length} (page #{page} of #{TodoStore.page_count})"

      # The `if` is the chapter's `@pagy.next` guard: without it Rails renders a
      # frame with a blank id and the chain dead-ends in "Content missing".
      if page < TodoStore.page_count
        button('Load more') { |s| s[:page] = page + 1 }
      end
    end

    div class: 'spike-gap' do
      header3 'Where it breaks'
      md 'Two gaps compose here: no visibility trigger (so a button stands in ' \
         'for the scroll), and no nested/appending fragments (so each click ' \
         're-sends every row already on screen instead of just the new page). ' \
         'See findings doc, feature 4.'
    end
  end
end.run!
