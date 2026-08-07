# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/env"
require "stream_weaver/opal/renderer"
require "stream_weaver/adapter/opal"
require "stream_weaver/opal/runtime"
require "stream_weaver/opal/bridge"
require "stream_weaver/opal/string_bridge"

# The Opal bundle is compiled once and run in two hosts: a browser tab, and a
# bare Node process with no `window` and no `document`. These specs pin the
# seams that make the second host possible -- DOM detection, CSS collection,
# and the render-to-string entry points -- all of which are exercisable under
# MRI precisely because they touch no DOM.
RSpec.describe "DOM-free rendering" do
  let(:adapter) { StreamWeaver::Adapter::Opal.new }
  let(:runtime) { StreamWeaver::Opal::OpalRuntime.new(adapter: adapter) }

  describe StreamWeaver::Opal::Env do
    it "reports no DOM outside Opal" do
      expect(described_class.dom?).to be false
    end
  end

  describe StreamWeaver::Adapter::Opal do
    describe "#collected_css" do
      let(:view) { StreamWeaver::Opal::OpalRenderer.new(adapter, {}) }

      it "starts empty" do
        expect(adapter.collected_css).to eq({})
      end

      it "collects CSS wrapped in the shared cascade layer" do
        adapter.inject_component_css(view, :callout, ".x { color: red; }")
        expect(adapter.collected_css[:callout]).to include("@layer stream-weaver")
        expect(adapter.collected_css[:callout]).to include(".x { color: red; }")
      end

      it "keeps the first registration for a key so re-renders do not duplicate" do
        adapter.inject_component_css(view, :callout, ".first {}")
        adapter.inject_component_css(view, :callout, ".second {}")
        expect(adapter.collected_css.keys).to eq([:callout])
        expect(adapter.collected_css[:callout]).to include(".first {}")
      end

      it "ignores empty CSS" do
        adapter.inject_component_css(view, :blank, "   ")
        expect(adapter.collected_css).to be_empty
      end

      it "emits nothing into the rendered markup" do
        adapter.inject_component_css(view, :callout, ".x {}")
        expect(view.to_html).to eq("")
      end

      it "joins collected stylesheets into one blob" do
        adapter.inject_component_css(view, :a, ".a {}")
        adapter.inject_component_css(view, :b, ".b {}")
        expect(adapter.collected_css_text).to include(".a {}").and include(".b {}")
      end
    end
  end

  describe StreamWeaver::Opal::OpalRuntime do
    describe "#render_body_html" do
      it "returns the same markup as the browser render path" do
        runtime.set_block { header1 "Hi" }
        expect(runtime.render_body_html).to eq(runtime.render_html)
      end

      it "renders document components without a DOM" do
        runtime.set_block do
          doc_header(title: "Hello", pills: [{ text: "Draft" }])
          doc_section_header "01", "Intro", id: "intro"
          table(headers: %w[A B], rows: [%w[1 2]])
          callout(variant: :warning, title: "Careful") { text "Watch out." }
          code_block("puts 1\n", lang: "ruby")
        end
        html = runtime.render_body_html
        expect(html).to include("sw-doc-header")
        expect(html).to include("sw-doc-section-header")
        expect(html).to include("<table")
        expect(html).to include("sw-callout")
        expect(html).to include("sw-code-block")
      end
    end

    describe "#collected_css" do
      it "is empty before anything renders" do
        expect(runtime.collected_css).to eq("")
      end

      it "carries the component CSS the render asked for" do
        runtime.set_block { callout(variant: :warning, title: "Careful") { text "!" } }
        runtime.render_body_html
        expect(runtime.collected_css).to include(".sw-callout")
      end

      it "is empty for an adapter with no collection support" do
        bare = StreamWeaver::Opal::OpalRuntime.new(adapter: Object.new)
        expect(bare.collected_css).to eq("")
      end
    end

    describe "#render_document" do
      subject(:doc) do
        runtime.set_block { callout(variant: :warning, title: "Careful") { text "Watch out." } }
        runtime.render_document(title: "My Doc")
      end

      it "is a complete HTML page" do
        expect(doc).to start_with("<!DOCTYPE html>")
        expect(doc).to include("<title>My Doc</title>")
      end

      it "bakes the rendered body into #sw-app" do
        expect(doc).to include('<div id="sw-app"><div id="sw-region-0">')
        expect(doc).to include("sw-callout")
      end

      it "inlines the collected component CSS, since there is no head to append to" do
        expect(doc).to include("<style>")
        expect(doc).to include(".sw-callout")
      end

      it "does not boot a runtime it has no app.js for" do
        expect(doc).not_to include("SWRuntime.start()")
        expect(doc).not_to include('<script src="app.js">')
      end

      it "accepts a caller-supplied framework stylesheet" do
        runtime.set_block { text "hi" }
        expect(runtime.render_document(stylesheet: ".from-host {}")).to include(".from-host {}")
      end

      it "forwards options through to the shell" do
        runtime.set_block { text "hi" }
        expect(runtime.render_document(theme_css: "sw-theme.css")).to include('href="sw-theme.css"')
      end
    end
  end

  describe StreamWeaver::Opal::OpalBridge do
    it "installs nothing when there is no DOM" do
      expect { described_class.new(runtime).install }.not_to raise_error
    end
  end

  describe StreamWeaver::Opal::StringBridge do
    it "is inert outside Opal, where there is no globalThis to publish to" do
      expect(described_class.new(runtime, title: "T").install).to be_nil
    end
  end

  describe StreamWeaver::CSS do
    describe ".base_stylesheet" do
      it "returns CSS" do
        expect(described_class.base_stylesheet).to be_a(String)
        expect(described_class.base_stylesheet).not_to be_empty
      end

      it "falls back to the minimal token set when the source file is out of reach" do
        allow(described_class).to receive(:full_stylesheet).and_raise(Errno::ENOENT)
        expect(described_class.base_stylesheet).to eq(described_class.minimal_css)
      end
    end
  end
end
