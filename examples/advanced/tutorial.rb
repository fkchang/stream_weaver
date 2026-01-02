#!/usr/bin/env ruby
# frozen_string_literal: true

# StreamWeaver Interactive Tutorial
# A self-documenting app that teaches StreamWeaver using StreamWeaver itself.
#
# Run with: streamweaver tutorial
# (Or: ruby examples/advanced/tutorial.rb)

require_relative '../../lib/stream_weaver'
require 'net/http'
require 'json'
require 'rbconfig'

# Source identifier for tracking apps in service
SOURCE = "tutorial"

# Track loaded apps: section_id => { app_id:, aliased_url: }
LOADED_APPS = {}

# Cleanup all loaded apps on exit
at_exit do
  next if LOADED_APPS.empty?
  puts "\nCleaning up #{LOADED_APPS.size} tutorial playground(s)..."
  begin
    info = StreamWeaver::Service.read_pid_file
    if info
      uri = URI("http://localhost:#{info[:port]}/clear-source")
      Net::HTTP.post_form(uri, { source: SOURCE })
    end
  rescue
    # Service might be down, that's ok
  end
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

  ALL_SECTIONS = [
    PHILOSOPHY,
    HELLO_WORLD,
    GETTING_INPUT,
    MAKING_CHOICES,
    TAKING_ACTION,
    LAYOUT
  ].freeze
end

# =============================================================================
# SERVICE HELPERS - API calls to StreamWeaver service
# =============================================================================

module ServiceHelpers
  def service_port
    info = StreamWeaver::Service.read_pid_file
    info ? info[:port] : StreamWeaver::Service::DEFAULT_PORT
  end

  def run_playground_via_service(section_id, code)
    # Remove old version if same section was already loaded
    if LOADED_APPS[section_id]
      remove_playground_via_service(LOADED_APPS[section_id][:app_id])
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

    # Load via service API
    uri = URI("http://localhost:#{service_port}/load-app")
    params = { file_path: temp_file, source: SOURCE, name: "tutorial/#{section_id}" }

    response = Net::HTTP.post_form(uri, params)
    result = JSON.parse(response.body)

    if result['success']
      LOADED_APPS[section_id] = {
        app_id: result['app_id'],
        aliased_url: result['aliased_url']
      }
      {
        ok: true,
        app_id: result['app_id'],
        url: "http://localhost:#{service_port}#{result['url']}",
        aliased_url: result['aliased_url'] ? "http://localhost:#{service_port}#{result['aliased_url']}" : nil
      }
    else
      { ok: false, error: result['error'] }
    end
  rescue Errno::ECONNREFUSED
    { ok: false, error: "Service not running. Start with: streamweaver tutorial" }
  rescue => e
    { ok: false, error: e.message }
  end

  def remove_playground_via_service(app_id)
    uri = URI("http://localhost:#{service_port}/remove-app")
    Net::HTTP.post_form(uri, { app_id: app_id })
    LOADED_APPS.delete_if { |_id, info| info[:app_id] == app_id }
  rescue
    # Ignore errors
  end

  def open_in_browser(url)
    case RbConfig::CONFIG['host_os']
    when /darwin|mac os/
      system('open', url)
    when /linux|bsd/
      system('xdg-open', url)
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      system('start', url)
    end
  end
end

# =============================================================================
# HELPER MODULE - Reusable rendering helpers
# =============================================================================

module TutorialHelpers
  include ServiceHelpers

  def code_panel(section_id, initial_code)
    # Store edited code in state
    state_key = :"#{section_id}_edited_code"
    state[state_key] ||= initial_code

    # Just use a simple, reliable textarea
    text_area(
      state_key,
      rows: 22,
      style: "font-family: 'Monaco', 'Menlo', 'Consolas', monospace; font-size: 14px; width: 100%; padding: 1rem; border: 1px solid var(--sw-color-border); border-radius: 4px; background: #f5f5f5; color: #333; line-height: 1.6; tab-size: 2;",
      submit: false
    )
  end

  def nav_link(section, current_id)
    is_active = section.id == current_id
    style = is_active ? :primary : :secondary

    button section.nav_title, style: style do |s|
      s[:current_section] = section.id
    end
  end

  def run_standalone_button(section_id)
    button "Run Standalone" do |s|
      # Get edited code from state
      edited_code = s[:"#{section_id}_edited_code"]

      # Load via service (replaces old version if same section)
      result = run_playground_via_service(section_id, edited_code)
      if result[:ok]
        # Auto-open in browser
        open_in_browser(result[:url])
        s[:standalone_launched] = section_id
      else
        s[:standalone_error] = result[:error]
      end
    end
  end

  def clear_playgrounds_button
    if LOADED_APPS.any?
      button "Clear #{LOADED_APPS.length} Playground(s)", style: :secondary do |s|
        LOADED_APPS.each { |_id, info| remove_playground_via_service(info[:app_id]) }
        LOADED_APPS.clear
        s[:standalone_launched] = nil
      end
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

  def render_philosophy_demo(_state)
    alert(variant: :info) do
      text "This section explains the philosophy. The demo is the entire tutorial!"
    end
  end

  def render_hello_world_demo(state)
    card do
      card_header "Live Demo"
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
  Sections::ALL_SECTIONS.each do |section|
    state[:"#{section.id}_edited_code"] ||= section.code
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
      button "Reset", style: :secondary do |s|
        # Clear all state including edited code
        s.clear
        s[:current_section] = :philosophy
        # Reinitialize all code editors with original code
        Sections::ALL_SECTIONS.each do |section|
          s[:"#{section.id}_edited_code"] = section.code
        end
      end
    end
  end

  # 3-column layout with stable widths
  div style: "display: flex; gap: 1.5rem; align-items: flex-start;" do
    # LEFT: Navigation (fixed width)
    div style: "flex: 0 0 180px; min-width: 180px;" do
      card do
        card_header "Contents"
        card_body do
          vstack spacing: :xs do
            Sections::ALL_SECTIONS.each do |section|
              nav_link(section, state[:current_section])
            end
          end
        end
      end
    end

    # MIDDLE: Content (flexible)
    div style: "flex: 1 1 auto; min-width: 300px;" do
      header2 current.title
      md current.content

      # Live demo
      header3 "Interactive Demo"
      render_demo(current.id, state)
    end

    # RIGHT: Code (fixed width)
    div style: "flex: 0 0 400px; min-width: 400px;" do
      card do
        card_header do
          hstack justify: :between, align: :center do
            text "Code"
            run_standalone_button(current.id)
          end
        end
        card_body do
          code_panel(current.id, current.code)
        end
      end

      if state[:standalone_launched] == current.id
        alert(variant: :success) do
          text "Launched! Check for new browser tab."
        end
      end
    end
  end

  # Footer navigation
  hstack justify: :between do
    current_idx = Sections::ALL_SECTIONS.index(current)

    if current_idx > 0
      prev_section = Sections::ALL_SECTIONS[current_idx - 1]
      button "← #{prev_section.nav_title}", style: :secondary do |s|
        s[:current_section] = prev_section.id
      end
    else
      text "" # Placeholder
    end

    if current_idx < Sections::ALL_SECTIONS.length - 1
      next_section = Sections::ALL_SECTIONS[current_idx + 1]
      button "#{next_section.nav_title} →" do |s|
        s[:current_section] = next_section.id
      end
    else
      text "" # Placeholder
    end
  end
end

# Always run - tutorial command runs this standalone
generated_app.run!
