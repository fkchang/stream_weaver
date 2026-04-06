# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Deck::CloseOverlay do
  describe "#initialize" do
    it "initializes with submitted status" do
      overlay = described_class.new(status: :submitted, message: "Done!")
      expect(overlay.status).to eq(:submitted)
      expect(overlay.message).to eq("Done!")
    end

    it "initializes with cancelled status" do
      overlay = described_class.new(status: :cancelled, message: "Cancelled.")
      expect(overlay.status).to eq(:cancelled)
      expect(overlay.message).to eq("Cancelled.")
    end

    it "raises on invalid status" do
      expect {
        described_class.new(status: :unknown, message: "Bad")
      }.to raise_error(ArgumentError, /Invalid status/)
    end

    it "accepts string status" do
      overlay = described_class.new(status: "submitted", message: "OK")
      expect(overlay.status).to eq(:submitted)
    end

    it "has default auto_close_delay of 800ms" do
      overlay = described_class.new(status: :submitted, message: "Done")
      expect(overlay.auto_close_delay).to eq(800)
    end

    it "accepts custom auto_close_delay" do
      overlay = described_class.new(status: :submitted, message: "Done", auto_close_delay: 2000)
      expect(overlay.auto_close_delay).to eq(2000)
    end
  end

  describe "#submitted?" do
    it "returns true for submitted status" do
      overlay = described_class.new(status: :submitted, message: "Done")
      expect(overlay.submitted?).to be true
      expect(overlay.cancelled?).to be false
    end
  end

  describe "#cancelled?" do
    it "returns true for cancelled status" do
      overlay = described_class.new(status: :cancelled, message: "Cancelled")
      expect(overlay.cancelled?).to be true
      expect(overlay.submitted?).to be false
    end
  end

  describe "#status_modifier" do
    it "returns submitted modifier" do
      overlay = described_class.new(status: :submitted, message: "Done")
      expect(overlay.status_modifier).to eq("sw-close-overlay--submitted")
    end

    it "returns cancelled modifier" do
      overlay = described_class.new(status: :cancelled, message: "Cancelled")
      expect(overlay.status_modifier).to eq("sw-close-overlay--cancelled")
    end
  end

  describe "#icon" do
    it "returns checkmark for submitted" do
      overlay = described_class.new(status: :submitted, message: "Done")
      expect(overlay.icon).to eq("\u2713") # checkmark
    end

    it "returns X for cancelled" do
      overlay = described_class.new(status: :cancelled, message: "Cancelled")
      expect(overlay.icon).to eq("\u2715") # X mark
    end
  end

  describe "#css_classes" do
    it "uses sw- prefix" do
      overlay = described_class.new(status: :submitted, message: "Done")
      expect(overlay.css_classes).to start_with("sw-")
    end

    it "includes status modifier for submitted" do
      overlay = described_class.new(status: :submitted, message: "Done")
      expect(overlay.css_classes).to include("sw-close-overlay")
      expect(overlay.css_classes).to include("sw-close-overlay--submitted")
    end

    it "includes status modifier for cancelled" do
      overlay = described_class.new(status: :cancelled, message: "Done")
      expect(overlay.css_classes).to include("sw-close-overlay--cancelled")
    end
  end
end
