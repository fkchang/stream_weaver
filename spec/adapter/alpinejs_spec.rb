# frozen_string_literal: true

require 'stream_weaver/adapter/alpinejs'

RSpec.describe StreamWeaver::Adapter::AlpineJS do
  let(:adapter) { described_class.new }
  let(:mock_view) { double("view") }
  let(:state) { { email: "test@example.com", name: "Alice", agree: true, color: "Red" } }

  describe "#render_text_field" do
    it "renders input with x-model attribute" do
      expect(mock_view).to receive(:input).with(
        hash_including(
          type: "text",
          name: "email",
          "x-model" => "email"
        )
      )

      adapter.render_text_field(mock_view, :email, {}, state)
    end

    it "uses state value" do
      expect(mock_view).to receive(:input).with(
        hash_including(value: "test@example.com")
      )

      adapter.render_text_field(mock_view, :email, {}, state)
    end

    it "handles nil state value" do
      expect(mock_view).to receive(:input).with(
        hash_including(value: "")
      )

      adapter.render_text_field(mock_view, :missing, {}, state)
    end

    it "includes placeholder option" do
      expect(mock_view).to receive(:input).with(
        hash_including(placeholder: "Enter email")
      )

      adapter.render_text_field(mock_view, :email, { placeholder: "Enter email" }, state)
    end

    it "uses empty placeholder by default" do
      expect(mock_view).to receive(:input).with(
        hash_including(placeholder: "")
      )

      adapter.render_text_field(mock_view, :email, {}, state)
    end
  end

  describe "#render_text_area" do
    it "renders textarea with x-model attribute" do
      expect(mock_view).to receive(:textarea).with(
        hash_including(
          name: "bio",
          "x-model" => "bio"
        )
      ).and_yield

      adapter.render_text_area(mock_view, :bio, {}, state)
    end

    it "uses state value as content" do
      state[:bio] = "Software developer"

      expect(mock_view).to receive(:textarea).with(any_args) do |&block|
        result = block.call
        expect(result).to eq("Software developer")
      end

      adapter.render_text_area(mock_view, :bio, {}, state)
    end

    it "handles nil state value" do
      expect(mock_view).to receive(:textarea).with(any_args).and_yield

      adapter.render_text_area(mock_view, :missing, {}, state)
    end

    it "uses rows option" do
      expect(mock_view).to receive(:textarea).with(
        hash_including(rows: 5)
      ).and_yield

      adapter.render_text_area(mock_view, :bio, { rows: 5 }, state)
    end

    it "uses default rows of 3" do
      expect(mock_view).to receive(:textarea).with(
        hash_including(rows: 3)
      ).and_yield

      adapter.render_text_area(mock_view, :bio, {}, state)
    end
  end

  describe "#render_checkbox" do
    it "renders checkbox with x-model attribute" do
      expect(mock_view).to receive(:label).and_yield
      expect(mock_view).to receive(:input).with(
        hash_including(
          type: "checkbox",
          name: "agree",
          "x-model" => "agree"
        )
      )
      expect(mock_view).to receive(:plain).with(" I agree")

      adapter.render_checkbox(mock_view, :agree, "I agree", {}, state)
    end

    it "uses checked state from state hash" do
      expect(mock_view).to receive(:label).and_yield
      expect(mock_view).to receive(:input).with(
        hash_including(checked: true)
      )
      expect(mock_view).to receive(:plain)

      adapter.render_checkbox(mock_view, :agree, "I agree", {}, state)
    end

    it "handles unchecked state" do
      state[:agree] = false

      expect(mock_view).to receive(:label).and_yield
      expect(mock_view).to receive(:input).with(
        hash_including(checked: false)
      )
      expect(mock_view).to receive(:plain)

      adapter.render_checkbox(mock_view, :agree, "I agree", {}, state)
    end
  end

  describe "#render_select" do
    let(:choices) { ["Red", "Green", "Blue"] }

    it "renders select with x-model attribute" do
      expect(mock_view).to receive(:select).with(
        hash_including(
          name: "color",
          "x-model" => "color"
        )
      ).and_yield

      expect(mock_view).to receive(:option).exactly(3).times.and_yield

      adapter.render_select(mock_view, :color, choices, {}, state)
    end

    it "marks selected option from state" do
      expect(mock_view).to receive(:select).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Red", selected: true)
      ).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Green", selected: false)
      ).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Blue", selected: false)
      ).and_yield

      adapter.render_select(mock_view, :color, choices, {}, state)
    end

    it "handles no selection" do
      state.delete(:color)

      expect(mock_view).to receive(:select).and_yield
      expect(mock_view).to receive(:option).exactly(3).times.with(
        hash_including(selected: false)
      ).and_yield

      adapter.render_select(mock_view, :color, choices, {}, state)
    end
  end

  describe "#render_button" do
    it "renders button with HTMX attributes" do
      expect(mock_view).to receive(:button).with(
        hash_including(
          class: "btn btn-primary",
          "hx-post" => "/action/btn_submit_1",
          "hx-include" => "[x-model]",
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML"
        )
      ).and_yield

      adapter.render_button(mock_view, "btn_submit_1", "Submit", {})
    end

    it "uses primary style by default" do
      expect(mock_view).to receive(:button).with(
        hash_including(class: "btn btn-primary")
      ).and_yield

      adapter.render_button(mock_view, "btn_submit_1", "Submit", {})
    end

    it "uses secondary style when specified" do
      expect(mock_view).to receive(:button).with(
        hash_including(class: "btn btn-secondary")
      ).and_yield

      adapter.render_button(mock_view, "btn_submit_1", "Submit", { style: :secondary })
    end

    it "uses button_id in hx-post URL" do
      expect(mock_view).to receive(:button).with(
        hash_including("hx-post" => "/action/btn_custom_5")
      ).and_yield

      adapter.render_button(mock_view, "btn_custom_5", "Click", {})
    end

    it "uses input_selector for hx-include" do
      expect(mock_view).to receive(:button).with(
        hash_including("hx-include" => "[x-model]")
      ).and_yield

      adapter.render_button(mock_view, "btn_submit_1", "Submit", {})
    end
  end

  describe "#container_attributes" do
    it "returns x-data attribute with JSON state" do
      attrs = adapter.container_attributes({ name: "Alice", age: 30 })

      expect(attrs).to have_key("x-data")
      parsed = JSON.parse(attrs["x-data"])
      expect(parsed).to eq({ "name" => "Alice", "age" => 30 })
    end

    it "converts symbol keys to strings" do
      attrs = adapter.container_attributes({ email: "test@example.com" })

      parsed = JSON.parse(attrs["x-data"])
      expect(parsed).to have_key("email")
      expect(parsed).not_to have_key(:email)
    end

    it "handles empty state" do
      attrs = adapter.container_attributes({})

      expect(attrs["x-data"]).to eq("{}")
    end

    it "handles complex state" do
      complex_state = {
        user: "Alice",
        count: 5,
        active: true,
        items: ["a", "b", "c"]
      }

      attrs = adapter.container_attributes(complex_state)
      parsed = JSON.parse(attrs["x-data"])

      expect(parsed["user"]).to eq("Alice")
      expect(parsed["count"]).to eq(5)
      expect(parsed["active"]).to eq(true)
      expect(parsed["items"]).to eq(["a", "b", "c"])
    end
  end

  describe "#cdn_scripts" do
    it "returns array of script tags" do
      scripts = adapter.cdn_scripts

      expect(scripts).to be_an(Array)
      expect(scripts.length).to eq(2)
    end

    it "includes HTMX script" do
      scripts = adapter.cdn_scripts

      htmx_script = scripts.find { |s| s.include?("htmx") }
      expect(htmx_script).not_to be_nil
      expect(htmx_script).to include("https://unpkg.com/htmx.org@2.0.4")
    end

    it "includes Alpine.js script" do
      scripts = adapter.cdn_scripts

      alpine_script = scripts.find { |s| s.include?("alpinejs") }
      expect(alpine_script).not_to be_nil
      expect(alpine_script).to include("https://unpkg.com/alpinejs@3.x.x")
      expect(alpine_script).to include("defer")
    end

    it "returns complete HTML script tags" do
      scripts = adapter.cdn_scripts

      scripts.each do |script|
        expect(script).to start_with("<script")
        expect(script).to end_with("</script>")
      end
    end
  end

  describe "#input_selector" do
    it "returns Alpine.js x-model selector" do
      expect(adapter.input_selector).to eq("[x-model]")
    end
  end
end
