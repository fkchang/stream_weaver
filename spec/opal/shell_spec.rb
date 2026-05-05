# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/shell"

RSpec.describe StreamWeaver::Opal::OpalShell do
  describe ".render" do
    let(:html) { described_class.render(title: "My App", app_js: "app.js") }

    it "includes DOCTYPE" do
      expect(html).to start_with("<!DOCTYPE html>")
    end

    it "includes the title" do
      expect(html).to include("<title>My App</title>")
    end

    it "loads morphdom from CDN" do
      expect(html).to include("morphdom")
    end

    it "includes the sw-app mount point" do
      expect(html).to include('id="sw-app"')
    end

    it "loads app.js" do
      expect(html).to include('src="app.js"')
    end

    it "calls SWRuntime.start() after scripts load" do
      expect(html).to include("SWRuntime.start()")
    end
  end

  describe ".render with theme/font/dark-mode params" do
    context "when dark_mode_script is provided" do
      let(:script) { "document.documentElement.classList.add('dark')" }
      let(:html) { described_class.render(dark_mode_script: script) }

      it "includes a script tag with the dark mode script" do
        expect(html).to include("<script>#{script}</script>")
      end
    end

    context "when google_fonts_url is provided" do
      let(:fonts_url) { "https://fonts.googleapis.com/css2?family=Inter&display=swap" }
      let(:html) { described_class.render(google_fonts_url: fonts_url) }

      it "includes a preconnect link to fonts.googleapis.com" do
        expect(html).to include('<link rel="preconnect" href="https://fonts.googleapis.com">')
      end

      it "includes a crossorigin preconnect link to fonts.gstatic.com" do
        expect(html).to include('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
      end

      it "includes a stylesheet link to the fonts URL" do
        expect(html).to include(%(<link rel="stylesheet" href="#{fonts_url}">))
      end
    end

    context "when theme_css is provided" do
      let(:html) { described_class.render(theme_css: "sw-theme.css") }

      it "includes a stylesheet link for the theme CSS" do
        expect(html).to include('<link rel="stylesheet" href="sw-theme.css">')
      end
    end

    context "when all three new params are nil (backward compatibility)" do
      let(:html) { described_class.render }

      it "does not include any dark mode script tag" do
        expect(html).not_to match(/<script>\s*<\/script>/)
      end

      it "does not include Google Fonts preconnect" do
        expect(html).not_to include("fonts.googleapis.com")
      end

      it "does not include a theme CSS link" do
        expect(html).not_to include("sw-theme.css")
      end
    end

    context "ordering — dark mode script appears before fonts and CSS links" do
      let(:script) { "document.documentElement.classList.add('dark')" }
      let(:fonts_url) { "https://fonts.googleapis.com/css2?family=Inter&display=swap" }
      let(:html) do
        described_class.render(
          dark_mode_script: script,
          google_fonts_url: fonts_url,
          theme_css: "sw-theme.css"
        )
      end

      it "dark mode script appears before Google Fonts preconnect" do
        dark_pos  = html.index("<script>#{script}</script>")
        fonts_pos = html.index("fonts.googleapis.com")
        expect(dark_pos).to be < fonts_pos
      end

      it "dark mode script appears before theme CSS link" do
        dark_pos  = html.index("<script>#{script}</script>")
        theme_pos = html.index("sw-theme.css")
        expect(dark_pos).to be < theme_pos
      end

      it "Google Fonts links appear before theme CSS link" do
        fonts_pos = html.index("fonts.googleapis.com")
        theme_pos = html.index("sw-theme.css")
        expect(fonts_pos).to be < theme_pos
      end
    end
  end
end
