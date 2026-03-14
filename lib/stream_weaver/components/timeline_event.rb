# frozen_string_literal: true

module StreamWeaver
  module Components
    # Timeline event row with colored type badge and expandable detail fields.
    # Designed to replicate the DTO Run Viewer event log style:
    # compact row with index, type badge, timestamp, label — click to expand key-value details.
    #
    # Event types map to distinct colors:
    #   phase        → cyan (#00bcd4)
    #   snapshot     → yellow (#ffc107)
    #   intervention → purple (#ce93d8)
    #   timeout      → red (#ef5350)
    #   guard        → red (#ef5350)
    #   final        → green (#66bb6a)
    #
    # sw- CSS classes:
    #   sw-timeline-event                    - outer row container
    #   sw-timeline-event--{type}            - type-specific border + badge colors
    #   sw-timeline-event__idx               - index number (right-aligned)
    #   sw-timeline-event__badge             - type badge pill
    #   sw-timeline-event__ts                - timestamp
    #   sw-timeline-event__label             - summary label
    #   sw-timeline-event__detail            - expandable detail section
    #   sw-timeline-event__field             - single key-value pair
    #   sw-timeline-event__field-key         - field label (bold)
    #   sw-timeline-event__field-value       - field value (may contain pre block)
    #
    # @example
    #   timeline_event index: 0, event_type: :phase, timestamp: "10:00:00",
    #                  label: "launch", fields: { run_id: "abc-123", phase: "launch" }
    class TimelineEvent < Base
      attr_reader :index, :event_type, :timestamp, :label, :fields, :expanded

      TYPES = %i[phase snapshot intervention timeout guard final].freeze

      # @param index [Integer] Event sequence number
      # @param event_type [Symbol] One of :phase, :snapshot, :intervention, :timeout, :guard, :final
      # @param timestamp [String] Time display (e.g., "10:00:00")
      # @param label [String] Summary label for the event row
      # @param fields [Hash] Key-value pairs shown in the expanded detail section
      # @param expanded [Boolean] Whether to start expanded (default: false)
      def initialize(index:, event_type:, timestamp:, label:, fields: {}, expanded: false, **options)
        @index = index
        @event_type = TYPES.include?(event_type.to_sym) ? event_type.to_sym : :phase
        @timestamp = timestamp
        @label = label
        @fields = fields
        @expanded = expanded
        super(**options)
      end

      def render(view, state)
        view.adapter.render_timeline_event(view, self, state)
      end
    end
  end
end
