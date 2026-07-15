# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "rack/test"

# Generalizes the favicon local-path mechanism (build_favicon_href) to any
# local file: stylesheets: auto-detects a local path and serves it via the
# /sw-asset/ route instead of a base64 data URI, and local_asset(path) is
# the same mechanism as a standalone helper (e.g. for image src:).
# Path-traversal-safe: only files under the app's own script directory, or
# an explicitly passed assets_dirs:, are ever registered (stream_weaver-1lo).
RSpec.describe "local asset serving (stream_weaver-1lo)" do
  # App.new resolves "the calling script's directory" via caller_locations,
  # so every app built directly in this spec file has spec/ as its script
  # dir -- fixture files placed under spec/ (via a tmpdir *inside* spec/)
  # exercise the default allow-list; files under the system tmpdir exercise
  # assets_dirs: / the traversal guard.
  around do |example|
    Dir.mktmpdir("sw-local-asset-", File.dirname(__FILE__)) do |dir|
      @in_script_dir = dir
      example.run
    end
  end

  def write_fixture(dir, name, content)
    path = File.join(dir, name)
    File.write(path, content)
    path
  end

  describe "App#local_asset" do
    it "returns a /sw-asset/ URL for a file under the script's own directory" do
      css_path = write_fixture(@in_script_dir, "styles.css", ".x { color: red; }")
      app = StreamWeaver::App.new("Test") {}
      url = app.local_asset(css_path)
      expect(url).to match(%r{\A/sw-asset/[a-f0-9]+/styles\.css\z})
    end

    it "raises for a file that does not exist" do
      app = StreamWeaver::App.new("Test") {}
      expect { app.local_asset(File.join(@in_script_dir, "nope.css")) }
        .to raise_error(ArgumentError, /not found/)
    end

    it "raises for a real file outside the script directory and assets_dirs:" do
      Tempfile.create(["outside", ".css"]) do |f|
        f.write(".y {}")
        f.flush
        app = StreamWeaver::App.new("Test") {}
        expect { app.local_asset(f.path) }.to raise_error(ArgumentError, /outside/)
      end
    end

    it "allows a file under an explicit assets_dirs: entry" do
      Tempfile.create(["allowed", ".css"]) do |f|
        f.write(".z {}")
        f.flush
        app = StreamWeaver::App.new("Test", assets_dirs: [File.dirname(f.path)]) {}
        url = app.local_asset(f.path)
        expect(url).to match(%r{\A/sw-asset/[a-f0-9]+/})
      end
    end
  end

  describe "stylesheets: auto-detection" do
    it "resolves a local file path to a /sw-asset/ URL" do
      css_path = write_fixture(@in_script_dir, "site.css", ".a {}")
      app = StreamWeaver::App.new("Test", stylesheets: [css_path]) {}
      expect(app.stylesheets.first).to match(%r{\A/sw-asset/[a-f0-9]+/site\.css\z})
    end

    it "passes a plain URL through unchanged" do
      app = StreamWeaver::App.new("Test", stylesheets: ["https://example.com/x.css"]) {}
      expect(app.stylesheets).to eq(["https://example.com/x.css"])
    end

    it "passes a relative href that isn't a real local file through unchanged (backward compat)" do
      app = StreamWeaver::App.new("Test", stylesheets: ["/css/site.css"]) {}
      expect(app.stylesheets).to eq(["/css/site.css"])
    end

    it "raises when a stylesheets: entry is a real file outside the allowed directories" do
      Tempfile.create(["outside", ".css"]) do |f|
        f.write(".y {}")
        f.flush
        expect { StreamWeaver::App.new("Test", stylesheets: [f.path]) {} }
          .to raise_error(ArgumentError, /outside/)
      end
    end
  end

  describe "the /sw-asset/ route" do
    include Rack::Test::Methods

    let(:css_path) { write_fixture(@in_script_dir, "route.css", ".r { color: blue; }") }
    let(:png_path) { write_fixture(@in_script_dir, "pic.png", "\x89PNG\r\n\x1a\n".b) }
    let(:stream_weaver_app) do
      css = css_path
      png = png_path
      StreamWeaver::App.new("Test") do
        @sw_css_url = local_asset(css)
        @sw_png_url = local_asset(png)
      end
    end
    let(:app) { stream_weaver_app.generate }

    def asset_url(instance_var)
      stream_weaver_app.rebuild_with_state({})
      stream_weaver_app.instance_variable_get(instance_var)
    end

    it "serves the file with the correct content-type and body" do
      get asset_url(:@sw_css_url)
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("text/css")
      expect(last_response.body).to eq(".r { color: blue; }")
    end

    it "infers content-type from extension for images" do
      get asset_url(:@sw_png_url)
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("image/png")
    end

    it "sets an ETag and returns 304 for a matching If-None-Match" do
      url = asset_url(:@sw_css_url)
      get url
      etag = last_response.headers["ETag"]
      expect(etag).not_to be_nil

      header "If-None-Match", etag
      get url
      expect(last_response.status).to eq(304)
    end

    it "404s for an unregistered key" do
      get "/sw-asset/0000000000000000/nope.css"
      expect(last_response.status).to eq(404)
    end
  end
end
