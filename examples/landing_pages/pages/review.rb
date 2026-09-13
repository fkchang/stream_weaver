# frozen_string_literal: true

module LandingPages
  module Pages
    module Review
      SOURCE = __FILE__

      def self.render(view)
        view.instance_exec do
          lp_page page: :review, source: SOURCE do
            lp_hero eyebrow: "Plan + code review / Proposed workflow",
              title: "REVIEW THE DECISION AND THE DIFF",
              summary: "A proposed review surface keeps the reason for a change beside the actual change and the criterion that decides whether it is complete."

            lp_section_label "Proposed review workflow", "Intent above. Evidence below."
            div class: "lp-stage" do
              div class: "lp-stage-grid" do
                div class: "lp-stage-panel" do
                  text "DECISION / NAVIGATION", class: "lp-eyebrow"
                  header3 "Use real hrefs for every page.", class: "lp-stage-title"
                  text "Rationale: routes remain bookmarkable, inspectable, and honest in a local preview.", class: "lp-stage-copy"
                  div class: "lp-review-criterion" do
                    text "ACCEPTANCE CRITERION\nGiven the preview is running\nWhen each primary navigation link is followed\nThen the matching page returns HTTP 200 and shows its unique headline."
                  end
                end
                div class: "lp-stage-panel lp-code" do
                  text "DIFF / ROUTE MAP", class: "lp-eyebrow"
                  diff(language: "ruby") do
                    before do
                      <<~'RUBY'
                        nav_item "Visuals", href: "#"
                        nav_item "Docs", href: "#"
                      RUBY
                    end
                    after do
                      <<~'RUBY'
                        link_to "Visuals", href: "/visuals"
                        link_to "Docs", href: "/documents"
                      RUBY
                    end
                  end
                end
              end
            end

            lp_benefits [
              ["Intent stays visible", "Review begins with the decision and rationale instead of reconstructing them from code."],
              ["The change is concrete", "A real diff makes the proposal inspectable line by line."],
              ["Completion has a test", "The acceptance criterion names the observable behavior that closes the review."]
            ]
          end
        end
      end
    end
  end
end
