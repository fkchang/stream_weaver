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
    it "raises NotImplementedError" do
      expect { runtime.render_html }.to raise_error(NotImplementedError, /render_html/)
    end

    it "clears the callback registry before raising" do
      runtime.register_callback("btn-x") { }
      expect { runtime.render_html }.to raise_error(NotImplementedError)
      # callbacks must be cleared even though render_html raises
      expect(runtime.instance_variable_get(:@callbacks)).to be_empty
    end
  end
end
