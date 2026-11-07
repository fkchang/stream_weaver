# frozen_string_literal: true

module StreamWeaver
  module Components
    # One region of an ide_shell. Subclasses name the element and the
    # sw-ide-* block class; the shell's stylesheet places each block in its
    # grid area.
    class IdeRegion < Base
      attr_accessor :children
      attr_reader :options

      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_ide_region(view, self, state)
      end

      # @return [Symbol] HTML element the region renders as
      def tag
        self.class::TAG
      end

      # @return [String] sw-ide-* block class
      def block_class
        self.class::BLOCK
      end

      # @return [Hash] attributes the region always carries
      def region_attributes
        {}
      end
    end

    class IdeRailLeft < IdeRegion
      TAG = :aside
      BLOCK = "sw-ide-rail-left"
    end

    class IdeEditor < IdeRegion
      TAG = :main
      BLOCK = "sw-ide-editor"
    end

    class IdeRailRight < IdeRegion
      TAG = :aside
      BLOCK = "sw-ide-rail-right"
      # Target of the shell's nav toggle (aria-controls).
      DOM_ID = "sw-ide-rail-right"

      def region_attributes
        { id: DOM_ID }
      end
    end
  end
end
