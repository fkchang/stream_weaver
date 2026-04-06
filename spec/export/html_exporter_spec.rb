# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe StreamWeaver::Export::HtmlExporter do
  let(:simple_app) do
    StreamWeaver::App.new("Test Export") do
      text "Hello World"
    end
  end

  let(:complex_app) do
    StreamWeaver::App.new("Complex Export") do
      hero { header1 "Welcome" }
      prose { text "Some content" }
      pullquote "A great quote", attribution: "Author"
      dir_tree "src/\n  app.rb [modified]"
      legend items: [{ color: "#22c55e", label: "New" }]
      flow_arrow label: "next step"
    end
  end

  # =========================================
  # Initialization
  # =========================================

  describe "#initialize" do
    it "accepts an app" do
      exporter = described_class.new(simple_app)
      expect(exporter).to be_a(described_class)
    end

    it "accepts state" do
      exporter = described_class.new(simple_app, state: { name: "test" })
      expect(exporter).to be_a(described_class)
    end
  end

  # =========================================
  # to_html
  # =========================================

  describe "#to_html" do
    it "produces a valid HTML document" do
      html = described_class.new(simple_app).to_html
      expect(html).to include("<!DOCTYPE html>")
      expect(html).to include("<html")
      expect(html).to include("</html>")
      expect(html).to include("<head>")
      expect(html).to include("<body>")
    end

    it "includes the app title" do
      html = described_class.new(simple_app).to_html
      expect(html).to include("<title>Test Export</title>")
    end

    it "includes the rendered body content" do
      html = described_class.new(simple_app).to_html
      expect(html).to include("Hello World")
    end

    it "includes meta charset and viewport" do
      html = described_class.new(simple_app).to_html
      expect(html).to include('charset="utf-8"')
      expect(html).to include('viewport')
    end

    it "includes Alpine.js CDN" do
      html = described_class.new(simple_app).to_html
      expect(html).to include("alpinejs")
    end

    it "includes HTMX CDN" do
      html = described_class.new(simple_app).to_html
      expect(html).to include("htmx.org")
    end

    it "includes Google Fonts link" do
      html = described_class.new(simple_app).to_html
      expect(html).to include("fonts.googleapis.com")
    end

    it "includes visual skills CSS custom properties" do
      html = described_class.new(simple_app).to_html
      expect(html).to include("--sw-bg")
      expect(html).to include("--sw-text")
    end

    it "renders hero content" do
      html = described_class.new(complex_app).to_html
      expect(html).to include("sw-hero")
      expect(html).to include("Welcome")
    end

    it "renders prose content" do
      html = described_class.new(complex_app).to_html
      expect(html).to include("sw-prose")
    end

    it "renders pullquote content" do
      html = described_class.new(complex_app).to_html
      expect(html).to include("sw-pullquote")
      expect(html).to include("A great quote")
      expect(html).to include("Author")
    end

    it "renders dir_tree content" do
      html = described_class.new(complex_app).to_html
      expect(html).to include("sw-dir-tree")
    end

    it "renders legend content" do
      html = described_class.new(complex_app).to_html
      expect(html).to include("sw-legend")
    end

    it "renders flow_arrow content" do
      html = described_class.new(complex_app).to_html
      expect(html).to include("sw-flow-arrow")
    end

    it "escapes HTML in title" do
      app = StreamWeaver::App.new("<script>alert('xss')</script>") do
        text "safe"
      end
      html = described_class.new(app).to_html
      expect(html).not_to include("<script>alert")
      expect(html).to include("&lt;script&gt;")
    end
  end

  # =========================================
  # export (file output)
  # =========================================

  describe "#export" do
    it "writes HTML to a file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "output.html")
        exporter = described_class.new(simple_app)
        result = exporter.export(path: path)

        expect(result).to eq(path)
        expect(File.exist?(path)).to be true
        content = File.read(path)
        expect(content).to include("<!DOCTYPE html>")
        expect(content).to include("Hello World")
      end
    end

    it "creates intermediate directories" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "sub", "dir", "output.html")
        exporter = described_class.new(simple_app)
        exporter.export(path: path)

        expect(File.exist?(path)).to be true
      end
    end

    it "inlines local images when inline_images: true" do
      Dir.mktmpdir do |dir|
        # Create a tiny PNG file
        png_path = File.join(dir, "test.png")
        # Minimal 1x1 transparent PNG
        png_data = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
        File.binwrite(png_path, png_data)

        app = StreamWeaver::App.new("Image Test") do
          image_block png_path, alt: "test"
        end

        output_path = File.join(dir, "output.html")
        exporter = described_class.new(app)
        exporter.export(path: output_path, inline_images: true)

        content = File.read(output_path)
        expect(content).to include("data:image/png;base64,")
      end
    end
  end

  # =========================================
  # Class-level .export convenience method
  # =========================================

  describe ".export" do
    it "exports via class method" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "output.html")
        result = described_class.export(simple_app, path: path)

        expect(result).to eq(path)
        expect(File.exist?(path)).to be true
      end
    end
  end

  # =========================================
  # CDN script collection
  # =========================================

  describe "CDN script collection" do
    it "does not include Mermaid CDN when no mermaid components" do
      html = described_class.new(simple_app).to_html
      expect(html).not_to include("mermaid")
    end

    it "does not include Chart.js CDN when no chart components" do
      html = described_class.new(simple_app).to_html
      expect(html).not_to include("chart.js")
    end

    it "does not include Prism.js CDN when no code blocks" do
      html = described_class.new(simple_app).to_html
      expect(html).not_to include("prismjs")
    end
  end

  # =========================================
  # Custom theme CSS
  # =========================================

  describe "theme CSS" do
    it "includes custom theme CSS when a registered theme is used" do
      StreamWeaver.register_theme(:test_export, {
        color_primary: "#ff0000"
      })

      app = StreamWeaver::App.new("Themed", theme: :test_export) do
        text "themed"
      end

      html = described_class.new(app).to_html
      expect(html).to include("sw-theme-test_export")
      expect(html).to include("#ff0000")
    end
  end
end
