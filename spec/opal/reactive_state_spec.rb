# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/reactive_state"

RSpec.describe StreamWeaver::Opal::ReactiveState do
  subject(:rs) { described_class.new }

  describe "#[] and #[]=" do
    it "stores and retrieves values by symbol key" do
      rs[:name] = "Alice"
      expect(rs[:name]).to eq("Alice")
    end

    it "coerces string keys to symbols" do
      rs["name"] = "Bob"
      expect(rs[:name]).to eq("Bob")
    end

    it "returns nil for missing keys" do
      expect(rs[:missing]).to be_nil
    end
  end

  describe "#==" do
    it "equals an empty hash when empty" do
      expect(rs).to eq({})
    end

    it "equals a populated hash with the same data" do
      rs[:a] = 1
      expect(rs).to eq({ a: 1 })
    end

    it "equals another ReactiveState with the same data" do
      rs[:a] = 1
      other = described_class.new(a: 1)
      expect(rs).to eq(other)
    end
  end

  describe "#to_h" do
    it "returns a plain hash copy" do
      rs[:x] = 42
      h = rs.to_h
      expect(h).to eq({ x: 42 })
      expect(h).to be_a(Hash)
    end
  end

  describe "#watch" do
    it "fires the block with the new value when the key changes" do
      received = nil
      rs.watch(:search) { |val| received = val }
      rs[:search] = "hello"
      expect(received).to eq("hello")
    end

    it "does not fire when value is unchanged" do
      calls = 0
      rs[:count] = 5
      rs.watch(:count) { calls += 1 }
      rs[:count] = 5
      expect(calls).to eq(0)
    end

    it "supports multiple watchers on the same key" do
      log = []
      rs.watch(:x) { |v| log << "a:#{v}" }
      rs.watch(:x) { |v| log << "b:#{v}" }
      rs[:x] = 1
      expect(log).to eq(["a:1", "b:1"])
    end

    it "does not fire watchers for other keys" do
      fired = false
      rs.watch(:a) { fired = true }
      rs[:b] = "unrelated"
      expect(fired).to be false
    end
  end

  describe "#track" do
    it "records which keys were read during the block" do
      rs.track("region-0") do
        rs[:name]
        rs[:age]
      end
      expect(rs.dependencies_for("region-0")).to contain_exactly(:name, :age)
    end

    it "does not record reads outside a track block" do
      rs[:name]
      expect(rs.dependencies_for("region-0")).to be_empty
    end

    it "supports nested tracking (outer tracks own reads)" do
      rs.track("outer") do
        rs[:x]
        rs.track("inner") { rs[:y] }
        rs[:z]
      end
      expect(rs.dependencies_for("outer")).to contain_exactly(:x, :z)
      expect(rs.dependencies_for("inner")).to contain_exactly(:y)
    end

    it "does not duplicate region IDs for the same key" do
      rs.track("r0") { rs[:name]; rs[:name] }
      expect(rs.dependencies_for("r0")).to eq([:name])
    end

    it "restores tracking state when the block raises" do
      expect { rs.track("r0") { raise "boom" } }.to raise_error("boom")
      rs.track("other") { rs[:after] }
      expect(rs.dependencies_for("r0")).to be_empty
    end
  end

  describe "#reset_tracking" do
    it "clears all recorded dependencies" do
      rs.track("r0") { rs[:name] }
      rs.reset_tracking
      expect(rs.dependencies_for("r0")).to be_empty
      expect(rs.dependencies_for_key(:name)).to be_empty
    end
  end

  describe "#dependencies_for_key (inverse of dependencies_for)" do
    it "returns region IDs that read the given key" do
      rs.track("region-0") { rs[:name] }
      rs.track("region-1") { rs[:name]; rs[:age] }
      expect(rs.dependencies_for_key(:name)).to contain_exactly("region-0", "region-1")
    end

    it "returns empty array for a key no region read" do
      expect(rs.dependencies_for_key(:untouched)).to be_empty
    end
  end

  describe "#key?" do
    it "returns true for keys that have been set" do
      rs[:foo] = "bar"
      expect(rs.key?(:foo)).to be true
    end

    it "returns false for absent keys" do
      expect(rs.key?(:missing)).to be false
    end
  end

  describe "#on_any_change" do
    it "fires the callback when any key changes" do
      changed = []
      rs.on_any_change { |key| changed << key }
      rs[:a] = 1
      rs[:b] = 2
      expect(changed).to eq([:a, :b])
    end

    it "supports multiple on_any_change callbacks" do
      log = []
      rs.on_any_change { |k| log << "first:#{k}" }
      rs.on_any_change { |k| log << "second:#{k}" }
      rs[:x] = 1
      expect(log).to eq(["first:x", "second:x"])
    end

    it "does not fire when value is unchanged" do
      calls = 0
      rs[:x] = 5
      rs.on_any_change { calls += 1 }
      rs[:x] = 5
      expect(calls).to eq(0)
    end
  end
end
