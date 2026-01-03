# frozen_string_literal: true

RSpec.describe StreamWeaver::App do
  describe "initialization" do
    it "stores title" do
      app = described_class.new("Test App") {}
      expect(app.title).to eq("Test App")
    end

    it "stores DSL block" do
      block = proc { text_field :name }
      app = described_class.new("Test", &block)
      expect(app.block).to eq(block)
    end

    it "initializes empty components array" do
      app = described_class.new("Test") {}
      expect(app.components).to eq([])
    end

    it "initializes empty state" do
      app = described_class.new("Test") {}
      expect(app.state).to eq({})
    end

    it "initializes button counter to 0" do
      app = described_class.new("Test") {}
      expect(app.instance_variable_get(:@button_counter)).to eq(0)
    end

    describe "layout option" do
      it "defaults to :default layout" do
        app = described_class.new("Test") {}
        expect(app.layout).to eq(:default)
      end

      it "accepts :wide layout" do
        app = described_class.new("Test", layout: :wide) {}
        expect(app.layout).to eq(:wide)
      end

      it "accepts :full layout" do
        app = described_class.new("Test", layout: :full) {}
        expect(app.layout).to eq(:full)
      end

      it "accepts :fluid layout" do
        app = described_class.new("Test", layout: :fluid) {}
        expect(app.layout).to eq(:fluid)
      end
    end
  end

  describe "DSL methods" do
    let(:app) { described_class.new("Test") {} }

    describe "#text_field" do
      it "adds TextField component" do
        app.text_field(:email, placeholder: "Email")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::TextField)
        expect(app.components.first.key).to eq(:email)
      end

      it "passes options to component" do
        app.text_field(:name, placeholder: "Name")
        component = app.components.first
        expect(component.instance_variable_get(:@options)).to include(placeholder: "Name")
      end
    end

    describe "#text_area" do
      it "adds TextArea component" do
        app.text_area(:comment, rows: 5)
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::TextArea)
      end
    end

    describe "#button" do
      it "adds Button component" do
        app.button("Submit") {}
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Button)
      end

      it "uses counter for blockless buttons" do
        expect {
          app.button("First", submit: false)
        }.to change { app.instance_variable_get(:@button_counter) }.from(0).to(1)
      end

      it "generates stable hash ID for buttons with blocks" do
        app.button("First") {}
        app.button("Second") {}

        # Buttons with blocks get stable hash IDs from source location
        expect(app.components[0].id).to match(/^btn_first_[a-f0-9]{8}$/)
        expect(app.components[1].id).to match(/^btn_second_[a-f0-9]{8}$/)
      end

      it "stores action block" do
        block = proc { |state| state[:clicked] = true }
        app.button("Click", &block)

        button = app.components.first
        button.execute(app.state)
        expect(app.state[:clicked]).to be true
      end
    end

    describe "#text" do
      it "adds Text component" do
        app.text("Hello World")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Text)
      end

      it "stores content literally (no markdown parsing)" do
        app.text("# Title")
        component = app.components.first
        expect(component.instance_variable_get(:@content)).to eq("# Title")
      end
    end

    describe "#md" do
      it "adds Markdown component" do
        app.md("**bold** text")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Markdown)
      end

      it "stores content for parsing" do
        app.md("**bold** and *italic*")
        component = app.components.first
        expect(component.instance_variable_get(:@content)).to eq("**bold** and *italic*")
      end
    end

    describe "#markdown" do
      it "is an alias for md" do
        app.markdown("**bold** text")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Markdown)
      end
    end

    describe "#header" do
      it "adds Header component with default level 2" do
        app.header("Section Title")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Header)
        expect(app.components.first.instance_variable_get(:@level)).to eq(2)
      end
    end

    describe "#header1" do
      it "adds Header component with level 1" do
        app.header1("Page Title")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Header)
        expect(app.components.first.instance_variable_get(:@level)).to eq(1)
      end
    end

    describe "#header2" do
      it "adds Header component with level 2" do
        app.header2("Section")
        component = app.components.first
        expect(component.instance_variable_get(:@level)).to eq(2)
      end
    end

    describe "#header3" do
      it "adds Header component with level 3" do
        app.header3("Subsection")
        component = app.components.first
        expect(component.instance_variable_get(:@level)).to eq(3)
      end
    end

    describe "#header4" do
      it "adds Header component with level 4" do
        app.header4("Minor Section")
        component = app.components.first
        expect(component.instance_variable_get(:@level)).to eq(4)
      end
    end

    describe "#header5" do
      it "adds Header component with level 5" do
        app.header5("Small Section")
        component = app.components.first
        expect(component.instance_variable_get(:@level)).to eq(5)
      end
    end

    describe "#header6" do
      it "adds Header component with level 6" do
        app.header6("Smallest Section")
        component = app.components.first
        expect(component.instance_variable_get(:@level)).to eq(6)
      end
    end

    describe "#div" do
      it "adds Div component" do
        app.div {}
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Div)
      end

      it "passes CSS class option" do
        app.div(class: "container") {}
        component = app.components.first
        expect(component.instance_variable_get(:@options)[:class]).to eq("container")
      end

      it "captures nested components" do
        app.div do
          text("Nested")
          text_field(:name)
        end

        div = app.components.first
        expect(div.children.length).to eq(2)
        expect(div.children[0]).to be_a(StreamWeaver::Components::Text)
        expect(div.children[1]).to be_a(StreamWeaver::Components::TextField)
      end

      it "maintains component order in parent after div" do
        app.text("Before")
        app.div { text("Inside") }
        app.text("After")

        expect(app.components.length).to eq(3)
        expect(app.components[0]).to be_a(StreamWeaver::Components::Text)
        expect(app.components[1]).to be_a(StreamWeaver::Components::Div)
        expect(app.components[2]).to be_a(StreamWeaver::Components::Text)
      end
    end

    describe "#checkbox" do
      it "adds Checkbox component" do
        app.checkbox(:agree, "I agree")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Checkbox)
        expect(app.components.first.key).to eq(:agree)
      end
    end

    describe "#select" do
      it "adds Select component" do
        app.select(:color, ["Red", "Green", "Blue"])
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Select)
        expect(app.components.first.key).to eq(:color)
      end

      it "sets default value in state when provided" do
        app.select(:color, ["Red", "Green", "Blue"], default: "Green")
        expect(app.state[:color]).to eq("Green")
      end

      it "does not override existing state with default" do
        app.state[:color] = "Blue"
        app.select(:color, ["Red", "Green", "Blue"], default: "Green")
        expect(app.state[:color]).to eq("Blue")
      end

      it "initializes state to empty string when no default provided" do
        app.select(:color, ["Red", "Green", "Blue"])
        expect(app.state[:color]).to eq("")
      end
    end

    describe "#radio_group" do
      it "adds RadioGroup component" do
        app.radio_group(:answer, ["A", "B", "C"])
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::RadioGroup)
        expect(app.components.first.key).to eq(:answer)
      end
    end

    describe "#checkbox_group" do
      it "adds CheckboxGroup component" do
        app.checkbox_group(:selected_emails) {}
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::CheckboxGroup)
        expect(app.components.first.key).to eq(:selected_emails)
      end

      it "passes options" do
        app.checkbox_group(:selected_emails, select_all: "Select All", select_none: "Clear") {}
        component = app.components.first
        expect(component.instance_variable_get(:@options)).to include(
          select_all: "Select All",
          select_none: "Clear"
        )
      end

      it "captures item children with values" do
        app.checkbox_group(:selected_emails) do
          item("email_1") { text("First email") }
          item("email_2") { text("Second email") }
        end

        group = app.components.first
        expect(group.children.length).to eq(2)
        expect(group.children[0]).to be_a(StreamWeaver::Components::CheckboxItem)
        expect(group.children[0].value).to eq("email_1")
        expect(group.children[1].value).to eq("email_2")
      end

      it "captures nested components within items" do
        app.checkbox_group(:selected_emails) do
          item("email_1") do
            text("From: sender@example.com")
            text("Subject: Hello")
          end
        end

        group = app.components.first
        item = group.children.first
        expect(item.children.length).to eq(2)
        expect(item.children[0]).to be_a(StreamWeaver::Components::Text)
        expect(item.children[1]).to be_a(StreamWeaver::Components::Text)
      end

      it "initializes state as empty array" do
        app.checkbox_group(:selected_emails) {}
        expect(app.state[:selected_emails]).to eq([])
      end

      it "does not override existing array state" do
        app.state[:selected_emails] = ["email_1", "email_3"]
        app.checkbox_group(:selected_emails) {}
        expect(app.state[:selected_emails]).to eq(["email_1", "email_3"])
      end

      it "supports default option for initial selection" do
        app.checkbox_group(:selected_emails, default: ["email_2"]) {}
        expect(app.state[:selected_emails]).to eq(["email_2"])
      end
    end

    describe "#card" do
      it "adds Card component" do
        app.card {}
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Card)
      end

      it "passes CSS class option" do
        app.card(class: "question-card") {}
        component = app.components.first
        expect(component.instance_variable_get(:@options)[:class]).to eq("question-card")
      end

      it "captures nested components" do
        app.card do
          text("Question")
          radio_group(:answer, ["A", "B"])
        end

        card = app.components.first
        expect(card.children.length).to eq(2)
        expect(card.children[0]).to be_a(StreamWeaver::Components::Text)
        expect(card.children[1]).to be_a(StreamWeaver::Components::RadioGroup)
      end

      it "maintains component order in parent after card" do
        app.text("Before")
        app.card { text("Inside") }
        app.text("After")

        expect(app.components.length).to eq(3)
        expect(app.components[0]).to be_a(StreamWeaver::Components::Text)
        expect(app.components[1]).to be_a(StreamWeaver::Components::Card)
        expect(app.components[2]).to be_a(StreamWeaver::Components::Text)
      end
    end
  end

  describe "#rebuild_with_state" do
    it "re-evaluates DSL block" do
      app = described_class.new("Test") do
        text_field(:name)
        button("Submit") {}
      end

      app.rebuild_with_state({})

      expect(app.components.length).to eq(2)
      expect(app.components[0]).to be_a(StreamWeaver::Components::TextField)
      expect(app.components[1]).to be_a(StreamWeaver::Components::Button)
    end

    it "clears previous components" do
      app = described_class.new("Test") do
        text_field(:name)
      end

      app.rebuild_with_state({})
      first_component_id = app.components.first.object_id

      app.rebuild_with_state({})
      second_component_id = app.components.first.object_id

      expect(first_component_id).not_to eq(second_component_id)
    end

    it "generates stable IDs across rebuilds" do
      app = described_class.new("Test") do
        button("First") {}
        button("Second") {}
      end

      app.rebuild_with_state({})
      first_ids = app.components.map(&:id)

      app.rebuild_with_state({})
      second_ids = app.components.map(&:id)

      # Stable hash IDs should be identical across rebuilds
      expect(first_ids).to eq(second_ids)
      expect(first_ids[0]).to match(/^btn_first_[a-f0-9]{8}$/)
      expect(first_ids[1]).to match(/^btn_second_[a-f0-9]{8}$/)
    end

    it "makes state available during rebuild" do
      app = described_class.new("Test") do
        text_field(:name)

        if state[:name] == "Alice"
          text("Hello Alice!")
        end
      end

      app.rebuild_with_state({ name: "Alice" })

      expect(app.components.length).to eq(2)
      expect(app.components[1]).to be_a(StreamWeaver::Components::Text)
    end

    it "allows conditional rendering based on state" do
      app = described_class.new("Test") do
        checkbox(:agree, "Agree")

        if state[:agree]
          button("Submit") {}
        end
      end

      # Without agreement
      app.rebuild_with_state({ agree: false })
      expect(app.components.length).to eq(1)

      # With agreement
      app.rebuild_with_state({ agree: true })
      expect(app.components.length).to eq(2)
    end
  end

  describe "state management" do
    it "provides access to current state" do
      app = described_class.new("Test") do
        state[:initialized] = true
      end

      app.rebuild_with_state({})
      expect(app.state[:initialized]).to be true
    end

    it "persists state across rebuilds" do
      app = described_class.new("Test") do
        button("Increment") do |state|
          state[:counter] ||= 0
          state[:counter] += 1
        end
      end

      app.rebuild_with_state({})
      button = app.components.first

      # First click
      button.execute(app.state)
      expect(app.state[:counter]).to eq(1)

      # Rebuild with same state
      app.rebuild_with_state(app.state)
      button = app.components.first

      # Second click
      button.execute(app.state)
      expect(app.state[:counter]).to eq(2)
    end
  end

  describe "#generate" do
    it "returns a Sinatra application" do
      app = described_class.new("Test") {}
      sinatra_app = app.generate

      expect(sinatra_app).to be < Sinatra::Base
    end

    it "sets streamlit_app setting" do
      app = described_class.new("Test") {}
      sinatra_app = app.generate

      expect(sinatra_app.settings.streamlit_app).to eq(app)
    end
  end

  describe "component tree building" do
    it "builds components in order" do
      app = described_class.new("Test") do
        text("First")
        text_field(:name)
        button("Submit") {}
        checkbox(:agree, "Agree")
        select(:color, ["Red"])
      end

      app.rebuild_with_state({})

      expect(app.components.length).to eq(5)
      expect(app.components[0]).to be_a(StreamWeaver::Components::Text)
      expect(app.components[1]).to be_a(StreamWeaver::Components::TextField)
      expect(app.components[2]).to be_a(StreamWeaver::Components::Button)
      expect(app.components[3]).to be_a(StreamWeaver::Components::Checkbox)
      expect(app.components[4]).to be_a(StreamWeaver::Components::Select)
    end

    it "supports nested structures" do
      app = described_class.new("Test") do
        div class: "outer" do
          text("Level 1")

          div class: "inner" do
            text("Level 2")
            text_field(:name)
          end
        end
      end

      app.rebuild_with_state({})

      outer_div = app.components.first
      expect(outer_div.children.length).to eq(2)

      inner_div = outer_div.children[1]
      expect(inner_div).to be_a(StreamWeaver::Components::Div)
      expect(inner_div.children.length).to eq(2)
    end

    it "handles complex mixed structures" do
      app = described_class.new("Test") do
        text("# Form")

        div class: "form" do
          text_field(:name)
          text_field(:email)

          checkbox(:subscribe, "Subscribe")

          div class: "buttons" do
            button("Submit") {}
            button("Cancel", style: :secondary) {}
          end
        end

        text("Footer text")
      end

      app.rebuild_with_state({})

      expect(app.components.length).to eq(3)
      form_div = app.components[1]
      expect(form_div.children.length).to eq(4)

      buttons_div = form_div.children[3]
      expect(buttons_div.children.length).to eq(2)
    end
  end

  describe "integration with StreamWeaver helper" do
    it "works with app helper method" do
      sinatra_app = app("Test App") do
        text_field(:name)
      end

      # The app helper generates and returns a Sinatra app
      expect(sinatra_app).to be < Sinatra::Base

      # The StreamWeaver::App is stored in settings
      stream_weaver_app = sinatra_app.settings.streamlit_app
      expect(stream_weaver_app).to be_a(StreamWeaver::App)
      expect(stream_weaver_app.title).to eq("Test App")

      stream_weaver_app.rebuild_with_state({})
      expect(stream_weaver_app.components.length).to eq(1)
    end
  end

  describe "lesson text DSL methods" do
    let(:glossary) do
      {
        "bullish" => { simple: "Expecting UP", detailed: "A bullish outlook means expecting prices to increase." },
        "bearish" => { simple: "Expecting DOWN", detailed: "A bearish outlook means expecting prices to decrease." }
      }
    end
    let(:app) { described_class.new("Test") {} }

    describe "#phrase" do
      it "adds Phrase component" do
        app.phrase("Hello world")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Phrase)
      end
    end

    describe "#term" do
      it "adds Term component" do
        app.term("bullish")
        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::Term)
        expect(app.components.first.term_key).to eq("bullish")
      end

      it "passes display option" do
        app.term("bullish", display: "Bull Market")
        component = app.components.first
        expect(component.instance_variable_get(:@options)).to include(display: "Bull Market")
      end
    end

    describe "#lesson_text with block" do
      it "adds LessonText component" do
        app.lesson_text(glossary: glossary) do
          phrase "Hello "
          term "bullish"
        end

        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::LessonText)
      end

      it "captures nested phrase and term components" do
        app.lesson_text(glossary: glossary) do
          phrase "When analysts are "
          term "bullish"
          phrase " on stocks."
        end

        lesson = app.components.first
        expect(lesson.children.length).to eq(3)
        expect(lesson.children[0]).to be_a(StreamWeaver::Components::Phrase)
        expect(lesson.children[1]).to be_a(StreamWeaver::Components::Term)
        expect(lesson.children[2]).to be_a(StreamWeaver::Components::Phrase)
      end

      it "stores glossary" do
        app.lesson_text(glossary: glossary) do
          term "bullish"
        end

        lesson = app.components.first
        expect(lesson.glossary).to eq(glossary)
      end

      it "maintains component order in parent after lesson_text" do
        app.text("Before")
        app.lesson_text(glossary: glossary) { term "bullish" }
        app.text("After")

        expect(app.components.length).to eq(3)
        expect(app.components[0]).to be_a(StreamWeaver::Components::Text)
        expect(app.components[1]).to be_a(StreamWeaver::Components::LessonText)
        expect(app.components[2]).to be_a(StreamWeaver::Components::Text)
      end
    end

    describe "#lesson_text with string" do
      it "adds LessonText component" do
        app.lesson_text("The market is {bullish} today.", glossary: glossary)

        expect(app.components.length).to eq(1)
        expect(app.components.first).to be_a(StreamWeaver::Components::LessonText)
      end

      it "parses string into phrase and term children" do
        app.lesson_text("The market is {bullish} today.", glossary: glossary)

        lesson = app.components.first
        expect(lesson.children.length).to eq(3)
        expect(lesson.children[0]).to be_a(StreamWeaver::Components::Phrase)
        expect(lesson.children[1]).to be_a(StreamWeaver::Components::Term)
        expect(lesson.children[2]).to be_a(StreamWeaver::Components::Phrase)
      end

      it "extracts term from braces" do
        app.lesson_text("Feeling {bullish}!", glossary: glossary)

        lesson = app.components.first
        term = lesson.children.find { |c| c.is_a?(StreamWeaver::Components::Term) }
        expect(term.term_key).to eq("bullish")
      end

      it "handles multiple terms" do
        app.lesson_text("Either {bullish} or {bearish}.", glossary: glossary)

        lesson = app.components.first
        terms = lesson.children.select { |c| c.is_a?(StreamWeaver::Components::Term) }
        expect(terms.length).to eq(2)
        expect(terms[0].term_key).to eq("bullish")
        expect(terms[1].term_key).to eq("bearish")
      end

      it "handles terms at beginning" do
        app.lesson_text("{bullish} sentiment.", glossary: glossary)

        lesson = app.components.first
        expect(lesson.children[0]).to be_a(StreamWeaver::Components::Term)
        expect(lesson.children[1]).to be_a(StreamWeaver::Components::Phrase)
      end

      it "handles terms at end" do
        app.lesson_text("Sentiment is {bullish}", glossary: glossary)

        lesson = app.components.first
        expect(lesson.children[0]).to be_a(StreamWeaver::Components::Phrase)
        expect(lesson.children[1]).to be_a(StreamWeaver::Components::Term)
      end

      it "handles adjacent terms" do
        app.lesson_text("{bullish}{bearish}", glossary: glossary)

        lesson = app.components.first
        expect(lesson.children.length).to eq(2)
        expect(lesson.children[0]).to be_a(StreamWeaver::Components::Term)
        expect(lesson.children[1]).to be_a(StreamWeaver::Components::Term)
      end

      it "handles terms with spaces in key" do
        glossary_with_spaces = { "Quad 4" => { simple: "Deflation", detailed: "Growth and inflation both falling" } }
        app.lesson_text("In {Quad 4}, bonds rally.", glossary: glossary_with_spaces)

        lesson = app.components.first
        term = lesson.children.find { |c| c.is_a?(StreamWeaver::Components::Term) }
        expect(term.term_key).to eq("Quad 4")
      end

      it "stores glossary" do
        app.lesson_text("Market is {bullish}.", glossary: glossary)

        lesson = app.components.first
        expect(lesson.glossary).to eq(glossary)
      end
    end
  end
end
