# frozen_string_literal: true

module LandingPages
  module Pages
    module Applications
      SOURCE = __FILE__
      PROOF_SOURCE = <<~'RUBY'
        header2 "Build queue"
        columns do
          column { stat_display value: "4", label: "READY", color: :green }
          column { stat_display value: "2", label: "REVIEW", color: :orange }
          column { stat_display value: "1", label: "BLOCKED", color: :red }
        end
        callout "Next: review source inspection", variant: :info
      RUBY

      def self.render(view)
        view.instance_exec do
          lp_page page: :applications, source: SOURCE do
            lp_hero eyebrow: "Dashboards and tools from the Ruby you already have",
              title: "TURN YOUR SCRIPT INTO A USEFUL APP",
              summary: "Put metrics, status, and the next action into a focused interface without starting a separate frontend codebase."

            lp_section_label "Dashboard proof", "A working view from a short, self-contained source.", anchor: "example"
            div class: "lp-proof" do
              code_preview PROOF_SOURCE, title: "A build queue", file: "build_queue.rb"
            end

            lp_audiences(
              ruby_author: "Keep the script, data, and presentation in one language and reuse the interface as the data changes.",
              agent_author: "Turn command output into a dashboard a person can scan instead of pasting a wall of logs.",
              reader: "See the status and the next action immediately, without learning how the script works first."
            )
          end
        end
      end
    end
  end
end
