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

    def grid(columns: 3, gap: :md, **options, &block)
      with_container(Components::Grid.new(columns: columns, gap: gap, **options), &block)
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
  end
end
