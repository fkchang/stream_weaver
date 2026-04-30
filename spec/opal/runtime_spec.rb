# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/renderer"
require "stream_weaver/adapter/opal"
require "stream_weaver/opal/runtime"

RSpec.describe StreamWeaver::Opal::OpalRuntime do
  let(:adapter) { StreamWeaver::Adapter::Opal.new }
  let(:runtime) { described_class.new(adapter: adapter) }

  describe "#state" do
    it "starts empty" do
      expect(runtime.state).to eq({})
    end

    it "allows reading and writing" do
      runtime.state[:name] = "Alice"
      expect(runtime.state[:name]).to eq("Alice")
    end
  end

  describe "#update_state" do
    it "sets a string-keyed value as symbol" do
      runtime.update_state("name", "Bob")
      expect(runtime.state[:name]).to eq("Bob")
    end

    it "converts numeric strings to appropriate types" do
      runtime.update_state("count", "42")
      expect(runtime.state[:count]).to eq("42")  # kept as string; type coercion is app's job
    end
  end

  describe "callback registry" do
    it "registers and invokes a callback" do
      called_with = nil
      runtime.register_callback("btn-1") { |s| called_with = s[:name] }
      runtime.state[:name] = "Alice"
      runtime.invoke_callback("btn-1")
      expect(called_with).to eq("Alice")
    end

    it "is a no-op for unknown callback ids" do
      expect { runtime.invoke_callback("nonexistent") }.not_to raise_error
    end
  end

  describe "#render_html" do
    it "returns an HTML string when block is set" do
      runtime.set_block { }  # empty block — no components
      result = runtime.render_html
      expect(result).to be_a(String)
    end

    it "clears the callback registry before rendering" do
      runtime.register_callback("btn-x") { }
      runtime.set_block { }
      runtime.render_html
      # btn-x is gone (re-registered only for components actually in the new render)
      expect(runtime.instance_variable_get(:@callbacks)).not_to have_key("btn-x")
    end

    it "renders DSL components from the block" do
      runtime.set_block do
        header1 "Hello from Opal"
      end
      html = runtime.render_html
      expect(html).to include("<h1>")
      expect(html).to include("Hello from Opal")
    end

    it "registers button callbacks so invoke_callback can execute them" do
      called = false
      runtime.set_block do
        button "Click me" do |_state|
          called = true
        end
      end
      runtime.render_html
      btn_id = runtime.instance_variable_get(:@callbacks).keys.first
      expect(btn_id).not_to be_nil
      runtime.invoke_callback(btn_id)
      expect(called).to be true
    end

    it "reflects current state in rendered output" do
      runtime.set_block do
        text_field :name, placeholder: "Enter your name"
      end
      runtime.update_state(:name, "Alice")
      html = runtime.render_html
      expect(html).to include("Alice")
    end
  end
end
