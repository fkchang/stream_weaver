# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/renderer"

RSpec.describe StreamWeaver::Opal::OpalRenderer do
  let(:adapter) { instance_double("StreamWeaver::Adapter::Opal") }
  let(:renderer) { described_class.new(adapter, {}) }

  describe "#adapter" do
    it "returns the adapter" do
      expect(renderer.adapter).to eq(adapter)
    end
  end

  describe "block tags (open/close pairs)" do
    it "renders div with attributes" do
      renderer.div(class: "foo") { }
      expect(renderer.to_html).to eq('<div class="foo"></div>')
    end

    it "renders nested tags" do
      renderer.div do
        renderer.span { renderer.plain("hello") }
      end
      expect(renderer.to_html).to eq("<div><span>hello</span></div>")
    end

    it "renders p" do
      renderer.p { renderer.plain("text") }
      expect(renderer.to_html).to eq("<p>text</p>")
    end

    it "renders h4 with content" do
      renderer.h4 { renderer.plain("Title") }
      expect(renderer.to_html).to eq("<h4>Title</h4>")
    end

    it "renders ul/li" do
      renderer.ul do
        renderer.li { renderer.plain("item") }
      end
      expect(renderer.to_html).to eq("<ul><li>item</li></ul>")
    end
  end

  describe "void tags (self-closing)" do
    it "renders input without closing tag" do
      renderer.input(type: "text", name: "foo")
      expect(renderer.to_html).to eq('<input type="text" name="foo">')
    end

    it "renders hr" do
      renderer.hr(class: "divider")
      expect(renderer.to_html).to eq('<hr class="divider">')
    end

    it "omits attributes with false values" do
      renderer.input(type: "checkbox", disabled: false)
      expect(renderer.to_html).to eq('<input type="checkbox">')
    end
  end

  describe "#attrs_to_html" do
    it "escapes double quotes in attribute values" do
      renderer.div(title: 'Say "hello"') { }
      expect(renderer.to_html).to eq('<div title="Say &quot;hello&quot;"></div>')
    end
  end

  describe "#plain" do
    it "appends raw text" do
      renderer.plain("hello world")
      expect(renderer.to_html).to eq("hello world")
    end

    it "escapes HTML entities" do
      renderer.plain("<script>alert(1)</script>")
      expect(renderer.to_html).to include("&lt;script&gt;")
    end
  end

  describe "#raw" do
    it "appends unescaped HTML" do
      renderer.raw("<strong>bold</strong>")
      expect(renderer.to_html).to eq("<strong>bold</strong>")
    end
  end

  describe "#to_html" do
    it "returns accumulated output as a string" do
      renderer.div { renderer.plain("x") }
      expect(renderer.to_html).to be_a(String)
    end
  end
end
