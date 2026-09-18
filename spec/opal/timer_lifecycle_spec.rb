# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/app"
require "stream_weaver/adapter/base"
require "stream_weaver/adapter/opal"
require "stream_weaver/opal/renderer"
require "stream_weaver/opal/runtime"
require "stream_weaver/opal/app_timers"

# render_html executes the doc's DSL block once per render. The timer registry
# still has to survive later renders, where every `every`/`after` callsite is
# encountered again. Before this guard each render installed a brand-new browser timer:
# a live Node probe against the compiled bundle measured one `every(1)`
# callsite becoming 3 live intervals after one render, 6 after two, 9 after
# three. Registration is keyed by callsite so a callsite that already owns a
# timer is a no-op on every subsequent execution.
#
# The browser-timer install itself is the only Opal-guarded part; the
# bookkeeping that decides whether to install runs in every host, which is what
# makes this provable without a browser.
#
# AppTimers is prepended onto a throwaway subclass rather than onto
# StreamWeaver::App itself: opal_entry.rb, the real caller, also installs
# browser-only global overrides (counter-based button ids,
# StreamWeaver.strict_ids? => false) that would change behaviour for the rest of
# the suite in the same process.
RSpec.describe StreamWeaver::Opal::AppTimers do
  let(:app_class) do
    Class.new(StreamWeaver::App) { prepend StreamWeaver::Opal::AppTimers }
  end
  let(:runtime) do
    StreamWeaver::Opal::OpalRuntime.new(adapter: StreamWeaver::Adapter::Opal.new)
  end

  # What OpalRuntime#render_html does to the DSL block, minus the DOM: build a
  # fresh App and evaluate the block once. Re-implemented here only because
  # render_html hardcodes
  # StreamWeaver::App, which this spec deliberately does not patch.
  def render
    StreamWeaver::Opal::OpalRuntime.current = runtime
    app_class.new("__opal__", &doc).rebuild_with_state({})
  ensure
    StreamWeaver::Opal::OpalRuntime.current = nil
  end

  describe "OpalRuntime#register_timer" do
    it "installs a callsite once and ignores repeat registrations" do
      3.times { runtime.register_timer(:every, "every:1", 1) { nil } }

      expect(runtime.timer_callsites).to eq(["every:1"])
    end

    it "keeps distinct callsites separate" do
      runtime.register_timer(:every, "every:1", 1) { nil }
      runtime.register_timer(:every, "every:2", 2) { nil }
      runtime.register_timer(:after, "after:1", 5) { nil }

      expect(runtime.timer_callsites).to contain_exactly("every:1", "every:2", "after:1")
    end

    # Deduping the TIMER must not freeze the BLOCK. A timer block closes over
    # DSL-time data, so if the first execution's block is the one that runs
    # forever, a doc polling state[:rows] keeps polling render-1's rows. The
    # count being right is not worth the closure going stale.
    it "runs the most recently registered block for a callsite, not the first" do
      fired = []
      runtime.register_timer(:every, "every:1", 1) { fired << :first }
      runtime.register_timer(:every, "every:1", 1) { fired << :second }
      runtime.register_timer(:every, "every:1", 1) { fired << :third }

      runtime.fire_timer("every:1")
      expect(fired).to eq([:third])
    end

    it "still holds exactly one timer for that callsite" do
      runtime.register_timer(:every, "every:1", 1) { nil }
      runtime.register_timer(:every, "every:1", 1) { nil }

      expect(runtime.timer_callsites).to eq(["every:1"])
    end
  end

  describe "a doc rendered repeatedly" do
    let(:doc) do
      proc do
        every(1) { nil }
        after(5) { nil }
        text "component one"
        text "component two"
      end
    end

    it "has exactly one live timer per callsite after one render" do
      render
      expect(runtime.timer_callsites).to contain_exactly("every:1", "after:1")
    end

    it "still has exactly one live timer per callsite after five renders" do
      5.times { render }
      expect(runtime.timer_callsites).to contain_exactly("every:1", "after:1")
    end
  end

  describe "a doc with several same-kind callsites" do
    let(:doc) do
      proc do
        every(1) { nil }
        every(2) { nil }
        text "only component"
      end
    end

    it "counts them independently and still does not grow across renders" do
      3.times { render }
      expect(runtime.timer_callsites).to contain_exactly("every:1", "every:2")
    end
  end

  describe "callsite identity" do
    let(:doc) do
      proc do
        every(1) { nil }
        every(2) { nil }
        after(3) { nil }
      end
    end

    it "numbers same-kind timer calls by position within one DSL-block execution" do
      render
      expect(runtime.timer_callsites).to eq(["every:1", "every:2", "after:1"])
    end

    # Ordinal identity only holds while every timer call runs on every render.
    # A conditional timer shifts the ones after it onto the wrong identity --
    # and since the period is fixed at first install, the later block would
    # start running on the earlier block's interval. `key:` is the escape hatch.
    context "when a timer is conditional" do
      def render_with(live)
        StreamWeaver::Opal::OpalRuntime.current = runtime
        app_class.new("__opal__") do
          every(1, key: :poll_a) { nil } if live
          every(5, key: :poll_b) { nil }
        end.rebuild_with_state({})
      ensure
        StreamWeaver::Opal::OpalRuntime.current = nil
      end

      it "keeps each keyed timer on its own identity when the condition flips" do
        render_with(true)
        expect(runtime.timer_callsites).to contain_exactly("every:poll_a", "every:poll_b")

        render_with(false)
        expect(runtime.timer_callsites).to contain_exactly("every:poll_a", "every:poll_b")
      end

      it "would collapse poll_b onto poll_a's slot without a key" do
        StreamWeaver::Opal::OpalRuntime.current = runtime
        app_class.new("__opal__") { every(5) { nil } }.rebuild_with_state({})

        # Unkeyed, the lone surviving timer takes the first ordinal -- which is
        # the identity the conditional timer would have owned.
        expect(runtime.timer_callsites).to eq(["every:1"])
      ensure
        StreamWeaver::Opal::OpalRuntime.current = nil
      end
    end

    it "does not mint a second set of keys when one App re-runs its block" do
      app = app_class.new("__opal__", &doc)
      StreamWeaver::Opal::OpalRuntime.current = runtime
      2.times { app.rebuild_with_state({}) }

      expect(runtime.timer_callsites).to eq(["every:1", "every:2", "after:1"])
    ensure
      StreamWeaver::Opal::OpalRuntime.current = nil
    end
  end
end
