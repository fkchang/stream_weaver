# frozen_string_literal: true

require 'digest'

module StreamWeaver
  # Evaluates trusted, self-contained display-only DSL snippets for code_preview.
  class CodePreview
    class << self
      def evaluate(source, adapter: nil)
        components = build_components(source)
        assert_display_only!(components)
        ComponentRenderer.render_html(adapter || StreamWeaver.default_adapter, components)
      end

      def source_digest(source)
        Digest::SHA256.hexdigest(source.to_s)[0, 10]
      end

      private

      def build_components(source)
        builder = FeedBuilder.new({})
        builder.instance_eval(source.to_s, "(code_preview)", 1)
        builder.components
      end

      def assert_display_only!(components)
        each_component(components) do |component|
          next unless live_component?(component)

          raise ArgumentError,
                "code_preview snippets must be trusted, self-contained, display-only Ruby; " \
                "#{component.class.name} is a live control"
        end
      end

      def each_component(components, &block)
        Array(components).each do |component|
          yield component
          each_component(component.children, &block) if component.respond_to?(:children)
        end
      end

      def live_component?(component)
        return true if component.is_a?(Components::CodePreview)
        return true if component.is_a?(Components::Button)
        return true if defined?(Components::CopyButton) && component.is_a?(Components::CopyButton)
        return true if component.respond_to?(:key) && !component.key.nil?

        registry = {}
        component.register_callbacks(registry)
        registry.any?
      end
    end
  end
end
