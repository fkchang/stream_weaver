# frozen_string_literal: true

RSpec.describe "Sidebar/Navbar/AppShell **options forwarding (stream_weaver-1lo)" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  describe StreamWeaver::Components::Sidebar do
    it "stores class:/style: in options" do
      sidebar = described_class.new(class: "tyrion-sidebar", style: "width: 280px;")
      expect(sidebar.options).to include(class: "tyrion-sidebar", style: "width: 280px;")
    end

    it "renders style:/class: passthrough on the sidebar container" do
      sidebar = described_class.new(class: "tyrion-sidebar", style: "width: 280px;")
      html = render_html(sidebar)
      expect(html).to include("sw-sidebar")
      expect(html).to include("tyrion-sidebar")
      expect(html).to include("width: 280px;")
    end
  end

  describe StreamWeaver::Components::Navbar do
    it "renders style:/class: passthrough on the nav container" do
      navbar = described_class.new(class: "tyrion-navbar", style: "gap: 2rem;")
      html = render_html(navbar)
      expect(html).to include("sw-navbar")
      expect(html).to include("tyrion-navbar")
      expect(html).to include("gap: 2rem;")
    end
  end

  describe StreamWeaver::Components::AppShell do
    it "stores class:/style: in options" do
      shell = described_class.new(class: "tyrion-shell", style: "--x: 1;")
      expect(shell.options).to include(class: "tyrion-shell", style: "--x: 1;")
    end

    it "renders style:/class: passthrough on the shell container" do
      shell = described_class.new(class: "tyrion-shell")
      html = render_html(shell)
      expect(html).to include("sw-app-shell")
      expect(html).to include("tyrion-shell")
    end

    it "keeps the sidebar-width/gap CSS custom properties when style: is also given" do
      shell = described_class.new(sidebar_width: "400px", style: "border: 1px solid red;")
      html = render_html(shell)
      expect(html).to include("--sw-shell-sidebar-width: 400px")
      expect(html).to include("border: 1px solid red;")
    end
  end
end
