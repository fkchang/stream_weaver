# frozen_string_literal: true

module StreamWeaver
  module Components
    # Code block with line-number-pinned annotation bubbles in a side panel.
    # Uses Prism.js for syntax highlighting. Note: highlighting is applied per line,
    # so multi-line constructs (heredocs, block comments) may highlight each line
    # independently — this component optimises for annotation alignment, not perfect highlighting.
    # Renders a side-by-side layout: code pane left, annotation panel right.
    # Each annotation is aligned to its target line; annotated lines get a subtle highlight.
    # Annotations are positioned by line number (1-based, in-range). Out-of-range lines
    # produce dangling bubbles with no highlighted counterpart — that is visible authoring feedback.
    class AnnotatedCode < Base
      Annotation = Struct.new(:line, :note, keyword_init: true)

      attr_reader :language, :annotations

      def initialize(language: nil, annotations: [], **options)
        @language = language
        @annotations = annotations.map { |a| Annotation.new(line: a[:line], note: a[:note]) }
        @options = options
      end

      def code=(value)
        @code = value.to_s
      end

      def code
        @code || ""
      end

      def lines
        code.lines
      end

      def line_count
        lines.length
      end

      def language_class
        language ? "language-#{language}" : "language-none"
      end

      def annotated_lines
        @annotated_lines ||= Set.new(annotations.map(&:line))
      end

      def render(view, state)
        view.adapter.render_annotated_code(view, self, state)
      end
    end
  end
end
