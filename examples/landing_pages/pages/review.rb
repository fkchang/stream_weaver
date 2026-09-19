# frozen_string_literal: true

module LandingPages
  module Pages
    module Review
      SOURCE = __FILE__
      PROOF_SOURCE = <<~'RUBY'
        comparison before_label: "Before", after_label: "Proposed" do
          before { code_block 'nav_item "Docs", href: "#"', lang: "ruby" }
          after { code_block 'link_to "Docs", href: "/documents"', lang: "ruby" }
        end
        callout "Criterion: the Docs link returns HTTP 200.", variant: :info
      RUBY

      def self.render(view)
        view.instance_exec do
          lp_page page: :review, source: SOURCE do
            lp_hero eyebrow: "Plan + code review / proposed workflow",
              title: "REVIEW THE DECISION AND THE DIFF",
              summary: "Explore a review surface that keeps the reason for a change beside the proposed code and the criterion that decides whether it is complete."

            lp_section_label "Review exploration", "Intent, change, and acceptance in one frame.", anchor: "example"
            div class: "lp-proof" do
              text "EXPLORATION", class: "lp-exploration-label"
              code_preview PROOF_SOURCE, title: "A navigation proposal", file: "navigation_review.rb"
            end

            lp_audiences(
              ruby_author: "Put the proposal and its acceptance criterion beside the code a reviewer will inspect.",
              agent_author: "Explain why the change exists, show the exact proposal, and name what would prove it works.",
              reader: "Judge the decision and the code together without reconstructing the plan from a terminal transcript."
            )
          end
        end
      end
    end
  end
end
