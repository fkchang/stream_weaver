# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe StreamWeaver::Components::Deck::ModelSelector do
  let(:models) do
    [
      { id: "claude-3", name: "Claude 3 Opus", provider: "Anthropic" },
      { id: "claude-sonnet", name: "Claude 3.5 Sonnet", provider: "Anthropic" },
      { id: "gpt-4", name: "GPT-4", provider: "OpenAI" },
      { id: "gpt-4o", name: "GPT-4o", provider: "OpenAI" },
      { id: "gemini-pro", name: "Gemini Pro", provider: "Google" }
    ]
  end

  describe "#initialize" do
    it "normalizes model hashes" do
      selector = described_class.new(models: models, default_model: "claude-3")
      expect(selector.models.length).to eq(5)
      expect(selector.models.first[:id]).to eq("claude-3")
      expect(selector.models.first[:name]).to eq("Claude 3 Opus")
      expect(selector.models.first[:provider]).to eq("Anthropic")
    end

    it "accepts string-keyed model hashes" do
      str_models = [{ "id" => "gpt-4", "name" => "GPT-4", "provider" => "OpenAI" }]
      selector = described_class.new(models: str_models)
      expect(selector.models.first[:id]).to eq("gpt-4")
    end

    it "defaults to first model when no default_model given" do
      selector = described_class.new(models: models)
      expect(selector.default_model).to eq("claude-3")
    end

    it "uses provided default_model" do
      selector = described_class.new(models: models, default_model: "gpt-4")
      expect(selector.default_model).to eq("gpt-4")
    end

    it "handles empty models list" do
      selector = described_class.new(models: [])
      expect(selector.models).to eq([])
      expect(selector.default_model).to be_nil
    end
  end

  describe "#providers" do
    it "returns unique sorted provider names" do
      selector = described_class.new(models: models)
      expect(selector.providers).to eq(["Anthropic", "Google", "OpenAI"])
    end

    it "returns empty for no models" do
      selector = described_class.new(models: [])
      expect(selector.providers).to eq([])
    end
  end

  describe "#models_for_provider" do
    let(:selector) { described_class.new(models: models) }

    it "returns all models for nil provider" do
      expect(selector.models_for_provider(nil).length).to eq(5)
    end

    it "returns all models for 'All' provider" do
      expect(selector.models_for_provider("All").length).to eq(5)
    end

    it "filters by Anthropic" do
      filtered = selector.models_for_provider("Anthropic")
      expect(filtered.length).to eq(2)
      expect(filtered.map { |m| m[:id] }).to contain_exactly("claude-3", "claude-sonnet")
    end

    it "filters by OpenAI" do
      filtered = selector.models_for_provider("OpenAI")
      expect(filtered.length).to eq(2)
    end

    it "filters by Google" do
      filtered = selector.models_for_provider("Google")
      expect(filtered.length).to eq(1)
      expect(filtered.first[:id]).to eq("gemini-pro")
    end

    it "returns empty for unknown provider" do
      expect(selector.models_for_provider("Unknown")).to eq([])
    end
  end

  describe "#visible?" do
    it "returns true when 2+ models" do
      selector = described_class.new(models: models)
      expect(selector.visible?).to be true
    end

    it "returns false when fewer than 2 models" do
      selector = described_class.new(models: [{ id: "one", name: "One", provider: "P" }])
      expect(selector.visible?).to be false
    end

    it "returns false when no models" do
      selector = described_class.new(models: [])
      expect(selector.visible?).to be false
    end
  end

  describe "#css_classes" do
    it "uses sw- prefix" do
      selector = described_class.new(models: models)
      expect(selector.css_classes).to eq("sw-model-selector")
      expect(selector.css_classes).to start_with("sw-")
    end
  end

  # =========================================
  # DeckState model persistence
  # =========================================

  describe "DeckState model persistence" do
    let(:tmpdir) { Dir.mktmpdir("model_selector_test") }
    let(:session_id) { "model-test-#{rand(10000)}" }
    let(:deck_state) { StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir) }

    after { FileUtils.rm_rf(tmpdir) }

    it "stores selected model" do
      deck_state.set_model("claude-3")
      expect(deck_state.selected_model).to eq("claude-3")
    end

    it "overwrites previous model selection" do
      deck_state.set_model("claude-3")
      deck_state.set_model("gpt-4")
      expect(deck_state.selected_model).to eq("gpt-4")
    end

    it "returns nil when no model selected" do
      expect(deck_state.selected_model).to be_nil
    end

    it "persists model across instances" do
      deck_state.set_model("gemini-pro")
      state2 = StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir)
      expect(state2.selected_model).to eq("gemini-pro")
    end
  end
end
