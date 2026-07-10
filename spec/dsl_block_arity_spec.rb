# frozen_string_literal: true

require 'rack/test'

# FAC-P0.3: the app DSL block and container/component blocks are instance_eval'd
# against the App, so calling a method on the enclosing (presenter) object from
# inside the block breaks -- `self` inside is the App, not the presenter. These
# specs cover the ergonomic fix: arity>=1 blocks are plain `block.call(app)`
# instead, so the block keeps its own self/binding and can call presenter
# methods, while still reaching the App via the yielded argument. Arity-0
# blocks are untouched (today's instance_eval behavior, for backward compat).
RSpec.describe "StreamWeaver DSL block arity dispatch (FAC-P0.3)" do
  # Presenter with a private helper method, in the shape real apps reach for:
  # capturing `method(:event_line)` today as a workaround.
  class ArityFixturePresenter
    def initialize(name)
      @name = name
    end

    def build_app
      StreamWeaver::App.new("Test") do |ui|
        ui.text greeting
        ui.card do |card_ui|
          card_ui.text greeting
        end
      end
    end

    private

    def greeting
      "Hello, #{@name}!"
    end
  end

  describe "App#initialize block (and rebuild_with_state)" do
    it "keeps instance_eval self=app for arity-0 blocks (backward compat)" do
      app = StreamWeaver::App.new("Test") { text_field :name }
      app.rebuild_with_state({})
      expect(app.components.first).to be_a(StreamWeaver::Components::TextField)
    end

    it "calls arity>=1 blocks with the app as the argument, self unchanged" do
      outer_self = self
      captured_self = nil
      captured_arg = nil

      app = StreamWeaver::App.new("Test") do |ui|
        captured_self = self
        captured_arg = ui
      end
      app.rebuild_with_state({})

      expect(captured_self).to equal(outer_self)
      expect(captured_arg).to equal(app)
    end

    it "lets an arity>=1 block call the app AND a private method on its own enclosing object" do
      presenter = ArityFixturePresenter.new("Alice")
      app = presenter.build_app
      app.rebuild_with_state({})

      texts = app.components.select { |c| c.is_a?(StreamWeaver::Components::Text) }
      expect(texts.first.instance_variable_get(:@content)).to eq("Hello, Alice!")
    end

    it "re-evaluates the arity>=1 app block correctly across rebuild_with_state" do
      presenter = ArityFixturePresenter.new("Bob")
      app = presenter.build_app
      app.rebuild_with_state({})
      app.rebuild_with_state({})

      texts = app.components.select { |c| c.is_a?(StreamWeaver::Components::Text) }
      expect(texts.first.instance_variable_get(:@content)).to eq("Hello, Bob!")
    end
  end

  describe "container/component blocks (consistent with the app-level block)" do
    it "gives div/card blocks the app instance for arity>=1, preserving caller self" do
      presenter = ArityFixturePresenter.new("Carol")
      app = presenter.build_app
      app.rebuild_with_state({})

      card = app.components.find { |c| c.is_a?(StreamWeaver::Components::Card) }
      nested_text = card.children.find { |c| c.is_a?(StreamWeaver::Components::Text) }
      expect(nested_text.instance_variable_get(:@content)).to eq("Hello, Carol!")
    end

    it "keeps arity-0 container blocks on instance_eval self=app (backward compat)" do
      app = StreamWeaver::App.new("Test") do
        card do
          text "plain arity-0 block"
        end
      end
      app.rebuild_with_state({})

      card = app.components.first
      expect(card.children.first.instance_variable_get(:@content)).to eq("plain arity-0 block")
    end
  end

  describe "end-to-end: presenter-driven app renders correctly (adapts the server_spec.rb 'Test App' pattern)" do
    include Rack::Test::Methods

    let(:app) { described_app.generate }
    let(:described_app) { ArityFixturePresenter.new("Dana").build_app }

    it "renders text produced via a private presenter method reached through the DSL block arg" do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include("Hello, Dana!")
    end
  end
end
