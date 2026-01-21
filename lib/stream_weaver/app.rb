# frozen_string_literal: true

require 'digest'

module StreamWeaver
  # Main app class that holds the DSL block and manages the component tree
  class App
    # Built-in themes (custom themes checked via StreamWeaver.theme_exists?)
    BUILT_IN_THEMES = [:default, :dashboard, :document, :dark].freeze
    # For backwards compatibility
    VALID_THEMES = BUILT_IN_THEMES

    attr_reader :title, :components, :block, :layout, :theme, :theme_overrides, :scripts, :stylesheets

    def initialize(title, layout: :default, theme: :default, theme_overrides: {}, components: [], scripts: [], stylesheets: [], &block)
      @title = title
      @layout = layout
      @theme = validate_theme(theme)
      @theme_overrides = theme_overrides
      @block = block
      @components = []
      @state_key = :streamlit_state
      @_state = {}
      @button_counter = 0
      @scripts = scripts
      @stylesheets = stylesheets

      components.each { |mod| singleton_class.include(mod) }
    end

    private

    def validate_theme(theme)
      theme = theme.to_sym
      # Accept built-in themes or custom registered themes
      return theme if BUILT_IN_THEMES.include?(theme) || StreamWeaver.theme_exists?(theme)
      warn "StreamWeaver: Unknown theme '#{theme}', falling back to :default"
      :default
    end

    public

    def state
      @_state
    end

    def rebuild_with_state(current_state)
      @_state = current_state
      @components = []
      @button_counter = 0
      instance_eval(&@block)
    end

    # Find a component by its key (for callback execution)
    def find_component_by_key(key, components_list = @components)
      components_list.each do |component|
        return component if component.respond_to?(:key) && component.key == key
        # Search in children if component has them
        if component.respond_to?(:children) && component.children
          found = find_component_by_key(key, component.children)
          return found if found
        end
        # Also search modal footer if present
        if component.is_a?(Components::Modal) && component.footer_component&.children
          found = find_component_by_key(key, component.footer_component.children)
          return found if found
        end
      end
      nil
    end

    def generate
      SinatraApp.create(self)
    end

    def has_charts?
      components_include?(Components::ChartBase)
    end

    private

    def components_include?(klass)
      @components.any? { |c| c.is_a?(klass) || nested_include?(c, klass) }
    end

    def nested_include?(component, klass)
      return false unless component.respond_to?(:children) && component.children
      component.children.any? { |c| c.is_a?(klass) || nested_include?(c, klass) }
    end

    public

    # =========================================
    # Container DSL methods
    # =========================================

    def div(**options, &block)
      with_container(Components::Div.new(**options), &block)
    end

    # App header bar - renders a full-width header with title, optional subtitle, and optional right-side content
    # @param title [String] The header title
    # @param subtitle [String, nil] Optional subtitle
    # @param variant [Symbol] Style variant (:dark, :light, :primary)
    def app_header(title, subtitle: nil, variant: :dark, &block)
      with_container(Components::AppHeader.new(title, subtitle: subtitle, variant: variant), &block)
    end

    def card(**options, &block)
      with_container(Components::Card.new(**options), &block)
    end

    def card_header(content_or_options = nil, **options, &block)
      component = if content_or_options.is_a?(String)
        Components::CardHeader.new(content_or_options, **options)
      else
        opts = content_or_options.is_a?(Hash) ? content_or_options.merge(options) : options
        Components::CardHeader.new(nil, **opts)
      end
      with_container(component, &block)
    end

    def card_body(**options, &block)
      with_container(Components::CardBody.new(**options), &block)
    end

    def card_footer(**options, &block)
      with_container(Components::CardFooter.new(**options), &block)
    end

    def vstack(spacing: :md, align: nil, divider: false, **options, &block)
      with_container(Components::VStack.new(spacing: spacing, align: align, divider: divider, **options), &block)
    end

    def hstack(spacing: :sm, align: nil, justify: nil, divider: false, **options, &block)
      with_container(Components::HStack.new(spacing: spacing, align: align, justify: justify, divider: divider, **options), &block)
    end

    def grid(columns: 3, gap: :md, **options, &block)
      with_container(Components::Grid.new(columns: columns, gap: gap, **options), &block)
    end

    def collapsible(label, expanded: false, **options, &block)
      with_container(Components::Collapsible.new(label, expanded: expanded, **options), &block)
    end

    def lesson_text(content_or_options = nil, **options, &block)
      if content_or_options.is_a?(String)
        glossary = options[:glossary] || {}
        lesson_component = Components::LessonText.new(glossary: glossary)
        @components << lesson_component
        lesson_component.children = parse_lesson_string(content_or_options, glossary)
      else
        opts = content_or_options.is_a?(Hash) ? content_or_options.merge(options) : options
        glossary = opts[:glossary] || {}
        with_container(Components::LessonText.new(glossary: glossary), &block)
      end
    end

    # =========================================
    # Layout containers with special behavior
    # =========================================

    def columns(widths: nil, **options, &block)
      columns_component = Components::Columns.new(widths: widths, **options)
      @components << columns_component

      parent_components = @components
      @current_columns = columns_component
      @components = []

      instance_eval(&block) if block

      columns_component.children = @components
      @components = parent_components
      @current_columns = nil
    end

    def column(**options, &block)
      column_component = Components::Column.new(**options)
      capture_children_then_append(column_component, &block)
    end

    def checkbox_group(key, **options, &block)
      @_state[key] = options[:default] || [] unless @_state.key?(key)

      group_component = Components::CheckboxGroup.new(key, **options)
      @components << group_component

      parent_components = @components
      @current_checkbox_group = group_component
      @components = []

      instance_eval(&block) if block

      group_component.children = @components
      @components = parent_components
      @current_checkbox_group = nil
    end

    def item(value, &block)
      item_component = Components::CheckboxItem.new(value)
      capture_children_then_append(item_component, &block)
    end

    # =========================================
    # Form container with special context
    # =========================================

    def form(name, **options, &block)
      form_component = Components::Form.new(name, **options)
      @components << form_component
      @_state[name] ||= {}

      parent_components = @components
      @current_form = form_component
      @form_context = { name: name }
      @components = []

      instance_eval(&block) if block

      form_component.children = @components
      @components = parent_components
      @current_form = nil
      @form_context = nil
    end

    def submit(label, &block)
      raise "submit can only be used inside a form block" unless @current_form
      @current_form.set_submit(label, &block)
    end

    def cancel(label)
      raise "cancel can only be used inside a form block" unless @current_form
      @current_form.set_cancel(label)
    end

    def form_context
      @form_context
    end

    # =========================================
    # Form input components
    # =========================================

    def text_field(key, **options)
      initialize_form_state(key, options, "")
      @components << Components::TextField.new(key, **options)
    end

    def text_area(key, **options)
      initialize_form_state(key, options, "")
      @components << Components::TextArea.new(key, **options)
    end

    def code_editor(key, language: :ruby, readonly: true, height: "400px", **options)
      initialize_form_state(key, options, "")
      @components << Components::CodeEditor.new(key, language: language, readonly: readonly, height: height, **options)
    end

    def checkbox(key, label, **options)
      initialize_form_state(key, options, false)
      @components << Components::Checkbox.new(key, label, **options)
    end

    def select(key, choices, **options)
      initialize_form_state(key, options, options[:default] || "", skip_if_exists: true)
      @components << Components::Select.new(key, choices, **options)
    end

    def radio_group(key, choices, **options)
      initialize_form_state(key, options, "")
      @components << Components::RadioGroup.new(key, choices, **options)
    end

    def tag_buttons(key, tags, **options)
      @_state[key] ||= nil
      @components << Components::TagButtons.new(key, tags, **options)
    end

    # =========================================
    # Simple leaf components
    # =========================================

    def text(content)
      @components << Components::Text.new(content)
    end

    def md(content)
      @components << Components::Markdown.new(content)
    end
    alias_method :markdown, :md

    # Header methods via metaprogramming (DRY)
    (1..6).each do |level|
      define_method(:"header#{level}") { |content| @components << Components::Header.new(content, level: level) }
    end
    alias_method :header, :header2

    def phrase(content)
      @components << Components::Phrase.new(content)
    end

    def term(term_key, **options)
      @components << Components::Term.new(term_key, **options)
    end

    def button(label, **options, &block)
      # Generate stable ID: use source location for buttons with blocks,
      # fallback to counter for blockless buttons (submit: false)
      if block
        source_loc = block.source_location.join(':')
        stable_id = Digest::MD5.hexdigest("#{label}:#{source_loc}")[0..7]
      else
        @button_counter += 1
        stable_id = @button_counter.to_s
      end
      # Pass modal context to button so it can close the modal via Alpine
      options[:modal_context] = @modal_context if @modal_context
      @components << Components::Button.new(label, stable_id, **options, &block)
    end

    def score_table(scores:, **options)
      @components << Components::ScoreTable.new(scores: scores, **options)
    end

    # Table component for displaying tabular data with smart inference
    # @param data [Array, Hash, Symbol, nil] Data source (positional or keyword)
    # @param headers [Array<String>] Column headers (optional, auto-inferred from data)
    # @param rows [Array<Array>] Row data (original API)
    # @param file [String] Path to YAML/JSON file
    # @param path [String] Dot-notation path within file data (e.g., "data.users")
    # @param striped [Boolean] Zebra striping (default: false)
    # @param bordered [Boolean] Show borders (default: false)
    # @param hoverable [Boolean] Highlight on hover (default: true)
    # @param compact [Boolean] Reduced padding (default: false)
    # @param sortable [Boolean] Enable client-side sorting (default: false)
    # @param sticky_header [Boolean] Keep header visible on scroll (default: false)
    # @param caption [String] Table caption (optional)
    # @example Original API
    #   table headers: ["Name", "Size"], rows: [["app.rb", "12kb"]]
    # @example Array of hashes (auto-infer headers)
    #   table [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }]
    # @example Hash of arrays
    #   table({ name: ["Alice", "Bob"], age: [30, 25] })
    # @example From file
    #   table file: "users.yaml", path: "data.users"
    # @example State binding
    #   table data: :users
    # @example Column DSL with formatters
    #   table users do
    #     column :name
    #     column :balance, format: :currency, align: :right
    #     column(:active) { |u| u.active ? "Yes" : "No" }
    #   end
    def table(positional_data = nil, data: nil, headers: nil, rows: nil, file: nil, path: nil, **options, &block)
      # Support both: table [data] (positional) and table data: :key (keyword)
      actual_data = positional_data || data
      @components << Components::Table.new(
        actual_data, headers: headers, rows: rows, file: file, path: path, **options, &block
      )
    end

    # =========================================
    # Chart DSL methods
    # =========================================

    def bar_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      @components << Components::BarChart.new(
        data: data, file: file, path: path, labels: labels, values: values, **options, &block
      )
    end

    def hbar_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      bar_chart(data: data, file: file, path: path, labels: labels, values: values, horizontal: true, **options, &block)
    end

    def line_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      @components << Components::LineChart.new(
        data: data, file: file, path: path, labels: labels, values: values, **options, &block
      )
    end

    def sparkline(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      line_chart(data: data, file: file, path: path, labels: labels, values: values, sparkline: true, **options, &block)
    end

    def area_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      line_chart(data: data, file: file, path: path, labels: labels, values: values, fill: true, **options, &block)
    end

    def pie_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      @components << Components::PieChart.new(
        data: data, file: file, path: path, labels: labels, values: values, **options, &block
      )
    end

    def doughnut_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      pie_chart(data: data, file: file, path: path, labels: labels, values: values, doughnut: true, **options, &block)
    end

    def stacked_bar_chart(data: nil, file: nil, path: nil, **options, &block)
      @components << Components::StackedBarChart.new(data: data, file: file, path: path, **options, &block)
    end

    def status_badge(status, reasoning)
      @components << Components::StatusBadge.new(status, reasoning)
    end

    def external_link_button(label, url:, submit: false)
      @components << Components::ExternalLinkButton.new(label, url: url, submit: submit)
    end

    # =========================================
    # Navigation DSL methods
    # =========================================

    def tabs(key, variant: :line, **options, &block)
      @_state[key] ||= 0

      tabs_component = Components::Tabs.new(key, variant: variant, **options)
      @components << tabs_component

      parent_components = @components
      @current_tabs = tabs_component
      @components = []

      instance_eval(&block) if block

      tabs_component.children = @components
      @components = parent_components
      @current_tabs = nil
    end

    def tab(label, **options, &block)
      tab_component = Components::Tab.new(label, **options)
      capture_children_then_append(tab_component, &block)
    end

    def breadcrumbs(separator: "/", **options, &block)
      breadcrumbs_component = Components::Breadcrumbs.new(separator: separator, **options)
      @components << breadcrumbs_component

      parent_components = @components
      @current_breadcrumbs = breadcrumbs_component
      @components = []

      instance_eval(&block) if block

      breadcrumbs_component.children = @components
      @components = parent_components
      @current_breadcrumbs = nil
    end

    def crumb(label, href: nil, **options)
      @components << Components::Crumb.new(label, href: href, **options)
    end

    def dropdown(**options, &block)
      dropdown_component = Components::Dropdown.new(**options)
      @components << dropdown_component

      @current_dropdown = dropdown_component
      instance_eval(&block) if block
      @current_dropdown = nil
    end

    def trigger(&block)
      raise "trigger can only be used inside a dropdown block" unless @current_dropdown

      trigger_component = Components::DropdownTrigger.new
      parent_components = @components
      @components = []

      instance_eval(&block) if block

      trigger_component.children = @components
      @components = parent_components
      @current_dropdown.trigger_component = trigger_component
    end

    def menu(**options, &block)
      raise "menu can only be used inside a dropdown block" unless @current_dropdown

      menu_component = Components::Menu.new(**options)
      parent_components = @components
      @current_menu = menu_component
      @components = []

      instance_eval(&block) if block

      menu_component.children = @components
      @components = parent_components
      @current_dropdown.menu_component = menu_component
      @current_menu = nil
    end

    def menu_item(label, style: :default, **options, &block)
      raise "menu_item can only be used inside a menu block" unless @current_menu
      @button_counter += 1
      item = Components::MenuItem.new(label, style: style, **options, &block)
      item.instance_variable_set(:@id, "menu_item_#{@button_counter}")
      @components << item
    end

    def menu_divider
      raise "menu_divider can only be used inside a menu block" unless @current_menu
      @components << Components::MenuDivider.new
    end

    # =========================================
    # Modal DSL methods
    # =========================================

    def modal(key, title: nil, size: :md, **options, &block)
      # Initialize state for modal open/close
      open_key = :"#{key}_open"
      @_state[open_key] = false unless @_state.key?(open_key)

      modal_component = Components::Modal.new(key, title: title, size: size, **options)
      @components << modal_component

      parent_components = @components
      @current_modal = modal_component
      @modal_context = { key: key }  # Track we're inside a modal
      @components = []

      instance_eval(&block) if block

      modal_component.children = @components
      @components = parent_components
      @current_modal = nil
      @modal_context = nil
    end

    def modal_footer(**options, &block)
      raise "modal_footer can only be used inside a modal block" unless @current_modal

      footer_component = Components::ModalFooter.new(**options)
      parent_components = @components
      # Keep modal_context active for buttons inside footer
      @components = []

      instance_eval(&block) if block

      footer_component.children = @components
      @components = parent_components
      @current_modal.footer_component = footer_component
    end

    # Helper to open a modal (use in button callbacks)
    def open_modal(key)
      @_state[:"#{key}_open"] = true
    end

    # Helper to close a modal (use in button callbacks)
    def close_modal(key)
      @_state[:"#{key}_open"] = false
    end

    # =========================================
    # Feedback DSL methods
    # =========================================

    def alert(variant: :info, title: nil, dismissible: false, **options, &block)
      with_container(Components::Alert.new(variant: variant, title: title, dismissible: dismissible, **options), &block)
    end

    # Add a toast container to render notifications at a screen position
    # @param position [Symbol] Screen position (:top_right, :top_left, :bottom_right, :bottom_left)
    # @param duration [Integer] Default auto-dismiss duration in milliseconds
    def toast_container(position: :top_right, duration: 5000, **options)
      @_state[:_toasts] ||= []
      @components << Components::ToastContainer.new(position: position, duration: duration, **options)
    end

    # Helper to show a toast notification (use in button callbacks)
    # @param message [String] The toast message
    # @param variant [Symbol] Toast type (:info, :success, :warning, :error)
    # @param duration [Integer] Auto-dismiss duration (uses container default if nil)
    def show_toast(message, variant: :info, duration: nil)
      @_state[:_toasts] ||= []
      toast_id = "toast_#{Time.now.to_f.to_s.gsub('.', '_')}_#{rand(1000)}"
      toast = { id: toast_id, message: message, variant: variant }
      toast[:duration] = duration if duration
      @_state[:_toasts] << toast
    end

    # Helper to dismiss a specific toast by ID
    def dismiss_toast(toast_id)
      @_state[:_toasts] ||= []
      @_state[:_toasts].reject! { |t| t[:id] == toast_id }
    end

    # Helper to clear all toasts
    def clear_toasts
      @_state[:_toasts] = []
    end

    def progress_bar(value:, max: 100, variant: :default, show_label: false, animated: false, **options)
      @components << Components::ProgressBar.new(value: value, max: max, variant: variant, show_label: show_label, animated: animated, **options)
    end

    def spinner(size: :md, label: nil, **options)
      @components << Components::Spinner.new(size: size, label: label, **options)
    end

    # Theme switcher dropdown for runtime theme selection
    # @param position [Symbol] Position (:inline, :fixed_top_right)
    # @param show_label [Boolean] Show "Theme:" label (default: true)
    def theme_switcher(position: :inline, show_label: true, **options)
      @components << Components::ThemeSwitcher.new(position: position, show_label: show_label, **options)
    end

    # =========================================
    # Dashboard components (Cabinet Control style)
    # =========================================

    # Colored status indicator dot with optional pulse animation
    # @param status [Symbol] Status color (:red, :yellow, :green, :gray)
    # @param pulse [Boolean] Enable pulsing animation (default: false)
    # @param size [Symbol] Size (:sm, :md, :lg) - default :md
    # @example
    #   status_dot status: :green, pulse: true
    def status_dot(status: :gray, pulse: false, size: :md, **options)
      @components << Components::StatusDot.new(status: status, pulse: pulse, size: size, **options)
    end

    # Small count/label badge pill
    # @param text [String] Badge text/count
    # @param variant [Symbol] Color variant (:default, :danger, :warning, :success, :info)
    # @param size [Symbol] Size (:sm, :md) - default :sm
    # @example
    #   badge "5", variant: :danger
    def badge(text, variant: :default, size: :sm, **options)
      @components << Components::Badge.new(text, variant: variant, size: size, **options)
    end

    # Large metric number with label
    # @param value [String, Integer] The main value to display
    # @param label [String] Label text below the value
    # @param color [Symbol] Value color (:default, :blue, :purple, :green, :red, :yellow)
    # @param size [Symbol] Size (:sm, :md, :lg) - default :md
    # @example
    #   stat_display value: 42, label: "TASKS", color: :blue
    def stat_display(value:, label:, color: :blue, size: :md, **options)
      @components << Components::StatDisplay.new(value: value, label: label, color: color, size: size, **options)
    end

    # Activity type tag badge
    # @param type_name [Symbol, String] The type (:research, :task, :escalation, etc.)
    # @param color [Symbol, nil] Override color for custom types
    # @example
    #   type_tag :research
    #   type_tag "custom", color: :purple
    def type_tag(type_name, color: nil, **options)
      @components << Components::TypeTag.new(type_name, color: color, **options)
    end

    # Animated pulse indicator with label
    # @param color [Symbol] Dot color (:green, :red, :yellow, :blue) - default :green
    # @param label [String] Status text next to the dot
    # @example
    #   pulse_indicator color: :green, label: "System Active"
    def pulse_indicator(color: :green, label: nil, **options)
      @components << Components::PulseIndicator.new(color: color, label: label, **options)
    end

    # Priority item with colored left border (escalation style)
    # @param priority [Symbol] Priority level (:critical, :urgent, :high, :normal, :low)
    # @param title [String] Item title
    # @param description [String, nil] Optional description text
    # @param meta_left [String, nil] Left-side metadata (e.g., secretary name)
    # @param meta_right [String, nil] Right-side metadata (e.g., action link)
    # @example
    #   priority_item priority: :critical, title: "Needs attention",
    #                 description: "Something requires action",
    #                 meta_left: "scheduler", meta_right: "View details"
    def priority_item(priority: :normal, title:, description: nil, meta_left: nil, meta_right: nil, **options, &block)
      component = Components::PriorityItem.new(
        priority: priority, title: title, description: description,
        meta_left: meta_left, meta_right: meta_right, **options
      )
      with_container(component, &block)
    end

    # Activity item with time, title, summary, and type tag
    # @param time [String] Time display (e.g., "15:00")
    # @param title [String] Activity title
    # @param summary [String, nil] Optional summary text
    # @param type [Symbol, nil] Activity type for TypeTag (:research, :task, etc.)
    # @example
    #   activity_item time: "14:30", title: "Meeting notes",
    #                 summary: "Discussed Q4 planning", type: :task
    def activity_item(time:, title:, summary: nil, type: nil, **options)
      @components << Components::ActivityItem.new(time: time, title: title, summary: summary, type: type, **options)
    end

    # =========================================
    # Layout components (Cabinet Control style)
    # =========================================

    # Two-column app layout with main content and sidebar
    # @param sidebar_width [String] CSS width for sidebar (default: "320px")
    # @param sidebar_position [Symbol] Sidebar position (:left, :right) - default :right
    # @param gap [String] Gap between main and sidebar (default: "1.5rem")
    # @yield Define main content with `main do ... end` and sidebar with `sidebar do ... end`
    # @example
    #   app_shell sidebar_width: "300px" do
    #     main do
    #       header2 "Content"
    #     end
    #     sidebar header: "Escalations" do
    #       priority_item priority: :critical, title: "Urgent"
    #     end
    #   end
    def app_shell(sidebar_width: "320px", sidebar_position: :right, gap: "1.5rem", **options, &block)
      component = Components::AppShell.new(
        sidebar_width: sidebar_width,
        sidebar_position: sidebar_position,
        gap: gap,
        **options
      )
      @components << component

      return component unless block

      # Capture the app_shell context for main/sidebar helpers
      @current_app_shell = component
      instance_eval(&block)
      @current_app_shell = nil

      component
    end

    # Main content area within app_shell
    # @yield Define main content components
    def main(**options, &block)
      raise "main can only be used inside an app_shell block" unless @current_app_shell

      parent_components = @components
      @components = []
      instance_eval(&block) if block
      @current_app_shell.main_children = @components
      @components = parent_components
    end

    # Sidebar within app_shell
    # @param header [String, nil] Optional header text for sidebar
    # @param sticky [Boolean] Whether sidebar content is sticky (default: true)
    # @yield Define sidebar content components
    def sidebar(header: nil, sticky: true, **options, &block)
      raise "sidebar can only be used inside an app_shell block" unless @current_app_shell

      sidebar_component = Components::Sidebar.new(header: header, sticky: sticky, **options)

      parent_components = @components
      @components = []
      instance_eval(&block) if block
      sidebar_component.children = @components
      @components = parent_components

      @current_app_shell.sidebar_children << sidebar_component
    end

    # Expandable card that shows/hides content on click
    # @param key [Symbol] State key for expanded state
    # @param title [String] Card title (always visible)
    # @param subtitle [String, nil] Optional subtitle
    # @param badge_text [String, nil] Optional badge text (e.g., "5 activities")
    # @param badge_variant [Symbol] Badge color variant
    # @param status [Symbol, nil] Status indicator color (:red, :yellow, :green, :gray)
    # @param initially_expanded [Boolean] Whether card starts expanded (default: false)
    # @yield Define card body content
    # @example
    #   expandable_card key: :scheduler_expanded, title: "Scheduler",
    #                   subtitle: "Time Management", badge_text: "5 activities",
    #                   status: :red do
    #     stat_display value: 1, label: "RESEARCH"
    #     activity_item time: "15:00", title: "Research task", type: :research
    #   end
    def expandable_card(key:, title:, subtitle: nil, badge_text: nil, badge_variant: :default,
                        status: nil, initially_expanded: false, **options, &block)
      @_state[key] ||= initially_expanded

      component = Components::ExpandableCard.new(
        key: key, title: title, subtitle: subtitle,
        badge_text: badge_text, badge_variant: badge_variant,
        status: status, initially_expanded: initially_expanded,
        **options
      )
      with_container(component, &block)
    end

    private

    # Captures nested components into a container and appends to current context
    def with_container(component, &block)
      @components << component
      return component unless block

      parent_components = @components
      @components = []
      instance_eval(&block)
      component.children = @components
      @components = parent_components
      component
    end

    # Captures children then appends the component (for item, column patterns)
    def capture_children_then_append(component, &block)
      parent_components = @components
      @components = []
      instance_eval(&block) if block
      component.children = @components
      @components = parent_components
      @components << component
    end

    # Initialize state for form fields, handling form context
    def initialize_form_state(key, options, default_value, skip_if_exists: false)
      options[:form_context] = @form_context if @form_context

      if @form_context
        form_name = @form_context[:name]
        @_state[form_name] ||= {}
        target = @_state[form_name]
      else
        target = @_state
      end

      if skip_if_exists
        target[key] = default_value unless target.key?(key)
      else
        target[key] ||= default_value
      end
    end

    # Parse a string with {term} markers into Phrase and Term components
    def parse_lesson_string(content, glossary)
      children = []
      parts = content.split(/(\{[^}]+\})/)

      parts.each do |part|
        if part.start_with?('{') && part.end_with?('}')
          term_key = part[1..-2]
          children << Components::Term.new(term_key)
        elsif !part.empty?
          children << Components::Phrase.new(part)
        end
      end

      children
    end
  end
end
