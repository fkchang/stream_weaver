# frozen_string_literal: true

module StreamWeaver
  module Components
    # Tab row at the top of ide_rail_right. A tab is a String, or
    # { label:, active:, hint: }; a tab with a hint is dimmed and shows the
    # hint as its tooltip (a tab that is not built yet, say).
    #
    # @example
    #   ide_rail_tabs([{ label: "Specs", hint: "Planned: the spec graph" },
    #                  { label: "Files", active: true }])
    class IdeRailTabs < Base
      attr_reader :tabs, :options

      def initialize(tabs, **options)
        @tabs = Array(tabs).map { |tab| tab.is_a?(Hash) ? tab : { label: tab } }
        @options = options
      end

      def render(view, state)
        view.adapter.render_ide_rail_tabs(view, self, state)
      end
    end

    # File tree of the editor's file sections, built at render time from the
    # ide_editor in the same ide_shell: one row per section, nested under a
    # folder row for each directory in its label. The row of the section on
    # screen is marked by the editor's scroll spy, and a click scrolls the
    # editor to it.
    #
    # @example
    #   ide_rail_right { ide_filetree }
    class IdeFiletree < Base
      attr_reader :label, :options

      # @param label [String] accessible name of the tree
      def initialize(label: "Files", **options)
        @label = label
        @options = options
      end

      # Folder and file rows for these sections, in order. A folder row is
      # emitted when a section's directory first differs from the one above.
      #
      # @param sections [Array<IdeFileSection>]
      # @return [Array<Hash>] { folder: name, depth: } or { section:, depth: }
      def rows(sections)
        open_folders = []
        sections.flat_map do |section|
          folders = section.label.split("/")[0...-1]
          shared = open_folders.zip(folders).take_while { |open, folder| open == folder }.size
          open_folders = folders
          new_folders = folders.each_with_index.drop(shared).map { |folder, depth| { folder: folder, depth: depth } }
          new_folders + [{ section: section, depth: folders.size }]
        end
      end

      def render(view, state)
        view.adapter.render_ide_filetree(view, self, state)
      end
    end

    # A terminal panel showing a fixed transcript. A line is a Hash
    # { command: } (shown after the prompt) or a String (output).
    #
    # @example
    #   ide_terminal(lines: [{ command: "gem install stream_weaver" },
    #                        "Successfully installed stream_weaver"])
    class IdeTerminal < Base
      attr_reader :label, :prompt, :lines, :options

      def initialize(lines: [], label: "Terminal", prompt: "❯", **options)
        @lines = Array(lines)
        @label = label
        @prompt = prompt
        @options = options
      end

      def render(view, state)
        view.adapter.render_ide_terminal(view, self, state)
      end
    end
  end
end
