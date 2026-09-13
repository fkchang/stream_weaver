# frozen_string_literal: true

module LandingPages
  module Pages
    module Visuals
      SOURCE = __FILE__

      def self.render(view)
        view.instance_exec do
          lp_page page: :visuals, source: SOURCE do
            lp_hero eyebrow: "Visual companion / Explain by showing",
              title: "MAKE THE WORK VISIBLE",
              summary: "Put the system map beside the choice it clarifies, so structure and consequence can be read together."

            lp_section_label "Diagram + comparison", "See the path and the change in one frame."
            div class: "lp-stage" do
              div class: "lp-stage-grid" do
                div class: "lp-stage-panel" do
                  text "FLOW / REQUEST TO RESULT", class: "lp-eyebrow"
                  div class: "lp-flow" do
                    text "BRIEF", class: "lp-flow-node"
                    text "CONCISE DSL", class: "lp-flow-node"
                    text "SHARED VISUAL", class: "lp-flow-node"
                    text "DECISION", class: "lp-flow-node lp-flow-result"
                  end
                end
                div class: "lp-stage-panel" do
                  text "COMPARISON / WORKING STYLE", class: "lp-eyebrow"
                  comparison before_label: "Text only", after_label: "Visible together" do
                    before do
                      text "Explain the flow, then describe each dependency, then restate what changed."
                    end
                    after do
                      text "Show the flow, place the alternatives beside it, and keep the source inspectable."
                    end
                  end
                end
              end
            end

            lp_benefits [
              ["Faster orientation", "A diagram exposes sequence and dependency before the explanation gets long."],
              ["Concrete alternatives", "Side-by-side states make a proposed change easier to judge."],
              ["Source stays nearby", "The visual and the Ruby that produced it remain available on the same page."]
            ]
          end
        end
      end
    end
  end
end
