# frozen_string_literal: true

module SourceTokenWorkflow
  module PlainDashboard
    METRICS = [{ value: "4", label: "Ready" }, { value: "2", label: "Review" }, { value: "1", label: "Blocked" }].freeze
    ROWS = [
      { work: "Navigation", owner: "Web", due: "Today" },
      { work: "Source inspection", owner: "Docs", due: "Today" },
      { work: "Mobile layout", owner: "Design", due: "Tomorrow" },
      { work: "Release checklist", owner: "Ops", due: "Friday" }
    ].freeze

    def self.locals
      blocked = METRICS.find { |metric| metric[:label] == "Blocked" }[:value].to_i
      {
        title: "Release readiness",
        metrics: METRICS,
        rows: ROWS,
        badge_label: blocked <= 1 ? "ON TRACK" : "AT RISK",
        include_status: false
      }
    end
  end
end
