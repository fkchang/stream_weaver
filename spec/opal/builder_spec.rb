# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/shell"
require "stream_weaver/opal/builder"
require "stream_weaver/css"
require "stream_weaver/theme"
require "tmpdir"

RSpec.describe StreamWeaver::Opal::OpalBuilder do
  describe ".require_opal!" do
    it "raises a friendly, actionable error when the opal gem isn't installed" do
      allow(described_class).to receive(:require).with("opal").and_raise(LoadError)

      expect { described_class.require_opal! }.to raise_error(
        LoadError, "Opal features need the opal gem: gem install opal"
      )
    end

    it "loads opal successfully when it is installed" do
      expect { described_class.require_opal! }.not_to raise_error
    end
  end

  describe ".build" do
    let(:app_content) do
      <<~RUBY
        app "Test" do
          text "hello"
        end
      RUBY
    end

    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    it "creates the output directory" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(Dir.exist?(out)).to be true
    end

    it "writes index.html" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(File.exist?(File.join(out, "index.html"))).to be true
    end

    it "writes app.js" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(File.exist?(File.join(out, "app.js"))).to be true
    end

    it "includes Opal runtime in app.js" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      js = File.read(File.join(out, "app.js"))
      expect(js).to include("Opal")  # Opal runtime marker
    end

    it "writes sw-theme.css to output dir" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(File.exist?(File.join(out, "sw-theme.css"))).to be true
    end

    it "sw-theme.css contains visual_skills_css content" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      css = File.read(File.join(out, "sw-theme.css"))
      # spot-check a token unique to visual_skills_css
      expect(css).to include("--sw-bg")
    end

    it "sw-theme.css contains animation CSS content" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      css = File.read(File.join(out, "sw-theme.css"))
      # spot-check a token from animation_css
      expect(css).to include("sw-fade-in")
    end

    context "with theme: :editorial" do
      it "sw-theme.css contains Instrument Serif font identifier" do
        app_file = File.join(@tmpdir, "app.rb")
        File.write(app_file, app_content)
        out = File.join(@tmpdir, "dist")
        described_class.build(app_file, output_dir: out, theme: :editorial)
        css = File.read(File.join(out, "sw-theme.css"))
        expect(css).to include("Instrument Serif")
      end
    end

    context "with unknown theme string" do
      it "warns to stderr and still writes sw-theme.css without crashing" do
        app_file = File.join(@tmpdir, "app.rb")
        File.write(app_file, app_content)
        out = File.join(@tmpdir, "dist")
        expect { described_class.build(app_file, output_dir: out, theme: :nonexistent_theme) }
          .to output(/Unknown theme preset/).to_stderr
        expect(File.exist?(File.join(out, "sw-theme.css"))).to be true
      end
    end

    it "index.html includes sw-theme.css link when the file exists" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      html = File.read(File.join(out, "index.html"))
      expect(html).to include('href="sw-theme.css"')
    end

    it "index.html includes dark mode script" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      html = File.read(File.join(out, "index.html"))
      # dark mode inline script contains a unique identifier
      expect(html).to include("sw-theme-preference")
    end

    # Adapter::Static#render_mermaid writes the mermaid source into a data
    # attribute rather than element text (stream_weaver-mermaid-extension) --
    # sw-mermaid-zoom.js is the only thing that reads that shape, so an
    # opal-build output missing it would silently render every mermaid
    # diagram as an empty box. Bundled unconditionally, unlike mermaid.min.js
    # itself, since it is StreamWeaver's own code and has no CDN fallback.
    it "bundles sw-mermaid-zoom.js and wires it into index.html" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(File.exist?(File.join(out, "sw-mermaid-zoom.js"))).to be true
      html = File.read(File.join(out, "index.html"))
      expect(html).to include('src="sw-mermaid-zoom.js"')
    end
  end
end
