# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamWeaver::Components::TagButtons do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:mock_view) { double('view', adapter: adapter) }
  let(:state) { {} }

  describe "initialization" do
    it "stores key and tags" do
      tags = described_class.new(:eliminate_reason, ["Too dark", "Wrong genre", "Not interested"])
      expect(tags.key).to eq(:eliminate_reason)
      expect(tags.instance_variable_get(:@tags)).to eq(["Too dark", "Wrong genre", "Not interested"])
    end

    it "stores style option" do
      tags = described_class.new(:reason, ["A", "B"], style: :destructive)
      expect(tags.instance_variable_get(:@options)[:style]).to eq(:destructive)
    end
  end

  describe "rendering" do
    it "delegates to adapter render_tag_buttons" do
      tags = described_class.new(:reason, ["A", "B"], style: :default)
      expect(adapter).to receive(:render_tag_buttons).with(
        mock_view,
        :reason,
        ["A", "B"],
        hash_including(style: :default),
        state
      )
      tags.render(mock_view, state)
    end
  end
end
