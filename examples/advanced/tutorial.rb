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
            card_header "Main Content"
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

      StreamWeaver supports theming via CSS variables and the `style` attribute.

      ### Built-in Themes

      - `:default` - Clean, minimal look
      - `:dashboard` - Optimized for data-heavy apps
      - `:document` - Reading-focused layout

      ### CSS Variables

      Override colors using `theme_overrides`:

      ```ruby
      app "My App", theme_overrides: { primary: "#0066cc" } do
        # ...
      end
      ```

      ### Inline Styles

      Any component accepts a `style:` attribute:
    MD
    code: <<~RUBY
      # Using CSS variables
      div style: "background: var(--sw-color-primary); color: white; padding: 1rem; border-radius: 8px;" do
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
    GETTING_INPUT,
    MAKING_CHOICES,
    TAKING_ACTION,
    LAYOUT,
    TABLES,
    MODALS,
    THEMES,
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
        div style: "background: var(--sw-color-primary); color: white; padding: 1rem; border-radius: 8px; margin-bottom: 0.5rem;" do
          text "Primary color box"
        end
        div style: "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 1rem; border-radius: 8px; color: white;" do
          text "Custom gradient"
        end
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
