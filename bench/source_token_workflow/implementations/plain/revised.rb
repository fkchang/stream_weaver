# frozen_string_literal: true

module SourceTokenWorkflow
  module PlainDashboard
    METRICS = [{ value: "4", label: "Ready" }, { value: "2", label: "Review" }, { value: "1", label: "Blocked" }].freeze
    ROWS = [
      { work: "Navigation", owner: "Web", due: "Today", status: "Ready" },
      { work: "Source inspection", owner: "Docs", due: "Today", status: "Review" },
      { work: "Mobile layout", owner: "Design", due: "Tomorrow", status: "Ready" },
      { work: "Release checklist", owner: "Ops", due: "Friday", status: "Blocked" }
    ].freeze

    def self.locals
      {
        title: "Release readiness",
        metrics: METRICS,
        rows: ROWS,
        badge_label: ROWS.any? { |row| row[:status] == "Blocked" } ? "ACTION NEEDED" : "ON TRACK",
        include_status: true
      }
    end
  end
end
