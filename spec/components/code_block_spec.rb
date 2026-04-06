# frozen_string_literal: true

RSpec.describe "CodeBlock Component (T4)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::CodeBlock do
    it "initializes with code" do
      cb = described_class.new("puts 'hello'")
      expect(cb.code).to eq("puts 'hello'")
    end

    it "defaults lang to nil" do
      cb = described_class.new("x = 1")
      expect(cb.lang).to be_nil
    end

    it "defaults file to nil" do
      cb = described_class.new("x = 1")
      expect(cb.file).to be_nil
    end

    it "defaults truncate to nil" do
      cb = described_class.new("x = 1")
      expect(cb.truncate).to be_nil
    end

    it "defaults scroll to true" do
      cb = described_class.new("x = 1")
      expect(cb.scroll).to eq(true)
    end

    it "accepts lang option" do
      cb = described_class.new("puts 'hi'", lang: "ruby")
      expect(cb.lang).to eq("ruby")
    end

    it "accepts file option" do
      cb = described_class.new("puts 'hi'", file: "src/app.rb")
      expect(cb.file).to eq("src/app.rb")
    end

    it "accepts truncate option" do
      cb = described_class.new("line1\nline2\nline3", truncate: 2)
      expect(cb.truncate).to eq(2)
    end

    it "accepts scroll: false" do
      cb = described_class.new("x = 1", scroll: false)
      expect(cb.scroll).to eq(false)
    end

    describe "#language_class" do
      it "returns language-ruby for lang: ruby" do
        cb = described_class.new("x = 1", lang: "ruby")
        expect(cb.language_class).to eq("language-ruby")
      end

      it "returns language-javascript for lang: javascript" do
        cb = described_class.new("x = 1", lang: "javascript")
        expect(cb.language_class).to eq("language-javascript")
      end

      it "returns language-none when no lang specified" do
        cb = described_class.new("x = 1")
        expect(cb.language_class).to eq("language-none")
      end
    end

    describe "#display_code" do
      it "returns full code when no truncation" do
        code = "line1\nline2\nline3"
        cb = described_class.new(code)
        expect(cb.display_code).to eq(code)
      end

      it "returns full code when truncate exceeds line count" do
        code = "line1\nline2"
        cb = described_class.new(code, truncate: 10)
        expect(cb.display_code).to eq(code)
      end

      it "truncates to specified number of lines" do
        code = "line1\nline2\nline3\nline4\nline5"
        cb = described_class.new(code, truncate: 2)
        expect(cb.display_code).to eq("line1\nline2\n")
      end
    end

    describe "#truncated?" do
      it "returns false when no truncation" do
        cb = described_class.new("line1\nline2")
        expect(cb.truncated?).to eq(false)
      end

      it "returns false when truncate exceeds line count" do
        cb = described_class.new("line1\nline2", truncate: 10)
        expect(cb.truncated?).to eq(false)
      end

      it "returns true when code exceeds truncate limit" do
        cb = described_class.new("line1\nline2\nline3", truncate: 2)
        expect(cb.truncated?).to eq(true)
      end
    end

    describe "#total_lines" do
      it "returns the number of lines" do
        cb = described_class.new("line1\nline2\nline3")
        expect(cb.total_lines).to eq(3)
      end

      it "returns 1 for single line" do
        cb = described_class.new("single line")
        expect(cb.total_lines).to eq(1)
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

    it "renders a code block container with sw-code-block class" do
      cb = StreamWeaver::Components::CodeBlock.new("puts 'hi'", lang: "ruby")
      html = render_html(cb)
      expect(html).to include('class="sw-code-block"')
    end

    it "renders code with language class" do
      cb = StreamWeaver::Components::CodeBlock.new("puts 'hi'", lang: "ruby")
      html = render_html(cb)
      expect(html).to include('class="language-ruby"')
    end

    it "renders the code content" do
      cb = StreamWeaver::Components::CodeBlock.new("puts 'hello world'", lang: "ruby")
      html = render_html(cb)
      expect(html).to include("puts &#39;hello world&#39;")
    end

    it "renders file header when file option is set" do
      cb = StreamWeaver::Components::CodeBlock.new("x = 1", file: "src/app.rb")
      html = render_html(cb)
      expect(html).to include('class="sw-code-block__header"')
      expect(html).to include("src/app.rb")
    end

    it "does not render file header when file is nil" do
      cb = StreamWeaver::Components::CodeBlock.new("x = 1")
      html = render_html(cb)
      # The class name appears in the inline CSS, but should not appear as a rendered HTML element
      expect(html).not_to include('class="sw-code-block__header"')
    end

    it "renders truncation indicator when code is truncated" do
      code = (1..20).map { |i| "line #{i}" }.join("\n")
      cb = StreamWeaver::Components::CodeBlock.new(code, truncate: 10)
      html = render_html(cb)
      expect(html).to include('class="sw-code-block__truncated"')
      expect(html).to include("10 more lines")
    end

    it "does not render truncation indicator when not truncated" do
      cb = StreamWeaver::Components::CodeBlock.new("short code")
      html = render_html(cb)
      # The class name appears in the inline CSS, but should not appear as a rendered HTML element
      expect(html).not_to include('class="sw-code-block__truncated"')
    end

    it "renders pre and code tags" do
      cb = StreamWeaver::Components::CodeBlock.new("x = 1", lang: "ruby")
      html = render_html(cb)
      expect(html).to include('class="sw-code-block__pre"')
      expect(html).to include("<code")
    end
  end

  # =========================================
  # Lazy CDN loading (Prism.js)
  # =========================================

  describe "lazy CDN loading" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(components)
      StreamWeaver::ComponentRenderer.render_html(adapter, components, state)
    end

    it "injects Prism.js CSS CDN link" do
      cb = StreamWeaver::Components::CodeBlock.new("x = 1", lang: "ruby")
      html = render_html([cb])
      expect(html).to include("prismjs")
      expect(html).to include("prism-tomorrow.min.css")
    end

    it "injects Prism.js core script" do
      cb = StreamWeaver::Components::CodeBlock.new("x = 1", lang: "ruby")
      html = render_html([cb])
      expect(html).to include("prism.min.js")
    end

    it "injects Prism.js autoloader plugin" do
      cb = StreamWeaver::Components::CodeBlock.new("x = 1", lang: "ruby")
      html = render_html([cb])
      expect(html).to include("prism-autoloader.min.js")
    end

    it "only injects CDN once for multiple code blocks" do
      cb1 = StreamWeaver::Components::CodeBlock.new("x = 1", lang: "ruby")
      cb2 = StreamWeaver::Components::CodeBlock.new("y = 2", lang: "python")
      html = render_html([cb1, cb2])
      css_occurrences = html.scan("prism-tomorrow.min.css").count
      expect(css_occurrences).to eq(1)
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:code_block_css) }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#code_block" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        code_block("puts 'hi'", lang: "ruby")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::CodeBlock) }
      expect(component).not_to be_nil
      expect(component.code).to eq("puts 'hi'")
      expect(component.lang).to eq("ruby")
    end

    it "passes file option" do
      app = StreamWeaver::App.new("Test") do
        code_block("x = 1", file: "src/app.rb")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::CodeBlock) }
      expect(component.file).to eq("src/app.rb")
    end

    it "passes truncate option" do
      app = StreamWeaver::App.new("Test") do
        code_block("line1\nline2\nline3", truncate: 2)
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::CodeBlock) }
      expect(component.truncate).to eq(2)
    end

    it "passes scroll option" do
      app = StreamWeaver::App.new("Test") do
        code_block("x = 1", scroll: false)
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::CodeBlock) }
      expect(component.scroll).to eq(false)
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_code_block" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_code_block(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_code_block/)
    end
  end
end
