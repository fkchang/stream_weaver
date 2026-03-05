# frozen_string_literal: true

module StreamWeaver
  # Display-only component DSL for feed context.
  # Uses the same DisplayDSL as App but omits interactive components.
  #
  # @example
  #   components = FeedBuilder.build do
  #     card { stat_display value: 42, label: "RPS", color: :blue }
  #   end
  class FeedBuilder
    include DisplayDSL

    attr_reader :components

    def initialize
      @components = []
    end

    def self.build(&block)
      builder = new
      builder.instance_eval(&block)
      builder.components
    end
  end
end
