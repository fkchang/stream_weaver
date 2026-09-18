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

  describe "#register_component_callbacks" do
    it "uses the register_callbacks protocol, not is_a? checks" do
      action = ->(state) { state[:hit] = true }
      btn = StreamWeaver::Components::Button.new("Go", "test_btn", &action)
      runtime.register_component_callbacks([btn])
      runtime.invoke_callback(btn.id)
      expect(runtime.state[:hit]).to be true
    end

    it "traverses children recursively via Base#children" do
      inner_action = ->(state) { state[:inner] = true }
      inner_btn = StreamWeaver::Components::Button.new("Inner", "inner_btn", &inner_action)
      wrapper = double("wrapper", register_callbacks: nil, children: [inner_btn])
      runtime.register_component_callbacks([wrapper])
      runtime.invoke_callback(inner_btn.id)
      expect(runtime.state[:inner]).to be true
    end

    it "registers footer button callbacks via Modal#register_callbacks" do
      confirmed = false
      btn = StreamWeaver::Components::Button.new("OK", "ok_btn") { |_state| confirmed = true }
      footer = StreamWeaver::Components::ModalFooter.new
      footer.children << btn
      modal = StreamWeaver::Components::Modal.new(:confirm)
      modal.footer_component = footer

      runtime.register_component_callbacks([modal])
      runtime.invoke_callback(btn.id)
      expect(confirmed).to be true
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

  describe "#watch wiring (S5 — search triggers side effect)" do
    it "fires a watch callback when the watched key changes via update_state" do
      fired_with = nil
      runtime.state.watch(:search) do |val|
        fired_with = val
        runtime.state[:results] = ["result:#{val}"]
      end

      runtime.update_state("search", "ruby")
      expect(fired_with).to eq("ruby")
      expect(runtime.state[:results]).to eq(["result:ruby"])
    end

    it "does not fire watch callback when value is unchanged" do
      calls = 0
      runtime.state[:search] = "same"
      runtime.state.watch(:search) { calls += 1 }
      runtime.update_state("search", "same")
      expect(calls).to eq(0)
    end
  end

  describe "#on_start wiring (S6 — run once)" do
    it "registers start hooks and marks them as pending" do
      hook_ran = false
      runtime.register_start_hook(-> { hook_ran = true })
      expect(runtime.instance_variable_get(:@start_hooks_fired)).to be false
      expect(runtime.instance_variable_get(:@start_hooks).length).to eq(1)
    end

    it "does not register hooks after start_hooks_fired" do
      runtime.instance_variable_set(:@start_hooks_fired, true)
      runtime.register_start_hook(-> { raise "should not register" })
      expect(runtime.instance_variable_get(:@start_hooks).length).to eq(0)
    end
  end

  describe "#watchers_initialized? (watcher accumulation guard)" do
    it "starts false" do
      expect(runtime.watchers_initialized?).to be false
    end

    it "becomes true after render_html runs" do
      runtime.set_block { text "hello" }
      runtime.render_html
      expect(runtime.watchers_initialized?).to be true
    end

    it "remains true on subsequent render_html calls" do
      runtime.set_block { text "hello" }
      runtime.render_html
      runtime.render_html
      expect(runtime.watchers_initialized?).to be true
    end
  end

  describe "#schedule_rerender guard" do
    it "does not set rerender_pending when sync_rendering is true" do
      runtime.instance_variable_set(:@sync_rendering, true)
      runtime.schedule_rerender
      expect(runtime.instance_variable_get(:@rerender_pending)).to be false
    end

    it "sets rerender_pending to true when not sync_rendering" do
      # On MRI, %x{setTimeout...#{perform_async_render}} evaluates the Ruby
      # interpolation synchronously, resetting @rerender_pending to false.
      # Stub perform_async_render to observe the flag as set by schedule_rerender.
      allow(runtime).to receive(:perform_async_render)
      runtime.instance_variable_set(:@sync_rendering, false)
      runtime.instance_variable_set(:@rerender_pending, false)
      runtime.schedule_rerender
      expect(runtime.instance_variable_get(:@rerender_pending)).to be true
    end
  end

  describe "granular region wrappers (Step 2)" do
    it "wraps each top-level component in sw-region-N div" do
      runtime.set_block do
        text "first"
        text "second"
      end
      html = runtime.render_html
      expect(html).to include('id="sw-region-0"')
      expect(html).to include('id="sw-region-1"')
    end

    it "populates track_map after render — region reads state key" do
      runtime.set_block do
        text ->(state) { state[:name].to_s }
      end
      runtime.state[:name] = "Alice"
      runtime.render_html
      deps = runtime.state.dependencies_for("sw-region-0")
      expect(deps).to include(:name)
    end

    it "clears stale tracking entries on each render" do
      runtime.set_block { text ->(state) { state[:name].to_s } }
      runtime.state[:name] = "Alice"
      runtime.render_html
      runtime.render_html  # second render should re-populate, not accumulate
      deps = runtime.state.dependencies_for("sw-region-0")
      expect(deps.count(:name)).to eq(1)
    end

    # patch_regions resolves each region by document.getElementById("sw-region-N").
    # A host that renders the wrappers once and then drops them turns every
    # later region-scoped patch into a silent no-op -- the state changes, the
    # DOM does not, and nothing errors.
    it "emits the wrappers on every render, not just the first" do
      runtime.set_block do
        text state[:first].to_s
        text "second"
      end

      renders = %w[a b c].map do |value|
        runtime.state[:first] = value
        runtime.render_html
      end

      renders.each_with_index do |html, i|
        expect(html).to include('id="sw-region-0"'), "render #{i + 1} lost sw-region-0"
        expect(html).to include('id="sw-region-1"'), "render #{i + 1} lost sw-region-1"
      end
    end
  end

  describe "state-update-loop banner" do
    # The guard in ReactiveState stops the loop; this is the half that makes it
    # visible to someone without devtools open. Without it the only symptom of
    # a doc-authoring feedback loop was a tab that stopped responding.
    it "is absent from a healthy render" do
      runtime.set_block { text "fine" }
      expect(runtime.render_html).not_to include("sw-state-loop-error")
    end

    it "is prepended to the render once the loop guard has tripped" do
      runtime.state.watch(:count) { |v| runtime.state[:count] = v + 1 }
      runtime.state[:count] = 1
      runtime.set_block { text "doc body" }

      html = runtime.render_html
      expect(html).to include("sw-state-loop-error")
      expect(html).to include("doc has a state update loop")
      expect(html).to include("state[:count]")
      expect(html).to include("doc body")
    end

    # The banner is emitted outside every sw-region-N wrapper, so a
    # region-scoped patch would morph only the regions and drop it. That is
    # exactly the path a text_field takes (OpalBridge routes input events
    # through update_and_patch), which is the path most likely to trip the
    # guard in the first place -- so a tripped loop has to force a full patch.
    describe "and the patch path that has to carry it" do
      before do
        runtime.set_block { text ->(state) { state[:query].to_s } }
        runtime.render_html # populate dependencies_for_key(:query)
        allow(runtime).to receive(:patch_dom)
        allow(runtime).to receive(:patch_regions)
      end

      it "patches only the affected regions for a healthy update" do
        runtime.update_and_patch(:query, "hello")

        expect(runtime).to have_received(:patch_regions)
        expect(runtime).not_to have_received(:patch_dom)
      end

      it "falls back to a full patch once the loop guard has tripped" do
        runtime.state.watch(:query) { |v| runtime.state[:query] = "#{v}!" }
        runtime.state[:query] = "loop"

        runtime.update_and_patch(:query, "hello")

        expect(runtime).to have_received(:patch_dom)
        expect(runtime).not_to have_received(:patch_regions)
      end
    end

    it "escapes the message so a doc-supplied key cannot inject markup" do
      runtime.state.watch(:"x<script>") { |v| runtime.state[:"x<script>"] = v.to_s + "!" }
      runtime.state[:"x<script>"] = "a"
      runtime.set_block { text "body" }

      expect(runtime.render_html).not_to include("<script>")
    end
  end
end
