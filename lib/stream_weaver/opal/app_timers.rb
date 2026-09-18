# frozen_string_literal: true

require_relative "runtime"

module StreamWeaver
  module Opal
    # Lifecycle-aware `every`/`after` for the browser runtime, prepended onto
    # StreamWeaver::App by opal_entry.rb.
    #
    # It lives in its own file rather than inside opal_entry because opal_entry
    # also installs overrides that change behaviour globally (counter-based
    # button ids, StreamWeaver.strict_ids? => false), so a test that needs the
    # timer behaviour must be able to reach it without pulling those in.
    #
    # All this module does is name the callsite; OpalRuntime#register_timer owns
    # what happens with it.
    module AppTimers
      # Numbering is per DSL-block execution, so reset it at the top of each
      # one. render_html happens to build a fresh App per execution, which would
      # reset the counters anyway -- not relying on that means re-running the
      # block on one App still yields the same callsite keys rather than a
      # second set.
      def rebuild_with_state(...)
        @sw_timer_counters = {}
        super
      end

      def after(seconds, key: nil, &block) = register_sw_timer(:after, seconds, key, &block)

      def every(seconds, key: nil, &block) = register_sw_timer(:every, seconds, key, &block)

      private

      # A timer's identity, which is what the runtime dedupes on.
      #
      # Opal has no source_location (the same constraint that gives buttons
      # counter-based ids), so the default is the call's ordinal position among
      # same-kind timer calls within one execution of the DSL block. Every
      # execution walks the same calls in the same order, so the Nth `every` is
      # the same authored callsite every time.
      #
      # That holds only while every `every`/`after` call runs on every render.
      # A CONDITIONAL or loop-generated timer breaks it -- in
      #
      #   every(1) { poll_a } if state[:live]
      #   every(5) { poll_b }
      #
      # `state[:live]` going false shifts poll_b onto the `every:1` identity, so
      # it starts running on the 1-second interval. Pass `key:` to pin identity
      # to something the doc controls instead:
      #
      #   every(1, key: :poll_a) { poll_a } if state[:live]
      #
      # Note also that `seconds` is read only when the timer is first installed
      # -- a callsite keeps the period it was created with, so `every(state
      # [:interval])` will not re-time itself. Change the key to get a new one.
      def next_timer_callsite(kind, key)
        return "#{kind}:#{key}" if key

        n = (@sw_timer_counters[kind] || 0) + 1
        @sw_timer_counters[kind] = n
        "#{kind}:#{n}"
      end

      def register_sw_timer(kind, seconds, key, &block)
        runtime = OpalRuntime.current
        if runtime
          return runtime.register_timer(kind, next_timer_callsite(kind, key), seconds, &block)
        end

        # No runtime in scope means the block is running outside render_html
        # (a bare App). Nothing tracks lifecycle there, so install directly --
        # same behaviour as before this guard existed.
        OpalRuntime.install_browser_timer(kind, seconds, &block)
      end
    end
  end
end
