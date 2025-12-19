# frozen_string_literal: true

RSpec.describe StreamWeaver do
  it "has a version number" do
    expect(StreamWeaver::VERSION).not_to be nil
  end

  it "provides app helper method" do
    expect(defined?(app)).to eq("method")
  end

  it "creates an App instance with app helper" do
    # The app helper returns a Sinatra app, but stores the StreamWeaver::App in settings
    sinatra_app = app("Test") { text_field :name }
    expect(sinatra_app).to be < Sinatra::Base
    expect(sinatra_app.settings.streamlit_app).to be_a(StreamWeaver::App)
    expect(sinatra_app.settings.streamlit_app.title).to eq("Test")
  end

  it "passes layout option through app helper" do
    sinatra_app = app("Test", layout: :wide) { text "content" }
    expect(sinatra_app.settings.streamlit_app.layout).to eq(:wide)
  end

  it "loads all component classes" do
    expect(defined?(StreamWeaver::Components::TextField)).to eq("constant")
    expect(defined?(StreamWeaver::Components::Button)).to eq("constant")
    expect(defined?(StreamWeaver::Components::Text)).to eq("constant")
    expect(defined?(StreamWeaver::Components::Div)).to eq("constant")
    expect(defined?(StreamWeaver::Components::Checkbox)).to eq("constant")
    expect(defined?(StreamWeaver::Components::Select)).to eq("constant")
    expect(defined?(StreamWeaver::Components::TextArea)).to eq("constant")
  end

  it "loads server classes" do
    expect(defined?(StreamWeaver::SinatraApp)).to eq("constant")
  end
end
