# frozen_string_literal: true

require 'digest'
require 'set'

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

      # Walk a component tree and collect unique CSS/JS declarations.
      # Returns [css_strings, css_paths, js_paths] — all deduped by component class.
      def collect(components, seen_classes = Set.new)
        css_strings = []
        css_paths   = []
        js_paths    = []

        components.each do |c|
          klass = c.class
          unless seen_classes.include?(klass)
            seen_classes << klass
            if klass.respond_to?(:component_css_strings)
              css_strings.concat(klass.component_css_strings)
            end
            if klass.respond_to?(:component_css_path) && klass.component_css_path
              css_paths << klass.component_css_path
            end
            if klass.respond_to?(:component_js_path) && klass.component_js_path
              js_paths << klass.component_js_path
            end
          end

          if c.respond_to?(:children) && !c.children.empty?
            child_css_s, child_css_p, child_js_p = collect(c.children, seen_classes)
            css_strings.concat(child_css_s)
            css_paths.concat(child_css_p)
            js_paths.concat(child_js_p)
          end
        end

        [css_strings, css_paths, js_paths]
      end

      def reset!
        @file_registry.clear
      end
    end
  end
end
