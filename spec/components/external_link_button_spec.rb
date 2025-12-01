# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamWeaver::Components::ExternalLinkButton do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:mock_view) { double('view', adapter: adapter) }
  let(:state) { {} }

  describe "initialization" do
    it "stores label and url" do
      btn = described_class.new("Get it on Amazon", url: "https://amazon.com/dp/B0XXX")
      expect(btn.instance_variable_get(:@label)).to eq("Get it on Amazon")
      expect(btn.instance_variable_get(:@url)).to eq("https://amazon.com/dp/B0XXX")
    end

    it "stores submit option" do
      btn = described_class.new("Get it", url: "https://example.com", submit: true)
      expect(btn.instance_variable_get(:@submit)).to eq(true)
    end

    it "defaults submit to false" do
      btn = described_class.new("Get it", url: "https://example.com")
      expect(btn.instance_variable_get(:@submit)).to eq(false)
    end
  end

  describe "rendering" do
    it "delegates to adapter render_external_link_button" do
      btn = described_class.new("Open", url: "https://example.com", submit: true)
      expect(adapter).to receive(:render_external_link_button).with(
        mock_view,
        "Open",
        "https://example.com",
        true,
        state
      )
      btn.render(mock_view, state)
    end
  end
end
