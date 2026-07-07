#!/usr/bin/env ruby
# frozen_string_literal: true

# StreamWeaver Interactive Tutorial
# A self-documenting app that teaches StreamWeaver using StreamWeaver itself.
#
# Run with: streamweaver tutorial
# (Or: ruby examples/advanced/tutorial.rb)

require_relative '../../lib/stream_weaver'

# Source identifier for tracking apps in service
SOURCE = "tutorial"

# Track loaded apps: section_id => { app_id:, aliased_url: }
LOADED_APPS = {}

# CodeMirror 5 CDN URLs
CODEMIRROR_CSS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css"
CODEMIRROR_JS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js"
CODEMIRROR_RUBY = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/ruby/ruby.min.js"

# Cleanup all loaded apps on exit
at_exit do
  next if LOADED_APPS.empty?
  puts "\nCleaning up #{LOADED_APPS.size} tutorial playground(s)..."
  # Use a temporary includer to call ServiceClient methods
  Object.new.extend(StreamWeaver::ServiceClient).clear_source_via_service(SOURCE)
end

# Section data object (DHH-style: prefer objects over hashes)
Section = Data.define(:id, :nav_title, :title, :content, :code) do
  def state_key = :"#{id}_edited_code"
end

# =============================================================================
# SECTIONS - Each section is self-contained for easy editing
# =============================================================================

module Sections
  PHILOSOPHY = Section.new(
    id: :philosophy,
    nav_title: "Philosophy",
    title: "Why StreamWeaver?",
    content: <<~MD,
      ## Express Intent, Nothing Else

      Think about what a simple UI actually requires: some text, a few inputs,
      maybe a dropdown, a button. **That's it.** That's what you're trying to build.

      But to get there you're dealing with HTML structure, CSS styling, JavaScript,
      controllers, state management...

      ### The Ruby Way

      Ruby's beauty is that you can express your intent and nothing else.
      StreamWeaver brings that philosophy to UI:

      > "I want a title, an input, and a button that does something."

      That's exactly what you write. No more, no less.

      ### Token Efficiency for AI

      When building with Claude Code or other AI assistants, this minimal approach
      pays off even more:

      - **Smaller generation = faster + cheaper** - Concise DSL instead of verbose HTML/React
      - **More context** - Less code means more room for your actual problem
      - **Data-only generation** - Pre-build the app, let AI just generate data
    MD
    # Standalone example with real interactivity
    code: <<~RUBY
      header1 "Welcome!"
      text_field :name, placeholder: "Your name"

      if state[:name].to_s.strip != ""
        text "Hello, \#{state[:name]}!"
      else
        text "Type your name above."
      end
    RUBY
  )

  HELLO_WORLD = Section.new(
    id: :hello_world,
    nav_title: "Hello World",
    title: "Your First App",
    content: <<~MD,
      ## The Simplest App

      Every StreamWeaver app starts with `app` and a title.
      Inside the block, you describe your UI.

      ### Try It

      Type your name in the input below. Notice how the greeting
      appears automatically - no JavaScript, no event handlers,
      just Ruby.
    MD
    code: <<~RUBY
      header1 "Welcome!"
      text_field :name, placeholder: "Your name"

      if state[:name].to_s.strip != ""
        text "Hello, \#{state[:name]}!"
      end
    RUBY
  )

  FOUR_MODES = Section.new(
    id: :four_modes,
    nav_title: "The Four Modes",
    title: "Standalone, Agentic, Service, Canvas/Panel",
    content: <<~MD,
      ## Four Ways To Run a StreamWeaver App

      Every mode uses the same DSL you just saw - what changes is **how it's
      launched** and **who's driving**. Get oriented before going further:

      | Mode | Launch | Who it's for |
      |---|---|---|
      | **Standalone** | `ruby app.rb` (calls `.run!`) | A person, in a browser, for the life of the process |
      | **Agentic** | `StreamWeaver.run_once!` inside a script | A script needs one answer, then keeps going |
      | **Service** | `streamweaver run app.rb` | Multiple apps on one server, human `/apps/:slug` URLs |
      | **Canvas / Panel** | `streamweaver panel <session>` + `canvas-push` | An agent (Claude Code) drives live UI mid-conversation |

      ### When To Use Which

      - Building a tool a human opens in a tab and uses for a while? **Standalone.**
      - A script needs a single decision from a human before continuing? **Agentic** (`run_once!`).
      - Running several apps side by side with memorable URLs? **Service.**
      - An agent needs to show live, updating UI while it works? **Canvas/Panel.**

      This tutorial is itself a **standalone** app (`ruby examples/advanced/tutorial.rb`).
      Its "Run" button launches each playground into the **service** - you'll see
      that in action a few lessons from now, and each of the other three modes
      gets its own lesson later on.
    MD
    code: <<~RUBY
      select :demo_mode, [
        "Standalone (ruby app.rb)",
        "Agentic (run_once!)",
        "Service (streamweaver run)",
        "Canvas/Panel (streamweaver panel)"
      ], default: "Standalone (ruby app.rb)"

      case state[:demo_mode]
      when "Standalone (ruby app.rb)"
        alert(variant: :info) { text 'app("My App") { ... }.run!' }
      when "Agentic (run_once!)"
        alert(variant: :info) { text "StreamWeaver.run_once! { ... }  # blocks, returns a Hash" }
      when "Service (streamweaver run)"
        alert(variant: :info) { text "streamweaver run app.rb  -> http://localhost:4567/apps/your-app" }
      when "Canvas/Panel (streamweaver panel)"
        alert(variant: :info) { text "streamweaver panel my-session, then canvas-push my-session" }
      end
    RUBY
  )

  GETTING_INPUT = Section.new(
    id: :getting_input,
    nav_title: "Getting Input",
    title: "Text Fields & State",
    content: <<~MD,
      ## How State Works

      Every input binds to a **state key**. When you write:

      ```ruby
      text_field :name
      ```

      StreamWeaver automatically:
      1. Creates `state[:name]`
      2. Syncs the input value with state
      3. Re-renders when state changes

      ### Conditional Display

      Since the app block re-evaluates on state changes, use normal Ruby conditionals:
    MD
    code: <<~RUBY
      text_field :email, placeholder: "Email"
      text_area :message, placeholder: "Your message...", rows: 3

      if state[:email].to_s.include?("@")
        alert(variant: :success) { text "Valid email!" }
      elsif state[:email].to_s.length > 0
        alert(variant: :warning) { text "Need @ in email" }
      end
    RUBY
  )

  MAKING_CHOICES = Section.new(
    id: :making_choices,
    nav_title: "Making Choices",
    title: "Selection Components",
    content: <<~MD,
      ## Dropdowns, Checkboxes, Radio Buttons

      StreamWeaver provides several ways to capture user choices:

      - **select** - Dropdown menu
      - **checkbox** - Boolean toggle
      - **radio_group** - Single choice from options
      - **checkbox_group** - Multiple selections
    MD
    code: <<~RUBY
      header3 "Preferences"
      select :priority, ["Low", "Medium", "High"], default: "Medium"
      checkbox :urgent, "Mark as urgent"

      text "Priority: \#{state[:priority]}"
      text "Urgent: \#{state[:urgent] ? 'YES!' : 'no'}"
    RUBY
  )

  TAKING_ACTION = Section.new(
    id: :taking_action,
    nav_title: "Taking Action",
    title: "Buttons & Callbacks",
    content: <<~MD,
      ## Making Things Happen

      Buttons execute code when clicked. The callback receives the current state:

      ```ruby
      button "Click Me" do |state|
        # Your code here
        state[:count] += 1
      end
      ```

      ### Button Styles

      Use `style: :secondary` for less prominent actions.
    MD
    code: <<~RUBY
      state[:count] ||= 0

      header2 "Count: \#{state[:count]}"

      hstack spacing: :sm do
        button "+" do |s|
          s[:count] += 1
        end
        button "-", style: :secondary do |s|
          s[:count] -= 1
        end
        button "Reset", style: :secondary do |s|
          s[:count] = 0
        end
      end
    RUBY
  )

  LAYOUT = Section.new(
    id: :layout,
    nav_title: "Layout",
    title: "Cards, Columns & Stacks",
    content: <<~MD,
      ## Organizing Your UI

      StreamWeaver provides several layout components:

      - **card** - Styled container with optional header/footer
      - **columns** - Multi-column layouts
      - **vstack/hstack** - Vertical/horizontal stacking
      - **grid** - Responsive grid layouts

      ### Labeled Card Headers

      `card_header "Title", badge: "C1", meta: "..."` renders a small mono
      badge before the title and right-aligned meta text after it - handy for
      compact, labeled sections (a status panel, a numbered step, ...).
    MD
    code: <<~RUBY
      columns widths: ['30%', '70%'] do
        column do
          card do
            card_header "Sidebar"
            card_body do
              text "Navigation"
              button "Option 1"
              button "Option 2", style: :secondary
            end
          end
        end
        column do
          card do
            card_header "Main Content", badge: "C1", meta: "content pane"
            card_body do
              text_field :search, placeholder: "Search..."
              text "Wide area for content"
            end
          end
        end
      end
    RUBY
  )

  TABLES = Section.new(
    id: :tables,
    nav_title: "Tables",
    title: "Displaying Data",
    content: <<~MD,
      ## Tables and Lists

      Build data displays using divs with CSS grid or flexbox.

      ### The Pattern

      Use nested divs with grid styling:

      ```ruby
      div style: "display: grid; grid-template-columns: repeat(3, 1fr);" do
        # Header row
        div { text "Name" }
        # Data rows...
      end
      ```

      ### Iteration

      Loop over data with `.each` to generate rows.
    MD
    code: <<~RUBY
      data = [
        { name: "Alice", role: "Admin", active: "Yes" },
        { name: "Bob", role: "User", active: "Yes" },
        { name: "Charlie", role: "Guest", active: "No" }
      ]

      # Grid-based table
      div style: "display: grid; grid-template-columns: 1fr 1fr 80px; border: 1px solid #ddd; border-radius: 4px;" do
        # Header
        ["Name", "Role", "Active?"].each do |h|
          div style: "padding: 10px; background: #f5f5f5; font-weight: 600; border-bottom: 2px solid #ddd;" do
            text h
          end
        end

        # Data rows
        data.each do |row|
          [:name, :role, :active].each do |col|
            div style: "padding: 10px; border-bottom: 1px solid #eee;" do
              text row[col]
            end
          end
        end
      end
    RUBY
  )

  MODALS = Section.new(
    id: :modals,
    nav_title: "Modals",
    title: "Dialogs & Confirmations",
    content: <<~MD,
      ## Modal Dialogs

      Use modals for confirmations, forms, or any content that needs focus.

      ### How Modals Work

      1. Define the modal with a unique key
      2. Set `state[:key_open] = true` to show it
      3. Use `modal_footer` for action buttons

      ### Sizes

      Available sizes: `:sm`, `:md`, `:lg`, `:xl`
    MD
    code: <<~RUBY
      button "Delete Item" do |s|
        s[:confirm_open] = true
      end

      if state[:confirmed]
        alert(variant: :success) { text "Item deleted!" }
      end

      modal :confirm, title: "Confirm Delete", size: :sm do
        text "Are you sure you want to delete this item?"
        text "This action cannot be undone."

        modal_footer do
          button "Delete", style: :primary do |s|
            s[:confirmed] = true
            s[:confirm_open] = false
          end
          button "Cancel", style: :secondary do |s|
            s[:confirm_open] = false
          end
        end
      end
    RUBY
  )

  THEMES = Section.new(
    id: :themes,
    nav_title: "Themes",
    title: "Custom Styling",
    content: <<~MD,
      ## Themes

      StreamWeaver theming has two independent layers, both switchable via CSS
      variables and the `style` attribute.

      ### Built-in Themes (`app theme: :name`)

      - `:default` - Warm Industrial
      - `:dashboard` - Data Dense
      - `:document` - Reading Mode (serif, generous line-height)
      - `:doc` - Compact Editorial (tight, magazine-like)

      ### Presets (`theme_preset :name`)

      A second layer of curated font + color palettes you can drop onto any
      theme with one line: `:editorial`, `:technical`, `:warm`, `:minimal`,
      `:terminal`, and `:sketch` (hand-drawn wireframe look - rough.js borders
      and a Caveat handwriting font).

      ```ruby
      app "My App", theme: :doc do
        theme_preset :sketch
        # ...
      end.run!
      ```

      ### Dark Mode, Automatically

      `theme_toggle mode: :auto` adds a dark/light/auto button that **follows
      the OS `prefers-color-scheme`** out of the box and remembers the user's
      override in `localStorage`. `theme_switcher` renders a full picker over
      every registered theme instead of a single toggle - try both below,
      they actually change this page's theme.

      ### CSS Variables & Inline Styles

      Override colors per-app with `theme_overrides:`, or reach for `style:`
      on any component for one-off styling:
    MD
    code: <<~RUBY
      theme_switcher
      theme_toggle mode: :auto

      # Using CSS variables
      div style: "background: var(--sw-color-primary); color: white; padding: 1rem; border-radius: 8px; margin-top: 0.75rem;" do
        text "Primary colored box"
      end

      div style: "margin-top: 1rem;" do end

      # Custom styling
      div style: "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 1.5rem; border-radius: 12px; color: white;" do
        header3 "Gradient Header"
        text "Custom styled content"
      end
    RUBY
  )

  NAVIGATION = Section.new(
    id: :navigation,
    nav_title: "Navigation",
    title: "navbar, nav_item, link_to & State Routing",
    content: <<~MD,
      ## Cross-App Navigation

      - `navbar` - a horizontal nav bar container
      - `nav_item "Label", href: "/path", active: true` - bold and
        non-clickable when active, a link otherwise
      - `link_to "Label", href: "/path"` - a plain inline anchor

      ```ruby
      navbar do
        nav_item "Dashboard", href: "/", active: true
        nav_item "Settings", href: "/settings"
      end
      link_to "Docs", href: "https://example.com"
      ```

      ### `route_by` / `route_with` - State Routing, Not HTTP Routing

      These map a URL to **state**, not to a server-side handler - the same
      StreamWeaver view still renders, just seeded differently.
      `route_by :page, home: "/", settings: "/settings"` gives one state key a
      bidirectional URL mapping; `route_with(parser:, builder:)` handles
      parameterized routes (`/post/:id`) with two lambdas. See
      `docs/routing.md` for the full parser/builder contract.

      If you need a genuine HTTP route that bypasses rendering entirely (a
      webhook, a JSON API, a file download), that's `endpoint` - next lesson.

      **Heads up:** Run below launches into the multi-app *service*, where
      every app lives under `/apps/:slug` - so this snippet's `/` and
      `/settings` hrefs point above that scope and will 404 if you click
      them there. State routing is built for **standalone** apps; save this
      code to a file and `ruby` it directly to see the real URLs work.
    MD
    code: <<~RUBY
      route_by :page, home: "/", settings: "/settings"
      state[:page] ||= :home

      navbar do
        nav_item "Home", href: "/", active: state[:page] == :home
        nav_item "Settings", href: "/settings", active: state[:page] == :settings
      end

      case state[:page]
      when :home
        header3 "Home"
        text "Visiting / sets state[:page] = :home"
      when :settings
        header3 "Settings"
        text "Visiting /settings sets state[:page] = :settings"
      end
    RUBY
  )

  RESOURCE_DSL = Section.new(
    id: :resource_dsl,
    nav_title: "Resource DSL",
    title: "CRUD Scaffolding",
    content: <<~MD,
      ## One Block, Full CRUD

      `resource :name, store: MyStore do field ... end` replaces 30-50 lines
      of hand-written routes/state/forms with index, show, new, edit, and
      delete - all deep-linkable.

      | URL | Action |
      |---|---|
      | `GET /posts` | Index - table with View / Edit / Delete |
      | `GET /posts/new` | New - form, Create button |
      | `GET /post/:id` | Show - card with field values |
      | `GET /post/:id/edit` | Edit - form seeded from the record |
      | Delete button | Inline confirm, then destroys |

      Stores are duck-typed - any object with `all`, `find`, `create`,
      `update`, `destroy` works. See `docs/resource-dsl.md` for the full
      field-type table, override blocks, and named-route helpers
      (`posts_path`, `post_path(rec)`, ...).

      Declare `page`/`route` calls **before** `resource` blocks - routing is
      first-registered-wins, so the root path needs its own landing page.

      **Heads up:** like the Navigation lesson, this is state routing -
      built for **standalone** apps. Run below launches into the multi-app
      service (same as every other lesson's playground), so the "View
      Posts" link's `/posts` href points above the service's `/apps/:slug`
      scope and will 404 if you click it there. Save this code to a file
      and `ruby` it directly to click through the real thing.
    MD
    code: <<~RUBY
      module PostStore
        @posts = [{ id: '1', title: 'Hello', body: 'First post', status: 'published' }]
        def self.all;        @posts; end
        def self.find(id);   @posts.find { |p| p[:id] == id }; end
        def self.create(attrs)
          id = ((@posts.map { |p| p[:id].to_i }.max || 0) + 1).to_s
          @posts << { id: id, **attrs }; id
        end
        def self.update(id, attrs); post = find(id) or return false; post.merge!(attrs); true; end
        def self.destroy(id);       @posts.reject! { |p| p[:id] == id }; true; end
      end

      state[:_sw_action] ||= :home  # first render inside this playground has no URL to route from

      page :home, '/' do
        header1 "Blog"
        link_to "View Posts", href: "/posts"  # posts_path isn't defined until `resource` below runs
      end

      resource :post, store: PostStore do
        field :title,  :string
        field :body,   :text
        field :status, :enum, values: %w[draft published]
      end
    RUBY
  )

  ENDPOINTS = Section.new(
    id: :endpoints,
    nav_title: "Endpoints",
    title: "The endpoint DSL - a Real HTTP Escape Hatch",
    content: <<~MD,
      ## When You Need Real HTTP

      `route_by`/`route_with` map URLs to *state* - same page, different
      seed. Sometimes you need a genuine HTTP route instead: a webhook
      receiver, a JSON API, a file download. That's `endpoint`.

      ```ruby
      app "My App" do
        endpoint :get, "/api/status" do |req|
          { ok: true, uptime: 42 }        # Hash -> 200 application/json
        end
      end.run!
      ```

      - Supported verbs: `:get`, `:post`, `:put`, `:patch`, `:delete`
      - The block receives the raw `Rack::Request`; return a `Hash` (JSON), a
        `String` (HTML), or `[status, headers, body]` for full control
      - Endpoints bypass state/session/CSRF entirely - no StreamWeaver
        machinery, just Rack
      - **Reserved paths**: anything under `/update`, `/action/*`, `/submit`,
        `/event/*`, `/form/*`, `/theme/*`, `/sw/*` always loses to
        StreamWeaver's internal routes - `endpoint` warns at registration
        time if you collide

      ### This Tutorial Eats Its Own Dog Food

      This tutorial app registers a real endpoint:
      `endpoint :get, "/tutorial/api/hello"`. With the tutorial running, hit
      it from another terminal (check the startup banner for the actual port
      - StreamWeaver auto-picks one starting at 4567):

      ```bash
      curl http://127.0.0.1:<PORT>/tutorial/api/hello
      ```
    MD
    code: <<~RUBY
      endpoint :get, "/api/ping" do |req|
        { ok: true, message: "pong", name: req.params["name"] || "world" }
      end

      header3 "Live Endpoint"
      text "Registered: GET /api/ping"
      text "Click Run, then curl the playground URL's /api/ping"
    RUBY
  )

  SERVICE_MODE = Section.new(
    id: :service_mode,
    nav_title: "Service Mode",
    title: "One Server, Many Apps, Human URLs",
    content: <<~MD,
      ## Multiple Apps, One Server

      `streamweaver run app.rb` (or just `streamweaver app.rb`) starts (or
      reuses) a single background service and serves your app at a
      human-readable slug URL like `/apps/sales-dashboard`, derived from the
      app's declared name (falling back to the filename). The old opaque hex
      `/apps/:app_id` URL still resolves too, as a canonical fallback.

      - Slugs that collide across different files get a numeric suffix
        (`-2`, `-3`, ...)
      - Re-loading the same file reuses its existing slug
      - `streamweaver list` shows every loaded app and its URL;
        `streamweaver remove <app_id>` / `streamweaver clear` tear them down

      **This tutorial already uses the service** - every "Run" button on a
      code panel loads that playground into the service and hands you back
      its slug URL. That's `streamweaver`'s service doing exactly this job,
      one playground at a time.
    MD
    code: <<~RUBY
      text_field :demo_app_name, placeholder: "App name...", default: "Sales Dashboard"

      name = state[:demo_app_name].to_s.strip
      name = "Sales Dashboard" if name.empty?
      slug = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\\A-+|-+\\z/, "")

      header3 "Derived slug"
      code_block "/apps/\#{slug}", lang: "text"
      text "A second app with the same name gets /apps/\#{slug}-2, and so on."
    RUBY
  )

  CANVAS_PANEL = Section.new(
    id: :canvas_panel,
    nav_title: "Canvas / Panel",
    title: "Live UI For Coding Agents",
    content: <<~MD,
      ## A Canvas Claude Code Can Push To

      Canvas/Panel mode gives an agent (Claude Code or similar) a
      **persistent browser session** it can push UI into and read responses
      from, mid-conversation - no polling, no screenshots.

      This lesson is a CLI walkthrough, not an in-page demo - canvas needs
      its own terminal and browser pane. Copy these into a real terminal:

      ```bash
      # 1. Open a panel - splits iTerm2, opens the canvas in the right pane
      #    (falls back to your system browser outside iTerm2 / without iterm2_ruby)
      streamweaver panel demo-session

      # 2. Push some UI to it (DSL via stdin)
      streamweaver canvas-push demo-session <<'RUBY'
      header1 "Working..."
      spinner label: "Crunching numbers"
      RUBY

      # 3. Ask the user something and block for the answer
      streamweaver canvas-wait demo-session
      # => {"choice":"B"}

      # High-level one-shot helpers - skip the create/push/wait dance
      streamweaver pick "Pick a branch" "main" "feature/x" "feature/y"
      streamweaver confirm "Deploy to production?"

      # When you're done
      streamweaver canvas-close demo-session
      ```

      See `docs/canvas-roadmap.md` and `docs/streamweaver-for-ai-agents.md`
      for the full pattern catalog.
    MD
    code: <<~RUBY
      # This is a shell walkthrough, not a StreamWeaver app - copy it into a
      # terminal rather than clicking Run.

      # streamweaver panel demo-session
      # streamweaver canvas-push demo-session <<'RUBY'
      #   header1 "Working..."
      #   spinner label: "Crunching numbers"
      # RUBY
      # streamweaver canvas-wait demo-session
    RUBY
  )

  PATTERNS = Section.new(
    id: :patterns,
    nav_title: "Patterns",
    title: "Real-World Patterns",
    content: <<~MD,
      ## Multi-Step Forms

      Combine state and conditionals to build wizards and multi-step flows.

      ### The Pattern

      1. Track current step in state
      2. Use `case` or `if` to show the right content
      3. Buttons update the step

      This same pattern works for:
      - Onboarding flows
      - Checkout processes
      - Survey wizards
    MD
    code: <<~RUBY
      state[:step] ||= 1

      # Progress indicator
      hstack spacing: :sm do
        [1, 2, 3].each do |n|
          style = state[:step] >= n ? "background: var(--sw-color-primary); color: white;" : "background: #eee; color: #666;"
          div style: "\#{style} width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold;" do
            text n.to_s
          end
        end
      end

      div style: "margin: 1rem 0;" do end

      case state[:step]
      when 1
        header3 "Step 1: Your Info"
        text_field :wizard_name, placeholder: "Your name"
        button "Next" do |s|
          s[:step] = 2 if s[:wizard_name].to_s.strip != ""
        end
      when 2
        header3 "Step 2: Preferences"
        select :wizard_plan, ["Free", "Pro", "Enterprise"]
        hstack spacing: :sm do
          button "Back", style: :secondary do |s| s[:step] = 1 end
          button "Next" do |s| s[:step] = 3 end
        end
      when 3
        header3 "Step 3: Confirm"
        text "Name: \#{state[:wizard_name]}"
        text "Plan: \#{state[:wizard_plan] || 'Free'}"
        hstack spacing: :sm do
          button "Back", style: :secondary do |s| s[:step] = 2 end
          button "Submit" do |s| s[:done] = true end
        end
      end

      if state[:done]
        alert(variant: :success) { text "All done! Welcome, \#{state[:wizard_name]}!" }
      end
    RUBY
  )

  ALL_SECTIONS = [
    PHILOSOPHY,
    HELLO_WORLD,
    FOUR_MODES,
    GETTING_INPUT,
    MAKING_CHOICES,
    TAKING_ACTION,
    LAYOUT,
    TABLES,
    MODALS,
    THEMES,
    NAVIGATION,
    RESOURCE_DSL,
    ENDPOINTS,
    SERVICE_MODE,
    CANVAS_PANEL,
    PATTERNS
  ].freeze
end

# =============================================================================
# SERVICE HELPERS - API calls to StreamWeaver service
# =============================================================================

module ServiceHelpers
  include StreamWeaver::ServiceClient

  def run_playground_via_service(section_id, code)
    # Remove old version if same section was already loaded
    if LOADED_APPS[section_id]
      remove_app_via_service(LOADED_APPS[section_id][:app_id])
      LOADED_APPS.delete(section_id)
    end

    # Write temp file with full app wrapper
    temp_file = "/tmp/streamweaver_tutorial_#{section_id}.rb"
    full_code = <<~RUBY
      require 'stream_weaver'

      app "Tutorial: #{section_id}" do
        #{code}
      end
    RUBY
    File.write(temp_file, full_code)

    # Load via ServiceClient
    result = load_app_via_service(temp_file, source: SOURCE, name: "tutorial/#{section_id}")

    if result[:ok]
      LOADED_APPS[section_id] = {
        app_id: result[:app_id],
        aliased_url: result[:aliased_url]
      }
    end

    result
  end

  def remove_playground_via_service(app_id)
    remove_app_via_service(app_id)
    LOADED_APPS.delete_if { |_id, info| info[:app_id] == app_id }
  end
end

# =============================================================================
# HELPER MODULE - Reusable rendering helpers
# =============================================================================

module TutorialHelpers
  include ServiceHelpers

  def code_panel(section_id, original_code)
    # Store edited code in state (initialized in main app)
    state_key = :"#{section_id}_edited_code"

    # Track if modified
    is_modified = state[state_key] != original_code

    # Use CodeMirror editor with syntax highlighting
    code_editor state_key, language: :ruby, readonly: false, height: "350px"

    # Show modified indicator
    if is_modified
      div style: "margin-top: 4px; font-size: 12px; color: #666;" do
        text "Modified"
      end
    end
  end

  def nav_link(section, current_id)
    is_active = section.id == current_id

    # Check if modified
    is_modified = state[:"#{section.id}_edited_code"] != section.code

    # Styled list item instead of button - looks like a ToC
    nav_item_style = <<~CSS.gsub("\n", " ")
      display: block;
      padding: 8px 12px;
      cursor: pointer;
      border-radius: 4px;
      border-left: 3px solid #{is_active ? 'var(--sw-color-primary)' : 'transparent'};
      background: #{is_active ? '#f0f7ff' : 'transparent'};
      color: #{is_active ? '#1a73e8' : '#444'};
      font-weight: #{is_active ? '500' : 'normal'};
      font-size: 14px;
      text-decoration: none;
      border-top: none;
      border-right: none;
      border-bottom: none;
      text-align: left;
      width: 100%;
    CSS

    # Use stable label for button ID (don't include indicator)
    # Show modified indicator separately in the button content
    div style: "display: flex; align-items: center;" do
      if is_modified
        div style: "width: 6px; height: 6px; background: var(--sw-color-primary); border-radius: 50%; margin-right: 6px;" do end
      end
      button section.nav_title, style: nav_item_style do |s|
        s[:current_section] = section.id
      end
    end
  end

  def check_syntax(code)
    require 'open3'
    temp_file = "/tmp/sw_tutorial_syntax_#{Process.pid}.rb"
    File.write(temp_file, code)
    _stdout, stderr, status = Open3.capture3("ruby", "-c", temp_file)
    File.delete(temp_file) rescue nil

    if status.success?
      { ok: true, message: "Syntax OK" }
    else
      error = stderr.gsub(temp_file, "code")
      { ok: false, message: error.strip }
    end
  end

  def code_action_buttons(section, current)
    is_modified = state[:"#{section.id}_edited_code"] != section.code

    hstack spacing: :xs do
      # Check syntax
      button "Check", style: :secondary do |s|
        result = check_syntax(s[:"#{section.id}_edited_code"])
        if result[:ok]
          s[:syntax_result] = :ok
        else
          s[:syntax_result] = :error
          s[:syntax_error] = result[:message]
        end
      end

      # Reset this lesson only - ALWAYS render with block for stable ID
      # The block checks is_modified at execution time, not render time
      reset_style = is_modified ? :secondary : "padding: 8px 16px; background: #f5f5f5; color: #aaa; border: 1px solid #ddd; border-radius: 6px; cursor: default;"
      button "Reset", style: reset_style do |s|
        # Only reset if actually modified (check at execution time)
        edited = s[:"#{section.id}_edited_code"]
        if edited != section.code
          s[:"#{section.id}_reset"] = true
          s[:syntax_result] = nil
        end
      end

      # Run as standalone app
      button "Run" do |s|
        edited_code = s[:"#{section.id}_edited_code"]
        result = check_syntax(edited_code)
        if result[:ok]
          run_result = run_playground_via_service(section.id, edited_code)
          if run_result[:ok]
            open_in_browser(run_result[:url])
            s[:standalone_launched] = section.id
            s[:syntax_result] = nil
          else
            s[:syntax_result] = :error
            s[:syntax_error] = run_result[:error]
          end
        else
          s[:syntax_result] = :error
          s[:syntax_error] = result[:message]
        end
      end
    end

    # Show running playground link
    if LOADED_APPS[section.id]
      app_info = LOADED_APPS[section.id]
      url = app_info[:aliased_url] || "http://localhost:#{service_port}/apps/#{app_info[:app_id]}"
      div style: "margin-top: 8px; padding: 6px 10px; background: #e8f5e9; border-radius: 4px; font-size: 13px; display: flex; justify-content: space-between; align-items: center;" do
        div style: "color: #2e7d32;" do
          text "Running"
          if app_info[:aliased_url]
            div style: "font-family: monospace; font-size: 11px; color: #666;" do
              text app_info[:aliased_url].sub("http://localhost:#{service_port}", "")
            end
          end
        end
        hstack spacing: :xs do
          button "Open", style: "padding: 2px 8px; font-size: 12px; background: #4caf50; color: white; border: none; border-radius: 3px; cursor: pointer;" do |_s|
            open_in_browser(url)
          end
          button "Stop", style: "padding: 2px 8px; font-size: 12px; background: transparent; color: #666; border: none; cursor: pointer;" do |s|
            remove_playground_via_service(app_info[:app_id])
            LOADED_APPS.delete(section.id)
            s[:standalone_launched] = nil
          end
        end
      end
    end

    # Show syntax result
    if state[:syntax_result] == :ok
      div style: "margin-top: 8px; padding: 6px 10px; background: #d4edda; color: #155724; border-radius: 4px; font-size: 13px;" do
        text "Syntax OK"
      end
    elsif state[:syntax_result] == :error
      div style: "margin-top: 8px; padding: 6px 10px; background: #f8d7da; color: #721c24; border-radius: 4px; font-size: 13px; font-family: monospace; white-space: pre-wrap;" do
        text state[:syntax_error]
      end
    end
  end

  def clear_playgrounds_button
    # Always render for stable button IDs
    if LOADED_APPS.any?
      button "Clear Playgrounds", style: :secondary do |s|
        LOADED_APPS.each { |_id, info| remove_playground_via_service(info[:app_id]) }
        LOADED_APPS.clear
        s[:standalone_launched] = nil
      end
    else
      # Disabled placeholder for stable ID
      button "Clear Playgrounds", style: "padding: 8px 16px; background: #f5f5f5; color: #aaa; border: 1px solid #ddd; border-radius: 6px; cursor: default;", submit: false
    end
  end
end

# =============================================================================
# DEMO RENDERERS - Live demos for each section
# =============================================================================

module DemoRenderers
  # Dynamic dispatch instead of case statement (DRY)
  def render_demo(section_id, state)
    method_name = :"render_#{section_id}_demo"
    send(method_name, state) if respond_to?(method_name, true)
  end

  def render_philosophy_demo(state)
    card do
      card_header "Try It"
      card_body do
        header1 "Welcome!"
        text_field :demo_philosophy_name, placeholder: "Your name"
        if state[:demo_philosophy_name].to_s.strip != ""
          text "Hello, #{state[:demo_philosophy_name]}! Welcome to StreamWeaver."
        else
          text "Type your name above to see reactive updates."
        end
      end
    end
  end

  def render_hello_world_demo(state)
    card do
      card_header "Try It"
      card_body do
        header1 "Welcome!"
        text_field :demo_name, placeholder: "Your name"
        if state[:demo_name].to_s.strip != ""
          text "Hello, #{state[:demo_name]}!"
        end
      end
    end
  end

  def render_four_modes_demo(state)
    card do
      card_header "Try It"
      card_body do
        select :demo_mode_pick, [
          "Standalone (ruby app.rb)",
          "Agentic (run_once!)",
          "Service (streamweaver run)",
          "Canvas/Panel (streamweaver panel)"
        ], default: "Standalone (ruby app.rb)"

        case state[:demo_mode_pick]
        when "Standalone (ruby app.rb)"
          alert(variant: :info) { text 'app("My App") { ... }.run!' }
        when "Agentic (run_once!)"
          alert(variant: :info) { text "StreamWeaver.run_once! { ... }  # blocks, returns a Hash" }
        when "Service (streamweaver run)"
          alert(variant: :info) { text "streamweaver run app.rb  -> http://localhost:4567/apps/your-app" }
        when "Canvas/Panel (streamweaver panel)"
          alert(variant: :info) { text "streamweaver panel my-session, then canvas-push my-session" }
        end
      end
    end
  end

  def render_getting_input_demo(state)
    card do
      card_header "Try It"
      card_body do
        text_field :demo_email, placeholder: "Email"
        text_area :demo_message, placeholder: "Your message...", rows: 3

        if state[:demo_email].to_s.include?("@")
          alert(variant: :success) { text "Valid email format!" }
        elsif state[:demo_email].to_s.length > 0
          alert(variant: :warning) { text "Please include @ in email" }
        end
      end
    end
  end

  def render_making_choices_demo(state)
    card do
      card_header "Try It"
      card_body do
        select :demo_priority, ["Low", "Medium", "High"], default: "Medium"
        checkbox :demo_urgent, "Mark as urgent"
        radio_group :demo_category, ["Bug", "Feature", "Question"]

        if state[:demo_priority] || state[:demo_category]
          vstack spacing: :sm do
            text "Priority: #{state[:demo_priority] || 'Not set'}"
            text "Urgent: #{state[:demo_urgent] ? 'Yes' : 'No'}"
            text "Category: #{state[:demo_category] || 'Not set'}"
          end
        end
      end
    end
  end

  def render_taking_action_demo(state)
    card do
      card_header "Try It"
      card_body do
        state[:demo_count] ||= 0

        header2 "Count: #{state[:demo_count]}"

        hstack spacing: :sm do
          button "Increment" do |s|
            s[:demo_count] += 1
          end
          button "Decrement", style: :secondary do |s|
            s[:demo_count] -= 1
          end
          button "Reset", style: :secondary do |s|
            s[:demo_count] = 0
          end
        end
      end
    end
  end

  def render_layout_demo(_state)
    card do
      card_header "Try It"
      card_body do
        columns widths: ["40%", "60%"] do
          column do
            card do
              card_body do
                text "Sidebar (40%)"
              end
            end
          end
          column do
            card do
              card_header "Main Content", badge: "C1", meta: "content pane"
              card_body do
                vstack spacing: :sm do
                  text "Main content (60%)"
                  hstack spacing: :sm do
                    alert(variant: :info) { text "Alert 1" }
                    alert(variant: :success) { text "Alert 2" }
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def render_tables_demo(_state)
    card do
      card_header "Try It"
      card_body do
        data = [
          { name: "Alice", role: "Admin", active: "Yes" },
          { name: "Bob", role: "User", active: "Yes" },
          { name: "Charlie", role: "Guest", active: "No" }
        ]

        div style: "display: grid; grid-template-columns: 1fr 1fr 80px; border: 1px solid #ddd; border-radius: 4px;" do
          # Header
          ["Name", "Role", "Active?"].each do |h|
            div style: "padding: 10px; background: #f5f5f5; font-weight: 600; border-bottom: 2px solid #ddd;" do
              text h
            end
          end

          # Data rows
          data.each do |row|
            [:name, :role, :active].each do |col|
              div style: "padding: 10px; border-bottom: 1px solid #eee;" do
                text row[col]
              end
            end
          end
        end
      end
    end
  end

  def render_modals_demo(state)
    card do
      card_header "Try It"
      card_body do
        button "Show Confirmation" do |s|
          s[:demo_modal_open] = true
        end

        if state[:demo_modal_confirmed]
          alert(variant: :success) { text "Action confirmed!" }
        end

        modal :demo_modal, title: "Confirm Action", size: :sm do
          text "Do you want to proceed with this action?"

          modal_footer do
            button "Confirm" do |s|
              s[:demo_modal_confirmed] = true
              s[:demo_modal_open] = false
            end
            button "Cancel", style: :secondary do |s|
              s[:demo_modal_open] = false
            end
          end
        end
      end
    end
  end

  def render_themes_demo(_state)
    card do
      card_header "Try It"
      card_body do
        hstack spacing: :sm, align: :center do
          theme_switcher
          theme_toggle mode: :auto
        end
        div style: "background: var(--sw-color-primary); color: white; padding: 1rem; border-radius: 8px; margin-top: 0.75rem; margin-bottom: 0.5rem;" do
          text "Primary color box"
        end
        div style: "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 1rem; border-radius: 8px; color: white;" do
          text "Custom gradient"
        end
      end
    end
  end

  def render_navigation_demo(_state)
    card do
      card_header "Try It"
      card_body do
        text "Preview of the navbar look (click Run above to try real state-routing URLs in an isolated playground):"
        navbar do
          nav_item "Home", active: true
          nav_item "Settings"
          nav_item "Profile"
        end
        div style: "margin-top: 0.75rem;" do end
        link_to "External docs example", href: "https://example.com"
      end
    end
  end

  def render_resource_dsl_demo(_state)
    card do
      card_header "Try It"
      card_body do
        text "Preview of a generated index view (real resource blocks are deep-linkable; click Run for the live version):"
        div style: "display: grid; grid-template-columns: 1fr 1fr 160px; border: 1px solid #ddd; border-radius: 4px; margin-top: 0.5rem;" do
          ["Title", "Status", "Actions"].each do |h|
            div style: "padding: 8px 10px; background: #f5f5f5; font-weight: 600; border-bottom: 2px solid #ddd;" do
              text h
            end
          end
          [["Hello", "published"], ["Draft idea", "draft"]].each do |title, status|
            div(style: "padding: 8px 10px; border-bottom: 1px solid #eee;") { text title }
            div(style: "padding: 8px 10px; border-bottom: 1px solid #eee;") { text status }
            div(style: "padding: 8px 10px; border-bottom: 1px solid #eee;") { text "View · Edit · Delete" }
          end
        end
      end
    end
  end

  def render_endpoints_demo(_state)
    card do
      card_header "Try It", badge: "Live", meta: "runs against this very page"
      card_body do
        text "This tutorial registered a real endpoint. From another terminal:"
        code_block "curl http://127.0.0.1:<PORT>/tutorial/api/hello", lang: "bash"
        text "(Swap <PORT> for whatever the startup banner printed - StreamWeaver auto-picks a free port starting at 4567.)"
      end
    end
  end

  def render_service_mode_demo(state)
    card do
      card_header "Try It"
      card_body do
        text_field :demo_app_name, placeholder: "App name...", default: "Sales Dashboard"

        name = state[:demo_app_name].to_s.strip
        name = "Sales Dashboard" if name.empty?
        slug = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")

        header3 "Derived slug"
        code_block "/apps/#{slug}", lang: "text"
        text "A second app with the same name gets /apps/#{slug}-2, and so on."
      end
    end
  end

  def render_canvas_panel_demo(_state)
    card do
      card_header "Try It", meta: "in a real terminal"
      card_body do
        alert(variant: :info) { text "Canvas/Panel needs its own terminal + browser pane - there's nothing to click here." }
        text "Copy the commands from the Code panel into a terminal to try it for real."
      end
    end
  end

  def render_patterns_demo(state)
    card do
      card_header "Try It"
      card_body do
        state[:demo_step] ||= 1

        # Progress dots
        hstack spacing: :xs do
          [1, 2, 3].each do |n|
            bg = state[:demo_step] >= n ? "var(--sw-color-primary)" : "#ddd"
            fg = state[:demo_step] >= n ? "white" : "#666"
            div style: "background: #{bg}; color: #{fg}; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold;" do
              text n.to_s
            end
          end
        end

        div style: "margin: 0.75rem 0;" do end

        case state[:demo_step]
        when 1
          text_field :demo_wizard_name, placeholder: "Your name"
          button "Next" do |s|
            s[:demo_step] = 2 if s[:demo_wizard_name].to_s.strip != ""
          end
        when 2
          select :demo_wizard_plan, ["Free", "Pro", "Enterprise"]
          hstack spacing: :sm do
            button "Back", style: :secondary do |s| s[:demo_step] = 1 end
            button "Next" do |s| s[:demo_step] = 3 end
          end
        when 3
          text "Name: #{state[:demo_wizard_name]}"
          text "Plan: #{state[:demo_wizard_plan] || 'Free'}"
          hstack spacing: :sm do
            button "Back", style: :secondary do |s| s[:demo_step] = 2 end
            button "Done" do |s| s[:demo_wizard_done] = true end
          end
        end

        if state[:demo_wizard_done]
          alert(variant: :success) { text "Wizard complete!" }
        end
      end
    end
  end
end

# =============================================================================
# MAIN APP
# =============================================================================

# Check for --reset flag
RESET_MODE = ARGV.include?('--reset')

generated_app = app(
  "StreamWeaver Tutorial",
  layout: :fluid,
  theme: :default,
  stylesheets: [CODEMIRROR_CSS],
  scripts: [CODEMIRROR_JS, CODEMIRROR_RUBY],
  components: [TutorialHelpers, DemoRenderers]
) do
  # Self-demonstrating endpoint for the "Endpoints" lesson - a real HTTP route
  # you can curl while the tutorial is running: see Sections::ENDPOINTS.
  endpoint :get, "/tutorial/api/hello" do |req|
    { ok: true, message: "Hello from the StreamWeaver tutorial's own endpoint!", name: req.params["name"] || "world" }
  end

  # Force clear state if --reset flag was passed
  if RESET_MODE && !state[:_reset_done]
    state.clear
    state[:_reset_done] = true
    state[:current_section] = :philosophy
  end

  # Initialize state
  state[:current_section] ||= :philosophy

  # Initialize edited code states for all sections
  # Check for reset flags (set by Reset button, survives session filtering)
  Sections::ALL_SECTIONS.each do |section|
    reset_flag = :"#{section.id}_reset"
    if state[reset_flag]
      # Reset was clicked - force original code and clear flag
      state[:"#{section.id}_edited_code"] = section.code
      state.delete(reset_flag)
    else
      state[:"#{section.id}_edited_code"] ||= section.code
    end
  end


  # Find current section
  current = Sections::ALL_SECTIONS.find { |s| s.id == state[:current_section] }
  current ||= Sections::PHILOSOPHY

  # Header
  hstack justify: :between, align: :center do
    header1 "StreamWeaver Tutorial"
    hstack spacing: :sm, align: :center do
      text "Learn by doing"
      clear_playgrounds_button
      button "Reset All", style: :secondary do |s|
        # Clear all state including edited code, but stay on current section
        current_section = s[:current_section]
        s.clear
        s[:current_section] = current_section || :philosophy
        # Set reset flags for all sections (init code will restore originals)
        Sections::ALL_SECTIONS.each do |section|
          s[:"#{section.id}_reset"] = true
        end
      end
    end
  end

  # 3-column layout with stable widths
  div style: "display: flex; gap: 1.5rem; align-items: flex-start;" do
    # LEFT: Navigation (fixed width)
    div style: "flex: 0 0 180px; min-width: 180px;" do
      div style: "font-weight: 600; font-size: 14px; color: #666; margin-bottom: 8px; padding: 0 12px;" do
        text "Contents"
      end
      div do
        Sections::ALL_SECTIONS.each do |section|
          nav_link(section, state[:current_section])
        end
      end
    end

    # MIDDLE: Content (roughly 50/50 with code)
    div style: "flex: 1 1 auto; min-width: 400px;" do
      header2 current.title
      md current.content

      # Live demo
      header3 "Interactive Demo"
      render_demo(current.id, state)
    end

    # RIGHT: Code (flexible - takes remaining space)
    div style: "flex: 1 1 auto; min-width: 400px;" do
      # Header row with Code label and action buttons
      div style: "display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;" do
        div style: "font-weight: 600; font-size: 14px; color: #666;" do
          text "Code"
        end
        code_action_buttons(current, current)
      end

      # Code editor in a card
      card do
        card_body do
          code_panel(current.id, current.code)
        end
      end
    end
  end

  # Footer navigation (use stable labels for button IDs)
  hstack justify: :between do
    current_idx = Sections::ALL_SECTIONS.index(current)

    # Previous button - always render with stable label
    if current_idx > 0
      prev_section = Sections::ALL_SECTIONS[current_idx - 1]
      button "Previous", style: :secondary do |s|
        s[:current_section] = prev_section.id
      end
    else
      button "Previous", style: "padding: 8px 16px; background: #f5f5f5; color: #aaa; border: 1px solid #ddd; border-radius: 6px; cursor: default;", submit: false
    end

    # Next button - always render with stable label
    if current_idx < Sections::ALL_SECTIONS.length - 1
      next_section = Sections::ALL_SECTIONS[current_idx + 1]
      button "Next", style: :primary do |s|
        s[:current_section] = next_section.id
      end
    else
      button "Next", style: "padding: 8px 16px; background: #f5f5f5; color: #aaa; border: 1px solid #ddd; border-radius: 6px; cursor: default;", submit: false
    end
  end
end

# Always run - tutorial command runs this standalone
generated_app.run!
