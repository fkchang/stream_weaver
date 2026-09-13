# frozen_string_literal: true

module LandingPages
  module Pages
    module Overview
      SOURCE = __FILE__

      def self.render(view)
        view.instance_exec do
          lp_page page: :overview, source: SOURCE do
            lp_hero eyebrow: "Ruby DSL / One shared surface",
              title: "EXPRESS MORE. WRITE LESS.",
              summary: "Turn concise Ruby into explorable interfaces for decisions, diagrams, documents, apps, and review. Less code to generate, read, and revise."

            lp_section_label "Code → render", "A small source can carry a large idea."
            div class: "lp-stage" do
              div class: "lp-stage-grid" do
                div class: "lp-stage-panel lp-code" do
                  text "RUBY DSL", class: "lp-eyebrow"
                  code_block <<~'RUBY', lang: "ruby", file: "idea.rb"
                    header1 "Make the work visible"
                    columns widths: ["42%", "58%"] do
                      column { decision_summary }
                      column do
                        mermaid workflow
                        diff(language: "ruby") do
                          before { draft }
                          after { proposal }
                        end
                      end
                    end
                  RUBY
                end
                div class: "lp-stage-panel lp-dark" do
                  text "RENDER / SHARED SURFACE", class: "lp-eyebrow"
                  header2 "A decision you can see, inspect, and discuss.", class: "lp-stage-title"
                  div class: "lp-chip-row" do
                    text "Decision", class: "lp-chip"
                    text "Diagram", class: "lp-chip"
                    text "Diff", class: "lp-chip"
                  end
                  text "The DSL stays close to the meaning of the work while StreamWeaver handles the presentation.", class: "lp-stage-copy"
                end
              end
            end

            lp_section_label "Five focused uses", "One language across the work."
            div class: "lp-use-grid" do
              {
                agents: ["Agents", "Give parallel work a shared decision surface."],
                visuals: ["Visuals", "Explain structure with diagrams and comparisons."],
                documents: ["Docs", "Create long-form material people can explore."],
                applications: ["Apps", "Turn a script into a useful working view."],
                review: ["Review workflows · concept", "Put intent, criteria, and code changes together."]
              }.each do |page, (label, copy)|
                div class: "lp-use" do
                  link_to "#{label} →", href: LandingPages::ROUTES.fetch(page)
                  text copy
                end
              end
            end

            lp_benefits [
              ["More meaning per line", "Compose with decisions, diagrams, tables, and diffs instead of rebuilding their markup."],
              ["One surface for the arc", "Move from thought to artifact without changing languages at every step."],
              ["Easy to revisit", "Readable Ruby keeps the source approachable when the work changes tomorrow."]
            ]
          end
        end
      end
    end
  end
end
