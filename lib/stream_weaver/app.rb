# frozen_string_literal: true

require 'digest'
require 'set'

module StreamWeaver
  # Main app class that holds the DSL block and manages the component tree
  class App
    include DisplayDSL

    # Built-in themes (custom themes checked via StreamWeaver.theme_exists?)
    BUILT_IN_THEMES = [:default, :dashboard, :document, :dark].freeze
    # For backwards compatibility
    VALID_THEMES = BUILT_IN_THEMES

    attr_reader :title, :components, :block, :layout, :theme, :theme_overrides, :scripts, :stylesheets, :stream_block, :timers, :transient_keys, :favicon_value

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
      @transient_keys = Set.new
      @timers = []
      @favicon_value = nil

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
      @timers_frozen = true
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
    # App-specific display components
    # =========================================

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

    def term(term_key, **options)
      @components << Components::Term.new(term_key, **options)
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
      @transient_keys << key if options.delete(:transient)
      initialize_form_state(key, options, options[:default] || "")
      @components << Components::TextField.new(key, **options)
    end

    def text_area(key, **options)
      @transient_keys << key if options.delete(:transient)
      initialize_form_state(key, options, options[:default] || "")
      @components << Components::TextArea.new(key, **options)
    end

    def code_editor(key, language: :ruby, readonly: true, height: "400px", **options)
      initialize_form_state(key, options, options[:default] || "")
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
    # Interactive components
    # =========================================

    def button(label, id: nil, **options, &block)
      # Generate stable ID: use source location for buttons with blocks,
      # fallback to counter for blockless buttons (submit: false)
      # If id: is provided, use it to disambiguate buttons in loops
      if block
        source_loc = block.source_location.join(':')
        id_input = id ? "#{label}:#{id}" : "#{label}:#{source_loc}"
        stable_id = Digest::MD5.hexdigest(id_input)[0..7]
      else
        @button_counter += 1
        stable_id = @button_counter.to_s
      end
      # Pass modal context to button so it can close the modal via Alpine
      options[:modal_context] = @modal_context if @modal_context
      @components << Components::Button.new(label, stable_id, **options, &block)
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
      open_key = :"#{key}_open"
      @_state[open_key] = false unless @_state.key?(open_key)

      modal_component = Components::Modal.new(key, title: title, size: size, **options)
      @components << modal_component

      parent_components = @components
      @current_modal = modal_component
      @modal_context = { key: key }
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
      @components = []

      instance_eval(&block) if block

      footer_component.children = @components
      @components = parent_components
      @current_modal.footer_component = footer_component
    end

    def open_modal(key)
      @_state[:"#{key}_open"] = true
    end

    def close_modal(key)
      @_state[:"#{key}_open"] = false
    end

    # =========================================
    # Feedback DSL methods (App-only)
    # =========================================

    def toast_container(position: :top_right, duration: 5000, **options)
      @_state[:_toasts] ||= []
      @components << Components::ToastContainer.new(position: position, duration: duration, **options)
    end

    def show_toast(message, variant: :info, duration: nil)
      @_state[:_toasts] ||= []
      toast_id = "toast_#{Time.now.to_f.to_s.gsub('.', '_')}_#{rand(1000)}"
      toast = { id: toast_id, message: message, variant: variant }
      toast[:duration] = duration if duration
      @_state[:_toasts] << toast
    end

    def dismiss_toast(toast_id)
      @_state[:_toasts] ||= []
      @_state[:_toasts].reject! { |t| t[:id] == toast_id }
    end

    def clear_toasts
      @_state[:_toasts] = []
    end

    def canvas_continue(message: "Processing...")
      @components << Components::CanvasContinue.new(message: message)
    end

    def theme_switcher(position: :inline, show_label: true, **options)
      @components << Components::ThemeSwitcher.new(position: position, show_label: show_label, **options)
    end

    # =========================================
    # Streaming DSL (server-push via SSE)
    # =========================================

    def stream(&block)
      @stream_block ||= block
    end

    def every(seconds, &block)
      return if @timers_frozen
      @timers << { interval: seconds, block: block, last_run: nil }
    end

    def has_timers?
      @timers.any?
    end

    # Set favicon — accepts a URL string or a single emoji character
    # Emoji example: favicon "🔥"
    # URL example: favicon "https://example.com/icon.png"
    def favicon(value)
      @favicon_value = value
    end

    # Returns the favicon as an href suitable for <link rel="icon">
    # Converts emoji to SVG data URI, file paths to base64 data URI; passes URLs through unchanged
    def favicon_href
      return nil unless @favicon_value
      @_favicon_href_cache ||= build_favicon_href
    end

    FAVICON_MIME_TYPES = {
      'ico' => 'image/x-icon', 'png' => 'image/png', 'svg' => 'image/svg+xml',
      'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'gif' => 'image/gif', 'webp' => 'image/webp'
    }.freeze

    # =========================================
    # Layout components (Cabinet Control style)
    # =========================================

    def app_shell(sidebar_width: "320px", sidebar_position: :right, gap: "1.5rem", **options, &block)
      component = Components::AppShell.new(
        sidebar_width: sidebar_width,
        sidebar_position: sidebar_position,
        gap: gap,
        **options
      )
      @components << component

      return component unless block

      @current_app_shell = component
      instance_eval(&block)
      @current_app_shell = nil

      component
    end

    def main(**options, &block)
      raise "main can only be used inside an app_shell block" unless @current_app_shell

      parent_components = @components
      @components = []
      instance_eval(&block) if block
      @current_app_shell.main_children = @components
      @components = parent_components
    end

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

    def build_favicon_href
      v = @favicon_value
      if v.match?(/\A\p{Emoji_Presentation}\z/) || v.match?(/\A[\p{So}\p{Sk}]\z/)
        "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>#{v}</text></svg>"
      elsif File.exist?(v)
        require 'base64'
        mime = FAVICON_MIME_TYPES[File.extname(v).delete('.').downcase] || 'image/png'
        "data:#{mime};base64,#{Base64.strict_encode64(File.binread(v))}"
      else
        v
      end
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
