# frozen_string_literal: true

module StreamWeaver
  # Shared display-only component DSL methods.
  # Included by both App (which adds interactive components) and FeedBuilder.
  module DisplayDSL
    # =========================================
    # Containers
    # =========================================

    def div(**options, &block)
      with_container(Components::Div.new(**options), &block)
    end

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

    def grid(columns: 3, gap: :md, template: nil, template_areas: nil, template_rows: nil, template_columns: nil, **options, &block)
      with_container(Components::Grid.new(columns: columns, gap: gap, template: template, template_areas: template_areas, template_rows: template_rows, template_columns: template_columns, **options), &block)
    end

    def columns(widths: nil, **options, &block)
      with_container(Components::Columns.new(widths: widths, **options), &block)
    end

    def column(**options, &block)
      with_container(Components::Column.new(**options), &block)
    end

    def scroll_box(max_height: "300px", **options, &block)
      with_container(Components::ScrollBox.new(max_height: max_height, **options), &block)
    end

    def grid_area(name, **options, &block)
      with_container(Components::GridArea.new(name, **options), &block)
    end

    def sticky(top: nil, bottom: nil, left: nil, right: nil, z_index: nil, **options, &block)
      with_container(Components::Sticky.new(top: top, bottom: bottom, left: left, right: right, z_index: z_index, **options), &block)
    end

    def overlay(z: 1, pointer_events: nil, **options, &block)
      with_container(Components::Overlay.new(z: z, pointer_events: pointer_events, **options), &block)
    end

    def fullbleed(**options, &block)
      with_container(Components::Fullbleed.new(**options), &block)
    end

    def collapsible(label, expanded: false, **options, &block)
      with_container(Components::Collapsible.new(label, expanded: expanded, **options), &block)
    end

    def alert(variant: :info, title: nil, dismissible: false, **options, &block)
      with_container(Components::Alert.new(variant: variant, title: title, dismissible: dismissible, **options), &block)
    end

    # =========================================
    # Text / display
    # =========================================

    def text(content)
      @components << Components::Text.new(content)
    end

    def md(content)
      @components << Components::Markdown.new(content)
    end
    alias_method :markdown, :md

    (1..6).each do |level|
      define_method(:"header#{level}") { |content| @components << Components::Header.new(content, level: level) }
    end
    alias_method :header, :header2

    def phrase(content)
      @components << Components::Phrase.new(content)
    end

    # =========================================
    # Dashboard display
    # =========================================

    def stat_display(value:, label:, color: :blue, size: :md, **options)
      @components << Components::StatDisplay.new(value: value, label: label, color: color, size: size, **options)
    end

    def badge(text, variant: :default, size: :sm, **options)
      @components << Components::Badge.new(text, variant: variant, size: size, **options)
    end

    def status_dot(status: :gray, pulse: false, size: :md, **options)
      @components << Components::StatusDot.new(status: status, pulse: pulse, size: size, **options)
    end

    def type_tag(type_name, color: nil, **options)
      @components << Components::TypeTag.new(type_name, color: color, **options)
    end

    def pulse_indicator(color: :green, label: nil, **options)
      @components << Components::PulseIndicator.new(color: color, label: label, **options)
    end

    def activity_item(time:, title:, summary: nil, type: nil, **options)
      @components << Components::ActivityItem.new(time: time, title: title, summary: summary, type: type, **options)
    end

    def timeline_event(index:, event_type:, timestamp:, label:, fields: {}, expanded: false, **options)
      @components << Components::TimelineEvent.new(
        index: index, event_type: event_type, timestamp: timestamp,
        label: label, fields: fields, expanded: expanded, **options
      )
    end

    def priority_item(priority: :normal, title:, description: nil, meta_left: nil, meta_right: nil, **options, &block)
      component = Components::PriorityItem.new(
        priority: priority, title: title, description: description,
        meta_left: meta_left, meta_right: meta_right, **options
      )
      with_container(component, &block)
    end

    def progress_bar(value:, max: 100, variant: :default, show_label: false, animated: false, **options)
      @components << Components::ProgressBar.new(value: value, max: max, variant: variant, show_label: show_label, animated: animated, **options)
    end

    def spinner(size: :md, label: nil, **options)
      @components << Components::Spinner.new(size: size, label: label, **options)
    end

    def score_table(scores:, **options)
      @components << Components::ScoreTable.new(scores: scores, **options)
    end

    def table(positional_data = nil, data: nil, headers: nil, rows: nil, file: nil, path: nil, **options, &block)
      actual_data = positional_data || data
      @components << Components::Table.new(
        actual_data, headers: headers, rows: rows, file: file, path: path, **options, &block
      )
    end

    def status_badge(status, reasoning)
      @components << Components::StatusBadge.new(status, reasoning)
    end

    def external_link_button(label, url:, submit: false)
      @components << Components::ExternalLinkButton.new(label, url: url, submit: submit)
    end

    def link_to(label, href:, **options)
      @components << Components::Link.new(label, href: href, **options)
    end

    def navbar(**options, &block)
      with_container(Components::Navbar.new(**options), &block)
    end

    def nav_item(label, href: nil, active: false, **options)
      @components << Components::NavItem.new(label, href: href, active: active, **options)
    end

    # =========================================
    # Visual skills content blocks
    # =========================================

    # Render a syntax-highlighted code block with optional file header.
    # Uses Prism.js CDN for highlighting (loaded lazily).
    #
    # @param code [String] The source code to display
    # @param lang [String, nil] Language for Prism.js highlighting (e.g. "ruby", "javascript")
    # @param file [String, nil] File path to show in a header bar above the code
    # @param truncate [Integer, nil] Max lines to show (with truncation indicator)
    # @param scroll [Boolean] Enable scrolling for long code (default: true)
    #
    # @example Basic
    #   code_block("puts 'hi'", lang: "ruby")
    #
    # @example With file header and truncation
    #   code_block(code, file: "src/app.rb", lang: "ruby", truncate: 10)
    def code_block(code, **options)
      @components << Components::CodeBlock.new(code, **options)
    end

    # Render an image with optional caption.
    # Supports local files, URLs, and base64 data URI conversion for export.
    #
    # @param src [String] Image source (URL or file path)
    # @param alt [String] Alt text for accessibility
    # @param caption [String, nil] Caption text below the image
    # @param base64 [Boolean] Convert local file to base64 data URI (default: false)
    #
    # @example Basic
    #   image_block("photo.png", alt: "A photo")
    #
    # @example With caption
    #   image_block("diagram.svg", caption: "Figure 1: Architecture")
    def image_block(src, **options)
      @components << Components::ImageBlock.new(src, **options)
    end

    # Render a Mermaid diagram.
    # CDN loads lazily -- only when this method is called.
    #
    # @param code [String] Mermaid diagram definition
    # @param zoom [Boolean] Enable zoom/pan controls (default: false)
    # @param compact [Boolean] Compact mode for card embedding (default: false)
    # @param layout [Symbol] Layout engine (:default or :elk)
    # @param theme_vars [Hash, nil] Per-block Mermaid themeVariables overrides
    # @param options [Hash] Additional options
    #
    # @example
    #   mermaid("graph LR; A-->B")
    #   mermaid("graph TD; A-->B-->C", zoom: true)
    #   mermaid("graph LR; A-->B", compact: true)
    #   mermaid("graph TD; A-->B", layout: :elk)
    def mermaid(code, zoom: false, compact: false, layout: :default, theme_vars: nil, **options)
      @components << Components::Mermaid.new(
        code, zoom: zoom, compact: compact, layout: layout,
        theme_vars: theme_vars, **options
      )
    end

    # =========================================
    # Visual explainer components (T12)
    # =========================================

    # Render a horizontal pipeline step flow with arrow connectors.
    # Steps are color-coded by status: complete (green), active (blue), pending (gray).
    # Responsive: collapses to vertical layout on narrow screens.
    #
    # @param steps [Array<Hash>] Steps with :label, :description (optional), :status (:complete, :active, :pending)
    #
    # @example
    #   pipeline steps: [
    #     { label: "Build", status: :complete },
    #     { label: "Test",  status: :active },
    #     { label: "Deploy", status: :pending }
    #   ]
    def pipeline(steps:, **options)
      @components << Components::Pipeline.new(steps: steps, **options)
    end

    # Render a KPI dashboard with auto-fit grid of metric cards.
    # Each card shows a large value, label, optional trend arrow, and optional color.
    #
    # @param metrics [Array<Hash>] Metrics with :value, :label, :color (optional), :trend (optional :up/:down/:flat)
    #
    # @example
    #   kpi_dashboard metrics: [
    #     { value: "99.9%", label: "Uptime", color: :green, trend: :up },
    #     { value: "42ms",  label: "Latency", trend: :down }
    #   ]
    def kpi_dashboard(metrics:, **options)
      @components << Components::KpiDashboard.new(metrics: metrics, **options)
    end

    # Render a Chart.js chart. CDN loads lazily (only when this method is called).
    # Supports: :bar, :line, :pie, :doughnut, :radar.
    # Dark mode aware: reads --sw-text and --sw-border for grid/text colors.
    #
    # @param type [Symbol] Chart type
    # @param data [Hash] Chart.js data config (labels, datasets)
    # @param options [Hash] Chart.js options config
    # @param height [Integer] Canvas height in pixels (default: 300)
    #
    # @example
    #   chart type: :bar, data: { labels: ["A", "B"], datasets: [{ data: [1, 2] }] }
    def chart(type:, data:, options: {}, height: 300, **extra)
      @components << Components::Chart.new(type: type, data: data, options: options, height: height, **extra)
    end

    # =========================================
    # Keyboard shortcuts (visual skills)
    # =========================================

    # Register keyboard shortcuts with context-aware suppression.
    # Non-visual component -- emits a <script> block.
    # "mod" maps to Cmd on Mac, Ctrl elsewhere.
    #
    # @yield [kb] Builder for registering shortcuts
    # @yieldparam kb [Components::KeyboardShortcuts] The shortcut registry
    #
    # @example
    #   keyboard_shortcuts do |kb|
    #     kb.on "mod+s", context: :global, js_action: "alert('save')"
    #     kb.on "ArrowRight", context: :navigation, js_action: "console.log('next')"
    #   end
    def keyboard_shortcuts(**options, &block)
      component = Components::KeyboardShortcuts.new(**options)
      yield component if block
      @components << component
      component
    end

    # =========================================
    # Slide container (visual skills)
    # =========================================

    # Create a slide container for navigable slides.
    # Supports :swap (one visible at a time) and :scroll_snap (CSS scroll-snap) modes.
    #
    # @param mode [Symbol] Display mode (:swap or :scroll_snap)
    # @param progress_bar [Boolean] Show progress bar (default: true)
    # @param keyboard_nav [Boolean] Enable arrow key navigation (default: true)
    # @param nav_dots [Boolean] Show navigation dots (default: false)
    # @param counter [Boolean] Show slide counter (default: false)
    # @param options [Hash] Additional options
    #
    # @example Swap mode
    #   slide_container mode: :swap do
    #     slide "intro", "Introduction" do
    #       text "Welcome"
    #     end
    #     slide "arch", "Architecture" do
    #       text "Design"
    #     end
    #   end
    #
    # @example Scroll-snap mode
    #   slide_container mode: :scroll_snap, nav_dots: true do
    #     slide "s1" do
    #       text "Slide 1"
    #     end
    #   end
    def slide_container(**options, &block)
      with_container(Components::SlideContainer.new(**options), &block)
    end

    # Create a slide within a slide_container.
    #
    # @param id [String] Unique slide identifier
    # @param title [String, nil] Optional slide title
    # @param type [Symbol] Slide type (:content, :title)
    # @param options [Hash] Additional options
    #
    # @example
    #   slide "intro", "Introduction" do
    #     text "Welcome to the presentation"
    #   end
    def slide(id, title = nil, **options, &block)
      with_container(Components::Slide.new(id, title, **options), &block)
    end

    # =========================================
    # Theme toggle (visual skills auto-mode)
    # =========================================

    # Add a dark/light/auto mode toggle button.
    # Auto-mode follows OS prefers-color-scheme via CSS media query + JS listener.
    # Preference persists in localStorage.
    #
    # @param mode [Symbol] Initial mode (:dark, :light, :auto)
    # @param hotkey [String, nil] Keyboard shortcut (e.g. "mod+shift+l")
    # @param persist [Boolean] Persist preference in localStorage (default: true)
    #
    # @example
    #   theme_toggle mode: :auto
    #   theme_toggle mode: :auto, hotkey: "mod+shift+l"
    def theme_toggle(mode: :auto, hotkey: nil, persist: true, **options)
      @components << Components::ThemeToggle.new(mode: mode, hotkey: hotkey, persist: persist, **options)
    end

    # =========================================
    # Theme presets (visual skills T15)
    # =========================================

    # Apply a curated theme preset.
    # Injects Google Fonts <link> and CSS custom property overrides
    # for the selected preset. Affects both light and dark modes.
    #
    # Available presets: :editorial, :technical, :warm, :minimal, :terminal
    #
    # @param name [Symbol] Preset name
    #
    # @example
    #   theme_preset :editorial   # Magazine serif + terracotta
    #   theme_preset :warm        # Friendly rounded + amber
    #   theme_preset :terminal    # Monospace retro hacker
    def theme_preset(name, **options)
      @components << Components::ThemePreset.new(name, **options)
    end

    # =========================================
    # Explainer components (visual skills T11)
    # =========================================

    # Render a sticky sidebar table-of-contents with scroll spy.
    # Desktop (>=1000px): sticky 170px sidebar with IntersectionObserver.
    # Mobile (<1000px): horizontal scrollable sticky bar.
    #
    # @param sections [Array<Hash>] Array of { id:, label: } hashes
    # @param options [Hash] Additional options
    #
    # @example
    #   sidebar_toc sections: [
    #     { id: "summary", label: "Executive Summary" },
    #     { id: "architecture", label: "Architecture" }
    #   ]
    def sidebar_toc(sections:, **options)
      @components << Components::SidebarToc.new(sections: sections, **options)
    end

    # Render a non-dismissible callout box with colored left border.
    # Unlike Alert, Callout is static -- no dismiss button.
    #
    # @param variant [Symbol] Callout type (:info, :warning, :success, :error, :tip)
    # @param title [String, nil] Optional callout title
    # @param options [Hash] Additional options
    # @yield Block of child components rendered inside the callout body
    #
    # @example
    #   callout(variant: :warning, title: "Caution") do
    #     text "Be careful with this API."
    #   end
    def callout(variant: :info, title: nil, **options, &block)
      with_container(Components::Callout.new(variant: variant, title: title, **options), &block)
    end

    # Render a file-path-to-rationale mapping for pre-flight planning.
    #
    # @param files [Array<Hash>] Array of {path:, note:} hashes
    # @example
    #   implementation_map(files: [
    #     { path: "lib/foo.rb", note: "Add the new method" }
    #   ])
    def implementation_map(files: [], **options)
      @components << Components::ImplementationMap.new(files: files, **options)
    end

    # Render an architecture decision block with labeled option cards.
    # The block is evaluated in DecisionBuilder scope — only `option(...)` is valid inside it.
    # Other DSL helpers (text, mermaid, etc.) are not available inside the block.
    #
    # @param question [String] The decision question shown as a heading
    # @yield Block of `option(id:, label:, detail:, recommended:)` calls
    #
    # @example
    #   decision(question: "Which database?") do
    #     option(id: :pg, label: "PostgreSQL", detail: "Full ACID", recommended: true)
    #     option(id: :sqlite, label: "SQLite", detail: "Zero-dep")
    #   end
    def decision(question:, **options, &block)
      component = Components::Decision.new(question: question, **options)
      @components << component
      if block
        builder = DecisionBuilder.new(component)
        builder.instance_eval(&block)
      end
      component
    end

    # Builder context for decision component's option calls
    class DecisionBuilder
      def initialize(component)
        @component = component
      end

      def option(id:, label:, detail:, recommended: false)
        @component.add_option(id: id, label: label, detail: detail, recommended: recommended)
      end
    end

    # Render side-by-side comparison panels.
    # Use `before { ... }` and `after { ... }` named blocks inside
    # to populate each panel.
    #
    # @param before_label [String] Label for the "before" panel (default: "Before")
    # @param after_label [String] Label for the "after" panel (default: "After")
    # @param options [Hash] Additional options
    # @yield Block containing `before { ... }` and `after { ... }` calls
    #
    # @example
    #   comparison(before_label: "Old", after_label: "New") do
    #     before { text "Version 1" }
    #     after { text "Version 2" }
    #   end
    def comparison(before_label: "Before", after_label: "After", **options, &block)
      component = Components::Comparison.new(
        before_label: before_label, after_label: after_label, **options
      )
      @components << component
      return component unless block

      # Capture before/after blocks using a builder context
      builder = ComparisonBuilder.new(self)
      builder.instance_eval(&block)
      component.before_children = builder.before_components
      component.after_children = builder.after_components
      component
    end

    # Builder context for comparison component's before/after blocks
    class ComparisonBuilder
      attr_reader :before_components, :after_components

      def initialize(dsl)
        @dsl = dsl
        @before_components = []
        @after_components = []
      end

      def before(&block)
        @before_components = capture_components(&block)
      end

      def after(&block)
        @after_components = capture_components(&block)
      end

      private

      def capture_components(&block)
        parent = @dsl.instance_variable_get(:@components)
        @dsl.instance_variable_set(:@components, [])
        @dsl.instance_eval(&block)
        captured = @dsl.instance_variable_get(:@components)
        @dsl.instance_variable_set(:@components, parent)
        captured
      end
    end

    # =========================================
    # CSS-only helpers (T13)
    # =========================================

    # Render a hero section with accent background tint and large padding.
    #
    # @param options [Hash] Additional options
    # @yield Block of child components rendered inside the hero
    #
    # @example
    #   hero { header1 "Welcome" }
    def hero(**options, &block)
      with_container(Components::Hero.new(**options), &block)
    end

    # Render a reading-optimized prose container (max-width ~65ch).
    #
    # @param dropcap [Boolean] Whether to enable dropcap on first paragraph (default: false)
    # @param options [Hash] Additional options
    # @yield Block of child components rendered inside the prose container
    #
    # @example
    #   prose(dropcap: true) { md "Long form text..." }
    def prose(dropcap: false, **options, &block)
      with_container(Components::Prose.new(dropcap: dropcap, **options), &block)
    end

    # Render a styled pullquote with optional attribution.
    #
    # @param text [String] The quote text
    # @param attribution [String, nil] Attribution (e.g., "Author Name")
    #
    # @example
    #   pullquote "Design is not just what it looks like.", attribution: "Steve Jobs"
    def pullquote(text, attribution: nil, **options)
      @components << Components::Pullquote.new(text, attribution: attribution, **options)
    end

    # Render a monospace file tree display with color-coded status.
    # Lines ending with [new], [modified], or [deleted] are color-coded.
    #
    # @param tree_text [String] Multi-line file tree text
    #
    # @example
    #   dir_tree "src/\n  app.rb [modified]\n  new_file.rb [new]"
    def dir_tree(tree_text, **options)
      @components << Components::DirTree.new(tree_text, **options)
    end

    # Render a color swatch legend (horizontal row of dots with labels).
    #
    # @param items [Array<Hash>] Array of { color: "#hex", label: "text" }
    #
    # @example
    #   legend items: [{ color: "#22c55e", label: "New" }, { color: "#f59e0b", label: "Modified" }]
    def legend(items:, **options)
      @components << Components::Legend.new(items: items, **options)
    end

    # Render a vertical arrow connector between sections.
    #
    # @param label [String, nil] Optional label on the arrow
    #
    # @example
    #   flow_arrow label: "transforms into"
    def flow_arrow(label: nil, **options)
      @components << Components::FlowArrow.new(label: label, **options)
    end

    # Render column count override buttons (1/2/3/4 columns).
    # Uses JS to change grid-template-columns on the target element.
    #
    # @param target [String] CSS selector of the grid to control
    # @param columns [Array<Integer>] Available column counts
    #
    # @example
    #   layout_toggle target: ".my-grid", columns: [1, 2, 3]
    def layout_toggle(target: ".sw-layout-target", columns: [1, 2, 3, 4], **options)
      @components << Components::LayoutToggle.new(target: target, columns: columns, **options)
    end

    # =========================================
    # Interactive components (render-only versions for FeedBuilder context)
    # App overrides these with full callback-wiring implementations.
    # =========================================

    def button(label, id: nil, **options, &block)
      require 'digest/md5'
      if block
        source_loc = block.source_location.join(':')
        id_input = id ? "#{label}:#{id}" : "#{label}:#{source_loc}"
        stable_id = Digest::MD5.hexdigest(id_input)[0..7]
      else
        @button_counter = (@button_counter || 0) + 1
        stable_id = @button_counter.to_s
      end
      @components << Components::Button.new(label, stable_id, **options, &block)
    end

    def select(key, choices, **options)
      @_state[key] = options[:default] || "" unless @_state&.key?(key)
      @components << Components::Select.new(key, choices, **options)
    end

    def expandable_card(key:, title:, subtitle: nil, badge_text: nil, badge_variant: :default,
                        status: nil, initially_expanded: false, **options, &block)
      @_state[key] ||= initially_expanded if @_state
      component = Components::ExpandableCard.new(
        key: key, title: title, subtitle: subtitle,
        badge_text: badge_text, badge_variant: badge_variant,
        status: status, initially_expanded: initially_expanded,
        **options
      )
      with_container(component, &block)
    end

    def show_toast(message, variant: :info, duration: nil)
      return unless @_state
      @_state[:_toasts] ||= []
      toast_id = "toast_#{Time.now.to_f.to_s.gsub('.', '_')}_#{rand(1000)}"
      toast = { id: toast_id, message: message, variant: variant }
      toast[:duration] = duration if duration
      @_state[:_toasts] << toast
    end

    private

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

    def watch(key, &block); end
    def on_start(&block); end
    def after(seconds, &block); end
    def every(seconds, &block); end
    def defer(&block); end
  end
end
