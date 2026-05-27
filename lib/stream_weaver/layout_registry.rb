# frozen_string_literal: true

module StreamWeaver
  # Registry for named page layouts.
  #
  # A layout controls the outer chrome (topbar, sidebar, main area) of a StreamWeaver app.
  # The built-in `:default` layout is the standard single-column centered body.
  # Custom layouts can opt out of the default chrome with `exclusive: true`.
  #
  # @example Registering a custom layout
  #   StreamWeaver.register_layout(:two_rail, exclusive: true, body_classes: %w[my-shell]) do
  #     div(class: "my-header")  { render_slot(:header)       }
  #     div(class: "my-content") do
  #       div(class: "my-sidebar") { render_slot(:sidebar_left) }
  #       main_content_region
  #     end
  #   end
  #
  # @example Using it in an app
  #   app "X", layout: :two_rail do
  #     layout_slot(:header)       { text "Header content" }
  #     layout_slot(:sidebar_left) { text "Sidebar content" }
  #     text "Main content"
  #   end
  module LayoutRegistry
    @registry = {}

    class << self
      # Register a named layout.
      #
      # @param name [Symbol, String] Layout identifier used as `layout:` in app(...)
      # @param exclusive [Boolean] When true, suppresses default h1/body-padding/#app-container chrome
      # @param body_classes [Array<String>] Extra classes added to <body> (in addition to sw-theme-*)
      # @param css_path [String, nil] Absolute path to a CSS file for this layout
      # @yield Block that is instance_exec'd on AppView — use Phlex DSL + render_slot/main_content_region
      def register(name, exclusive: false, body_classes: [], css_path: nil, &render_block)
        entry = {
          exclusive:    exclusive,
          body_classes: Array(body_classes),
          css_path:     css_path,
          render_block: render_block
        }
        ComponentAssets.register_file(css_path) if css_path
        @registry[name.to_sym] = entry
      end

      def [](name)
        @registry[name.to_sym]
      end

      def registered?(name)
        @registry.key?(name.to_sym)
      end

      def all
        @registry.dup
      end

      def reset!
        @registry.clear
      end
    end
  end

  class << self
    # Register a named page layout.
    #
    # @param name [Symbol, String] Layout identifier
    # @param exclusive [Boolean] Opt out of default header/padding/#app-container chrome
    # @param body_classes [Array<String>] Extra <body> classes
    # @param css_path [String, nil] Layout-specific CSS file path
    # @yield Phlex DSL block (instance_exec'd on AppView); call render_slot/main_content_region
    def register_layout(name, exclusive: false, body_classes: [], css_path: nil, &block)
      LayoutRegistry.register(name, exclusive: exclusive, body_classes: body_classes,
                               css_path: css_path, &block)
    end
  end
end
