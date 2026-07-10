# frozen_string_literal: true

require "sinatra/base"
require "phlex"
require_relative "../support"

module StreamWeaverBench
  module Baselines
    class LedgerRows < Phlex::HTML
      def initialize(people) = @people = people
      def view_template
        tbody(id: "people-rows") do
          @people.each do |person|
            tr(id: "person-#{person[:id]}") do
              td { plain person[:name] }; td { plain person[:email] }; td { plain person[:touched] }
              td { button { plain "Edit" }; button { plain "Delete" } }
            end
          end
        end
      end
    end

    class LedgerRow < Phlex::HTML
      def initialize(person) = @person = person
      def view_template
        tr(id: "person-#{@person[:id]}") do
          td { plain @person[:name] }; td { plain @person[:email] }; td { plain @person[:touched] }
          td { button { plain "Edit" }; button { plain "Delete" } }
        end
      end
    end

    class LedgerToolbar < Phlex::HTML
      def initialize(error) = @error = error
      def view_template = div(id: "toolbar") { button { plain "Create" }; button { plain "Invalid" }; span { plain @error } }
    end

    module Ledger
      module_function

      def build
        metrics = Metrics.new
        people = StreamWeaverBench.deep_copy(PEOPLE)
        error = ""
        app = Class.new(Sinatra::Base)
        app.set :environment, :test
        app.set :show_exceptions, false
        app.get("/") { LedgerToolbar.new(error).call + "<table>#{LedgerRows.new(people).call}</table>" }
        app.post("/create") { metrics.callback!; people << { id: 51, name: "New Person", email: "new@example.test", touched: "2026-07-01" }; LedgerRow.new(people.last).call }
        app.post("/edit") { metrics.callback!; people.first[:name] = "Edited Person"; LedgerRow.new(people.first).call }
        app.post("/invalid") { metrics.callback!; error = "Name is required"; LedgerToolbar.new(error).call }
        app.post("/filter") { metrics.callback!; LedgerRows.new(people.select { |p| p[:name].downcase.include?(params[:query].to_s.downcase) }).call }
        app.post("/delete") { metrics.callback!; people.shift; "" }
        [app, metrics]
      end
    end
  end
end
