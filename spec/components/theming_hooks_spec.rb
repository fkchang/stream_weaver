# frozen_string_literal: true

RSpec.describe "stable sw- class hooks on structural components (stream_weaver-oeo, closes stream_weaver-lyb)" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  describe StreamWeaver::Components::Lane do
    it "forwards class:/style: onto the lane container (previously silently dropped)" do
      lane = described_class.new("Queue", class: "tyrion-lane", style: "min-width: 280px;")
      html = render_html(lane)
      expect(html).to include("sw-board__lane")
      expect(html).to include("tyrion-lane")
      expect(html).to include("min-width: 280px;")
    end
  end

  describe StreamWeaver::Components::Table do
    it "forwards class:/style: onto the <table> element (previously silently dropped)" do
      table = described_class.new(headers: ["A"], rows: [["1"]], class: "tyrion-table", style: "font-size: 12px;")
      html = render_html(table)
      expect(html).to include("sw-table")
      expect(html).to include("tyrion-table")
      expect(html).to include("font-size: 12px;")
      # the required base style survives alongside the user's style:
      expect(html).to include("border-collapse: collapse;")
    end
  end

  describe StreamWeaver::Components::NavItem do
    it "forwards class:/style: (previously silently dropped)" do
      item = described_class.new("Roadmap", href: "/roadmap", class: "tyrion-nav-item", style: "letter-spacing: 1px;")
      html = render_html(item)
      expect(html).to include("sw-navbar-item")
      expect(html).to include("tyrion-nav-item")
      expect(html).to include("letter-spacing: 1px;")
    end
  end

  describe StreamWeaver::Components::Modal do
    it "forwards class:/style: onto the dialog element (previously silently dropped)" do
      modal = described_class.new(:confirm, class: "tyrion-modal", style: "max-width: 640px;")
      html = render_html(modal)
      expect(html).to include("sw-modal")
      expect(html).to include("tyrion-modal")
      expect(html).to include("max-width: 640px;")
    end
  end

  describe StreamWeaver::Components::Button do
    it "emits the sw-button hook alongside the legacy .btn classes" do
      button = described_class.new("Submit", 1)
      html = render_html(button)
      expect(html).to match(/class="sw-button btn btn-primary/)
    end

    it "still emits sw-button under style: :none (identifying hook, no forced visual style)" do
      button = described_class.new("Bare", 1, style: :none, class: "my-own-class")
      html = render_html(button)
      expect(html).to match(/class="sw-button my-own-class/)
      expect(html).not_to include("btn-primary")
    end
  end

  describe StreamWeaver::Components::Card do
    it "emits sw-card alongside the legacy .card class" do
      html = render_html(described_class.new)
      expect(html).to match(/class="card sw-card/)
    end
  end

  describe StreamWeaver::Components::CardHeader do
    it "emits sw-card-header alongside the legacy .card-header class" do
      html = render_html(described_class.new("Title"))
      expect(html).to match(/class="card-header sw-card-header/)
    end
  end

  describe StreamWeaver::Components::CardBody do
    it "emits sw-card-body alongside the legacy .card-body class, and now forwards class:/style:" do
      body = described_class.new(class: "tyrion-card-body", style: "padding: 0;")
      html = render_html(body)
      expect(html).to include("card-body sw-card-body")
      expect(html).to include("tyrion-card-body")
      expect(html).to include("padding: 0;")
    end
  end

  describe StreamWeaver::Components::CardFooter do
    it "emits sw-card-footer alongside the legacy .card-footer class, and now forwards class:/style:" do
      footer = described_class.new(class: "tyrion-card-footer", style: "justify-content: flex-start;")
      html = render_html(footer)
      expect(html).to include("card-footer sw-card-footer")
      expect(html).to include("tyrion-card-footer")
      expect(html).to include("justify-content: flex-start;")
    end
  end

  describe "status_badge DSL (closes stream_weaver-lyb's .status-badge collision)" do
    let(:status_badge_component) do
      Class.new(StreamWeaver::Components::Base) do
        def initialize(status, reasoning)
          @status = status
          @reasoning = reasoning
        end

        def render(view, state)
          view.adapter.render_status_badge(view, @status, @reasoning, state)
        end

        def children
          []
        end
      end
    end

    it "emits sw-status-badge hooks alongside the legacy unprefixed classes" do
      component = status_badge_component.new(:strong, "looks good")
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)

      expect(html).to include("status-badge sw-status-badge status-badge-strong sw-status-badge--strong")
      expect(html).to include("status-badge-icon sw-status-badge__icon")
      expect(html).to include("status-badge-label sw-status-badge__label")
      expect(html).to include("status-badge-reasoning sw-status-badge__reasoning")
    end
  end

  describe "sidebar-section utility class (closes stream_weaver-lyb's .sidebar-section collision)" do
    it "the CSS also styles .sw-sidebar-section (a user applies it via class:, no dedicated component)" do
      app = StreamWeaver::App.new("Title") { text "hi" }
      state = {}
      app.rebuild_with_state(state)
      html = StreamWeaver::Views::AppView.new(app, state, adapter).call

      expect(html).to match(/\.sidebar-section,\s*\.sw-sidebar-section\s*\{/)
    end
  end
end
