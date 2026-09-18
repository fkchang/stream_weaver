# frozen_string_literal: true

module StreamWeaver
  module Opal
    class ReactiveState
      # Bounds on watcher dispatch for ONE top-level state write. Watcher
      # callbacks run synchronously inside #[]=, so the guard has to live at the
      # dispatch site -- a cap on the async re-render never sees the recursion.
      #
      # Two bounds because there are two shapes of runaway: DEPTH catches a
      # watcher chain that recurses (the :a -> :a feedback loop), CALLS catches
      # one that fans out wide without nesting deeply (many watchers on one key,
      # each writing another key). The budget resets per top-level write, which
      # is what keeps real traffic clear of it: typing is one call per
      # keystroke, and a deliberate :a -> :b -> :c chain is depth 3.
      MAX_WATCHER_DEPTH           = 25
      MAX_WATCHER_CALLS_PER_WRITE = 200

      # The last state-update-loop message, or nil -- a pull-style query for
      # callers that just want to ask whether the guard has tripped, rather
      # than registering an on_state_loop handler. OpalRuntime uses the handler.
      attr_reader :state_loop_error

      def initialize(hash = {})
        @data             = hash.transform_keys(&:to_sym)
        @watchers         = Hash.new { |h, k| h[k] = [] }
        @tracking         = nil
        @track_map        = Hash.new { |h, k| h[k] = [] }
        @change_hooks     = []
        @loop_handlers    = []
        @watch_depth      = 0
        @watch_calls      = 0
        @loop_tripped     = false
        @state_loop_error = nil
      end

      def [](key)
        key = key.to_sym
        @track_map[key] << @tracking if @tracking && !@track_map[key].include?(@tracking)
        @data[key]
      end

      def []=(key, value)
        key = key.to_sym
        old = @data[key]
        @data[key] = value
        return if old == value
        notify_watchers(key)
        @change_hooks.each { |h| h.call(key) }
      end

      def watch(key, &block)
        @watchers[key.to_sym] << block
      end

      def on_any_change(&block)
        @change_hooks << block
      end

      # Called with (message, key) when the loop guard trips. A host registers
      # one of these to put the message somewhere a person will see it.
      def on_state_loop(&block)
        @loop_handlers << block
      end

      def track(region_id)
        prev, @tracking = @tracking, region_id
        yield
      ensure
        @tracking = prev
      end

      def reset_tracking
        @track_map.clear
      end

      def dependencies_for(region_id)
        @track_map.each_with_object([]) { |(key, ids), arr| arr << key if ids.include?(region_id) }
      end

      def dependencies_for_key(key)
        @track_map[key.to_sym].dup
      end

      def ==(other)
        other.is_a?(ReactiveState) ? @data == other.to_h : @data == other
      end

      def to_h
        @data.dup
      end

      def key?(key)
        @data.key?(key.to_sym)
      end

      private

      def notify_watchers(key)
        watchers = @watchers.fetch(key, [])
        return if watchers.empty?

        top_level = @watch_depth.zero?
        @watch_calls = 0 if top_level
        @watch_depth += 1
        begin
          watchers.each do |w|
            # One check location, checked before every callback: @loop_tripped
            # unwinds the entire chain rather than letting each enclosing frame
            # resume dispatching once an inner frame has tripped.
            break if @loop_tripped
            break trip_state_loop(key, exhausted_bound) if exhausted_bound

            @watch_calls += 1
            w.call(@data[key])
          end
        ensure
          @watch_depth -= 1
          @loop_tripped = false if top_level
        end
      end

      # Which bound is spent, or nil. Named rather than boolean so the message
      # can tell the author what actually happened -- a nested feedback loop and
      # a wide fan-out need different things looked at.
      def exhausted_bound
        return :depth if @watch_depth > MAX_WATCHER_DEPTH
        return :calls if @watch_calls >= MAX_WATCHER_CALLS_PER_WRITE

        nil
      end

      def trip_state_loop(key, bound)
        @loop_tripped = true
        @state_loop_error =
          "StreamWeaver: doc has a state update loop. Writing state[:#{key}] re-triggered its " \
          "own watchers #{loop_bound_description(bound)}, so dispatch was stopped. " \
          "Look at watch(:#{key}) in the doc -- its callback must not write back into the same " \
          "key, or into a key whose watcher writes it."
        @loop_handlers.each { |h| h.call(@state_loop_error, key) }
      end

      def loop_bound_description(bound)
        if bound == :depth
          "#{MAX_WATCHER_DEPTH} levels deep (a nested feedback loop)"
        else
          "#{MAX_WATCHER_CALLS_PER_WRITE} times in one write (a wide fan-out, not deep nesting)"
        end
      end
    end
  end
end
