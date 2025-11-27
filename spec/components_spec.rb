# frozen_string_literal: true

RSpec.describe StreamWeaver::Components do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:mock_view) { double('view', adapter: adapter) }
  let(:state) { {} }

  describe StreamWeaver::Components::Base do
    it "raises NotImplementedError for render" do
      component = described_class.new
      expect { component.render(mock_view, state) }.to raise_error(NotImplementedError)
    end

    it "returns nil for key by default" do
      component = described_class.new
      expect(component.key).to be_nil
    end

    it "returns empty array for children by default" do
      component = described_class.new
      expect(component.children).to eq([])
    end
  end

  describe StreamWeaver::Components::TextField do
    describe "initialization" do
      it "stores the key" do
        field = described_class.new(:email)
        expect(field.key).to eq(:email)
      end

      it "stores options" do
        field = described_class.new(:name, placeholder: "Enter name")
        expect(field.instance_variable_get(:@options)).to include(placeholder: "Enter name")
      end
    end

    describe "rendering" do
      let(:field) { described_class.new(:email, placeholder: "Enter email") }

      it "renders input with correct type" do
        expect(mock_view).to receive(:input).with(hash_including(type: "text"))
        field.render(mock_view, state)
      end

      it "includes name attribute from key" do
        expect(mock_view).to receive(:input).with(hash_including(name: "email"))
        field.render(mock_view, state)
      end

      it "includes x-model binding for Alpine.js" do
        expect(mock_view).to receive(:input).with(hash_including("x-model" => "email"))
        field.render(mock_view, state)
      end

      it "uses state value when present" do
        state[:email] = "test@example.com"
        expect(mock_view).to receive(:input).with(hash_including(value: "test@example.com"))
        field.render(mock_view, state)
      end

      it "uses empty string when state value is nil" do
        expect(mock_view).to receive(:input).with(hash_including(value: ""))
        field.render(mock_view, state)
      end

      it "includes placeholder text" do
        expect(mock_view).to receive(:input).with(hash_including(placeholder: "Enter email"))
        field.render(mock_view, state)
      end
    end

    describe "edge cases" do
      let(:field) { described_class.new(:comment) }

      it "handles nil state value" do
        state[:comment] = nil
        expect(mock_view).to receive(:input).with(hash_including(value: ""))
        field.render(mock_view, state)
      end

      it "handles special characters in value" do
        state[:comment] = "Test <script>alert('xss')</script>"
        expect(mock_view).to receive(:input).with(hash_including(value: "Test <script>alert('xss')</script>"))
        field.render(mock_view, state)
      end

      it "handles very long text" do
        long_text = "a" * 10000
        state[:comment] = long_text
        expect(mock_view).to receive(:input).with(hash_including(value: long_text))
        field.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::TextArea do
    describe "initialization" do
      it "stores the key" do
        area = described_class.new(:comment)
        expect(area.key).to eq(:comment)
      end

      it "stores options" do
        area = described_class.new(:comment, placeholder: "Enter comment", rows: 5)
        expect(area.instance_variable_get(:@options)).to include(placeholder: "Enter comment", rows: 5)
      end
    end

    describe "rendering" do
      let(:area) { described_class.new(:comment, placeholder: "Comment", rows: 5) }

      it "renders textarea element" do
        expect(mock_view).to receive(:textarea).with(
          hash_including(name: "comment", placeholder: "Comment", rows: 5, "x-model" => "comment")
        ).and_yield
        area.render(mock_view, state)
      end

      it "includes state value as content" do
        state[:comment] = "Hello World"
        expect(mock_view).to receive(:textarea).and_yield
        expect(area.render(mock_view, state)).to eq("Hello World")
      end

      it "uses empty string when state is nil" do
        expect(mock_view).to receive(:textarea).and_yield
        expect(area.render(mock_view, state)).to eq("")
      end
    end
  end

  describe StreamWeaver::Components::Button do
    describe "initialization" do
      it "stores label" do
        button = described_class.new("Submit", 1)
        expect(button.instance_variable_get(:@label)).to eq("Submit")
      end

      it "stores action block" do
        block = proc { |state| state[:clicked] = true }
        button = described_class.new("Submit", 1, &block)
        expect(button.instance_variable_get(:@action)).to eq(block)
      end

      it "generates deterministic ID with counter" do
        button = described_class.new("Submit", 1)
        expect(button.id).to eq("btn_submit_1")
      end

      it "normalizes label in ID" do
        button = described_class.new("Add Todo", 2)
        expect(button.id).to eq("btn_add_todo_2")
      end

      it "maintains consistent ID across rebuilds with same counter" do
        button1 = described_class.new("Submit", 1)
        button2 = described_class.new("Submit", 1)
        expect(button1.id).to eq(button2.id)
      end
    end

    describe "rendering" do
      let(:button) { described_class.new("Submit", 1) }

      it "renders button element" do
        expect(mock_view).to receive(:button).with(
          hash_including(
            class: "btn btn-primary",
            "hx-post" => "/action/btn_submit_1",
            "hx-include" => "[x-model]",
            "hx-target" => "#app-container",
            "hx-swap" => "innerHTML"
          )
        ).and_yield
        button.render(mock_view, state)
      end

      it "applies primary style by default" do
        expect(mock_view).to receive(:button).with(hash_including(class: "btn btn-primary")).and_yield
        button.render(mock_view, state)
      end

      it "applies secondary style when specified" do
        button = described_class.new("Cancel", 1, style: :secondary)
        expect(mock_view).to receive(:button).with(hash_including(class: "btn btn-secondary")).and_yield
        button.render(mock_view, state)
      end
    end

    describe "action execution" do
      it "executes the action block" do
        executed = false
        button = described_class.new("Test", 1) { |state| executed = true }
        button.execute(state)
        expect(executed).to be true
      end

      it "receives state parameter" do
        received_state = nil
        button = described_class.new("Test", 1) { |state| received_state = state }
        button.execute(state)
        expect(received_state).to eq(state)
      end

      it "can modify state" do
        button = described_class.new("Test", 1) { |state| state[:counter] = 5 }
        button.execute(state)
        expect(state[:counter]).to eq(5)
      end

      it "handles nil action gracefully" do
        button = described_class.new("Test", 1)
        expect { button.execute(state) }.not_to raise_error
      end
    end
  end

  describe StreamWeaver::Components::Text do
    describe "rendering" do
      let(:text) { described_class.new("Hello World") }

      it "renders paragraph for plain text" do
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end

      it "converts content to string" do
        text = described_class.new(42)
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end

      it "renders text literally (no markdown parsing)" do
        text = described_class.new("## This stays as-is")
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end

      it "renders bold asterisks literally" do
        text = described_class.new("**bold** stays as-is")
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end
    end

    describe "dynamic content" do
      it "evaluates proc content with state" do
        text = described_class.new(-> (s) { "Hello #{s[:name]}" })
        state[:name] = "Alice"
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end
    end

    describe "edge cases" do
      it "handles string interpolation in content" do
        text = described_class.new("Count: #{5}")
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end

      it "handles HTML in content" do
        text = described_class.new("<script>alert('xss')</script>")
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end

      it "handles empty string" do
        text = described_class.new("")
        expect(mock_view).to receive(:p).and_yield
        text.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::Markdown do
    describe "initialization" do
      it "stores content" do
        md = described_class.new("**bold** text")
        expect(md.instance_variable_get(:@content)).to eq("**bold** text")
      end
    end

    describe "rendering" do
      it "delegates to adapter render_markdown" do
        md = described_class.new("**bold** and *italic*")
        expect(adapter).to receive(:render_markdown).with(mock_view, "**bold** and *italic*", state)
        md.render(mock_view, state)
      end

      it "evaluates proc content with state" do
        md = described_class.new(-> (s) { "**#{s[:name]}** is bold" })
        state[:name] = "Alice"
        expect(adapter).to receive(:render_markdown).with(mock_view, "**Alice** is bold", state)
        md.render(mock_view, state)
      end

      it "converts content to string" do
        md = described_class.new(42)
        expect(adapter).to receive(:render_markdown).with(mock_view, "42", state)
        md.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::Header do
    describe "initialization" do
      it "stores content and level" do
        header = described_class.new("Title", level: 3)
        expect(header.instance_variable_get(:@content)).to eq("Title")
        expect(header.instance_variable_get(:@level)).to eq(3)
      end

      it "defaults to level 2" do
        header = described_class.new("Title")
        expect(header.instance_variable_get(:@level)).to eq(2)
      end

      it "clamps level to valid range (1-6)" do
        header = described_class.new("Title", level: 0)
        expect(header.instance_variable_get(:@level)).to eq(1)

        header = described_class.new("Title", level: 10)
        expect(header.instance_variable_get(:@level)).to eq(6)
      end
    end

    describe "rendering" do
      it "delegates to adapter render_header" do
        header = described_class.new("Section Title", level: 2)
        expect(adapter).to receive(:render_header).with(mock_view, "Section Title", 2, state)
        header.render(mock_view, state)
      end

      it "evaluates proc content with state" do
        header = described_class.new(-> (s) { "Welcome #{s[:name]}" }, level: 1)
        state[:name] = "Alice"
        expect(adapter).to receive(:render_header).with(mock_view, "Welcome Alice", 1, state)
        header.render(mock_view, state)
      end

      it "converts content to string" do
        header = described_class.new(42, level: 3)
        expect(adapter).to receive(:render_header).with(mock_view, "42", 3, state)
        header.render(mock_view, state)
      end

      it "renders all header levels correctly" do
        (1..6).each do |level|
          header = described_class.new("Level #{level}", level: level)
          expect(adapter).to receive(:render_header).with(mock_view, "Level #{level}", level, state)
          header.render(mock_view, state)
        end
      end
    end
  end

  describe StreamWeaver::Components::Div do
    describe "initialization" do
      it "initializes with empty children" do
        div = described_class.new
        expect(div.children).to eq([])
      end

      it "stores CSS class option" do
        div = described_class.new(class: "container")
        expect(div.instance_variable_get(:@options)[:class]).to eq("container")
      end
    end

    describe "rendering" do
      let(:div) { described_class.new(class: "card") }

      it "renders div element" do
        expect(mock_view).to receive(:div).with(class: "card").and_yield
        div.render(mock_view, state)
      end

      it "renders nested children" do
        child1 = StreamWeaver::Components::Text.new("Child 1")
        child2 = StreamWeaver::Components::Text.new("Child 2")
        div.children = [child1, child2]

        expect(mock_view).to receive(:div).and_yield
        expect(child1).to receive(:render).with(mock_view, state)
        expect(child2).to receive(:render).with(mock_view, state)

        div.render(mock_view, state)
      end

      it "handles empty div" do
        expect(mock_view).to receive(:div).and_yield
        div.render(mock_view, state)
      end
    end

    describe "nesting" do
      it "handles deep nesting (5 levels)" do
        level5 = described_class.new
        level4 = described_class.new
        level4.children = [level5]
        level3 = described_class.new
        level3.children = [level4]
        level2 = described_class.new
        level2.children = [level3]
        level1 = described_class.new
        level1.children = [level2]

        allow(mock_view).to receive(:div).and_yield

        expect { level1.render(mock_view, state) }.not_to raise_error
      end

      it "handles mixed content types" do
        text = StreamWeaver::Components::Text.new("Hello")
        button = StreamWeaver::Components::Button.new("Click", 1)
        div = described_class.new
        div.children = [text, button]

        allow(mock_view).to receive(:div).and_yield
        allow(text).to receive(:render)
        allow(button).to receive(:render)

        div.render(mock_view, state)

        expect(text).to have_received(:render)
        expect(button).to have_received(:render)
      end
    end
  end

  describe StreamWeaver::Components::Checkbox do
    describe "initialization" do
      it "stores key and label" do
        checkbox = described_class.new(:agree, "I agree")
        expect(checkbox.key).to eq(:agree)
        expect(checkbox.instance_variable_get(:@label)).to eq("I agree")
      end
    end

    describe "rendering" do
      let(:checkbox) { described_class.new(:agree, "I agree to terms") }

      it "renders label container" do
        expect(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including(type: "checkbox"))
        expect(mock_view).to receive(:plain).with(" I agree to terms")
        checkbox.render(mock_view, state)
      end

      it "includes name attribute from key" do
        expect(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including(name: "agree"))
        expect(mock_view).to receive(:plain)
        checkbox.render(mock_view, state)
      end

      it "includes x-model binding" do
        expect(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including("x-model" => "agree"))
        expect(mock_view).to receive(:plain)
        checkbox.render(mock_view, state)
      end

      it "sets checked attribute from state (true)" do
        state[:agree] = true
        expect(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including(checked: true))
        expect(mock_view).to receive(:plain)
        checkbox.render(mock_view, state)
      end

      it "sets checked attribute from state (false)" do
        state[:agree] = false
        expect(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including(checked: false))
        expect(mock_view).to receive(:plain)
        checkbox.render(mock_view, state)
      end

      it "handles nil state (unchecked)" do
        expect(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including(checked: nil))
        expect(mock_view).to receive(:plain)
        checkbox.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::Select do
    describe "initialization" do
      it "stores key and choices" do
        select = described_class.new(:color, ["Red", "Green", "Blue"])
        expect(select.key).to eq(:color)
        expect(select.instance_variable_get(:@choices)).to eq(["Red", "Green", "Blue"])
      end
    end

    describe "rendering" do
      let(:select) { described_class.new(:color, ["Red", "Green", "Blue"]) }

      it "renders select element" do
        expect(mock_view).to receive(:select).with(
          hash_including(name: "color", "x-model" => "color")
        ).and_yield
        allow(mock_view).to receive(:option).and_yield

        select.render(mock_view, state)
      end

      it "renders all choices as options" do
        expect(mock_view).to receive(:select).and_yield
        expect(mock_view).to receive(:option).with(hash_including(value: "Red")).and_yield
        expect(mock_view).to receive(:option).with(hash_including(value: "Green")).and_yield
        expect(mock_view).to receive(:option).with(hash_including(value: "Blue")).and_yield

        select.render(mock_view, state)
      end

      it "marks selected option from state" do
        state[:color] = "Green"

        expect(mock_view).to receive(:select).and_yield
        expect(mock_view).to receive(:option).with(hash_including(value: "Red", selected: false)).and_yield
        expect(mock_view).to receive(:option).with(hash_including(value: "Green", selected: true)).and_yield
        expect(mock_view).to receive(:option).with(hash_including(value: "Blue", selected: false)).and_yield

        select.render(mock_view, state)
      end

      it "handles no selection (nil state)" do
        expect(mock_view).to receive(:select).and_yield
        allow(mock_view).to receive(:option).with(hash_including(selected: false)).and_yield

        select.render(mock_view, state)
      end
    end

    describe "edge cases" do
      it "handles empty choices array" do
        select = described_class.new(:color, [])
        expect(mock_view).to receive(:select).and_yield

        select.render(mock_view, state)
      end

      it "handles single choice" do
        select = described_class.new(:color, ["Only One"])
        expect(mock_view).to receive(:select).and_yield
        expect(mock_view).to receive(:option).once.and_yield

        select.render(mock_view, state)
      end

      it "handles many choices (100)" do
        choices = (1..100).map { |i| "Choice #{i}" }
        select = described_class.new(:number, choices)

        expect(mock_view).to receive(:select).and_yield
        expect(mock_view).to receive(:option).exactly(100).times.and_yield

        select.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::RadioGroup do
    describe "initialization" do
      it "stores key and choices" do
        radio = described_class.new(:answer, ["A", "B", "C"])
        expect(radio.key).to eq(:answer)
        expect(radio.instance_variable_get(:@choices)).to eq(["A", "B", "C"])
      end
    end

    describe "rendering" do
      let(:radio) { described_class.new(:answer, ["Option A", "Option B"]) }

      it "renders div container with radio-group class" do
        expect(mock_view).to receive(:div).with(class: "radio-group").and_yield
        allow(mock_view).to receive(:label).and_yield
        allow(mock_view).to receive(:input)
        allow(mock_view).to receive(:span).and_yield

        radio.render(mock_view, state)
      end

      it "renders label for each choice" do
        expect(mock_view).to receive(:div).and_yield
        expect(mock_view).to receive(:label).twice.and_yield
        allow(mock_view).to receive(:input)
        allow(mock_view).to receive(:span).and_yield

        radio.render(mock_view, state)
      end

      it "renders radio input for each choice" do
        expect(mock_view).to receive(:div).and_yield
        allow(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including(type: "radio", name: "answer")).twice
        allow(mock_view).to receive(:span).and_yield

        radio.render(mock_view, state)
      end

      it "marks checked option from state" do
        state[:answer] = "Option B"

        expect(mock_view).to receive(:div).and_yield
        allow(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).with(hash_including(value: "Option A", checked: false))
        expect(mock_view).to receive(:input).with(hash_including(value: "Option B", checked: true))
        allow(mock_view).to receive(:span).and_yield

        radio.render(mock_view, state)
      end

      it "handles no selection (nil state)" do
        expect(mock_view).to receive(:div).and_yield
        allow(mock_view).to receive(:label).and_yield
        expect(mock_view).to receive(:input).twice.with(hash_including(checked: false))
        allow(mock_view).to receive(:span).and_yield

        radio.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::Card do
    describe "initialization" do
      it "initializes with empty children" do
        card = described_class.new
        expect(card.children).to eq([])
      end

      it "stores CSS class option" do
        card = described_class.new(class: "question-card")
        expect(card.instance_variable_get(:@options)[:class]).to eq("question-card")
      end
    end

    describe "rendering" do
      let(:card) { described_class.new }

      it "renders div element with card class" do
        expect(mock_view).to receive(:div).with(class: "card").and_yield
        card.render(mock_view, state)
      end

      it "combines card class with custom class" do
        card_with_class = described_class.new(class: "question-card")
        expect(mock_view).to receive(:div).with(class: "card question-card").and_yield
        card_with_class.render(mock_view, state)
      end

      it "renders nested children" do
        child1 = StreamWeaver::Components::Text.new("Child 1")
        child2 = StreamWeaver::Components::Text.new("Child 2")
        card.children = [child1, child2]

        expect(mock_view).to receive(:div).and_yield
        expect(child1).to receive(:render).with(mock_view, state)
        expect(child2).to receive(:render).with(mock_view, state)

        card.render(mock_view, state)
      end

      it "handles empty card" do
        expect(mock_view).to receive(:div).and_yield
        card.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::Phrase do
    describe "initialization" do
      it "stores content" do
        phrase = described_class.new("Hello world")
        expect(phrase.instance_variable_get(:@content)).to eq("Hello world")
      end
    end

    describe "rendering" do
      let(:phrase) { described_class.new("Some text") }

      it "renders span element" do
        expect(mock_view).to receive(:span).and_yield
        phrase.render(mock_view, state)
      end

      it "handles empty string" do
        phrase = described_class.new("")
        expect(mock_view).to receive(:span).and_yield
        phrase.render(mock_view, state)
      end

      it "handles special characters" do
        phrase = described_class.new("Test <>&\"'")
        expect(mock_view).to receive(:span).and_yield
        phrase.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::Term do
    describe "initialization" do
      it "stores term_key" do
        term = described_class.new("bullish")
        expect(term.term_key).to eq("bullish")
      end

      it "stores options" do
        term = described_class.new("bullish", display: "Bull Market")
        expect(term.instance_variable_get(:@options)).to include(display: "Bull Market")
      end
    end

    describe "rendering" do
      let(:term) { described_class.new("bullish") }

      it "delegates to adapter render_term" do
        expect(adapter).to receive(:render_term).with(mock_view, "bullish", {}, state)
        term.render(mock_view, state)
      end

      it "passes display option to adapter" do
        term_with_display = described_class.new("Quad 4", display: "Q4")
        expect(adapter).to receive(:render_term).with(mock_view, "Quad 4", { display: "Q4" }, state)
        term_with_display.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::LessonText do
    describe "initialization" do
      it "initializes with empty children" do
        lesson = described_class.new
        expect(lesson.children).to eq([])
      end

      it "stores glossary" do
        glossary = { "bullish" => { simple: "Up", detailed: "Expecting increase" } }
        lesson = described_class.new(glossary: glossary)
        expect(lesson.glossary).to eq(glossary)
      end

      it "defaults to empty glossary" do
        lesson = described_class.new
        expect(lesson.glossary).to eq({})
      end
    end

    describe "rendering" do
      let(:glossary) { { "bullish" => { simple: "Up", detailed: "Expecting increase" } } }
      let(:lesson) { described_class.new(glossary: glossary) }

      it "delegates to adapter render_lesson_text" do
        expect(adapter).to receive(:render_lesson_text).with(mock_view, glossary, [], {}, state)
        lesson.render(mock_view, state)
      end

      it "passes children to adapter" do
        phrase = StreamWeaver::Components::Phrase.new("Hello ")
        term = StreamWeaver::Components::Term.new("bullish")
        lesson.children = [phrase, term]

        expect(adapter).to receive(:render_lesson_text).with(mock_view, glossary, [phrase, term], {}, state)
        lesson.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::CheckboxGroup do
    describe "initialization" do
      it "stores the key" do
        group = described_class.new(:selected_emails)
        expect(group.key).to eq(:selected_emails)
      end

      it "stores options" do
        group = described_class.new(:selected_emails, select_all: "Select All", select_none: "Clear")
        expect(group.instance_variable_get(:@options)).to include(select_all: "Select All", select_none: "Clear")
      end

      it "initializes with empty children" do
        group = described_class.new(:selected_emails)
        expect(group.children).to eq([])
      end
    end

    describe "rendering" do
      let(:group) { described_class.new(:selected_emails, select_all: "Select All", select_none: "Clear") }

      it "delegates rendering to adapter" do
        expect(adapter).to receive(:render_checkbox_group).with(
          mock_view,
          :selected_emails,
          [],
          hash_including(select_all: "Select All", select_none: "Clear"),
          state
        )

        group.render(mock_view, state)
      end

      it "passes children to adapter" do
        item1 = StreamWeaver::Components::CheckboxItem.new("email_1")
        item2 = StreamWeaver::Components::CheckboxItem.new("email_2")
        group.children = [item1, item2]

        expect(adapter).to receive(:render_checkbox_group).with(
          mock_view,
          :selected_emails,
          [item1, item2],
          anything,
          state
        )

        group.render(mock_view, state)
      end
    end
  end

  describe StreamWeaver::Components::CheckboxItem do
    describe "initialization" do
      it "stores the value" do
        item = described_class.new("email_123")
        expect(item.value).to eq("email_123")
      end

      it "initializes with empty children" do
        item = described_class.new("email_123")
        expect(item.children).to eq([])
      end
    end
  end
end
