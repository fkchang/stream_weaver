# frozen_string_literal: true

module StreamWeaver
  module Components
    # One "file" of an ide_editor: a section the editor's tab strip links
    # to, and that the scroll spy marks active while it is on screen. The
    # name is the section's DOM id (so #name links to it); the label is a
    # file path whose last segment names the tab, and whose folders give a
    # right-rail file tree its depth. The comment renders as an HTML-style
    # comment line at the top of the section.
    #
    # @example
    #   ide_editor do
    #     file_section "install", label: "docs/INSTALL.md", icon: :package, comment: "INSTALL" do
    #       md "gem install stream_weaver"
    #     end
    #   end
    class IdeFileSection < Base
      attr_accessor :children
      attr_reader :name, :label, :icon, :comment, :options

      # @param name [String] DOM id of the section
      # @param label [String] file path shown in the tab and the file tree
      # @param icon [Symbol, String] Components::Ide::ICONS name, or text
      # @param comment [String, false] comment line text; false for none
      def initialize(name, label: name, icon: :file, comment: label, **options)
        @name = name.to_s
        @label = label.to_s
        @icon = icon
        @comment = comment
        @options = options
        @children = []
      end

      # @return [String] last path segment, shown on the tab
      def file_name
        label.split("/").last
      end

      def render(view, state)
        view.adapter.render_ide_file_section(view, self, state)
      end
    end
  end
end
