# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::CardHeader do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:mock_view) { double("view", adapter: adapter) }
  let(:state) { {} }

  describe "plain call (no badge/meta)" do
    it "renders exactly as before: plain div + h4, no new classes/layout" do
      header = described_class.new("Section Title")
      expect(mock_view).to receive(:div).with(class: "card-header").and_yield
      expect(mock_view).to receive(:h4).and_yield
      header.render(mock_view, state)
    end

    it "renders plain div with no h4 when no content given" do
      header = described_class.new
      expect(mock_view).to receive(:div).with(class: "card-header").and_yield
      expect(mock_view).not_to receive(:h4)
      header.render(mock_view, state)
    end
  end

  describe "badge: and meta: options" do
    it "renders a flex-row layout with badge, title (as h4), and meta" do
      header = described_class.new("C1 — Title", badge: "C1", meta: "scheduler secretary")

      expect(mock_view).to receive(:div).with(class: "card-header card-header--badged").and_yield
      expect(mock_view).to receive(:span).with(class: "card-header__badge").and_yield
      expect(mock_view).to receive(:h4).with(class: "card-header__title").and_yield
      expect(mock_view).to receive(:span).with(class: "card-header__meta").and_yield

      header.render(mock_view, state)
    end

    it "renders only the badge when meta is not given" do
      header = described_class.new("Title", badge: "C1")

      expect(mock_view).to receive(:div).with(class: "card-header card-header--badged").and_yield
      expect(mock_view).to receive(:span).with(class: "card-header__badge").and_yield
      expect(mock_view).to receive(:h4).with(class: "card-header__title").and_yield
      expect(mock_view).not_to receive(:span).with(class: "card-header__meta")

      header.render(mock_view, state)
    end

    it "renders only the meta when badge is not given" do
      header = described_class.new("Title", meta: "scheduler secretary")

      expect(mock_view).to receive(:div).with(class: "card-header card-header--badged").and_yield
      expect(mock_view).not_to receive(:span).with(class: "card-header__badge")
      expect(mock_view).to receive(:h4).with(class: "card-header__title").and_yield
      expect(mock_view).to receive(:span).with(class: "card-header__meta").and_yield

      header.render(mock_view, state)
    end

    it "renders a heading element for the title, not a span, for accessibility" do
      html = Class.new(Phlex::HTML) do
        define_method(:view_template) do
          StreamWeaver::Components::CardHeader.new("C1 — Title", badge: "C1", meta: "scheduler secretary").render(self, {})
        end
      end.new.call

      expect(html).to include('<h4 class="card-header__title">C1 — Title</h4>')
      expect(html).to include('<span class="card-header__badge">C1</span>')
      expect(html).to include('<span class="card-header__meta">scheduler secretary</span>')
    end
  end

  describe "DisplayDSL#card_header passthrough" do
    let(:dummy_class) do
      Class.new do
        include StreamWeaver::DisplayDSL

        def with_container(component, &block)
          component
        end
      end
    end

    it "passes badge:/meta: through when content is a String" do
      component = dummy_class.new.card_header("Title", badge: "C1", meta: "meta text")
      expect(component).to be_a(StreamWeaver::Components::CardHeader)
      expect(component.instance_variable_get(:@badge)).to eq("C1")
      expect(component.instance_variable_get(:@meta)).to eq("meta text")
    end

    it "passes badge:/meta: through when no content is given" do
      component = dummy_class.new.card_header(badge: "C1", meta: "meta text")
      expect(component).to be_a(StreamWeaver::Components::CardHeader)
      expect(component.instance_variable_get(:@badge)).to eq("C1")
      expect(component.instance_variable_get(:@meta)).to eq("meta text")
    end
  end
end
