# frozen_string_literal: true

RSpec.describe "CodePreview Component" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

  def render_components(components)
    StreamWeaver::ComponentRenderer.render_html(adapter, components)
  end

  describe StreamWeaver::CodePreview do
    it "exposes a headless evaluator without a public state parameter" do
      expect(described_class.method(:evaluate).parameters).to eq([[:req, :source], [:key, :adapter]])
    end

    it "evaluates trusted display-only Ruby and returns rendered HTML" do
      html = described_class.evaluate("header2 'Proof'\ntext 'Rendered once'")

      expect(html).to include("Proof")
      expect(html).to include("Rendered once")
    end

    it "raises source errors for headless callers" do
      expect { described_class.evaluate("not_a_real_component 'x'") }
        .to raise_error(NameError)
    end

    it "rejects live controls in trusted snippets" do
      expect { described_class.evaluate("button 'Save'") }
        .to raise_error(ArgumentError, /display-only/)
    end

    it "rejects stateful form controls in trusted snippets" do
      expect { described_class.evaluate("select :choice, ['A', 'B']") }
        .to raise_error(ArgumentError, /display-only/)
    end

    it "rejects nested previews in trusted snippets" do
      expect { described_class.evaluate("code_preview \"text 'Nested'\"") }
        .to raise_error(ArgumentError, /display-only/)
    end

  end

  describe "DSL rendering" do
    it "accepts source as the first positional argument and preserves exact displayed source" do
      source = "text \"<Exact & visible>\"\n"
      components = StreamWeaver::FeedBuilder.build do
        code_preview(source, title: "Trusted snippet", file: "examples/proof.rb")
      end

      html = render_components(components)

      expect(html).to include('class="sw-code-preview sw-code-preview--side-by-side"')
      expect(html).to include('id="code-preview-')
      expect(html).to include("Trusted snippet")
      expect(html).to include("examples/proof.rb")
      expect(html).to include("&lt;Exact &amp; visible&gt;")
      expect(html).to include("text &quot;&lt;Exact &amp; visible&gt;&quot;")
    end

    it "renders side_by_side as preview then source regions" do
      components = StreamWeaver::FeedBuilder.build do
        code_preview("text 'Preview first'")
      end

      html = render_components(components)

      expect(html.index('sw-code-preview__preview')).to be < html.index('sw-code-preview__source')
    end

    it "renders stacked layout preview above code" do
      components = StreamWeaver::FeedBuilder.build do
        code_preview("text 'Stacked preview'", layout: :stacked)
      end

      html = render_components(components)

      expect(html).to include('class="sw-code-preview sw-code-preview--stacked"')
      expect(html.index('sw-code-preview__preview')).to be < html.index('sw-code-preview__source')
    end

    it "raises for unsupported layouts" do
      expect do
        StreamWeaver::FeedBuilder.build { code_preview("text 'x'", layout: :carousel) }
      end.to raise_error(ArgumentError, /unsupported code_preview layout/)
    end

    it "allocates digest ids and disambiguates repeated digest and explicit ids" do
      source = "text 'Same'"
      components = StreamWeaver::FeedBuilder.build do
        code_preview(source)
        code_preview(source)
        code_preview("text 'Explicit one'", id: "proof")
        code_preview("text 'Explicit two'", id: "proof")
      end

      ids = components.map(&:id)

      expect(ids[0]).to match(/\Acode-preview-[a-f0-9]{10}\z/)
      expect(ids[1]).to eq("#{ids[0]}-dup-2")
      expect(ids[2]).to eq("code-preview-proof")
      expect(ids[3]).to eq("code-preview-proof-dup-2")

      rendered_ids = render_components(components).scan(/<section id="([^"]+)"/).flatten
      expect(rendered_ids).to eq(ids)
      expect(rendered_ids.uniq).to eq(rendered_ids)
    end

    it "evaluates a snippet once while building the host render" do
      $sw_code_preview_calls = 0

      components = StreamWeaver::FeedBuilder.build do
        code_preview("$sw_code_preview_calls += 1\ntext \"calls #{$sw_code_preview_calls}\"")
      end
      render_components(components)
      render_components(components)

      expect($sw_code_preview_calls).to eq(1)
    ensure
      $sw_code_preview_calls = nil
    end

    it "shows honest visible errors while preserving the source" do
      source = "not_a_real_component \"<x & y>\"\ntext 'after'"
      components = StreamWeaver::FeedBuilder.build do
        code_preview(source)
      end

      html = render_components(components)

      expect(html).to include("sw-code-preview__error")
      expect(html).to include("NoMethodError")
      expect(html).to include("not_a_real_component")
      expect(html).to include("not_a_real_component &quot;&lt;x &amp; y&gt;&quot;")
      expect(html).to include("text &#39;after&#39;")
    end

    it "shows syntax errors without swallowing the source pane" do
      source = "text(\ntext 'after'"
      components = StreamWeaver::FeedBuilder.build do
        code_preview(source)
      end

      html = render_components(components)

      expect(html).to include("SyntaxError")
      expect(html).to include("text(")
      expect(html).to include("text &#39;after&#39;")
    end
  end

  describe "documentation" do
    it "documents the C005-shaped runtime boundary matrix" do
      docs = File.read(File.expand_path("../../docs/components_reference.md", __dir__), encoding: "UTF-8")

      expect(docs).to include("### Code Preview")
      expect(docs).to include('category: "examples/documentation"')
      expect(docs).to include("runtime:")
      expect(docs).to include('server: "supported"')
      expect(docs).to include('build: "supported"')
      expect(docs).to include('export: "supported_static_markup"')
      expect(docs).to include('canvas: "supported_static_markup"')
      expect(docs).to include('opal: "unsupported"')
      expect(docs).to include("trusted, self-contained, display-only Ruby")
    end
  end
end
