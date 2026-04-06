# frozen_string_literal: true

RSpec.describe "ImageBlock Component (T4)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::ImageBlock do
    it "initializes with src" do
      ib = described_class.new("photo.png")
      expect(ib.src).to eq("photo.png")
    end

    it "defaults alt to empty string" do
      ib = described_class.new("photo.png")
      expect(ib.alt).to eq("")
    end

    it "defaults caption to nil" do
      ib = described_class.new("photo.png")
      expect(ib.caption).to be_nil
    end

    it "defaults base64 to false" do
      ib = described_class.new("photo.png")
      expect(ib.base64).to eq(false)
    end

    it "accepts alt option" do
      ib = described_class.new("photo.png", alt: "A beautiful photo")
      expect(ib.alt).to eq("A beautiful photo")
    end

    it "accepts caption option" do
      ib = described_class.new("photo.png", caption: "Figure 1")
      expect(ib.caption).to eq("Figure 1")
    end

    it "accepts base64 option" do
      ib = described_class.new("photo.png", base64: true)
      expect(ib.base64).to eq(true)
    end

    describe "#resolved_src" do
      it "returns src unchanged when base64 is false" do
        ib = described_class.new("https://example.com/photo.png")
        expect(ib.resolved_src).to eq("https://example.com/photo.png")
      end

      it "returns src unchanged when base64 is true but file does not exist" do
        ib = described_class.new("nonexistent.png", base64: true)
        expect(ib.resolved_src).to eq("nonexistent.png")
      end

      it "converts local file to data URI when base64 is true and file exists" do
        # Create a temporary file
        require 'tempfile'
        tmp = Tempfile.new(['test', '.png'])
        tmp.binmode
        tmp.write("\x89PNG\r\n\x1a\n") # PNG magic bytes
        tmp.close

        ib = described_class.new(tmp.path, base64: true)
        result = ib.resolved_src
        expect(result).to start_with("data:image/png;base64,")
        expect(result).to include(Base64.strict_encode64("\x89PNG\r\n\x1a\n"))

        tmp.unlink
      end

      it "detects JPEG MIME type" do
        require 'tempfile'
        tmp = Tempfile.new(['test', '.jpg'])
        tmp.write("fake jpeg")
        tmp.close

        ib = described_class.new(tmp.path, base64: true)
        expect(ib.resolved_src).to start_with("data:image/jpeg;base64,")

        tmp.unlink
      end

      it "detects SVG MIME type" do
        require 'tempfile'
        tmp = Tempfile.new(['test', '.svg'])
        tmp.write("<svg></svg>")
        tmp.close

        ib = described_class.new(tmp.path, base64: true)
        expect(ib.resolved_src).to start_with("data:image/svg+xml;base64,")

        tmp.unlink
      end
    end
  end

  # =========================================
  # HTML rendering via adapter
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders an image block with sw-image-block class" do
      ib = StreamWeaver::Components::ImageBlock.new("photo.png")
      html = render_html(ib)
      expect(html).to include('class="sw-image-block"')
    end

    it "renders a figure element" do
      ib = StreamWeaver::Components::ImageBlock.new("photo.png")
      html = render_html(ib)
      expect(html).to include("<figure")
      expect(html).to include("</figure>")
    end

    it "renders an img tag with src" do
      ib = StreamWeaver::Components::ImageBlock.new("photo.png")
      html = render_html(ib)
      expect(html).to include('src="photo.png"')
    end

    it "renders img with alt text" do
      ib = StreamWeaver::Components::ImageBlock.new("photo.png", alt: "A photo")
      html = render_html(ib)
      expect(html).to include('alt="A photo"')
    end

    it "renders caption when provided" do
      ib = StreamWeaver::Components::ImageBlock.new("photo.png", caption: "Figure 1")
      html = render_html(ib)
      expect(html).to include("<figcaption")
      expect(html).to include("Figure 1")
      expect(html).to include('class="sw-image-block__caption"')
    end

    it "does not render caption when not provided" do
      ib = StreamWeaver::Components::ImageBlock.new("photo.png")
      html = render_html(ib)
      expect(html).not_to include("<figcaption")
    end

    it "renders img with sw-image-block__img class" do
      ib = StreamWeaver::Components::ImageBlock.new("photo.png")
      html = render_html(ib)
      expect(html).to include('class="sw-image-block__img"')
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#image_block" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        image_block("photo.png", caption: "Figure 1")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ImageBlock) }
      expect(component).not_to be_nil
      expect(component.src).to eq("photo.png")
      expect(component.caption).to eq("Figure 1")
    end

    it "passes alt option" do
      app = StreamWeaver::App.new("Test") do
        image_block("photo.png", alt: "A photo")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ImageBlock) }
      expect(component.alt).to eq("A photo")
    end

    it "passes base64 option" do
      app = StreamWeaver::App.new("Test") do
        image_block("photo.png", base64: true)
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ImageBlock) }
      expect(component.base64).to eq(true)
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_image_block" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_image_block(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_image_block/)
    end
  end
end
