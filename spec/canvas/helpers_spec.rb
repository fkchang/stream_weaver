# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/protocol'
require 'stream_weaver/canvas/session'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/helpers'

RSpec.describe StreamWeaver::Canvas::Helpers do
  describe '.pick_dsl' do
    it 'generates DSL for a single-choice picker' do
      dsl = described_class.pick_dsl("Pick a color", ["Red", "Green", "Blue"])

      expect(dsl).to include("header1")
      expect(dsl).to include("Pick a color")
      expect(dsl).to include("radio_group")
      expect(dsl).to include("Red")
      expect(dsl).to include("Green")
      expect(dsl).to include("Blue")
      expect(dsl).to include("button")
    end
  end

  describe '.confirm_dsl' do
    it 'generates DSL for a confirmation dialog' do
      dsl = described_class.confirm_dsl("Delete all files?")

      expect(dsl).to include("header1")
      expect(dsl).to include("Delete all files?")
      expect(dsl).to include("button")
      expect(dsl).to include("Confirm")
      expect(dsl).to include("Cancel")
    end

    it 'uses custom button labels' do
      dsl = described_class.confirm_dsl("Proceed?", yes_label: "Yes", no_label: "No")

      expect(dsl).to include("Yes")
      expect(dsl).to include("No")
    end
  end

  describe '.form_dsl' do
    it 'generates DSL for a form with fields' do
      dsl = described_class.form_dsl("Quick Survey", {
        name: { type: :text, placeholder: "Your name" },
        priority: { type: :radio, choices: ["Low", "Medium", "High"] }
      })

      expect(dsl).to include("header1")
      expect(dsl).to include("Quick Survey")
      expect(dsl).to include("text_field :name")
      expect(dsl).to include("Your name")
      expect(dsl).to include("radio_group :priority")
      expect(dsl).to include("Low")
      expect(dsl).to include("button")
    end
  end

  describe '.parse_pick_result' do
    it 'extracts choice from event data' do
      event_data = { choice: "Green", _button: "btn_submit" }
      result = described_class.parse_pick_result(event_data)

      expect(result).to eq("Green")
    end
  end

  describe '.parse_confirm_result' do
    it 'returns true for confirm button' do
      event_data = { _button: "btn_confirm" }
      result = described_class.parse_confirm_result(event_data)

      expect(result).to be true
    end

    it 'returns false for cancel button' do
      event_data = { _button: "btn_cancel" }
      result = described_class.parse_confirm_result(event_data)

      expect(result).to be false
    end
  end

  describe '.parse_form_result' do
    it 'returns form field values' do
      event_data = { name: "Alice", priority: "High", _button: "btn_submit" }
      result = described_class.parse_form_result(event_data, [:name, :priority])

      expect(result).to eq({ name: "Alice", priority: "High" })
    end

    it 'excludes internal fields' do
      event_data = { name: "Alice", _button: "btn_submit" }
      result = described_class.parse_form_result(event_data, [:name])

      expect(result).not_to have_key(:_button)
    end
  end
end
