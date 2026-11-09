# frozen_string_literal: true

require "tmpdir"
require "rack/test"
require "stream_weaver/canvas/bridge_server"
require "stream_weaver/canvas/reader"
require "stream_weaver/export/html_exporter"
require "stream_weaver/opal/builder"

RSpec.describe StreamWeaver::Delivery do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, "fonts"))
      File.binwrite(File.join(dir, "fonts", "probe.woff2"), "wOF2-probe")
      File.write(File.join(dir, "widget.css"), %(.w { background: url("fonts/probe.woff2"); } .r { background: url(https://x.test/a.png); }))
      File.write(File.join(dir, "widget.js"), "window.widgetLoaded = true;")
      example.run
    end
  end

  let(:css) { File.join(@dir, "widget.css") }
  let(:js) { File.join(@dir, "widget.js") }
  let(:font) { File.join(@dir, "fonts", "probe.woff2") }

  it "passes URLs, root-relative URLs and data: URIs through every delivery unchanged" do
    [described_class::Served.new, described_class::Inline.new, described_class::Copied.new(@dir)].each do |delivery|
      expect(delivery.ref("https://cdn.test/a.css", :stylesheet)).to eq('<link rel="stylesheet" href="https://cdn.test/a.css">')
      expect(delivery.ref("/app.css", :stylesheet)).to eq('<link rel="stylesheet" href="/app.css">')
      expect(delivery.ref("data:font/woff2;base64,AA", :font)).to eq('url("data:font/woff2;base64,AA")')
    end
  end

  describe described_class::Served do
    it "returns a /sw-asset URL that resolves back to the registered file" do
      tag = subject.ref(css, :stylesheet)
      key = tag[%r{/sw-asset/(\h+)/widget\.css}, 1]
      expect(StreamWeaver::ComponentAssets.resolve_file(key)).to eq(css)
      expect(subject.ref(js, :script)).to match(%r{\A<script src="/sw-asset/\h+/widget\.js"></script>\z})
      expect(subject.ref(font, :font)).to match(%r{\Aurl\("/sw-asset/\h+/probe\.woff2"\)\z})
    end
  end

  describe described_class::Inline do
    it "inlines a stylesheet with its relative url() as base64 and leaves remote ones alone" do
      tag = subject.ref(css, :stylesheet)
      expect(tag).to start_with("<style>").and end_with("</style>")
      expect(tag).to include(%(url("data:font/woff2;base64,#{Base64.strict_encode64('wOF2-probe')}")))
      expect(tag).to include("url(https://x.test/a.png)")
    end

    it "inlines scripts and fonts" do
      expect(subject.ref(js, :script)).to eq("<script>window.widgetLoaded = true;</script>")
      expect(subject.ref(font, :font)).to eq(%(url("data:font/woff2;base64,#{Base64.strict_encode64('wOF2-probe')}")))
    end

    it "delivers the file behind a /sw-asset URL" do
      served = StreamWeaver::Delivery::Served.new.ref(js, :script)[/src="([^"]+)"/, 1]
      expect(subject.ref(served, :script)).to eq("<script>window.widgetLoaded = true;</script>")
    end
  end

  describe described_class::Copied do
    it "copies files into root/sw-assets with relative hrefs, and the files a stylesheet names beside it" do
      out = File.join(@dir, "dist")
      delivery = described_class.new(out)
      href = delivery.ref(css, :stylesheet)[/href="([^"]+)"/, 1]
      expect(href).to start_with("sw-assets/")
      copied = File.read(File.join(out, href))
      font_name = copied[/url\("([^"]+)"\)/, 1]
      expect(File.binread(File.join(out, "sw-assets", font_name))).to eq("wOF2-probe")
      expect(delivery.ref(font, :font)).to match(%r{\Aurl\("sw-assets/\h+-probe\.woff2"\)\z})
    end
  end

  describe "a theme's self-hosted font on every host" do
    before do
      StreamWeaver.register_theme(:delivery_spec_theme, {}, fonts: [{ family: "Probe Sans", src: font }])
    end

    after { StreamWeaver.themes.delete(:delivery_spec_theme) }

    let(:dsl) { "use_theme :delivery_spec_theme\ntext 'hello'\n" }
    let(:face) { %r{@font-face \{ font-family: 'Probe Sans'; src: url\("([^"]+)"\) format\('woff2'\)} }

    it "standalone: served from /sw-asset by the app server" do
      app = StreamWeaver::App.new("T", theme: :delivery_spec_theme) { text "hi" }
      app.rebuild_with_state({})
      html = StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call
      expect(html[face, 1]).to start_with("/sw-asset/")
    end

    it "canvas: served from /sw-asset by the bridge" do
      server = StreamWeaver::Canvas::BridgeServer
      previous = server.bridge
      server.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      server.bridge.create_session("fonts", theme: :delivery_spec_theme)
      request = Rack::MockRequest.new(server)
      html = request.get("/canvas/fonts", "HTTP_HOST" => "localhost").body
      url = html[face, 1]
      expect(url).to start_with("/sw-asset/")
      response = request.get(url, "HTTP_HOST" => "localhost")
      expect(response.status).to eq(200)
      expect(response.content_type).to eq("font/woff2")
      expect(response.body).to eq("wOF2-probe")
    ensure
      server.bridge = previous
    end

    it "export: inlined as base64" do
      html = StreamWeaver::Export::HtmlExporter.from_dsl("text 'hi'", theme: :delivery_spec_theme).to_html
      expect(html[face, 1]).to eq("data:font/woff2;base64,#{Base64.strict_encode64('wOF2-probe')}")
    end

    it "opal: copied into the build" do
      app_file = File.join(@dir, "app.rb")
      File.write(app_file, "app 'T' do\nend\n")
      out = File.join(@dir, "dist")
      FileUtils.mkdir_p(out)
      builder = StreamWeaver::Opal::OpalBuilder.new(app_file, output_dir: out, theme: :delivery_spec_theme)
      capture = StringIO.new
      $stderr, previous = capture, $stderr
      %i[write_theme_css write_index_html].each { |step| builder.send(step) }
      $stderr = previous
      url = File.read(File.join(out, "index.html"))[face, 1]
      expect(url).to start_with("sw-assets/")
      expect(File.binread(File.join(out, url))).to eq("wOF2-probe")
    end
  end

  describe "a component's css_path and js_path on canvas" do
    it "lead the pushed content as /sw-asset tags the bridge serves" do
      stylesheet = css
      script = js
      klass = Class.new(StreamWeaver::Components::Base) do
        css_path stylesheet
        js_path script
        def render(view, _state) = view.div(class: "w") { "w" }
      end
      stub_const("StreamWeaver::DeliverySpecWidget", klass)
      StreamWeaver.register_component(klass, dsl: :delivery_spec_widget)

      server = StreamWeaver::Canvas::BridgeServer
      previous = server.bridge
      server.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      server.bridge.create_session("widget")
      server.bridge.handle_claude_message(type: "push", name: "widget", dsl: "delivery_spec_widget")
      request = Rack::MockRequest.new(server)
      html = request.get("/canvas/widget", "HTTP_HOST" => "localhost").body
      script_url = html[%r{<script src="(/sw-asset/\h+/widget\.js)"></script>}, 1]
      expect(html).to match(%r{<link rel="stylesheet" href="/sw-asset/\h+/widget\.css">})
      expect(request.get(script_url, "HTTP_HOST" => "localhost").body).to eq("window.widgetLoaded = true;")
    ensure
      server.bridge = previous
      StreamWeaver::ComponentRegistry.instance_variable_get(:@registry).delete(:delivery_spec_widget)
      StreamWeaver::DisplayDSL.send(:remove_method, :delivery_spec_widget) if StreamWeaver::DisplayDSL.method_defined?(:delivery_spec_widget)
    end
  end
end
