# frozen_string_literal: true

require_relative "../support"

module StreamWeaverBench
  module Fixtures
    module Ledger
      VARIANTS = %i[legacy_full named_full named_fragments update_filter].freeze
      INTERACTIONS = %i[create edit validation filter delete].freeze

      module_function

      def build(variant)
        metrics = Metrics.new
        people = MemoryStore.new(PEOPLE)
        named = variant != :legacy_full
        scoped = %i[named_fragments update_filter].include?(variant)
        app = StreamWeaver::App.new("Ledger #{variant}") do
          state[:query] ||= ""
          state[:error] ||= ""
          state[:selection] ||= nil

          if named
            action(:create_person, updates: (scoped ? :people : nil)) { |_s, _| metrics.callback!; people.create(id: 51, name: "New Person", email: "new@example.test", touched: "2026-07-01") }
            action(:edit_person) { |_s, key| metrics.callback!; people.update(key, name: "Edited Person") }
            action(:invalid_person) { |s, _| metrics.callback!; s[:error] = "Name is required" }
            action(:delete_person) { |_s, key| metrics.callback!; people.destroy(key) }
          end

          toolbar = proc do
            if named
              button "Create", action: :create_person, key: "new"
              button "Invalid", action: :invalid_person, key: "invalid"
            else
              button("Create") { |_s| metrics.callback!; people.create(id: 51, name: "New Person", email: "new@example.test", touched: "2026-07-01") }
              button("Invalid") { |s| metrics.callback!; s[:error] = "Name is required" }
            end
            text state[:error]
            form :quick_edit do
              text_field :name, default: "Person 01"
              text_field :email, default: "person01@example.test"
              submit("Save quick edit") { |_values| metrics.callback! }
            end
          end
          scoped ? fragment(:toolbar, &toolbar) : instance_exec(&toolbar)

          people_view = proc do
            text_field :query, placeholder: "Search", on_change: ->(_s, _value) { metrics.callback! } if variant == :update_filter
            shown = people.all.select { |person| person[:name].downcase.include?(state[:query].to_s.downcase) }
            table shown, row_key: ->(person) { person[:id] } do
              column :name
              column :email
              column :touched
              column :actions do |person|
                if named
                  hstack do
                    button "Edit", action: :edit_person, key: person[:id]
                    button "Delete", action: :delete_person, key: person[:id]
                  end
                else
                  hstack do
                    button("Edit", key: person[:id]) { |_s| metrics.callback!; people.update(person[:id], name: "Edited Person") }
                    button("Delete", key: person[:id]) { |_s| metrics.callback!; people.destroy(person[:id]) }
                  end
                end
              end
            end
          end
          scoped ? fragment(:people, &people_view) : instance_exec(&people_view)
        end
        StreamWeaverBench.instrument(app, metrics)
        [app.generate, metrics]
      end
    end
  end
end
