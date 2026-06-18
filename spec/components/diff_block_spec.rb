# frozen_string_literal: true

RSpec.describe "DiffBlock Component" do
  describe StreamWeaver::Components::DiffBlock do
    let(:before_code) { "def greet\n  puts 'hi'\nend\n" }
    let(:after_code)  { "def greet(name)\n  puts \"Hello, \#{name}\"\nend\n" }

    it "initializes with language" do
      db = described_class.new(language: "ruby")
      expect(db.language).to eq("ruby")
    end

    it "defaults before_code and after_code to empty string" do
      db = described_class.new
      expect(db.before_code).to eq("")
      expect(db.after_code).to eq("")
    end

    it "accepts before_code and after_code via assignment" do
      db = described_class.new
      db.before_code = before_code
      db.after_code  = after_code
      expect(db.before_code).to eq(before_code)
      expect(db.after_code).to eq(after_code)
    end

    describe "#language_class" do
      it "returns language-ruby for ruby" do
        db = described_class.new(language: "ruby")
        expect(db.language_class).to eq("language-ruby")
      end

      it "returns language-none when no language" do
        db = described_class.new
        expect(db.language_class).to eq("language-none")
      end
    end

    describe "#parsed_lines" do
      it "returns empty array when both strings are empty" do
        db = described_class.new
        expect(db.parsed_lines).to eq([])
      end

      it "returns DiffLine structs" do
        db = described_class.new
        db.before_code = "old\n"
        db.after_code  = "new\n"
        lines = db.parsed_lines
        expect(lines).not_to be_empty
        expect(lines.first).to respond_to(:type, :old_num, :new_num, :prefix, :content)
      end

      it "marks removed lines with type :removed and '-' prefix" do
        db = described_class.new
        db.before_code = "old line\n"
        db.after_code  = "new line\n"
        removed = db.parsed_lines.select { |l| l.type == :removed }
        expect(removed).not_to be_empty
        expect(removed.all? { |l| l.prefix == "-" }).to be true
      end

      it "marks added lines with type :added and '+' prefix" do
        db = described_class.new
        db.before_code = "old line\n"
        db.after_code  = "new line\n"
        added = db.parsed_lines.select { |l| l.type == :added }
        expect(added).not_to be_empty
        expect(added.all? { |l| l.prefix == "+" }).to be true
      end

      it "marks unchanged context lines with type :context" do
        db = described_class.new
        db.before_code = "same\nold\nsame\n"
        db.after_code  = "same\nnew\nsame\n"
        context_lines = db.parsed_lines.select { |l| l.type == :context }
        expect(context_lines).not_to be_empty
      end

      it "tracks old line numbers on removed lines" do
        db = described_class.new
        db.before_code = "line1\nline2\n"
        db.after_code  = "line1\nchanged\n"
        removed = db.parsed_lines.select { |l| l.type == :removed }
        expect(removed.first.old_num).to be_a(Integer)
        expect(removed.first.old_num).to be > 0
      end

      it "tracks new line numbers on added lines" do
        db = described_class.new
        db.before_code = "line1\nold\n"
        db.after_code  = "line1\nnew\n"
        added = db.parsed_lines.select { |l| l.type == :added }
        expect(added.first.new_num).to be_a(Integer)
        expect(added.first.new_num).to be > 0
      end

      it "strips the prefix character from content" do
        db = described_class.new
        db.before_code = "old line\n"
        db.after_code  = "new line\n"
        removed = db.parsed_lines.select { |l| l.type == :removed }.first
        expect(removed.content).to eq("old line")
      end
    end
  end

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state)   { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    let(:before_code) { "def greet\n  puts 'hi'\nend\n" }
    let(:after_code)  { "def greet(name)\n  puts 'Hello'\nend\n" }

    def make_diff(language: "ruby")
      db = StreamWeaver::Components::DiffBlock.new(language: language)
      db.before_code = before_code
      db.after_code  = after_code
      db
    end

    it "renders without error when before and after differ" do
      expect { render_html(make_diff) }.not_to raise_error
    end

    it "renders removed lines with sw-diff-block__line--removed class" do
      html = render_html(make_diff)
      expect(html).to include("sw-diff-block__line--removed")
    end

    it "renders the '-' prefix character for removed lines" do
      html = render_html(make_diff)
      expect(html).to include("-")
    end

    it "renders added lines with sw-diff-block__line--added class" do
      html = render_html(make_diff)
      expect(html).to include("sw-diff-block__line--added")
    end

    it "renders the '+' prefix character for added lines" do
      html = render_html(make_diff)
      expect(html).to include("+")
    end

    it "renders context lines with sw-diff-block__line--context class" do
      html = render_html(make_diff)
      expect(html).to include("sw-diff-block__line--context")
    end

    it "renders a gutter element" do
      html = render_html(make_diff)
      expect(html).to include("sw-diff-block__gutter")
    end

    it "renders old and new line number gutter cells" do
      html = render_html(make_diff)
      expect(html).to include("sw-diff-block__gutter-old")
      expect(html).to include("sw-diff-block__gutter-new")
    end

    it "renders numeric line numbers in the gutter" do
      html = render_html(make_diff)
      expect(html).to match(/sw-diff-block__gutter-old[^>]*>[^<]*\d/)
    end

    it "injects Prism.js CDN" do
      html = render_html(make_diff)
      expect(html).to include("prismjs")
    end

    it "renders the language class for Prism.js tokenization" do
      html = render_html(make_diff)
      expect(html).to include("language-ruby")
    end

    it "wraps line content in <code> tags" do
      html = render_html(make_diff)
      expect(html).to include("<code")
    end

    it "renders the outer sw-diff-block container" do
      html = render_html(make_diff)
      expect(html).to include("sw-diff-block")
    end

    it "renders the code content" do
      html = render_html(make_diff)
      expect(html).to include("greet")
    end
  end

  describe "lazy CDN loading" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state)   { {} }

    it "only injects Prism.js once when multiple diff_block components render" do
      db1 = StreamWeaver::Components::DiffBlock.new(language: "ruby")
      db1.before_code = "a\n"
      db1.after_code  = "b\n"
      db2 = StreamWeaver::Components::DiffBlock.new(language: "javascript")
      db2.before_code = "x\n"
      db2.after_code  = "y\n"
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [db1, db2], state)
      expect(html.scan("prism-tomorrow.min.css").length).to eq(1)
    end
  end

  describe "empty before/after" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state)   { {} }

    it "renders without error when both strings are empty" do
      db = StreamWeaver::Components::DiffBlock.new
      expect {
        StreamWeaver::ComponentRenderer.render_html(adapter, [db], state)
      }.not_to raise_error
    end
  end

  describe "DisplayDSL#diff" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        diff(language: "ruby") do
          before { "old\n" }
          after  { "new\n" }
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DiffBlock) }
      expect(component).not_to be_nil
      expect(component.language).to eq("ruby")
    end

    it "captures before and after strings from the block" do
      app = StreamWeaver::App.new("Test") do
        diff(language: "ruby") do
          before { "old line\n" }
          after  { "new line\n" }
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DiffBlock) }
      expect(component.before_code).to eq("old line\n")
      expect(component.after_code).to eq("new line\n")
    end

    it "defaults to empty strings when no block given" do
      app = StreamWeaver::App.new("Test") do
        diff(language: "ruby")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DiffBlock) }
      expect(component.before_code).to eq("")
      expect(component.after_code).to eq("")
    end
  end

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

    it "all CSS class selectors use sw- prefix" do
      css = adapter.send(:diff_block_css)
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
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

  describe "Adapter::Base#render_diff_block" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_diff_block(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_diff_block/)
    end
  end
end
