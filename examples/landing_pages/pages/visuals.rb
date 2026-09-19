# frozen_string_literal: true

module LandingPages
  module Pages
    module Visuals
      SOURCE = __FILE__
      PROOF_SOURCE = <<~'RUBY'
        mermaid <<~DIAGRAM, compact: true
          flowchart LR
            Brief --> Ruby
            Ruby --> Interface
            Interface --> Decision
        DIAGRAM
      RUBY

      def self.render(view)
        view.instance_exec do
          lp_page page: :visuals, source: SOURCE do
            lp_hero eyebrow: "Diagrams, charts, and comparisons from Ruby",
              title: "SHOW THE DIAGRAM NEXT TO THE DECISION",
              summary: "Turn a system, sequence, or changing value into a visual a person can inspect alongside the explanation."

            lp_section_label "Diagram proof", "This exact Ruby renders the flow.", anchor: "example"
            div class: "lp-proof" do
              code_preview PROOF_SOURCE, title: "Brief to decision", file: "decision_flow.rb"
            end

            lp_audiences(
              ruby_author: "Add a diagram, chart, or comparison without hand-building SVG or wiring a charting frontend.",
              agent_author: "Render the architecture or tradeoff directly so the person can verify what your prose means.",
              reader: "Read the visual and its explanation together, then inspect the short Ruby source when details matter."
            )
          end
        end
      end
    end
  end
end
