# frozen_string_literal: true

RSpec.describe "AnnotatedCode Component" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::AnnotatedCode do
    let(:code) do
      <<~RUBY
        class Fetcher
          def initialize(id)
            @id = id
          end

          def record
            @record ||= Record.find(@id)
          end
        end
      RUBY
    end

    let(:annotations) { [{ line: 2, note: "Constructor" }, { line: 7, note: "Memoized" }] }

    it "initializes with language and annotations" do
      ac = described_class.new(language: "ruby", annotations: annotations)
      expect(ac.language).to eq("ruby")
      expect(ac.annotations.length).to eq(2)
    end

    it "stores code via assignment and returns empty string when unset" do
      ac = described_class.new
      expect(ac.code).to eq("")
      ac.code = code
      expect(ac.code).to eq(code)
    end

    describe "#language_class" do
      it "returns language-ruby for ruby" do
        ac = described_class.new(language: "ruby")
        expect(ac.language_class).to eq("language-ruby")
      end

      it "returns language-none when no language" do
        ac = described_class.new
        expect(ac.language_class).to eq("language-none")
      end
    end

    describe "#annotated_lines" do
      it "returns a set of annotated line numbers" do
        ac = described_class.new(annotations: [{ line: 2, note: "A" }, { line: 7, note: "B" }])
        expect(ac.annotated_lines).to include(2, 7)
        expect(ac.annotated_lines.length).to eq(2)
      end

      it "returns empty set when no annotations" do
        ac = described_class.new
        expect(ac.annotated_lines).to be_empty
      end
    end

    describe "Annotation struct" do
      it "stores line and note" do
        ac = described_class.new(annotations: [{ line: 5, note: "Key step" }])
        ann = ac.annotations.first
        expect(ann.line).to eq(5)
        expect(ann.note).to eq("Key step")
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

    let(:code) do
      <<~'RUBY'
        def greet(name)
          puts "Hello, #{name}"
          puts "Done"
        end
      RUBY
    end

    let(:annotations) do
      [
        { line: 1, note: "Method signature" },
        { line: 2, note: "Output the greeting" }
      ]
    end

    # Criterion 3: Prism.js syntax highlighting
    it "injects Prism.js CDN for syntax highlighting" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: annotations)
      ac.code = code
      html = render_html(ac)
      expect(html).to include("prismjs")
      expect(html).to include("prism-tomorrow.min.css")
    end

    it "renders code with the language class for Prism.js" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: annotations)
      ac.code = code
      html = render_html(ac)
      expect(html).to include("language-ruby")
    end

    it "renders the code content" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: [])
      ac.code = "def greet\nend\n"
      html = render_html(ac)
      expect(html).to include("def greet")
    end

    # Criterion 4: annotation panel aligned to target line
    it "renders the outer container with sw-annotated-code class" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: annotations)
      ac.code = code
      html = render_html(ac)
      expect(html).to include("sw-annotated-code")
    end

    it "renders each annotation note text" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: annotations)
      ac.code = code
      html = render_html(ac)
      expect(html).to include("Method signature")
      expect(html).to include("Output the greeting")
    end

    it "renders the annotation panel element" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: annotations)
      ac.code = code
      html = render_html(ac)
      expect(html).to include("sw-annotated-code__panel")
    end

    # Criterion 5: annotated lines highlighted/marked
    it "renders highlighted class on annotated lines" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: [{ line: 1, note: "First" }])
      ac.code = code
      html = render_html(ac)
      expect(html).to include("sw-annotated-code__line--highlighted")
    end

    it "does not highlight non-annotated lines" do
      ac = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: [{ line: 1, note: "First" }])
      ac.code = "line1\nline2\nline3\n"
      html = render_html(ac)
      # Count HTML elements with the highlighted class (not CSS rule occurrences)
      highlights = html.scan(/class="[^"]*sw-annotated-code__line--highlighted[^"]*"/).length
      expect(highlights).to eq(1)
    end

    # Criterion 6: annotations do not overlap
    it "renders each annotation with a data-line attribute for alignment" do
      ac = StreamWeaver::Components::AnnotatedCode.new(
        language: "ruby",
        annotations: [{ line: 1, note: "A" }, { line: 2, note: "B" }]
      )
      ac.code = "x = 1\ny = 2\n"
      html = render_html(ac)
      expect(html).to include('data-line="1"')
      expect(html).to include('data-line="2"')
    end
  end

  # =========================================
  # Prism.js only loaded once
  # =========================================

  describe "lazy CDN loading" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    it "only injects Prism.js once when multiple annotated_code components render" do
      ac1 = StreamWeaver::Components::AnnotatedCode.new(language: "ruby", annotations: [])
      ac1.code = "x = 1\n"
      ac2 = StreamWeaver::Components::AnnotatedCode.new(language: "javascript", annotations: [])
      ac2.code = "var x = 1;\n"
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [ac1, ac2], state)
      expect(html.scan("prism-tomorrow.min.css").length).to eq(1)
    end
  end

  # =========================================
  # Out-of-range annotation line behaviour (pinned)
  # =========================================

  describe "out-of-range annotation lines" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    it "renders without error when annotation line exceeds code line count" do
      ac = StreamWeaver::Components::AnnotatedCode.new(
        language: "ruby",
        annotations: [{ line: 99, note: "Dangling" }]
      )
      ac.code = "x = 1\n"
      expect {
        StreamWeaver::ComponentRenderer.render_html(adapter, [ac], state)
      }.not_to raise_error
    end

    it "does not highlight any line when annotation is out of range" do
      ac = StreamWeaver::Components::AnnotatedCode.new(
        language: "ruby",
        annotations: [{ line: 99, note: "Dangling" }]
      )
      ac.code = "x = 1\n"
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [ac], state)
      highlights = html.scan(/class="[^"]*sw-annotated-code__line--highlighted[^"]*"/).length
      expect(highlights).to eq(0)
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#annotated_code" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        annotated_code(language: "ruby", annotations: [{ line: 1, note: "Start" }]) do
          "def foo\nend\n"
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::AnnotatedCode) }
      expect(component).not_to be_nil
      expect(component.language).to eq("ruby")
      expect(component.annotations.length).to eq(1)
      expect(component.code).to eq("def foo\nend\n")
    end

    it "captures code from the block" do
      app = StreamWeaver::App.new("Test") do
        annotated_code(language: "ruby", annotations: []) { "puts 'hi'\n" }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::AnnotatedCode) }
      expect(component.code).to eq("puts 'hi'\n")
    end

    it "defaults to empty code when no block given" do
      app = StreamWeaver::App.new("Test") do
        annotated_code(language: "ruby", annotations: [])
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::AnnotatedCode) }
      expect(component.code).to eq("")
    end
  end

  # =========================================
  # CSS sw- prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

    it "all CSS class selectors use sw- prefix" do
      css = adapter.send(:annotated_code_css)
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
      # Negative lookbehind excludes element-qualified classes like html.dark or body.theme
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/(?<![a-zA-Z])\.([\w][\w-]*)/).flatten
      }.uniq

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # Adapter::Base interface
  # =========================================

  describe "Adapter::Base#render_annotated_code" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_annotated_code(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_annotated_code/)
    end
  end
end
