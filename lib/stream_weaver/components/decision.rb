# frozen_string_literal: true

module StreamWeaver
  module Components
    # Architecture decision block with labeled options and a recommended flag.
    # Renders a question heading with option cards; recommended option gets a badge,
    # non-recommended options are visually de-emphasized.
    #
    # @example
    #   decision(question: "Which database should we use?") do
    #     option(id: :pg, label: "PostgreSQL", detail: "Full ACID, rich extensions", recommended: true)
    #     option(id: :sqlite, label: "SQLite", detail: "Zero-dependency, great for dev")
    #   end
    class Decision < Base
      Option = Struct.new(:id, :label, :detail, :recommended, keyword_init: true)

      attr_reader :question

      def initialize(question:, **options)
        @question = question
        @options = options
        @decision_options = []
      end

      def options
        @decision_options
      end

      def add_option(id:, label:, detail:, recommended: false)
        @decision_options << Option.new(id: id, label: label, detail: detail, recommended: recommended)
      end

      def render(view, state)
        view.adapter.render_decision(view, self, state)
      end
    end
  end
end
