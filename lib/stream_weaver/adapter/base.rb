# frozen_string_literal: true

module StreamWeaver
  module Adapter
    # Base adapter class that all adapters must inherit from
    # Defines the interface that components use to render themselves
    #
    # This adapter pattern decouples components from specific frontend frameworks
    # (Alpine.js, HTMX, React, Opal, etc.), allowing pluggable implementations.
    #
    # @abstract Subclass and override all methods to implement a new adapter
    #
    # @example Creating a custom adapter
    #   class MyAdapter < StreamWeaver::Adapter::Base
    #     def render_text_field(view, key, options, state)
    #       view.input(type: "text", "my-binding" => key.to_s)
    #     end
    #     # ... implement all other methods
    #   end
    #
    # @example Using an adapter
    #   app = StreamWeaver::App.new("My App", adapter: MyAdapter.new) do
    #     text_field :name
    #   end
    class Base
      # Render a single-line text input field
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this input
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_text_field(view, :email, { placeholder: "Email" }, state)
      def render_text_field(view, key, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_text_field"
      end

      # Render a multi-line text area
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this textarea
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @option options [Integer] :rows Number of rows (default: 3)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_text_area(view, :bio, { rows: 5 }, state)
      def render_text_area(view, key, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_text_area"
      end

      # Render a checkbox input
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this checkbox
      # @param label [String] The label text
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_checkbox(view, :agree, "I agree", {}, state)
      def render_checkbox(view, key, label, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_checkbox"
      end

      # Render a select dropdown
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this select
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_select(view, :color, ["Red", "Green", "Blue"], {}, state)
      def render_select(view, key, choices, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_select"
      end

      # Render a radio button group for single-choice selection
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this radio group
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_radio_group(view, :answer, ["Option A", "Option B"], {}, state)
      def render_radio_group(view, key, choices, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_radio_group"
      end

      # Render a button that executes an action
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param button_id [String] The deterministic button ID (e.g., "btn_submit_1")
      # @param label [String] The button label text
      # @param options [Hash] Component options
      # @option options [Symbol] :style Button style (:primary or :secondary)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_button(view, "btn_submit_1", "Submit", { style: :primary })
      def render_button(view, button_id, label, options)
        raise NotImplementedError, "#{self.class} must implement #render_button"
      end

      # Get HTML attributes for the app container (e.g., x-data for Alpine.js)
      #
      # @param state [Hash] Current state hash (symbol keys)
      # @return [Hash] HTML attributes to apply to container div
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   attrs = adapter.container_attributes({ name: "Alice" })
      #   # => { "x-data" => '{"name":"Alice"}' }
      def container_attributes(state)
        raise NotImplementedError, "#{self.class} must implement #container_attributes"
      end

      # Get CDN script tags or inline scripts needed by this adapter
      #
      # @return [Array<String>] Array of HTML script tags
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.cdn_scripts
      #   # => ['<script src="..."></script>', '<script>...</script>']
      def cdn_scripts
        raise NotImplementedError, "#{self.class} must implement #cdn_scripts"
      end

      # Render CDN scripts directly to the view using Phlex methods
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @return [void] Renders script tags to the view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_cdn_scripts(view)
      def render_cdn_scripts(view)
        raise NotImplementedError, "#{self.class} must implement #render_cdn_scripts"
      end

      # Get the input selector for including form data (e.g., "[x-model]" for Alpine.js)
      # Used by buttons to know which inputs to include when submitting
      #
      # @return [String] CSS selector for input elements
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.input_selector
      #   # => "[x-model]"
      def input_selector
        raise NotImplementedError, "#{self.class} must implement #input_selector"
      end

      # Render a checkbox group with select all/none functionality
      # State is stored as an array of selected values
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this group (stores array)
      # @param children [Array<CheckboxItem>] The checkbox items
      # @param options [Hash] Component options (select_all, select_none labels)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_checkbox_group(view, key, children, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_checkbox_group"
      end

      # Render a vertical stack container
      def render_vstack(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_vstack"
      end

      # Render a horizontal stack container
      def render_hstack(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_hstack"
      end

      # Render a responsive grid container
      def render_grid(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_grid"
      end

      # Render a scrollable container with max-height
      def render_scroll_box(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_scroll_box"
      end

      # =========================================
      # Navigation component rendering
      # =========================================

      # Render a tabbed navigation container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Tabs] The tabs component with children
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_tabs(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_tabs"
      end

      # Render a breadcrumbs navigation trail
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Breadcrumbs] The breadcrumbs component with children
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_breadcrumbs(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_breadcrumbs"
      end

      # Render a dropdown menu container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Dropdown] The dropdown component with trigger and menu
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_dropdown(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_dropdown"
      end

      # Render a theme toggle button (dark/light/auto mode)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ThemeToggle] The theme toggle component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_theme_toggle(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_theme_toggle"
      end

      # Render a theme preset (Google Fonts link + CSS custom properties)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ThemePreset] The theme preset component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_theme_preset(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_theme_preset"
      end

      # Render a syntax-highlighted code block with Prism.js
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [CodeBlock] The code block component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_code_block(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_code_block"
      end

      # Render an image with optional caption
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ImageBlock] The image block component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_image_block(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_image_block"
      end

      # Render a Mermaid diagram with optional zoom/pan
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Mermaid] The mermaid component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_mermaid(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_mermaid"
      end

      # Render a pipeline step flow visualization
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Pipeline] The pipeline component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_pipeline(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_pipeline"
      end

      # Render a KPI dashboard grid of metric cards
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [KpiDashboard] The KPI dashboard component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_kpi_dashboard(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_kpi_dashboard"
      end

      # Render a Chart.js chart (visual skills T12 wrapper)
      # Named render_chartjs to avoid collision with existing render_chart
      # which uses config_class: keyword for legacy BarChart/LineChart/PieChart.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Chart] The chart component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_chartjs(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_chartjs"
      end

      # Render keyboard shortcuts (non-visual -- emits <script> block)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [KeyboardShortcuts] The keyboard shortcuts component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_keyboard_shortcuts(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_keyboard_shortcuts"
      end

      # Render a slide container with navigation
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [SlideContainer] The slide container component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_slide_container(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_slide_container"
      end

      # Render an individual slide within a container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Slide] The slide component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_slide(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_slide"
      end

      # =========================================
      # Explainer component rendering (T11)
      # =========================================

      # Render a sticky sidebar table-of-contents with scroll spy
      def render_sidebar_toc(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_sidebar_toc"
      end

      # Render a non-dismissible callout box with colored left border
      def render_callout(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_callout"
      end

      # Render side-by-side comparison panels
      def render_comparison(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_comparison"
      end

      def render_implementation_map(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_implementation_map"
      end

      def render_decision(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_decision"
      end

      def render_annotated_code(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_annotated_code"
      end

      # =========================================
      # Design Deck component rendering (T7)
      # =========================================

      # Render a design deck (top-level orchestrator)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DesignDeck] The deck component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_design_deck(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_design_deck"
      end

      # Render a deck slide with options grid
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DeckSlide] The slide component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_deck_slide(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_deck_slide"
      end

      # Render a deck option card
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DeckOption] The option component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_deck_option(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_deck_option"
      end

      # Render the auto-generated deck summary slide
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DeckSummary] The summary component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_deck_summary(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_deck_summary"
      end

      # =========================================
      # CSS-Only Helpers (T13)
      # =========================================

      # Render a hero section
      def render_hero(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_hero"
      end

      # Render a prose container
      def render_prose(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_prose"
      end

      # Render a pullquote
      def render_pullquote(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_pullquote"
      end

      # Render a directory tree display
      def render_dir_tree(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_dir_tree"
      end

      # Render a color legend
      def render_legend(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_legend"
      end

      # Render a flow arrow connector
      def render_flow_arrow(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_flow_arrow"
      end

      # Render layout toggle buttons
      def render_layout_toggle(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_layout_toggle"
      end

      # Render a timeline event row with expandable details
      def render_timeline_event(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_timeline_event"
      end

      # Render a wireframe surface block with raw HTML content
      def render_wireframe_block(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_wireframe_block"
      end

      protected

      # Convert spacing symbol to CSS value
      #
      # @param spacing [Symbol, String] Spacing value (:xs, :sm, :md, :lg, :xl or raw CSS)
      # @return [String] CSS value
      def spacing_to_css(spacing)
        case spacing
        when :xs then "var(--sw-spacing-xs)"
        when :sm then "var(--sw-spacing-sm)"
        when :md then "var(--sw-spacing-md)"
        when :lg then "var(--sw-spacing-lg)"
        when :xl then "var(--sw-spacing-xl)"
        else spacing.to_s
        end
      end
    end
  end
end
