# frozen_string_literal: true

require "sinatra/base"
require "phlex"
require_relative "../support"

module StreamWeaverBench
  module Baselines
    class StoryDetail < Phlex::HTML
      def initialize(story) = @story = story
      def view_template
        section(id: "story-detail") do
          h2 { plain @story[:title] }
          @story[:notes].each { |note| p { plain note } }
          button { plain "Append note" }; button { plain "Move story" }
        end
      end
    end

    class BoardColumn < Phlex::HTML
      def initialize(stories, column) = (@stories, @column = stories, column)
      def view_template
        section(id: "column-#{@column.downcase}") do
          h2 { plain @column }
          @stories.select { |story| story[:column] == @column }.each { |story| article { plain "#{story[:id]} — #{story[:title]}" } }
        end
      end
    end

    module Warroom
      module_function

      def build
        metrics = Metrics.new
        stories = StreamWeaverBench.deep_copy(STORIES)
        app = Class.new(Sinatra::Base)
        app.set :environment, :test
        app.set :show_exceptions, false
        app.get("/") do
          %w[Ready Active Done].map { |column| BoardColumn.new(stories, column).call }.join + StoryDetail.new(stories.first).call
        end
        app.post("/note") { metrics.callback!; stories.first[:notes] << "Appended note"; StoryDetail.new(stories.first).call }
        app.post("/move") do
          metrics.callback!; stories.first[:column] = "Active"
          BoardColumn.new(stories, "Ready").call + BoardColumn.new(stories, "Active").call
        end
        [app, metrics]
      end
    end
  end
end
