# frozen_string_literal: true

module LandingPages
  module Pages
    module Applications
      SOURCE = __FILE__

      def self.render(view)
        view.instance_exec do
          lp_page page: :applications, source: SOURCE do
            lp_hero eyebrow: "Application surface / Useful by default",
              title: "FROM SCRIPT TO USEFUL APP",
              summary: "Shape real information into a focused operating view without hand-building the surrounding interface."

            lp_section_label "Release desk", "A compact dashboard for the next action."
            div class: "lp-stage" do
              div class: "lp-dashboard" do
                div class: "lp-stat" do
                  text "READY", class: "lp-eyebrow"
                  text "04", class: "lp-stat-value"
                end
                div class: "lp-stat" do
                  text "NEEDS REVIEW", class: "lp-eyebrow"
                  text "02", class: "lp-stat-value"
                end
                div class: "lp-stat" do
                  text "BLOCKED", class: "lp-eyebrow"
                  text "01", class: "lp-stat-value"
                end
                div class: "lp-stage-panel lp-wide" do
                  text "WORK QUEUE / ILLUSTRATIVE DATA", class: "lp-eyebrow"
                  div class: "lp-status-list" do
                    [
                      ["Navigation pass", "Ready", "Today"],
                      ["Source inspection", "Review", "Today"],
                      ["Narrow viewport", "Ready", "Tomorrow"],
                      ["Release checklist", "Blocked", "Finding"]
                    ].each do |name, status, timing|
                      div class: "lp-status-row" do
                        text name
                        text status, class: "lp-eyebrow"
                        text timing
                      end
                    end
                  end
                end
                div class: "lp-stage-panel" do
                  text "NEXT ACTION", class: "lp-eyebrow"
                  header3 "Review source inspection", class: "lp-stage-title"
                  text "One focused queue turns script output into an interface someone can use.", class: "lp-stage-copy"
                end
              end
            end

            lp_benefits [
              ["Useful composition", "Metrics, queues, and next actions share one clear operating hierarchy."],
              ["Reuse the interface", "Build the view once, then let agents supply fresh data."],
              ["Ruby all the way down", "The presentation reads like the domain instead of a second frontend project."]
            ]
          end
        end
      end
    end
  end
end
