# frozen_string_literal: true

module SourceTokenWorkflow
  module StreamWeaverDashboard
    METRICS = [["4", "READY", :green], ["2", "REVIEW", :orange], ["1", "BLOCKED", :red]].freeze
    ROWS = [
      ["Navigation", "Web", "Today", "Ready"],
      ["Source inspection", "Docs", "Today", "Review"],
      ["Mobile layout", "Design", "Tomorrow", "Ready"],
      ["Release checklist", "Ops", "Friday", "Blocked"]
    ].freeze

    def self.app(stylesheet)
      badge_label = ROWS.any? { |row| row.last == "Blocked" } ? "ACTION NEEDED" : "ON TRACK"

      StreamWeaver::App.new("Release readiness", chrome: false) do
        use_stylesheet stylesheet
        div class: "benchmark-shell" do
          div class: "benchmark-header" do
            header1 "Release readiness"
            badge badge_label, variant: :warning
          end
          grid columns: 3, class: "metrics" do
            METRICS.each { |value, label, color| stat_display value: value, label: label, color: color }
          end
          div class: "table-wrap" do
            table headers: ["Work", "Owner", "Due", "Status"], rows: ROWS
          end
        end
      end
    end
  end
end
