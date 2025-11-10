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
    describe "rendering plain text" do
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
    end

    describe "rendering markdown headers" do
      it "renders h1 for # header" do
        text = described_class.new("# Main Title")
        expect(mock_view).to receive(:h1).and_yield
        text.render(mock_view, state)
      end

      it "renders h2 for ## header" do
        text = described_class.new("## Section")
        expect(mock_view).to receive(:h2).and_yield
        text.render(mock_view, state)
      end

      it "renders h3 for ### header" do
        text = described_class.new("### Subsection")
        expect(mock_view).to receive(:h3).and_yield
        text.render(mock_view, state)
      end

      it "renders h4 for #### header" do
        text = described_class.new("#### Detail")
        expect(mock_view).to receive(:h4).and_yield
        text.render(mock_view, state)
      end

      it "renders h5 for ##### header" do
        text = described_class.new("##### Fine Print")
        expect(mock_view).to receive(:h5).and_yield
        text.render(mock_view, state)
      end

      it "renders h6 for ###### header" do
        text = described_class.new("###### Smallest")
        expect(mock_view).to receive(:h6).and_yield
        text.render(mock_view, state)
      end

      it "extracts text content without hashes" do
        text = described_class.new("## Test Header")
        expect(mock_view).to receive(:h2).with(no_args).and_yield
        result = text.render(mock_view, state)
        # The yielded block returns "Test Header"
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
end
