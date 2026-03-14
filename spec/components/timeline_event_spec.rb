# frozen_string_literal: true

RSpec.describe "TimelineEvent Component" do
  describe StreamWeaver::Components::TimelineEvent do
    let(:defaults) do
      { index: 0, event_type: :phase, timestamp: "10:00:00", label: "launch" }
    end

    it "initializes with required attributes" do
      te = described_class.new(**defaults)
      expect(te.index).to eq(0)
      expect(te.event_type).to eq(:phase)
      expect(te.timestamp).to eq("10:00:00")
      expect(te.label).to eq("launch")
    end

    it "defaults fields to empty hash" do
      te = described_class.new(**defaults)
      expect(te.fields).to eq({})
    end

    it "defaults expanded to false" do
      te = described_class.new(**defaults)
      expect(te.expanded).to be false
    end

    it "accepts fields hash" do
      te = described_class.new(**defaults, fields: { run_id: "abc" })
      expect(te.fields[:run_id]).to eq("abc")
    end

    it "normalizes event_type to symbol" do
      te = described_class.new(**defaults.merge(event_type: "snapshot"))
      expect(te.event_type).to eq(:snapshot)
    end

    it "falls back to :phase for unknown event_type" do
      te = described_class.new(**defaults.merge(event_type: :unknown))
      expect(te.event_type).to eq(:phase)
    end

    StreamWeaver::Components::TimelineEvent::TYPES.each do |type|
      it "accepts valid type #{type}" do
        te = described_class.new(**defaults.merge(event_type: type))
        expect(te.event_type).to eq(type)
      end
    end
  end

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders with type-specific CSS class" do
      te = StreamWeaver::Components::TimelineEvent.new(
        index: 0, event_type: :phase, timestamp: "10:00:00", label: "launch"
      )
      html = render_html(te)
      expect(html).to include("sw-timeline-event--phase")
    end

    it "renders index, badge, timestamp, and label" do
      te = StreamWeaver::Components::TimelineEvent.new(
        index: 3, event_type: :snapshot, timestamp: "10:00:16", label: "state=working"
      )
      html = render_html(te)
      expect(html).to include("3")
      expect(html).to include("snapshot")
      expect(html).to include("10:00:16")
      expect(html).to include("state=working")
    end

    it "renders detail fields when provided" do
      te = StreamWeaver::Components::TimelineEvent.new(
        index: 0, event_type: :phase, timestamp: "10:00:00", label: "launch",
        fields: { run_id: "abc-123", phase: "launch" }
      )
      html = render_html(te)
      expect(html).to include("sw-timeline-event__detail")
      expect(html).to include("run_id:")
      expect(html).to include("abc-123")
      expect(html).to include("phase:")
      expect(html).to include("launch")
    end

    it "does not render detail section when no fields" do
      te = StreamWeaver::Components::TimelineEvent.new(
        index: 0, event_type: :phase, timestamp: "10:00:00", label: "launch"
      )
      html = render_html(te)
      expect(html).not_to include("sw-timeline-event__detail")
    end

    it "renders multiline values as pre blocks" do
      te = StreamWeaver::Components::TimelineEvent.new(
        index: 5, event_type: :intervention, timestamp: "10:00:22", label: "question",
        fields: { rendered_message: "INTENT: Clarify\nWHY: Jumped ahead" }
      )
      html = render_html(te)
      expect(html).to include("<pre")
      expect(html).to include("INTENT: Clarify")
    end

    it "uses Alpine.js x-data for toggle" do
      te = StreamWeaver::Components::TimelineEvent.new(
        index: 0, event_type: :phase, timestamp: "10:00:00", label: "launch",
        fields: { a: "b" }
      )
      html = render_html(te)
      expect(html).to include('x-data')
      expect(html).to include('x-show')
    end

    it "respects expanded: true" do
      te = StreamWeaver::Components::TimelineEvent.new(
        index: 0, event_type: :phase, timestamp: "10:00:00", label: "launch",
        fields: { a: "b" }, expanded: true
      )
      html = render_html(te)
      expect(html).to include("open: true")
    end

    %i[phase snapshot intervention timeout guard final].each do |type|
      it "renders #{type} with correct modifier class" do
        te = StreamWeaver::Components::TimelineEvent.new(
          index: 0, event_type: type, timestamp: "10:00:00", label: "test"
        )
        html = render_html(te)
        expect(html).to include("sw-timeline-event--#{type}")
      end
    end
  end

  describe "DisplayDSL#timeline_event" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        timeline_event index: 0, event_type: :phase, timestamp: "10:00:00", label: "launch"
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::TimelineEvent) }
      expect(component).not_to be_nil
      expect(component.label).to eq("launch")
    end

    it "passes fields through" do
      app = StreamWeaver::App.new("Test") do
        timeline_event index: 0, event_type: :snapshot, timestamp: "10:00:16",
                       label: "state=working", fields: { state: "working", busy: true }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::TimelineEvent) }
      expect(component.fields[:state]).to eq("working")
      expect(component.fields[:busy]).to eq(true)
    end
  end
end
