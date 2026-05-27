# frozen_string_literal: true

RSpec.describe StreamWeaver::Fonts do
  describe ".google_fonts_href" do
    it "returns nil when fonts list is empty" do
      expect(described_class.google_fonts_href([])).to be_nil
    end

    it "builds a URL from a string entry" do
      href = described_class.google_fonts_href(["Cinzel:wght@400;700"])
      expect(href).to start_with("https://fonts.googleapis.com/css2?")
      expect(href).to include("family=Cinzel:wght@400;700")
      expect(href).to end_with("&display=swap")
    end

    it "builds a URL from a hash entry with :google key" do
      href = described_class.google_fonts_href([{ google: "Lora:ital,wght@1,400" }])
      expect(href).to include("family=Lora:ital,wght@1,400")
    end

    it "combines multiple families into one URL" do
      href = described_class.google_fonts_href([
        "Cinzel:wght@400",
        { google: "Lora:ital,wght@1,400" }
      ])
      expect(href).to include("family=Cinzel:wght@400")
      expect(href).to include("family=Lora:ital,wght@1,400")
    end

    it "ignores self-hosted entries" do
      href = described_class.google_fonts_href([
        { src: "/fonts/custom.woff2", family: "Custom" }
      ])
      expect(href).to be_nil
    end
  end

  describe ".google_fonts?" do
    it "returns true for string entries" do
      expect(described_class.google_fonts?(["Cinzel:wght@400"])).to be true
    end

    it "returns true for hash entries with :google" do
      expect(described_class.google_fonts?([{ google: "Lora" }])).to be true
    end

    it "returns false for empty list" do
      expect(described_class.google_fonts?([])).to be false
    end

    it "returns false for only self-hosted entries" do
      expect(described_class.google_fonts?([{ src: "/f.woff2", family: "X" }])).to be false
    end
  end

  describe "HTML injection — <link> tags in <head>" do
    def render_head(app)
      state = {}
      app.rebuild_with_state(state)
      StreamWeaver::Views::AppView.new(app, state, StreamWeaver::Adapter::AlpineJS.new).call
    end

    it "emits a <link> for declared Google fonts" do
      a = StreamWeaver::App.new("Test", fonts: [{ google: "Cinzel:wght@400;700" }]) {}
      html = render_head(a)
      expect(html).to include("Cinzel")
      expect(html).to match(%r{<link [^>]*href="https://fonts.googleapis.com/css2[^"]*Cinzel})
    end

    it "combines multiple families in one link" do
      a = StreamWeaver::App.new("Test", fonts: [
        { google: "Cinzel:wght@400" },
        { google: "Lora:ital,wght@1,400" }
      ]) {}
      html = render_head(a)
      # Only one custom fonts link tag (combined URL), plus the built-in one
      custom_links = html.scan(%r{googleapis\.com/css2\?[^"]+}).uniq
      # The combined custom URL should contain both families
      combined = custom_links.find { |u| u.include?("Cinzel") }
      expect(combined).to include("Lora")
    end

    it "emits preconnect hints when fonts are declared" do
      a = StreamWeaver::App.new("Test", fonts: [{ google: "Inter:wght@400" }]) {}
      html = render_head(a)
      expect(html).to include("fonts.googleapis.com")
      expect(html).to include("fonts.gstatic.com")
    end

    it "emits no extra link when fonts list is empty (default)" do
      a = StreamWeaver::App.new("Test") {}
      html = render_head(a)
      # The built-in fonts link is present; no second custom link
      custom_links = html.scan(%r{googleapis\.com/css2\?[^"]+})
      expect(custom_links.length).to eq(1)
    end
  end
end
