# frozen_string_literal: true

RSpec.describe StreamWeaver::FeedBuilder do
  describe ".build" do
    it "returns an array of components" do
      components = described_class.build do
        text "Hello"
      end

      expect(components).to be_an(Array)
      expect(components.size).to eq(1)
      expect(components.first).to be_a(StreamWeaver::Components::Text)
    end

    it "builds stat_display components" do
      components = described_class.build do
        stat_display value: 42, label: "COUNT", color: :blue
      end

      expect(components.first).to be_a(StreamWeaver::Components::StatDisplay)
    end

    it "builds activity_item components" do
      components = described_class.build do
        activity_item time: "14:30", title: "Deploy", summary: "Completed", type: :task
      end

      expect(components.first).to be_a(StreamWeaver::Components::ActivityItem)
    end

    it "builds priority_item components" do
      components = described_class.build do
        priority_item priority: :critical, title: "Alert"
      end

      expect(components.first).to be_a(StreamWeaver::Components::PriorityItem)
    end

    it "supports nested containers (card with children)" do
      components = described_class.build do
        card do
          stat_display value: 100, label: "RPS", color: :green
        end
      end

      expect(components.size).to eq(1)
      card = components.first
      expect(card).to be_a(StreamWeaver::Components::Card)
      expect(card.children.size).to eq(1)
      expect(card.children.first).to be_a(StreamWeaver::Components::StatDisplay)
    end

    it "supports deeply nested containers" do
      components = described_class.build do
        div do
          card do
            vstack do
              text "nested"
            end
          end
        end
      end

      div = components.first
      expect(div).to be_a(StreamWeaver::Components::Div)
      card = div.children.first
      expect(card).to be_a(StreamWeaver::Components::Card)
      vstack = card.children.first
      expect(vstack).to be_a(StreamWeaver::Components::VStack)
      expect(vstack.children.first).to be_a(StreamWeaver::Components::Text)
    end

    it "builds badge components" do
      components = described_class.build do
        badge "5", variant: :danger
      end

      expect(components.first).to be_a(StreamWeaver::Components::Badge)
    end

    it "builds header components" do
      components = described_class.build do
        header2 "Title"
        header3 "Subtitle"
      end

      expect(components[0]).to be_a(StreamWeaver::Components::Header)
      expect(components[1]).to be_a(StreamWeaver::Components::Header)
    end

    it "builds grid containers" do
      components = described_class.build do
        grid columns: 3 do
          text "col1"
          text "col2"
          text "col3"
        end
      end

      grid = components.first
      expect(grid).to be_a(StreamWeaver::Components::Grid)
      expect(grid.children.size).to eq(3)
    end

    it "builds alert components" do
      components = described_class.build do
        alert variant: :warning, title: "Watch out" do
          text "Something happened"
        end
      end

      alert = components.first
      expect(alert).to be_a(StreamWeaver::Components::Alert)
      expect(alert.children.size).to eq(1)
    end

    it "builds progress_bar components" do
      components = described_class.build do
        progress_bar value: 75
      end

      expect(components.first).to be_a(StreamWeaver::Components::ProgressBar)
    end

    it "builds markdown components" do
      components = described_class.build do
        md "**bold**"
      end

      expect(components.first).to be_a(StreamWeaver::Components::Markdown)
    end
  end

  describe "omitted interactive methods" do
    it "does not define text_field" do
      builder = described_class.new
      expect(builder).not_to respond_to(:text_field)
    end

    it "does not define button" do
      builder = described_class.new
      expect(builder).not_to respond_to(:button)
    end

    it "does not define form" do
      builder = described_class.new
      expect(builder).not_to respond_to(:form)
    end

    it "does not define checkbox" do
      builder = described_class.new
      expect(builder).not_to respond_to(:checkbox)
    end

    it "does not define select" do
      builder = described_class.new
      expect(builder).not_to respond_to(:select)
    end

    it "does not define text_area" do
      builder = described_class.new
      expect(builder).not_to respond_to(:text_area)
    end

    it "does not define stream" do
      builder = described_class.new
      expect(builder).not_to respond_to(:stream)
    end
  end
end
