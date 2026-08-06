# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::CopyButton do
  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(*components)
      StreamWeaver::ComponentRenderer.render_html(adapter, components, state)
    end

    it "renders the copy text in the data-sw-copy-text attribute" do
      component = described_class.new(text: "hello world")
      html = render_html(component)

      expect(html).to include('data-sw-copy-text="hello world"')
    end

    it "escapes a hostile payload in the attribute and never leaks it raw into the click handler" do
      payload = %(some "quoted" 'text' with\nnewline and \\backslash\\ and <script>alert(1)</script>)
      component = described_class.new(text: payload)
      html = render_html(component)

      # Phlex escapes double quotes in the attribute value, so the payload
      # cannot break out of the data-sw-copy-text="..." attribute boundary
      # (the raw, unescaped payload string -- quotes intact -- never appears).
      expect(html).not_to include(%(data-sw-copy-text="#{payload}"))
      expect(html).to include("&quot;quoted&quot;")

      # The click handler is a fixed literal -- it must never contain any
      # fragment of the raw payload.
      click_handler = html[/@click="([^"]*)"/, 1]
      expect(click_handler).not_to be_nil
      expect(click_handler).not_to include("quoted")
      expect(click_handler).not_to include("backslash")
      expect(click_handler).not_to include("script")
    end

    it "renders a fixed swCopy($el) click handler with no interpolated text" do
      component = described_class.new(text: "plain payload")
      html = render_html(component)

      expect(html).to include("swCopy($el)")
      expect(html).to include('@click="swCopy($el).then(() => { copied = true; setTimeout(() => copied = false, 1500) })"')

      click_handler = html[/@click="([^"]*)"/, 1]
      expect(click_handler).not_to include("plain payload")
    end

    it "renders both label spans gated on the copied flag" do
      component = described_class.new("Copy", text: "x", copied_label: "Copied!")
      html = render_html(component)

      expect(html).to include('x-show="!copied"')
      expect(html).to include('x-show="copied"')
      expect(html).to include("x-cloak")
      expect(html).to include("Copy")
      expect(html).to include("Copied!")
    end

    it "injects the sw-copy.js script content exactly once for two copy_buttons" do
      first = described_class.new(text: "one")
      second = described_class.new(text: "two")
      html = render_html(first, second)

      expect(html.scan("window.swCopy").length).to eq(1)
    end
  end

  describe "sw-copy.js" do
    let(:js_path) { File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-copy.js') }
    let(:js_content) { File.read(js_path) }

    it "exists" do
      expect(File.exist?(js_path)).to be true
    end

    it "defines the swCopy global" do
      expect(js_content).to include("window.swCopy")
    end

    it "prefers navigator.clipboard on a secure context" do
      expect(js_content).to include("navigator.clipboard")
      expect(js_content).to include("isSecureContext")
    end

    it "falls back to execCommand for non-secure origins" do
      expect(js_content).to include("execCommand")
      expect(js_content).to include("textarea")
    end
  end
end
