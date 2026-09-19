# frozen_string_literal: true

module SourceTokenWorkflow
  module StreamWeaverDashboard
    METRICS = [["4", "READY", :green], ["2", "REVIEW", :orange], ["1", "BLOCKED", :red]].freeze
    ROWS = [
      ["Navigation", "Web", "Today"],
      ["Source inspection", "Docs", "Today"],
      ["Mobile layout", "Design", "Tomorrow"],
      ["Release checklist", "Ops", "Friday"]
    ].freeze

    def self.app(stylesheet)
      blocked = METRICS.last.first.to_i
      badge_label = blocked <= 1 ? "ON TRACK" : "AT RISK"

      StreamWeaver::App.new("Release readiness", chrome: false) do
        use_stylesheet stylesheet
        div class: "benchmark-shell" do
          div class: "benchmark-header" do
            header1 "Release readiness"
            badge badge_label, variant: :success
          end
          grid columns: 3, class: "metrics" do
            METRICS.each { |value, label, color| stat_display value: value, label: label, color: color }
          end
          div class: "table-wrap" do
            table headers: ["Work", "Owner", "Due"], rows: ROWS
          end
        end
      end
    end
  end
end
