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
      expect(html).to include('<body class="sw-theme-default sw-layout-default">')
    end

    it "wraps the body content in #app-container, as the canvas and reader do" do
      html = described_class.new(simple_app).to_html
      expect(html).to include('<div id="app-container">')
    end

    it "carries the app's theme and layout on the body class" do
      app = StreamWeaver::App.new("Themed") do
        use_theme :doc
        use_layout :wide
        text "hi"
      end
      html = described_class.new(app).to_html
      expect(html).to include('<body class="sw-theme-doc sw-layout-wide">')
    end

    it "emits the doc's use_stylesheet CSS unlayered, after the framework CSS" do
      app = StreamWeaver::App.new("Styled") do
        use_stylesheet "h1 { color: rebeccapurple; }"
        header1 "Hi"
      end
      html = described_class.new(app).to_html

      expect(html).to include("<style>h1 { color: rebeccapurple; }</style>")
      expect(html.index("h1 { color: rebeccapurple; }")).to be > html.index("@layer #{StreamWeaver::CSS::LAYER_NAME}")
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

  # These assert against a <script> tag shape, not a bare substring
  # ("mermaid", "chart.js", ...): the framework CSS PageShell emits mentions
  # sw-mermaid-zoom.js in a comment, so a bare-substring form would fail on a
  # document that loads no mermaid script at all. Shape (not the literal
  # CDN_* constant) so the spec still catches a wrong-URL regression instead
  # of only "not exactly today's URL".
  describe "CDN script collection" do
    it "does not include Mermaid CDN when no mermaid components" do
      html = described_class.new(simple_app).to_html
      expect(html).not_to match(%r{<script[^>]*mermaid}i)
    end

    it "does not include Chart.js CDN when no chart components" do
      html = described_class.new(simple_app).to_html
      expect(html).not_to match(%r{<script[^>]*chart\.js}i)
    end

    it "does not include Prism.js CDN when no code blocks" do
      html = described_class.new(simple_app).to_html
      expect(html).not_to match(%r{<script[^>]*prism}i)
    end

    # A static export never talks to a server -- htmx/idiomorph are dead
    # weight, and dead weight that fails to load under a CSP that blocks
    # external script-src (stream_weaver-4gs). Exercised against an
    # interactive component (tabs) so the assertion isn't just "an empty
    # doc has no scripts" -- htmx/idiomorph must be absent even when the
    # doc is exactly the kind that used to justify loading them.
    it "never includes htmx, regardless of components used" do
      app = StreamWeaver::App.new("Has Tabs") { tabs(:demo) { tab("A") { text "hi" } } }
      html = described_class.new(app).to_html
      expect(html).not_to match(%r{<script[^>]*htmx}i)
    end

    it "never includes idiomorph, regardless of components used" do
      app = StreamWeaver::App.new("Has Tabs") { tabs(:demo) { tab("A") { text "hi" } } }
      html = described_class.new(app).to_html
      expect(html).not_to match(%r{<script[^>]*idiomorph}i)
    end

    # Alpine is loaded only when the rendered body actually contains an
    # x-data directive -- checked against the rendered HTML itself, not an
    # allowlist of component classes (see ALPINE_DIRECTIVE). Loading it
    # unconditionally meant every export depended on an external script
    # that a CSP-locked-down viewer (SharePoint's HTML preview, etc.)
    # blocks outright.
    it "does not include Alpine.js when no component needs it" do
      html = described_class.new(simple_app).to_html
      expect(html).not_to match(%r{<script[^>]*alpinejs}i)
    end

    it "includes Alpine.js when the doc uses collapsible" do
      app = StreamWeaver::App.new("Has Collapsible") do
        collapsible("Details") { text "hidden" }
      end
      html = described_class.new(app).to_html
      expect(html).to match(%r{<script[^>]*alpinejs}i)
    end

    it "includes Alpine.js when the doc uses theme_toggle" do
      app = StreamWeaver::App.new("Has Theme Toggle") { theme_toggle }
      html = described_class.new(app).to_html
      expect(html).to match(%r{<script[^>]*alpinejs}i)
    end

    # Proves the detection is body-content-based, not a hardcoded list:
    # tabs was never in any Alpine allowlist here and still needs Alpine
    # (adapter/alpinejs.rb emits x-data="{ activeTab: ... }" for it).
    it "includes Alpine.js when the doc uses tabs, with no allowlist entry for it" do
      app = StreamWeaver::App.new("Has Tabs") do
        tabs(:demo) { tab("A") { text "hi" } }
      end
      html = described_class.new(app).to_html
      expect(html).to match(%r{<script[^>]*alpinejs}i)
    end

    # Mermaid needs no Alpine at all: sw-mermaid-zoom.js self-inits on
    # DOMContentLoaded/htmx:afterSwap (stream_weaver-4gs) rather than
    # relying on an x-init directive on the diagram element.
    it "does not include Alpine.js for a mermaid-only doc" do
      app = StreamWeaver::App.new("Has Mermaid") { mermaid "graph TD; A-->B;" }
      html = described_class.new(app).to_html
      expect(html).not_to match(%r{<script[^>]*alpinejs}i)
    end

    # disc-094: the gate used to key on Components::Chart -- the class the
    # generic `chart type:` DSL builds. Every shorthand (bar_chart, pie_chart,
    # ...) builds a ChartBase subclass instead, which is not a Chart, so the
    # CDN tag was omitted and the adapter's
    # `if (typeof Chart !== 'undefined')` x-init guard swallowed the failure:
    # empty box, console-silent. The gate keys on the family now, so a new
    # ChartBase subclass cannot silently drift out of coverage.
    #
    # Every chart DSL method is exercised, not a sample -- an allowlist that
    # covers "most" charts is the bug this describe block exists to prevent.
    describe "Chart.js inclusion for every chart DSL method" do
      chart_calls = {
        "chart"             => -> { chart type: :bar, data: { labels: %w[A B], datasets: [{ data: [1, 2] }] } },
        "bar_chart"         => -> { bar_chart labels: %w[A B], values: [1, 2] },
        "hbar_chart"        => -> { hbar_chart labels: %w[A B], values: [1, 2] },
        "line_chart"        => -> { line_chart labels: %w[A B], values: [1, 2] },
        "sparkline"         => -> { sparkline labels: %w[A B], values: [1, 2] },
        "area_chart"        => -> { area_chart labels: %w[A B], values: [1, 2] },
        "pie_chart"         => -> { pie_chart labels: %w[A B], values: [1, 2] },
        "doughnut_chart"    => -> { doughnut_chart labels: %w[A B], values: [1, 2] },
        "stacked_bar_chart" => -> { stacked_bar_chart data: { "Widgets" => [3, 5], "Gadgets" => [2, 4] } }
      }

      chart_calls.each do |dsl_method, build|
        context "#{dsl_method}" do
          let(:html) do
            app = StreamWeaver::App.new("Chart Export") { instance_exec(&build) }
            described_class.new(app).to_html
          end

          it "includes the Chart.js CDN script" do
            expect(html).to match(%r{<script[^>]*chart\.js}i)
          end

          # The CDN tag alone is not enough: the chart only draws if the
          # emitted init code actually reaches the Chart constructor. Without
          # this, a doc could load the library and still render an empty box.
          it "emits init code that constructs a Chart" do
            expect(html).to include("new Chart(")
          end
        end
      end

      # Charts nested inside a container still need the library -- the gate
      # walks children, and containers are where real docs put their charts.
      it "includes the Chart.js CDN for a chart nested in a container" do
        app = StreamWeaver::App.new("Nested Chart") do
          card { bar_chart labels: %w[A B], values: [1, 2] }
        end
        expect(described_class.new(app).to_html).to match(%r{<script[^>]*chart\.js}i)
      end

      # A ChartBase subclass defined after this gate was written must be
      # covered by it. Registering a throwaway subclass proves the check is
      # on the family, not on a list of names someone has to remember to
      # extend.
      it "covers a ChartBase subclass the gate has never heard of" do
        novel = Class.new(StreamWeaver::Components::BarChart)
        app = StreamWeaver::App.new("Novel Chart")
        app.components << novel.new(labels: %w[A B], values: [1, 2])
        expect(described_class.new(app).to_html).to match(%r{<script[^>]*chart\.js}i)
      end
    end
  end

  # =========================================
  # offline: (stream_weaver-dnq) -- inline mermaid's library so it
  # renders in a viewer whose CSP blocks external scripts entirely.
  # Stubs the network fetch: these specs are about the flag being wired
  # through the exporter correctly, not about actually reaching jsdelivr.
  # =========================================

  describe "offline:" do
    let(:mermaid_app) do
      StreamWeaver::App.new("Has Mermaid") { mermaid "graph TD; A-->B;" }
    end

    it "does not fetch anything for a doc with no mermaid component" do
      exporter = described_class.new(simple_app)
      expect(exporter).not_to receive(:fetch_url)
      exporter.to_html(offline: true)
    end

    it "inlines the fetched script instead of referencing mermaid's CDN" do
      exporter = described_class.new(mermaid_app)
      allow(exporter).to receive(:fetch_url)
        .with(described_class::CDN_MERMAID_OFFLINE).and_return("/* stubbed mermaid global */")

      html = exporter.to_html(offline: true)

      expect(html).to include("<script>/* stubbed mermaid global */</script>")
      expect(html).not_to match(%r{<script[^>]*mermaid\.esm})
    end

    it "still references the CDN when offline: is false (the default)" do
      html = described_class.new(mermaid_app).to_html
      expect(html).to match(%r{<script[^>]*mermaid\.esm})
    end

    it "raises OfflineAssetError with an actionable message when the fetch fails" do
      exporter = described_class.new(mermaid_app)
      allow(exporter).to receive(:fetch_url).and_raise(Timeout::Error, "execution expired")

      expect { exporter.to_html(offline: true) }
        .to raise_error(StreamWeaver::Export::OfflineAssetError, /needs network access/)
    end

    # A floating-version CDN response is untrusted-ish content interpolated
    # directly into a <script> element's raw text. The HTML tokenizer closes
    # a script at the first "</script" it sees, even inside a JS string --
    # today's mermaid build happens to already escape this in its own
    # output, but this can't depend on that holding for every future fetch.
    it "neutralizes a </script> in the fetched payload so it can't break out of the script tag" do
      exporter = described_class.new(mermaid_app)
      allow(exporter).to receive(:fetch_url)
        .and_return(%(var s = "</script><img src=x onerror=alert(1)>";))

      html = exporter.to_html(offline: true)

      expect(html).not_to include("</script><img")
      expect(html).to include('<\/script>')
    end

    it "neutralizes <!-- in the fetched payload (starts script-data-escaped state otherwise)" do
      exporter = described_class.new(mermaid_app)
      allow(exporter).to receive(:fetch_url).and_return(%(var s = "<!--<script>";))

      html = exporter.to_html(offline: true)

      expect(html).to include('<\!--')
    end

    # Regression guard: a first draft escaped every bare "</", not just
    # "</script" -- which corrupted real code. Mermaid's own minified
    # source contains the regex literal /</g (matches a literal "<"); a
    # blind "</" -> "<\/" replacement turned it into /<\/g, an invalid
    # regex literal -- a JS syntax error that silently broke the whole
    # inlined script (globalThis.mermaid never got set, so the offline
    # export fell straight through to the CDN it exists to avoid). Caught
    # by a live browser check under a CSP mirroring SharePoint's, not by
    # any spec -- this one pins that a "</" not followed by "script" is
    # left completely untouched.
    it "leaves a bare </ that isn't part of </script untouched" do
      exporter = described_class.new(mermaid_app)
      allow(exporter).to receive(:fetch_url).and_return(%(var pattern = /</g;))

      html = exporter.to_html(offline: true)

      expect(html).to include("<script>var pattern = /</g;</script>")
    end
  end

  describe "#fetch_url (used by offline:)" do
    # Direct coverage of the network-handling method itself, rather than
    # stubbing it away -- the house pattern for stubbing Net::HTTP by hand
    # (see spec/feed_spec.rb) applied to a real Net::HTTPResponse instance,
    # since #fetch_url's case/when dispatches on the response's actual
    # class (Net::HTTPSuccess/Net::HTTPRedirection), which a plain double
    # can't satisfy.
    subject(:exporter) { described_class.new(StreamWeaver::App.new("X") { text "hi" }) }

    def fake_response(klass, code:, body: nil, location: nil)
      res = klass.new("1.1", code, "status")
      res.instance_variable_set(:@read, true)
      res.body = body if body
      res['location'] = location if location
      res
    end

    it "returns the body on success" do
      allow(Net::HTTP).to receive(:start).and_return(fake_response(Net::HTTPOK, code: "200", body: "ok"))
      expect(exporter.send(:fetch_url, "https://example.com/x")).to eq("ok")
    end

    it "forces the body to UTF-8 even when the response is tagged ASCII-8BIT" do
      body = "hello".dup.force_encoding(Encoding::ASCII_8BIT)
      allow(Net::HTTP).to receive(:start).and_return(fake_response(Net::HTTPOK, code: "200", body: body))

      result = exporter.send(:fetch_url, "https://example.com/x")
      expect(result.encoding).to eq(Encoding::UTF_8)
    end

    it "follows a redirect and returns the second response's body" do
      first  = fake_response(Net::HTTPFound, code: "302", location: "https://example.com/y")
      second = fake_response(Net::HTTPOK, code: "200", body: "final")
      allow(Net::HTTP).to receive(:start).and_return(first, second)

      expect(exporter.send(:fetch_url, "https://example.com/x")).to eq("final")
    end

    it "resolves a relative Location against the redirecting URL" do
      # If this weren't resolved against the original URL, URI("/y") would
      # have a nil host and Net::HTTP.start would raise instead of
      # returning the second response's body.
      first  = fake_response(Net::HTTPFound, code: "302", location: "/y")
      second = fake_response(Net::HTTPOK, code: "200", body: "final")
      allow(Net::HTTP).to receive(:start).and_return(first, second)

      expect(exporter.send(:fetch_url, "https://example.com/x")).to eq("final")
    end

    it "refuses a redirect to a non-https URL" do
      allow(Net::HTTP).to receive(:start)
        .and_return(fake_response(Net::HTTPFound, code: "302", location: "http://example.com/y"))

      expect { exporter.send(:fetch_url, "https://example.com/x") }
        .to raise_error(/non-https/)
    end

    it "gives up after too many redirects" do
      allow(Net::HTTP).to receive(:start)
        .and_return(fake_response(Net::HTTPFound, code: "302", location: "https://example.com/x"))

      expect { exporter.send(:fetch_url, "https://example.com/x") }
        .to raise_error(/too many redirects/)
    end

    it "raises with the status code on a non-2xx/3xx response" do
      allow(Net::HTTP).to receive(:start).and_return(fake_response(Net::HTTPNotFound, code: "404"))

      expect { exporter.send(:fetch_url, "https://example.com/x") }
        .to raise_error(/HTTP 404/)
    end
  end

  # =========================================
  # DSL-string apps (canvas docs / history snapshots)
  # =========================================

  describe "apps built by instance_eval'ing a DSL string" do
    # A canvas doc has no block to rebuild from -- @block is nil -- so an
    # unguarded rebuild_with_state wiped every component and exported an
    # empty page (stream_weaver-65z).
    let(:dsl_app) do
      app = StreamWeaver::App.new("Doc")
      app.instance_eval(<<~DSL)
        header1 "Canvas Doc Title"
        text "Body paragraph from the DSL."
      DSL
      app
    end

    it "keeps its components instead of wiping them" do
      expect { described_class.new(dsl_app).to_html }
        .not_to change { dsl_app.components.size }
      expect(dsl_app.components.size).to eq(2)
    end

    it "renders the DSL's markup into the export" do
      html = described_class.new(dsl_app).to_html
      expect(html).to include("<h1")
      expect(html).to include("Canvas Doc Title")
      expect(html).to include("Body paragraph from the DSL.")
    end
  end

  # =========================================
  # Input contract: canvas-doc DSL fragments only
  # =========================================

  describe ".from_dsl" do
    it "builds an exporter from a bare DSL fragment" do
      html = described_class.from_dsl(%(header1 "From Fragment")).to_html
      expect(html).to include("From Fragment")
    end

    it "titles the document from the source filename" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "arch-notes.rb")
        File.write(path, %(text "hi"))
        expect(described_class.from_dsl_file(path).to_html).to include("<title>arch-notes</title>")
      end
    end

    it "rejects a full standalone app file with a message naming the expected input" do
      full_app = <<~RUBY
        require "stream_weaver"
        app = StreamWeaver::App.new("Standalone") do
          text "hi"
        end
        app.run!
      RUBY

      expect { described_class.from_dsl(full_app) }
        .to raise_error(StreamWeaver::Export::InvalidDslError, /canvas-doc DSL fragment/)
    end

    it "rejects a run! call even without App.new" do
      expect { described_class.from_dsl("my_app.run!") }
        .to raise_error(StreamWeaver::Export::InvalidDslError)
    end

    it "resolves relative image paths against the source file's directory" do
      Dir.mktmpdir do |dir|
        png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
        File.binwrite(File.join(dir, "pic.png"), png)
        path = File.join(dir, "doc.rb")
        File.write(path, %(image_block "pic.png", alt: "rel"))

        html = described_class.from_dsl_file(path).to_html(inline_images: true)
        expect(html).to include("data:image/png;base64,")
      end
    end
  end

  # =========================================
  # Download filename sanitization
  # =========================================

  describe ".export_filename" do
    it "keeps a well-formed doc name" do
      expect(described_class.export_filename("/docs/auth-flow.v2.rb")).to eq("auth-flow.v2.html")
    end

    it "replaces characters outside the DocStore allowlist, collapsing runs into one hyphen" do
      expect(described_class.export_filename("/docs/my doc (draft).rb")).to eq("my-doc-draft-.html")
    end

    it "collapses dot runs so no traversal survives" do
      expect(described_class.export_filename("/docs/..%2f..%2fetc.rb")).not_to include("..")
    end

    it "strips a leading non-alphanumeric so the result matches VALID_NAME" do
      name = described_class.export_filename("/docs/-leading.rb")
      expect(name).to eq("leading.html")
      expect(File.basename(name, ".html")).to match(StreamWeaver::Canvas::DocStore::VALID_NAME)
    end

    it "falls back to export.html when nothing usable is left" do
      expect(described_class.export_filename("/docs/___.rb")).to eq("export.html")
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
