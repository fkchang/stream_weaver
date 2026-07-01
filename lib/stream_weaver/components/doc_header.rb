# frozen_string_literal: true

module StreamWeaver
  module Components
    # Document-level header with eyebrow label, serif title, and meta pill row.
    # Used to open long-form documents: PRDs, reports, explainers.
    #
    # Pills are an array of mixed items:
    #   - String → rendered as plain meta text
    #   - Hash { text:, variant: } → colored pill (:default, :warn, :good)
    #
    # @example
    #   doc_header(
    #     eyebrow: "cultiv-ai · Personal OS",
    #     title: "Calendar-Driven Travel State",
    #     pills: [
    #       { text: "Draft" },
    #       "June 25, 2026",
    #       "Author: Forrest Chang"
    #     ]
    #   )
    class DocHeader < Base
      attr_reader :eyebrow, :title, :pills

      def initialize(eyebrow: nil, title:, pills: [], **options)
        @eyebrow = eyebrow
        @title = title
        @pills = Array(pills)
        @options = options
      end

      def render(view, state)
        view.adapter.render_doc_header(view, self, state)
      end
    end

    # Numbered section eyebrow + heading pair for document sections.
    # Renders a monospace number badge and an h2 heading with a decorative line.
    #
    # @example
    #   doc_section_header "01", "Problem Statement", id: "problem"
    class DocSectionHeader < Base
      attr_reader :number, :title, :anchor_id

      def initialize(number, title, id: nil, **options)
        @number = number.to_s
        @title = title
        @anchor_id = id
        @options = options
      end

      def render(view, state)
        view.adapter.render_doc_section_header(view, self, state)
      end
    end
  end
end
