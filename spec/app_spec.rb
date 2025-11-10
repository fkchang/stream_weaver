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

      it "increments button counter" do
        expect {
          app.button("First") {}
        }.to change { app.instance_variable_get(:@button_counter) }.from(0).to(1)
      end

      it "passes counter to button for deterministic ID" do
        app.button("First") {}
        app.button("Second") {}

        expect(app.components[0].id).to eq("btn_first_1")
        expect(app.components[1].id).to eq("btn_second_2")
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

      it "supports markdown headers" do
        app.text("# Title")
        component = app.components.first
        expect(component.instance_variable_get(:@content)).to eq("# Title")
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

    it "resets button counter for deterministic IDs" do
      app = described_class.new("Test") do
        button("First") {}
        button("Second") {}
      end

      app.rebuild_with_state({})
      first_ids = app.components.map(&:id)

      app.rebuild_with_state({})
      second_ids = app.components.map(&:id)

      expect(first_ids).to eq(second_ids)
      expect(first_ids).to eq(["btn_first_1", "btn_second_2"])
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
end
