# frozen_string_literal: true

require 'digest'

module StreamWeaver
  # Registry for files served via the /sw-asset/ route.
  # Maps a short SHA key → absolute path so only pre-registered files are served.
  module ComponentAssets
    @file_registry = {}

    class << self
      # Register a file and return its URL key.
      def register_file(abs_path)
        key = Digest::SHA256.hexdigest(abs_path)[0, 16]
        @file_registry[key] = abs_path
        key
      end

      # The /sw-asset URL that serves a local file (AssetRoute), registering it.
      #
      # @param abs_path [String]
      # @return [String]
      def url(abs_path)
        "/sw-asset/#{register_file(abs_path)}/#{File.basename(abs_path)}"
      end

      # Resolve a key back to an absolute path, or nil if unknown.
      def resolve_file(key)
        @file_registry[key]
      end

      # Return the key for an already-registered path (registers if new).
      def file_key(abs_path)
        key = Digest::SHA256.hexdigest(abs_path)[0, 16]
        @file_registry[key] ||= abs_path
        key
      end

      # The assets the component classes in a tree declare with the css,
      # css_path, js_path and font class macros, each class once, in tree
      # order.
      #
      # @param components [Array<Components::Base>]
      # @return [PageShell::Assets]
      def assets(components)
        assets_of(classes_in(components))
      end

      # The assets of every registered component class: the framework's own
      # (StreamWeaver::Components, by name) and those registered with
      # StreamWeaver.register_component. For a host with no component tree
      # to walk: an Opal build compiles a file, so it ships them all.
      #
      # @return [PageShell::Assets]
      def every_class_assets
        framework = Components.constants.sort.map { |name| Components.const_get(name) }
                              .select { |c| c.is_a?(Class) && c < Components::Base }
        registered = ComponentRegistry.all.values.map { |entry| entry[:class] }
        assets_of((framework + registered).uniq)
      end

      def reset!
        @file_registry.clear
      end

      private

      def classes_in(components, seen = [])
        components.each do |c|
          seen << c.class unless seen.include?(c.class)
          classes_in(c.children, seen) if c.respond_to?(:children) && c.children && !c.children.empty?
        end
        seen
      end

      def assets_of(classes)
        classes = classes.select { |k| k.respond_to?(:component_css_strings) }
        PageShell::Assets.of(
          framework_css: classes.flat_map(&:component_framework_css),
          user_css: classes.flat_map(&:component_css_strings),
          stylesheets: classes.filter_map(&:component_css_path),
          scripts: classes.filter_map(&:component_js_path),
          fonts: classes.flat_map(&:component_fonts)
        )
      end
    end
  end
end
