# frozen_string_literal: true

module StreamWeaver
  # Renders StreamWeaver components to HTML strings via Phlex.
  # Used by Feed and Streamer to turn component DSL blocks into HTML
  # that can be pushed via SSE or POST /stream/push.
  #
  # @example
  #   components = [Components::StatDisplay.new(value: 42, label: "RPS", color: :blue)]
  #   html = ComponentRenderer.render_html(adapter, components)
  class ComponentRenderer < Phlex::HTML
    attr_reader :adapter

    # @param delivery [Delivery::Served, Delivery::Inline, nil] see
    #   PageShell.components_html: given, the components' own files lead the
    #   output; nil, only their CSS does
    # @param assets [Boolean] false when the page's head already carries
    #   the components' class-macro assets (the exporter resolves them)
    def initialize(adapter, components, state = {}, delivery: nil, assets: true)
      @adapter = adapter
      @components = Array(components)
      @state = state
      @delivery = delivery
      @assets = assets
    end

    def view_template
      raw(safe(PageShell.components_html(@components, @delivery))) if @assets
      @components.each { |c| c.render(self, @state) }
    end

    # Fragment scope tracking, matching Views::AppContentView. Components::Fragment
    # asks every view it renders into for this, so a renderer without it raises
    # NoMethodError on any app that uses `fragment`.
    attr_reader :current_fragment_id

    def with_fragment(id)
      previous = @current_fragment_id
      @current_fragment_id = id
      yield
    ensure
      @current_fragment_id = previous
    end

    # Render components to an HTML string
    #
    # @param adapter [StreamWeaver::Adapter::Base] The adapter (default: AlpineJS)
    # @param components [Array<Components::Base>] Components to render
    # @param state [Hash] State hash (default: empty)
    # @return [String] Rendered HTML
    def self.render_html(adapter = nil, components = [], state = {}, delivery: nil, assets: true)
      adapter ||= Adapter::AlpineJS.new
      new(adapter, components, state, delivery: delivery, assets: assets).call
    end
  end
end
