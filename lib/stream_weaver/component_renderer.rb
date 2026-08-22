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

    def initialize(adapter, components, state = {})
      @adapter = adapter
      @components = Array(components)
      @state = state
    end

    def view_template
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
    def self.render_html(adapter = nil, components = [], state = {})
      adapter ||= Adapter::AlpineJS.new
      new(adapter, components, state).call
    end
  end
end
