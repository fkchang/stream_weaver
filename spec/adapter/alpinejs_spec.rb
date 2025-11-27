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

    it "uses default option when state is nil" do
      state.delete(:color)

      expect(mock_view).to receive(:select).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Red", selected: false)
      ).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Green", selected: true)
      ).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Blue", selected: false)
      ).and_yield

      adapter.render_select(mock_view, :color, choices, { default: "Green" }, state)
    end

    it "prefers state value over default" do
      state[:color] = "Blue"

      expect(mock_view).to receive(:select).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Red", selected: false)
      ).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Green", selected: false)
      ).and_yield
      expect(mock_view).to receive(:option).with(
        hash_including(value: "Blue", selected: true)
      ).and_yield

      adapter.render_select(mock_view, :color, choices, { default: "Green" }, state)
    end
  end

  describe "#render_radio_group" do
    let(:choices) { ["Option A", "Option B", "Option C"] }

    it "renders div with radio-group class" do
      expect(mock_view).to receive(:div).with(class: "radio-group").and_yield
      expect(mock_view).to receive(:label).exactly(3).times.and_yield
      expect(mock_view).to receive(:input).exactly(3).times
      expect(mock_view).to receive(:span).exactly(3).times.and_yield

      adapter.render_radio_group(mock_view, :answer, choices, {}, state)
    end

    it "renders radio inputs with x-model attribute" do
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:label).exactly(3).times.and_yield
      expect(mock_view).to receive(:input).with(
        hash_including(
          type: "radio",
          name: "answer",
          "x-model" => "answer"
        )
      ).exactly(3).times
      expect(mock_view).to receive(:span).exactly(3).times.and_yield

      adapter.render_radio_group(mock_view, :answer, choices, {}, state)
    end

    it "marks checked option from state" do
      state[:answer] = "Option B"

      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:label).exactly(3).times.and_yield
      expect(mock_view).to receive(:input).with(
        hash_including(value: "Option A", checked: false)
      )
      expect(mock_view).to receive(:input).with(
        hash_including(value: "Option B", checked: true)
      )
      expect(mock_view).to receive(:input).with(
        hash_including(value: "Option C", checked: false)
      )
      expect(mock_view).to receive(:span).exactly(3).times.and_yield

      adapter.render_radio_group(mock_view, :answer, choices, {}, state)
    end

    it "handles no selection (nil state)" do
      state.delete(:answer)

      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:label).exactly(3).times.and_yield
      expect(mock_view).to receive(:input).exactly(3).times.with(
        hash_including(checked: false)
      )
      expect(mock_view).to receive(:span).exactly(3).times.and_yield

      adapter.render_radio_group(mock_view, :answer, choices, {}, state)
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

  describe "#render_term" do
    it "renders span with term class" do
      expect(mock_view).to receive(:span).with(
        hash_including(class: "term")
      ).and_yield

      adapter.render_term(mock_view, "bullish", {}, state)
    end

    it "includes data-term attribute with normalized key" do
      expect(mock_view).to receive(:span).with(
        hash_including("data-term" => "bullish")
      ).and_yield

      adapter.render_term(mock_view, "bullish", {}, state)
    end

    it "normalizes term key with spaces" do
      expect(mock_view).to receive(:span).with(
        hash_including("data-term" => "quad_4")
      ).and_yield

      adapter.render_term(mock_view, "Quad 4", {}, state)
    end

    it "includes Alpine.js event handlers" do
      expect(mock_view).to receive(:span).with(
        hash_including(
          "@mouseenter" => "showTooltip('bullish', $el)",
          "@mouseleave" => "hideTooltip()",
          "@focus" => "showTooltip('bullish', $el)",
          "@blur" => "hideTooltip()"
        )
      ).and_yield

      adapter.render_term(mock_view, "bullish", {}, state)
    end

    it "includes tabindex for keyboard accessibility" do
      expect(mock_view).to receive(:span).with(
        hash_including("tabindex" => "0")
      ).and_yield

      adapter.render_term(mock_view, "bullish", {}, state)
    end

    it "uses term_key as display text by default" do
      result = nil
      expect(mock_view).to receive(:span).with(any_args) do |&block|
        result = block.call
      end

      adapter.render_term(mock_view, "bullish", {}, state)
      expect(result).to eq("bullish")
    end

    it "uses display option as display text when provided" do
      result = nil
      expect(mock_view).to receive(:span).with(any_args) do |&block|
        result = block.call
      end

      adapter.render_term(mock_view, "bullish", { display: "Bull Market" }, state)
      expect(result).to eq("Bull Market")
    end
  end

  describe "#render_header" do
    it "renders h1 for level 1" do
      expect(mock_view).to receive(:h1).and_yield
      adapter.render_header(mock_view, "Title", 1, state)
    end

    it "renders h2 for level 2" do
      expect(mock_view).to receive(:h2).and_yield
      adapter.render_header(mock_view, "Section", 2, state)
    end

    it "renders h3 for level 3" do
      expect(mock_view).to receive(:h3).and_yield
      adapter.render_header(mock_view, "Subsection", 3, state)
    end

    it "renders h4 for level 4" do
      expect(mock_view).to receive(:h4).and_yield
      adapter.render_header(mock_view, "Minor", 4, state)
    end

    it "renders h5 for level 5" do
      expect(mock_view).to receive(:h5).and_yield
      adapter.render_header(mock_view, "Small", 5, state)
    end

    it "renders h6 for level 6" do
      expect(mock_view).to receive(:h6).and_yield
      adapter.render_header(mock_view, "Smallest", 6, state)
    end

    it "defaults to h2 for unknown level" do
      expect(mock_view).to receive(:h2).and_yield
      adapter.render_header(mock_view, "Unknown", 99, state)
    end
  end

  describe "#render_markdown" do
    it "renders div with markdown-content class" do
      expect(mock_view).to receive(:div).with(class: "markdown-content").and_yield
      expect(mock_view).to receive(:safe).and_return(:safe_html)
      expect(mock_view).to receive(:raw).with(:safe_html)
      adapter.render_markdown(mock_view, "plain text", state)
    end

    it "parses bold text" do
      html_output = nil
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
      expect(mock_view).to receive(:raw).with(:safe_html)

      adapter.render_markdown(mock_view, "**bold** text", state)

      expect(html_output).to include("<strong>bold</strong>")
    end

    it "parses italic text" do
      html_output = nil
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
      expect(mock_view).to receive(:raw).with(:safe_html)

      adapter.render_markdown(mock_view, "*italic* text", state)

      expect(html_output).to include("<em>italic</em>")
    end

    it "parses inline code" do
      html_output = nil
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
      expect(mock_view).to receive(:raw).with(:safe_html)

      adapter.render_markdown(mock_view, "`code` snippet", state)

      expect(html_output).to include("<code>code</code>")
    end

    it "parses links" do
      html_output = nil
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
      expect(mock_view).to receive(:raw).with(:safe_html)

      adapter.render_markdown(mock_view, "[click here](https://example.com)", state)

      expect(html_output).to include('<a href="https://example.com">click here</a>')
    end

    it "parses markdown headers" do
      html_output = nil
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
      expect(mock_view).to receive(:raw).with(:safe_html)

      adapter.render_markdown(mock_view, "## Section Title", state)

      expect(html_output).to include("<h2")
      expect(html_output).to include("Section Title</h2>")
    end

    it "parses all header levels" do
      (1..6).each do |level|
        html_output = nil
        expect(mock_view).to receive(:div).and_yield
        expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
        expect(mock_view).to receive(:raw).with(:safe_html)

        adapter.render_markdown(mock_view, "#{'#' * level} Level #{level}", state)

        expect(html_output).to include("<h#{level}")
        expect(html_output).to include("Level #{level}</h#{level}>")
      end
    end

    it "renders raw HTML in markdown (user responsibility to sanitize)" do
      # Note: Kramdown passes through raw HTML by default
      # Users should sanitize untrusted input before passing to md component
      html_output = nil
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
      expect(mock_view).to receive(:raw).with(:safe_html)

      adapter.render_markdown(mock_view, "<em>emphasis</em>", state)

      expect(html_output).to include("<em>emphasis</em>")
    end

    it "handles combined formatting" do
      html_output = nil
      expect(mock_view).to receive(:div).and_yield
      expect(mock_view).to receive(:safe) { |html| html_output = html; :safe_html }
      expect(mock_view).to receive(:raw).with(:safe_html)

      adapter.render_markdown(mock_view, "**bold** and *italic* with `code`", state)

      expect(html_output).to include("<strong>bold</strong>")
      expect(html_output).to include("<em>italic</em>")
      expect(html_output).to include("<code>code</code>")
    end
  end

  describe "#render_lesson_text" do
    let(:glossary) do
      {
        "bullish" => { simple: "Expecting UP", detailed: "A bullish outlook means expecting prices to increase." },
        "Quad 4" => { simple: "Deflation", detailed: "Quad 4 occurs when growth and inflation are both falling." }
      }
    end

    it "renders div with lesson-text class" do
      expect(mock_view).to receive(:div).with(
        hash_including(class: "lesson-text")
      ).and_yield
      allow(mock_view).to receive(:div)
      allow(mock_view).to receive(:span)
      allow(mock_view).to receive(:plain)

      adapter.render_lesson_text(mock_view, glossary, [], {}, state)
    end

    it "includes x-data with Alpine.js state" do
      expect(mock_view).to receive(:div).with(
        hash_including("x-data" => a_string_matching(/activeTooltip: null/))
      ).and_yield
      allow(mock_view).to receive(:div)
      allow(mock_view).to receive(:span)
      allow(mock_view).to receive(:plain)

      adapter.render_lesson_text(mock_view, glossary, [], {}, state)
    end

    it "includes glossary in x-data" do
      expect(mock_view).to receive(:div).with(
        hash_including("x-data" => a_string_matching(/"bullish":\{.*"simple":"Expecting UP"/))
      ).and_yield
      allow(mock_view).to receive(:div)
      allow(mock_view).to receive(:span)
      allow(mock_view).to receive(:plain)

      adapter.render_lesson_text(mock_view, glossary, [], {}, state)
    end

    it "normalizes glossary keys" do
      expect(mock_view).to receive(:div).with(
        hash_including("x-data" => a_string_matching(/"quad_4":\{/))
      ).and_yield
      allow(mock_view).to receive(:div)
      allow(mock_view).to receive(:span)
      allow(mock_view).to receive(:plain)

      adapter.render_lesson_text(mock_view, glossary, [], {}, state)
    end

    it "renders children" do
      phrase = StreamWeaver::Components::Phrase.new("Hello ")

      allow(mock_view).to receive(:div).and_yield
      expect(phrase).to receive(:render).with(mock_view, state)
      allow(mock_view).to receive(:span)
      allow(mock_view).to receive(:plain)

      adapter.render_lesson_text(mock_view, glossary, [phrase], {}, state)
    end

    it "renders tooltip container" do
      expect(mock_view).to receive(:div).with(hash_including(class: "lesson-text")).and_yield
      expect(mock_view).to receive(:div).with(
        hash_including(
          class: "tooltip",
          "x-show" => "activeTooltip !== null",
          "x-cloak" => true
        )
      ).and_yield
      expect(mock_view).to receive(:div).with(class: "tooltip-content").and_yield
      expect(mock_view).to receive(:span).with("x-text" => "showDetailed ? tooltipDetailed : tooltipContent")
      expect(mock_view).to receive(:div).with(hash_including(class: "tooltip-hint")).and_yield
      expect(mock_view).to receive(:plain).with("Tap for more detail")

      adapter.render_lesson_text(mock_view, glossary, [], {}, state)
    end

    it "handles empty glossary" do
      expect(mock_view).to receive(:div).with(
        hash_including("x-data" => a_string_matching(/glossary: \{\}/))
      ).and_yield
      allow(mock_view).to receive(:div)
      allow(mock_view).to receive(:span)
      allow(mock_view).to receive(:plain)

      adapter.render_lesson_text(mock_view, {}, [], {}, state)
    end
  end
end
