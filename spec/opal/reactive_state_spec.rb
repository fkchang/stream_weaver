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

  describe "state-update-loop guard" do
    # A watcher whose callback writes the key it watches recurses synchronously
    # inside notify_watchers, so an async rerender-rate cap never sees it.
    it "stops a watcher that writes the key it watches, instead of recursing unboundedly" do
      calls = 0
      rs.watch(:count) do |v|
        calls += 1
        rs[:count] = v + 1
      end

      expect { rs[:count] = 1 }.not_to raise_error
      # Bound against the cap that actually fires for this shape, not the
      # looser one -- a `<= 200` here would stay green if the depth guard broke.
      expect(calls).to eq(described_class::MAX_WATCHER_DEPTH)
    end

    # The other runaway shape: wide, not deep. Many watchers on one key each
    # writing a DIFFERENT key never nests past depth 2, so only the call cap
    # can stop it. This is the case MAX_WATCHER_CALLS_PER_WRITE exists for.
    it "stops a wide fan-out that never recurses deeply" do
      calls = 0
      300.times do |i|
        rs.watch(:fan) do
          calls += 1
          rs[:"leaf#{i}"] = i
        end
      end

      expect { rs[:fan] = 1 }.not_to raise_error
      expect(calls).to eq(described_class::MAX_WATCHER_CALLS_PER_WRITE)
      expect(calls).to be < 300
      expect(rs.state_loop_error).to include("state update loop")
    end

    it "records a visible state-update-loop error naming the offending key" do
      rs.watch(:count) { |v| rs[:count] = v + 1 }
      rs[:count] = 1

      expect(rs.state_loop_error).to include("state update loop")
      expect(rs.state_loop_error).to include("count")
    end

    it "reports the loop to a registered handler" do
      reported = []
      rs.on_state_loop { |message, key| reported << [message, key] }
      rs.watch(:count) { |v| rs[:count] = v + 1 }
      rs[:count] = 1

      expect(reported.length).to eq(1)
      expect(reported.first[1]).to eq(:count)
      expect(reported.first[0]).to include("state update loop")
    end

    it "stops an indirect loop that cycles through another key" do
      calls = 0
      rs.watch(:a) { |v| calls += 1; rs[:b] = v + 1 }
      rs.watch(:b) { |v| calls += 1; rs[:a] = v + 1 }

      expect { rs[:a] = 1 }.not_to raise_error
      expect(rs.state_loop_error).to include("state update loop")
      expect(calls).to eq(described_class::MAX_WATCHER_DEPTH)
    end

    # The trip must not wedge the object: @loop_tripped is per top-level write,
    # so an unrelated healthy key still dispatches afterwards.
    it "keeps dispatching healthy watchers after a loop has been stopped" do
      rs.watch(:count) { |v| rs[:count] = v + 1 }
      rs[:count] = 1

      healthy = 0
      rs.watch(:other) { healthy += 1 }
      rs[:other] = "fine"

      expect(healthy).to eq(1)
    end

    it "keeps the error sticky, because a doc with a feedback loop stays broken" do
      rs.watch(:count) { |v| rs[:count] = v + 1 }
      rs[:count] = 1
      first = rs.state_loop_error

      rs[:unrelated] = "later write"
      expect(rs.state_loop_error).to eq(first)
    end

    it "leaves legitimate rapid sequential updates completely unaffected" do
      calls = 0
      rs.watch(:query) { calls += 1 }
      500.times { |i| rs[:query] = "term#{i}" }

      expect(calls).to eq(500)
      expect(rs.state_loop_error).to be_nil
    end

    it "leaves a legitimate bounded watcher chain unaffected" do
      log = []
      rs.watch(:a) { |v| log << :a; rs[:b] = v }
      rs.watch(:b) { |v| log << :b; rs[:c] = v }
      rs.watch(:c) { log << :c }

      rs[:a] = 1
      expect(log).to eq([:a, :b, :c])
      expect(rs.state_loop_error).to be_nil
    end

    it "resets the per-write budget between top-level writes" do
      rs.watch(:a) { |v| rs[:b] = v }
      rs.watch(:b) { nil }

      200.times { |i| rs[:a] = i }
      expect(rs.state_loop_error).to be_nil
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
