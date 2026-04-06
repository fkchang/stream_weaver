# frozen_string_literal: true

RSpec.describe "CSS-Only Helpers (T13)" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  # =========================================
  # Hero
  # =========================================

  describe StreamWeaver::Components::Hero do
    it "initializes with empty children" do
      c = described_class.new
      expect(c.children).to eq([])
    end

    it "renders a div with sw-hero class" do
      c = described_class.new
      html = render_html(c)
      expect(html).to include("sw-hero")
    end

    it "renders children inside the hero" do
      c = described_class.new
      c.children = [StreamWeaver::Components::Text.new("Welcome")]
      html = render_html(c)
      expect(html).to include("sw-hero")
      expect(html).to include("Welcome")
    end
  end

  # =========================================
  # Prose
  # =========================================

  describe StreamWeaver::Components::Prose do
    it "initializes with dropcap: false by default" do
      c = described_class.new
      expect(c.dropcap).to be false
    end

    it "initializes with dropcap: true" do
      c = described_class.new(dropcap: true)
      expect(c.dropcap).to be true
    end

    it "renders a div with sw-prose class" do
      c = described_class.new
      html = render_html(c)
      expect(html).to include("sw-prose")
    end

    it "adds sw-prose--dropcap class when dropcap is true" do
      c = described_class.new(dropcap: true)
      html = render_html(c)
      expect(html).to include("sw-prose--dropcap")
    end

    it "does not add dropcap class on the element when dropcap is false" do
      c = described_class.new
      html = render_html(c)
      expect(html).to include('class="sw-prose"')
      expect(html).not_to include('class="sw-prose sw-prose--dropcap"')
    end

    it "renders children inside the prose container" do
      c = described_class.new
      c.children = [StreamWeaver::Components::Text.new("Long form text")]
      html = render_html(c)
      expect(html).to include("Long form text")
    end
  end

  # =========================================
  # Pullquote
  # =========================================

  describe StreamWeaver::Components::Pullquote do
    it "initializes with text" do
      c = described_class.new("Some quote")
      expect(c.text).to eq("Some quote")
    end

    it "initializes with attribution" do
      c = described_class.new("Some quote", attribution: "Author")
      expect(c.attribution).to eq("Author")
    end

    it "defaults attribution to nil" do
      c = described_class.new("Some quote")
      expect(c.attribution).to be_nil
    end

    it "renders a blockquote with sw-pullquote class" do
      c = described_class.new("Design is important")
      html = render_html(c)
      expect(html).to include("sw-pullquote")
      expect(html).to include("Design is important")
    end

    it "renders attribution when provided" do
      c = described_class.new("Design is important", attribution: "Steve Jobs")
      html = render_html(c)
      expect(html).to include("sw-pullquote__attribution")
      expect(html).to include("Steve Jobs")
    end

    it "does not render attribution element when nil" do
      c = described_class.new("Design is important")
      html = render_html(c)
      expect(html).not_to include('class="sw-pullquote__attribution"')
    end
  end

  # =========================================
  # DirTree
  # =========================================

  describe StreamWeaver::Components::DirTree do
    it "initializes with tree text" do
      c = described_class.new("src/\n  app.rb")
      expect(c.tree_text).to eq("src/\n  app.rb")
    end

    it "parses lines without status markers" do
      c = described_class.new("src/\n  app.rb")
      lines = c.parsed_lines
      expect(lines.length).to eq(2)
      expect(lines[0][:status]).to be_nil
      expect(lines[1][:status]).to be_nil
    end

    it "parses [new] status marker" do
      c = described_class.new("  new_file.rb [new]")
      lines = c.parsed_lines
      expect(lines[0][:status]).to eq(:new)
      expect(lines[0][:text]).to eq("  new_file.rb")
    end

    it "parses [modified] status marker" do
      c = described_class.new("  app.rb [modified]")
      lines = c.parsed_lines
      expect(lines[0][:status]).to eq(:modified)
      expect(lines[0][:text]).to eq("  app.rb")
    end

    it "parses [deleted] status marker" do
      c = described_class.new("  old.rb [deleted]")
      lines = c.parsed_lines
      expect(lines[0][:status]).to eq(:deleted)
      expect(lines[0][:text]).to eq("  old.rb")
    end

    it "renders a div with sw-dir-tree class" do
      c = described_class.new("src/\n  app.rb")
      html = render_html(c)
      expect(html).to include("sw-dir-tree")
    end

    it "renders color-coded status lines" do
      c = described_class.new("  app.rb [modified]\n  new.rb [new]\n  old.rb [deleted]")
      html = render_html(c)
      expect(html).to include("sw-dir-tree__line--modified")
      expect(html).to include("sw-dir-tree__line--new")
      expect(html).to include("sw-dir-tree__line--deleted")
    end

    it "renders monospace pre container" do
      c = described_class.new("src/")
      html = render_html(c)
      expect(html).to include("sw-dir-tree__pre")
    end
  end

  # =========================================
  # Legend
  # =========================================

  describe StreamWeaver::Components::Legend do
    it "initializes with items" do
      items = [{ color: "#22c55e", label: "New" }]
      c = described_class.new(items: items)
      expect(c.items).to eq(items)
    end

    it "renders a div with sw-legend class" do
      c = described_class.new(items: [{ color: "#22c55e", label: "New" }])
      html = render_html(c)
      expect(html).to include("sw-legend")
    end

    it "renders color dots" do
      c = described_class.new(items: [{ color: "#22c55e", label: "New" }])
      html = render_html(c)
      expect(html).to include("sw-legend__dot")
      expect(html).to include("#22c55e")
    end

    it "renders labels" do
      c = described_class.new(items: [{ color: "#22c55e", label: "New" }])
      html = render_html(c)
      expect(html).to include("sw-legend__label")
      expect(html).to include("New")
    end

    it "renders multiple items" do
      items = [
        { color: "#22c55e", label: "New" },
        { color: "#f59e0b", label: "Modified" }
      ]
      c = described_class.new(items: items)
      html = render_html(c)
      expect(html).to include("New")
      expect(html).to include("Modified")
    end
  end

  # =========================================
  # FlowArrow
  # =========================================

  describe StreamWeaver::Components::FlowArrow do
    it "initializes with nil label by default" do
      c = described_class.new
      expect(c.label).to be_nil
    end

    it "initializes with a label" do
      c = described_class.new(label: "transforms into")
      expect(c.label).to eq("transforms into")
    end

    it "renders a div with sw-flow-arrow class" do
      c = described_class.new
      html = render_html(c)
      expect(html).to include("sw-flow-arrow")
    end

    it "renders arrow line and head" do
      c = described_class.new
      html = render_html(c)
      expect(html).to include("sw-flow-arrow__line")
      expect(html).to include("sw-flow-arrow__head")
    end

    it "renders label when provided" do
      c = described_class.new(label: "transforms into")
      html = render_html(c)
      expect(html).to include("sw-flow-arrow__label")
      expect(html).to include("transforms into")
    end

    it "does not render label element when nil" do
      c = described_class.new
      html = render_html(c)
      expect(html).not_to include('class="sw-flow-arrow__label"')
    end
  end

  # =========================================
  # LayoutToggle
  # =========================================

  describe StreamWeaver::Components::LayoutToggle do
    it "initializes with default columns [1, 2, 3, 4]" do
      c = described_class.new
      expect(c.columns).to eq([1, 2, 3, 4])
    end

    it "initializes with custom columns" do
      c = described_class.new(columns: [1, 2, 3])
      expect(c.columns).to eq([1, 2, 3])
    end

    it "initializes with default target" do
      c = described_class.new
      expect(c.target).to eq(".sw-layout-target")
    end

    it "renders a div with sw-layout-toggle class" do
      c = described_class.new
      html = render_html(c)
      expect(html).to include("sw-layout-toggle")
    end

    it "renders buttons for each column count" do
      c = described_class.new(columns: [1, 2, 3])
      html = render_html(c)
      expect(html).to include("sw-layout-toggle__btn")
      # Count actual button elements (class="sw-layout-toggle__btn")
      expect(html.scan('class="sw-layout-toggle__btn"').length).to eq(3)
    end

    it "renders @click handlers with grid-template-columns" do
      c = described_class.new(target: ".my-grid", columns: [2])
      html = render_html(c)
      expect(html).to include("repeat(2,1fr)")
      expect(html).to include(".my-grid")
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL integration" do
    it "hero is available as DSL method" do
      app = StreamWeaver::App.new("Test") do
        hero { header1 "Title" }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Hero) }
      expect(component).not_to be_nil
      expect(component.children.length).to eq(1)
    end

    it "prose is available as DSL method" do
      app = StreamWeaver::App.new("Test") do
        prose(dropcap: true) { text "Long text" }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Prose) }
      expect(component).not_to be_nil
      expect(component.dropcap).to be true
    end

    it "pullquote is available as DSL method" do
      app = StreamWeaver::App.new("Test") do
        pullquote "Quote text", attribution: "Author"
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Pullquote) }
      expect(component).not_to be_nil
      expect(component.text).to eq("Quote text")
      expect(component.attribution).to eq("Author")
    end

    it "dir_tree is available as DSL method" do
      app = StreamWeaver::App.new("Test") do
        dir_tree "src/\n  app.rb [modified]"
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DirTree) }
      expect(component).not_to be_nil
    end

    it "legend is available as DSL method" do
      app = StreamWeaver::App.new("Test") do
        legend items: [{ color: "#22c55e", label: "New" }]
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Legend) }
      expect(component).not_to be_nil
    end

    it "flow_arrow is available as DSL method" do
      app = StreamWeaver::App.new("Test") do
        flow_arrow label: "transforms into"
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::FlowArrow) }
      expect(component).not_to be_nil
      expect(component.label).to eq("transforms into")
    end

    it "layout_toggle is available as DSL method" do
      app = StreamWeaver::App.new("Test") do
        layout_toggle target: ".my-grid", columns: [1, 2, 3]
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::LayoutToggle) }
      expect(component).not_to be_nil
      expect(component.columns).to eq([1, 2, 3])
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { adapter.send(:helpers_css) }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") && !l.strip.start_with?("html") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # Adapter::Base interface
  # =========================================

  describe "Adapter::Base interface" do
    let(:base_adapter) { StreamWeaver::Adapter::Base.new }

    %i[render_hero render_prose render_pullquote render_dir_tree
       render_legend render_flow_arrow render_layout_toggle].each do |method|
      it "#{method} raises NotImplementedError" do
        expect {
          base_adapter.send(method, nil, nil, nil)
        }.to raise_error(NotImplementedError, /#{method}/)
      end
    end
  end
end
