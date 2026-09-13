# frozen_string_literal: true

module LandingPages
  module Pages
    module Documents
      SOURCE = __FILE__

      def self.render(view)
        view.instance_exec do
          lp_page page: :documents, source: SOURCE do
            lp_hero eyebrow: "Living documents / Editorial structure",
              title: "DOCUMENTS YOU CAN EXPLORE",
              summary: "Give long-form thinking a clear reading path, a compact table of contents, and evidence that remains part of the document."

            lp_section_label "Miniature field note", "A document with wayfinding built in."
            div class: "lp-stage" do
              div class: "lp-document" do
                div do
                  sidebar_toc sections: [
                    { id: "doc-question", label: "Question" },
                    { id: "doc-observation", label: "Observation" },
                    { id: "doc-next", label: "Next move" }
                  ]
                end
                div class: "lp-doc-body" do
                  div id: "doc-question" do
                    text "FIELD NOTE / SEPTEMBER 13", class: "lp-eyebrow"
                    header2 "What makes a document stay useful?", class: "lp-stage-title"
                    md "A useful document supports a first read and a return visit. Its structure reveals where the answer lives; its source stays simple enough to revise when the answer changes."
                  end
                  div id: "doc-observation" do
                    header3 "Observation", class: "lp-stage-title"
                    table headers: ["Layer", "Job", "Reader signal"], rows: [
                      ["Outline", "Expose the argument", "I know where I am"],
                      ["Evidence", "Support the claim", "I can verify this"],
                      ["Source", "Keep revision cheap", "I can change this later"]
                    ]
                  end
                  div id: "doc-next" do
                    header3 "Next move", class: "lp-stage-title"
                    callout "Keep the reading path visible and the authoring language concise.", tone: :neutral
                  end
                end
              end
            end

            lp_benefits [
              ["Readable structure", "Sections and wayfinding help readers scan before committing to the whole piece."],
              ["Evidence in context", "Tables, diagrams, and code live inside the argument they support."],
              ["Living source", "Less code to generate, read, and revise keeps maintenance close to authorship."]
            ]
          end
        end
      end
    end
  end
end
