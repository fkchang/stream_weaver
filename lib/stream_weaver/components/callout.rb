# frozen_string_literal: true

module StreamWeaver
  module Components
    # Non-dismissible callout box with colored left border and icon area.
    #
    # Unlike Alert (which is dismissible), Callout is a static content box
    # used for tips, warnings, notes, etc. in explainer documents.
    #
    # Variants: :info (blue), :warning (amber), :success (green),
    #           :error (red), :tip (purple)
    #
    # @example
    #   callout(variant: :warning, title: "Caution") do
    #     text "Be careful with this API."
    #   end
    class Callout < Base
      VARIANTS = %i[info warning success error tip].freeze

      attr_reader :variant, :title
      attr_accessor :children

      # @param variant [Symbol] Callout type (:info, :warning, :success, :error, :tip)
      # @param title [String, nil] Optional callout title
      # @param options [Hash] Additional options
      def initialize(variant: :info, title: nil, **options)
        @variant = VARIANTS.include?(variant) ? variant : :info
        @title = title
        @options = options
        @children = []
      end

      # Icon character for each variant
      # @return [String] Unicode icon
      def icon
        case @variant
        when :info    then "\u2139\uFE0F"  # info
        when :warning then "\u26A0\uFE0F"  # warning
        when :success then "\u2705"         # check
        when :error   then "\u274C"         # cross
        when :tip     then "\u{1F4A1}"      # lightbulb
        else "\u2139\uFE0F"
        end
      end

      # CSS modifier class for the variant
      # @return [String]
      def variant_class
        "sw-callout--#{@variant}"
      end

      def render(view, state)
        view.adapter.render_callout(view, self, state)
      end
    end
  end
end
