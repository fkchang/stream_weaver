# frozen_string_literal: true

module LandingPages
  module Pages
    module Agents
      SOURCE = __FILE__
      PROOF_SOURCE = <<~'RUBY'
        decision question: "How should we release?" do
          option id: :phased, label: "Two phases", detail: "Observe each step", recommended: true
          option id: :once, label: "One cutover", detail: "Fast, harder to reverse"
        end
      RUBY

      def self.render(view)
        view.instance_exec do
          lp_page page: :agents, source: SOURCE do
            lp_hero eyebrow: "For agents that need to show, ask, and continue",
              title: "LET YOUR AGENT SHOW YOU THE CHOICE",
              summary: "Instead of a wall of terminal text, the agent can put the options on a page and make the tradeoff readable."

            lp_section_label "Agent proof", "A real decision, rendered from the source beside it.", anchor: "example"
            div class: "lp-proof" do
              code_preview PROOF_SOURCE, title: "A release decision", file: "release_choice.rb"
            end

            lp_audiences(
              ruby_author: "Define the page with the same Ruby components you use for the rest of the workflow.",
              agent_author: "Show options, diagrams, progress, or a structured question instead of describing them in terminal prose.",
              reader: "See what the agent is asking, compare the choices, and answer now or return to the persistent canvas later."
            )
          end
        end
      end
    end
  end
end
