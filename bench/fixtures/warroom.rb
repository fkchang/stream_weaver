# frozen_string_literal: true

require_relative "../support"

module StreamWeaverBench
  module Fixtures
    module Warroom
      VARIANTS = %i[legacy_full named_full named_fragments named_fragments_oob].freeze
      INTERACTIONS = %i[note_append column_move].freeze

      module_function

      def build(variant)
        metrics = Metrics.new
        named = variant != :legacy_full
        app = StreamWeaver::App.new("Warroom #{variant}") do
          state[:stories] ||= StreamWeaverBench.deep_copy(STORIES)
          if named
            action(:append_note) { |s, key| metrics.callback!; s[:stories].find { |story| story[:id] == key }[:notes] << "Appended note" }
            action(:move_story) { |s, key| metrics.callback!; s[:stories].find { |story| story[:id] == key }[:column] = "Active" }
          end

          board = proc do
            grid(columns: 3) do
              %w[Ready Active Done].each do |column|
                card(title: column) do
                  state[:stories].select { |story| story[:column] == column }.each { |story| text "#{story[:id]} — #{story[:title]}" }
                end
              end
            end
          end
          scoped = %i[named_fragments named_fragments_oob].include?(variant)
          scoped ? fragment(:board, &board) : instance_exec(&board)
          detail = proc do
            story = state[:stories].first
            text story[:title]
            story[:notes].each { |note| text note }
            form :note do
              text_area :body, default: "Appended note"
              submit("Add note") { |_values| metrics.callback! }
            end
            if named
              button "Append note", action: :append_note, key: story[:id]
              button "Move story", action: :move_story, key: story[:id], updates: (variant == :named_fragments_oob ? :board : nil)
            else
              button("Append note") { |s| metrics.callback!; s[:stories].first[:notes] << "Appended note" }
              button("Move story") { |s| metrics.callback!; s[:stories].first[:column] = "Active" }
            end
          end
          scoped ? fragment(:detail, &detail) : instance_exec(&detail)
        end
        StreamWeaverBench.instrument(app, metrics)
        [app.generate, metrics]
      end
    end
  end
end
