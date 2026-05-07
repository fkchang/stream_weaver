# frozen_string_literal: true

module StreamWeaver
  module Opal
    class ReactiveState
      def initialize(hash = {})
        @data         = hash.transform_keys(&:to_sym)
        @watchers     = Hash.new { |h, k| h[k] = [] }
        @tracking     = nil
        @track_map    = Hash.new { |h, k| h[k] = [] }
        @change_hooks = []
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

      def track(region_id)
        prev      = @tracking
        @tracking = region_id
        result    = yield
        @tracking = prev
        result
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
        @watchers[key].each { |w| w.call(@data[key]) }
      end
    end
  end
end
