# frozen_string_literal: true

require 'stream_weaver/adapter/base'

RSpec.describe StreamWeaver::Adapter::Base do
  let(:adapter) { described_class.new }
  let(:mock_view) { double("view") }
  let(:state) { { name: "Alice", email: "alice@example.com" } }

  describe "#render_text_field" do
    it "raises NotImplementedError" do
      expect {
        adapter.render_text_field(mock_view, :name, {}, state)
      }.to raise_error(NotImplementedError, /must implement #render_text_field/)
    end
  end

  describe "#render_text_area" do
    it "raises NotImplementedError" do
      expect {
        adapter.render_text_area(mock_view, :bio, {}, state)
      }.to raise_error(NotImplementedError, /must implement #render_text_area/)
    end
  end

  describe "#render_checkbox" do
    it "raises NotImplementedError" do
      expect {
        adapter.render_checkbox(mock_view, :agree, "I agree", {}, state)
      }.to raise_error(NotImplementedError, /must implement #render_checkbox/)
    end
  end

  describe "#render_select" do
    it "raises NotImplementedError" do
      expect {
        adapter.render_select(mock_view, :color, ["Red", "Blue"], {}, state)
      }.to raise_error(NotImplementedError, /must implement #render_select/)
    end
  end

  describe "#render_button" do
    it "raises NotImplementedError" do
      expect {
        adapter.render_button(mock_view, "btn_submit_1", "Submit", {})
      }.to raise_error(NotImplementedError, /must implement #render_button/)
    end
  end

  describe "#container_attributes" do
    it "raises NotImplementedError" do
      expect {
        adapter.container_attributes(state)
      }.to raise_error(NotImplementedError, /must implement #container_attributes/)
    end
  end

  describe "#cdn_scripts" do
    it "raises NotImplementedError" do
      expect {
        adapter.cdn_scripts
      }.to raise_error(NotImplementedError, /must implement #cdn_scripts/)
    end
  end

  describe "#input_selector" do
    it "raises NotImplementedError" do
      expect {
        adapter.input_selector
      }.to raise_error(NotImplementedError, /must implement #input_selector/)
    end
  end
end
