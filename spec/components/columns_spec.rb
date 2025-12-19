# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Columns do
  describe "initialization" do
    it "initializes with empty children" do
      columns = described_class.new
      expect(columns.children).to eq([])
    end

    it "stores widths option" do
      columns = described_class.new(widths: ['30%', '70%'])
      expect(columns.widths).to eq(['30%', '70%'])
    end

    it "defaults widths to nil" do
      columns = described_class.new
      expect(columns.widths).to be_nil
    end

    it "stores additional options" do
      columns = described_class.new(gap: "20px")
      expect(columns.instance_variable_get(:@options)).to include(gap: "20px")
    end
  end
end

RSpec.describe StreamWeaver::Components::Column do
  describe "initialization" do
    it "initializes with empty children" do
      column = described_class.new
      expect(column.children).to eq([])
    end

    it "initializes width to nil" do
      column = described_class.new
      expect(column.width).to be_nil
    end

    it "stores class option" do
      column = described_class.new(class: "sidebar")
      expect(column.instance_variable_get(:@options)).to include(class: "sidebar")
    end

    it "allows setting width" do
      column = described_class.new
      column.width = "30%"
      expect(column.width).to eq("30%")
    end
  end
end

RSpec.describe "columns DSL" do
  let(:app) { StreamWeaver::App.new("Test") {} }

  describe "#columns" do
    it "adds Columns component" do
      app.columns {}
      expect(app.components.length).to eq(1)
      expect(app.components.first).to be_a(StreamWeaver::Components::Columns)
    end

    it "passes widths option" do
      app.columns(widths: ['25%', '75%']) {}
      component = app.components.first
      expect(component.widths).to eq(['25%', '75%'])
    end

    it "passes gap option" do
      app.columns(gap: "2rem") {}
      component = app.components.first
      expect(component.instance_variable_get(:@options)).to include(gap: "2rem")
    end

    it "captures column children" do
      app.columns do
        column { text "Left" }
        column { text "Right" }
      end

      columns = app.components.first
      expect(columns.children.length).to eq(2)
      expect(columns.children[0]).to be_a(StreamWeaver::Components::Column)
      expect(columns.children[1]).to be_a(StreamWeaver::Components::Column)
    end

    it "maintains component order in parent after columns" do
      app.text("Before")
      app.columns { column { text "Inside" } }
      app.text("After")

      expect(app.components.length).to eq(3)
      expect(app.components[0]).to be_a(StreamWeaver::Components::Text)
      expect(app.components[1]).to be_a(StreamWeaver::Components::Columns)
      expect(app.components[2]).to be_a(StreamWeaver::Components::Text)
    end
  end

  describe "#column" do
    it "adds Column component within columns context" do
      app.columns do
        column {}
      end

      columns = app.components.first
      expect(columns.children.length).to eq(1)
      expect(columns.children.first).to be_a(StreamWeaver::Components::Column)
    end

    it "captures nested components" do
      app.columns do
        column do
          header4 "Work"
          text "Engineer"
        end
      end

      columns = app.components.first
      column = columns.children.first
      expect(column.children.length).to eq(2)
      expect(column.children[0]).to be_a(StreamWeaver::Components::Header)
      expect(column.children[1]).to be_a(StreamWeaver::Components::Text)
    end

    it "supports nested cards and collapsibles" do
      app.columns do
        column do
          card { text "Card content" }
        end
        column do
          collapsible "Details" do
            text "Collapsible content"
          end
        end
      end

      columns = app.components.first
      left_column = columns.children[0]
      right_column = columns.children[1]

      expect(left_column.children.first).to be_a(StreamWeaver::Components::Card)
      expect(right_column.children.first).to be_a(StreamWeaver::Components::Collapsible)
    end

    it "passes class option to column" do
      app.columns do
        column(class: "sidebar") { text "Content" }
      end

      columns = app.components.first
      column = columns.children.first
      expect(column.instance_variable_get(:@options)).to include(class: "sidebar")
    end
  end

  describe "Monica-style layout" do
    it "supports sidebar + main content pattern" do
      app.columns(widths: ['30%', '70%']) do
        column do
          header4 "Work"
          text "Software Engineer"
          header4 "Location"
          text "San Francisco"
        end

        column do
          collapsible "Context" do
            markdown "Background info here..."
          end
          collapsible "Key Facts" do
            markdown "- Fact 1\n- Fact 2"
          end
        end
      end

      columns = app.components.first
      expect(columns.widths).to eq(['30%', '70%'])
      expect(columns.children.length).to eq(2)

      # Left sidebar
      left = columns.children[0]
      expect(left.children.length).to eq(4)

      # Right main content
      right = columns.children[1]
      expect(right.children.length).to eq(2)
      expect(right.children[0]).to be_a(StreamWeaver::Components::Collapsible)
    end
  end
end
