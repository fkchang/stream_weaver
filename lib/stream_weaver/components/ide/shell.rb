# frozen_string_literal: true

module StreamWeaver
  module Components
    # Full-viewport editor-style frame: a title bar over three columns
    # (left rail | editor | right rail) over a status bar. The regions are
    # its children (ide_titlebar, ide_rail_left, ide_editor, ide_rail_right,
    # ide_statusbar); each places itself in the grid by its own class.
    #
    # Below 1180px the right rail slides off-canvas behind a nav toggle and a
    # backdrop; below 840px the left rail is hidden, with no replacement, as
    # the reference layout does (put anything a phone reader needs in the
    # editor or the right rail).
    #
    # A container component rather than a registered layout, so it renders on
    # the standalone and canvas paths. The Opal adapter has no ide renderers,
    # so it does not render there. One shell per page (the right rail has a
    # fixed id).
    #
    # @example
    #   app "Docs", chrome: false, theme: :ide do
    #     ide_shell do
    #       ide_titlebar { text "StreamWeaver" }
    #       ide_rail_left { text "Pages" }
    #       ide_editor { md "# README" }
    #       ide_rail_right { text "Files" }
    #       ide_statusbar { text "MIT" }
    #     end
    #   end
    class IdeShell < Base
      attr_reader :children, :options

      def initialize(**options)
        @options = options
        @children = []
      end

      # Hands the shell's ide_editor to every ide_filetree inside it, which
      # renders in a sibling region.
      def children=(children)
        @children = children
        editor = children.find { |child| child.is_a?(IdeEditor) }
        filetrees(children).each { |tree| tree.editor = editor }
      end

      def render(view, state)
        view.adapter.render_ide_shell(view, self, state)
      end

      private

      def filetrees(components)
        components.flat_map do |component|
          nested = component.respond_to?(:children) ? filetrees(Array(component.children)) : []
          component.is_a?(IdeFiletree) ? [component, *nested] : nested
        end
      end
    end
  end
end
