# frozen_string_literal: true

module LandingPages
  module Pages
    module Agents
      SOURCE = __FILE__

      def self.render(view)
        view.instance_exec do
          lp_page page: :agents, source: SOURCE do
            lp_hero eyebrow: "Agent communication / Structured handoff",
              title: "GIVE AGENTS A SHARED SURFACE",
              summary: "Move a choice from scattered context into a visible decision with options, rationale, and a structured result."

            lp_section_label "Decision storyboard", "From an open question to a reusable result."
            div class: "lp-stage" do
              div class: "lp-storyboard" do
                div class: "lp-story-step" do
                  text "INPUT / OPEN QUESTION", class: "lp-eyebrow"
                  header3 "How should the release be staged?", class: "lp-story-title"
                  text "Constraints: reversible, observable, and easy to hand off.", class: "lp-stage-copy"
                end
                div class: "lp-story-step" do
                  text "OPTIONS / TRADEOFFS", class: "lp-eyebrow"
                  div class: "lp-chip-row" do
                    text "One cutover", class: "lp-chip"
                    text "Two phases", class: "lp-chip"
                    text "Feature flag", class: "lp-chip"
                  end
                  text "Each option stays attached to the reason it exists.", class: "lp-stage-copy"
                end
                div class: "lp-story-step lp-story-result" do
                  text "RESULT / EXAMPLE DECISION", class: "lp-eyebrow"
                  header3 "Ship in two observable phases.", class: "lp-story-title"
                  text "Owner: release agent · Gate: route checks · Follow-up: remove flag after UAT", class: "lp-stage-copy"
                end
              end
            end

            lp_benefits [
              ["Structured inputs", "Forms give every agent the same question, constraints, and vocabulary."],
              ["Persistent canvas", "Keep the decision surface available as options and rationale become a result."],
              ["Choose when to respond", "Collect a blocking answer or keep a canvas available while the agent continues."]
            ]
          end
        end
      end
    end
  end
end
