# frozen_string_literal: true

module StreamWeaver
  module Components
    # File-path-to-rationale mapping component for pre-flight planning.
    # Shows what files will be touched and why, before writing any code.
    #
    # @example
    #   implementation_map(files: [
    #     { path: "lib/foo.rb", note: "Add the new method" },
    #     { path: "spec/foo_spec.rb", note: "Cover edge cases" }
    #   ])
    class ImplementationMap < Base
      attr_reader :files

      # @param files [Array<Hash>] Array of {path:, note:} or {"path"=>,"note"=>} hashes
      def initialize(files: [], **options)
        @files = files.map { |f| normalize(f) }
        @options = options
      end

      def render(view, state)
        view.adapter.render_implementation_map(view, self, state)
      end

      private

      def normalize(entry)
        { path: entry[:path] || entry["path"] || "", note: entry[:note] || entry["note"] || "" }
      end
    end
  end
end
