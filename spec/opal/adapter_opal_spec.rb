# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/renderer"
require "stream_weaver/adapter/opal"

RSpec.describe StreamWeaver::Adapter::Opal do
  let(:adapter) { described_class.new }
  let(:state) { {} }
  let(:view) { StreamWeaver::Opal::OpalRenderer.new(adapter, state) }

  describe "#render_header" do
    it "renders h1 for level 1" do
      adapter.render_header(view, "Hello", 1, state)
      expect(view.to_html).to eq("<h1>Hello</h1>")
    end

    it "renders h3 for level 3" do
      adapter.render_header(view, "Sub", 3, state)
      expect(view.to_html).to eq("<h3>Sub</h3>")
    end
  end

  describe "#render_text_field" do
    it "renders an input with name and oninput handler" do
      adapter.render_text_field(view, :name, {}, state)
      html = view.to_html
      expect(html).to include('name="name"')
      expect(html).to include('type="text"')
      expect(html).to include("SWRuntime.update")
    end

    it "sets value from state" do
      adapter.render_text_field(view, :name, {}, { name: "Alice" })
      expect(view.to_html).to include('value="Alice"')
    end

    it "uses placeholder option" do
      adapter.render_text_field(view, :q, { placeholder: "Search..." }, state)
      expect(view.to_html).to include('placeholder="Search..."')
    end
  end

  describe "#render_checkbox" do
    it "renders a checkbox input" do
      adapter.render_checkbox(view, :agree, "I agree", {}, state)
      html = view.to_html
      expect(html).to include('type="checkbox"')
      expect(html).to include("I agree")
    end

    it "marks checked when state is true" do
      adapter.render_checkbox(view, :agree, "I agree", {}, { agree: true })
      expect(view.to_html).to include("checked")
    end
  end

  describe "#render_button" do
    it "renders a button element with onclick" do
      adapter.render_button(view, "btn-1", "Click me", {})
      html = view.to_html
      expect(html).to include("Click me")
      expect(html).to include("SWRuntime.invoke")
      expect(html).to include("btn-1")
    end
  end

  describe "#render_div" do
    it "renders a div container" do
      component = double("Div", children: [], html_options: { class: "foo" })
      adapter.render_div(view, component, state)
      expect(view.to_html).to include('<div class="foo">')
    end
  end

  describe "#render_markdown" do
    it "wraps content in a sw-markdown div" do
      adapter.render_markdown(view, "**bold**", state)
      expect(view.to_html).to include('class="sw-markdown"')
    end
  end

  describe "#render_cdn_scripts" do
    it "emits nothing — morphdom is loaded by OpalShell" do
      adapter.render_cdn_scripts(view)
      expect(view.to_html).to eq("")
    end
  end
end
