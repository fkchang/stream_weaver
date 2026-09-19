# frozen_string_literal: true

module LandingPages
  module Pages
    module Documents
      SOURCE = __FILE__
      PROOF_SOURCE = <<~'RUBY'
        doc_header title: "Release note",
          eyebrow: "What changed and why",
          pills: ["Product team"]
        callout "Navigation now uses real, bookmarkable routes.", variant: :success
        md "Readers get the decision, the evidence, and the next step in one document."
      RUBY

      def self.render(view)
        view.instance_exec do
          lp_page page: :documents, source: SOURCE do
            lp_hero eyebrow: "Reports, notes, and slide decks from the same DSL",
              title: "WRITE A DOCUMENT PEOPLE CAN EXPLORE",
              summary: "Give long-form work a reading path, evidence, and a source that stays approachable when the story changes."

            lp_section_label "Document proof", "The source and the reading experience stay together.", anchor: "example"
            div class: "lp-proof" do
              code_preview PROOF_SOURCE, title: "A compact release note", file: "release_note.rb", layout: :stacked
            end

            lp_audiences(
              ruby_author: "Compose reports and slide decks with named sections, navigation, tables, code, and diagrams.",
              agent_author: "Draft a structured artifact that is easier to review than a long answer in chat.",
              reader: "Follow the argument, open supporting details, and receive a static export when no live server is needed."
            )
          end
        end
      end
    end
  end
end
