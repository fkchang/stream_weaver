# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamWeaver::Components::StatusBadge do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:mock_view) { double('view', adapter: adapter) }
  let(:state) { {} }

  describe "initialization" do
    it "stores status and reasoning" do
      badge = described_class.new(:strong, "Great match for your preferences")
      expect(badge.instance_variable_get(:@status)).to eq(:strong)
      expect(badge.instance_variable_get(:@reasoning)).to eq("Great match for your preferences")
    end

    it "accepts valid statuses: :strong, :maybe, :skip" do
      [:strong, :maybe, :skip].each do |status|
        badge = described_class.new(status, "reason")
        expect(badge.instance_variable_get(:@status)).to eq(status)
      end
    end
  end

  describe "rendering" do
    it "delegates to adapter render_status_badge" do
      badge = described_class.new(:strong, "Perfect tone match")
      expect(adapter).to receive(:render_status_badge).with(mock_view, :strong, "Perfect tone match", state)
      badge.render(mock_view, state)
    end
  end
end
