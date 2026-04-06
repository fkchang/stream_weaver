# frozen_string_literal: true

module StreamWeaver
  module Components
    # Pipeline step flow visualization.
    # Renders a horizontal sequence of steps with arrow connectors,
    # color-coded by status: complete (green), active (blue), pending (gray).
    # Responsive: collapses to vertical layout on narrow screens.
    #
    # sw- CSS classes:
    #   sw-pipeline              - outer flexbox container
    #   sw-pipeline__step        - individual step box
    #   sw-pipeline__step--complete  - green (done)
    #   sw-pipeline__step--active    - blue (in progress)
    #   sw-pipeline__step--pending   - gray (not started)
    #   sw-pipeline__label       - step label text
    #   sw-pipeline__desc        - step description text
    #   sw-pipeline__arrow       - CSS triangle arrow connector
    #
    # @example Basic
    #   pipeline steps: [
    #     { label: "Build", status: :complete },
    #     { label: "Test",  status: :active },
    #     { label: "Deploy", status: :pending }
    #   ]
    class Pipeline < Base
      attr_reader :steps

      # @param steps [Array<Hash>] Array of step hashes with :label, :description (optional), :status
      #   status values: :complete, :active, :pending
      # @param options [Hash] Additional options
      def initialize(steps:, **options)
        @steps = steps.map { |s| normalize_step(s) }
        super(**options)
      end

      def render(view, state)
        view.adapter.render_pipeline(view, self, state)
      end

      # CSS class for a step based on its status
      def step_css_class(step)
        base = "sw-pipeline__step"
        modifier = case step[:status]
                   when :complete then "sw-pipeline__step--complete"
                   when :active   then "sw-pipeline__step--active"
                   else                "sw-pipeline__step--pending"
                   end
        "#{base} #{modifier}"
      end

      private

      def normalize_step(step)
        {
          label: step[:label] || "Step",
          description: step[:description],
          status: (step[:status] || :pending).to_sym
        }
      end
    end
  end
end
