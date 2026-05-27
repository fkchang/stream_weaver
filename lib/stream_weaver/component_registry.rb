# frozen_string_literal: true

module StreamWeaver
  # Registry for third-party component classes.
  #
  # Allows downstream gems to contribute DSL methods without monkey-patching App or DisplayDSL.
  # Registered components are available globally on every app instance via DisplayDSL.
  #
  # @example
  #   StreamWeaver.register_component(MyGem::Banner, dsl: :banner)
  #
  # Then in any app block:
  #   banner(text: "Hello") { ... }
  module ComponentRegistry
    @registry = {}

    class << self
      def register(klass, dsl:, adapter: :alpinejs)
        dsl_name = dsl.to_sym
        @registry[dsl_name] = { class: klass, adapter: adapter }

        # Install the DSL method on DisplayDSL so every App picks it up immediately.
        # with_container handles both leaf (no block) and container (block) usage.
        DisplayDSL.module_eval do
          define_method(dsl_name) do |*args, **kwargs, &block|
            with_container(klass.new(*args, **kwargs), &block)
          end
        end
      end

      def [](dsl_name)
        @registry[dsl_name.to_sym]
      end

      def registered?(dsl_name)
        @registry.key?(dsl_name.to_sym)
      end

      def each(&block)
        @registry.each(&block)
      end

      def all
        @registry.dup
      end

      # Remove all registrations (intended for test isolation only).
      def reset!
        @registry.each_key do |dsl_name|
          DisplayDSL.undef_method(dsl_name) if DisplayDSL.method_defined?(dsl_name)
        end
        @registry.clear
      end
    end
  end

  class << self
    # Register a component class with a DSL method name.
    #
    # @param klass [Class] A class that inherits from Components::Base
    # @param dsl [Symbol, String] The DSL method name to define on App/DisplayDSL
    # @param adapter [Symbol] Adapter hint (:alpinejs, :opal) — informational for now
    def register_component(klass, dsl:, adapter: :alpinejs)
      ComponentRegistry.register(klass, dsl: dsl, adapter: adapter)
    end
  end
end
