# frozen_string_literal: true

module LandingPages
  module Pages
    module Overview
      SOURCE = __FILE__
      PROOF_SOURCE = <<~'RUBY'
        header2 "Release readiness"
        columns do
          column do
            stat_display value: "4", label: "READY", color: :green
          end
          column do
            callout "Checks passed. Ready for review.", variant: :success
          end
        end
      RUBY

      def self.render(view)
        view.instance_exec do
          lp_page page: :overview, source: SOURCE do
            lp_hero eyebrow: "Ruby DSL for interfaces agents can write and people can use.",
              title: "ONE RUBY FILE. A REAL INTERFACE.",
              summary: "Build a dashboard, document, slide deck, diagram, chart, or question for a person—without starting a second frontend project."

            lp_section_label "One source / one result", "One snippet. Its actual result.", anchor: "example"
            div class: "lp-proof" do
              code_preview PROOF_SOURCE, title: "A small release dashboard", file: "release_readiness.rb"
            end

            lp_section_label "What do you want to make?", "One language across the work."
            div class: "lp-use-grid" do
              [
                [:applications, "Dashboards + apps", "Turn the Ruby script you already have into a useful view."],
                [:documents, "Documents", "Write long-form material with navigation, tables, and evidence."],
                [:documents, "Slide decks", "Compose presentations from the same Ruby component language."],
                [:visuals, "Diagrams + charts", "Show a system, sequence, comparison, or changing value."],
                [:agents, "Forms + answers", "Ask a person a question and receive structured data in a live workflow."],
                [:agents, "Agent canvas", "Let an agent show its work while you decide when to answer."]
              ].each do |page, label, copy|
                div class: "lp-use" do
                  link_to "#{label} →", href: LandingPages::ROUTES.fetch(page)
                  text copy
                end
              end
            end

            lp_audiences(
              ruby_author: "Keep the data and the interface in Ruby, with no separate JavaScript application to maintain.",
              agent_author: "Give the agent a short component vocabulary and let it produce something you can inspect line by line.",
              reader: "Open an explorable page or exported file; the source stays close when you want to understand how it was made."
            )
          end
        end
      end
    end
  end
end
