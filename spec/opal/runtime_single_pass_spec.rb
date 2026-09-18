# frozen_string_literal: true

require "spec_helper"
require "stream_weaver/opal/renderer"
require "stream_weaver/adapter/opal"
require "stream_weaver/opal/runtime"

RSpec.describe StreamWeaver::Opal::OpalRuntime do
  let(:runtime) { described_class.new(adapter: StreamWeaver::Adapter::Opal.new) }

  it "builds a multi-component document once while preserving regions, order, and callbacks" do
    builds = 0
    clicked = false
    runtime.set_block do
      builds += 1
      text "first"
      button("choose") { |state| state[:chosen] = true; clicked = true }
      text "last"
    end

    html = runtime.render_html

    expect(builds).to eq(1)
    expect(html.scan(/id="sw-region-(\d+)"/).flatten).to eq(%w[0 1 2])
    expect(html.index("first")).to be < html.index("choose")
    expect(html.index("choose")).to be < html.index("last")

    callback_id = runtime.instance_variable_get(:@callbacks).keys.fetch(0)
    runtime.invoke_callback(callback_id)
    expect(clicked).to be(true)
    expect(runtime.state[:chosen]).to be(true)
  end

  it "does not schedule lifecycle work when a document has no start hooks" do
    runtime.instance_variable_set(:@start_hooks, [])

    expect(runtime).not_to receive(:schedule_start_hooks)
    runtime.send(:fire_start_hooks_once)
  end

  it "full-patches state read only while building the DSL" do
    runtime.set_block { text state[:query].to_s }
    runtime.render_html
    allow(runtime).to receive(:patch_dom)
    allow(runtime).to receive(:patch_regions)

    runtime.update_and_patch(:query, "new value")

    expect(runtime).to have_received(:patch_dom)
    expect(runtime).not_to have_received(:patch_regions)
  end

  it "keeps region patches for dependencies read while rendering a component" do
    runtime.set_block { text ->(state) { state[:query].to_s } }
    runtime.render_html
    allow(runtime).to receive(:patch_dom)
    allow(runtime).to receive(:patch_regions)

    runtime.update_and_patch(:query, "new value")

    expect(runtime).to have_received(:patch_regions).with(["sw-region-0"], kind_of(String))
    expect(runtime).not_to have_received(:patch_dom)
  end

  it "full-patches a key that changes DSL structure even when a region also reads it" do
    runtime.set_block do
      text "conditional" if state[:show]
      text ->(state) { state[:show] ? "yes" : "no" }
    end
    runtime.state[:show] = false
    runtime.render_html
    allow(runtime).to receive(:patch_dom)
    allow(runtime).to receive(:patch_regions)

    runtime.update_and_patch(:show, true)

    expect(runtime).to have_received(:patch_dom).with(include("conditional", "yes"))
    expect(runtime).not_to have_received(:patch_regions)
  end
end
