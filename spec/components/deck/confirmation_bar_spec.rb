# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Deck::ConfirmationBar do
  describe "#initialize" do
    it "initializes with message" do
      bar = described_class.new(message: "Are you sure?")
      expect(bar.message).to eq("Are you sure?")
    end

    it "has default labels" do
      bar = described_class.new(message: "Test")
      expect(bar.confirm_label).to eq("Cancel")
      expect(bar.cancel_label).to eq("Keep Going")
    end

    it "accepts custom labels" do
      bar = described_class.new(
        message: "Abandon changes?",
        confirm_label: "Yes, Abandon",
        cancel_label: "No, Stay"
      )
      expect(bar.confirm_label).to eq("Yes, Abandon")
      expect(bar.cancel_label).to eq("No, Stay")
    end

    it "has default auto_hide of 5 seconds" do
      bar = described_class.new(message: "Test")
      expect(bar.auto_hide).to eq(5)
    end

    it "accepts custom auto_hide" do
      bar = described_class.new(message: "Test", auto_hide: 10)
      expect(bar.auto_hide).to eq(10)
    end

    it "accepts nil auto_hide to disable" do
      bar = described_class.new(message: "Test", auto_hide: nil)
      expect(bar.auto_hide).to be_nil
    end
  end

  describe "#auto_hide?" do
    it "returns true when auto_hide is set" do
      bar = described_class.new(message: "Test", auto_hide: 5)
      expect(bar.auto_hide?).to be true
    end

    it "returns false when auto_hide is nil" do
      bar = described_class.new(message: "Test", auto_hide: nil)
      expect(bar.auto_hide?).to be false
    end

    it "returns false when auto_hide is 0" do
      bar = described_class.new(message: "Test", auto_hide: 0)
      expect(bar.auto_hide?).to be false
    end
  end

  describe "#css_classes" do
    it "uses sw- prefix" do
      bar = described_class.new(message: "Test")
      expect(bar.css_classes).to eq("sw-confirmation-bar")
      expect(bar.css_classes).to start_with("sw-")
    end
  end
end
