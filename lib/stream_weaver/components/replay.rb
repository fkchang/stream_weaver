# frozen_string_literal: true

require "json"

module StreamWeaver
  module Components
    # Animated "event replay": a big clock, bumping counters, lane tracks that
    # receive event chips, interstitial cards between active time windows, and
    # a closing card. Everything plays client-side (sw-replay.js, vanilla JS),
    # so it works offline, inside an iframe, and under a screen recorder.
    #
    # The block is instance_eval'd on the component (or yielded it when it
    # takes an argument), so the vocabulary is just:
    #
    #   counter :commit, "commits"
    #   lane :access, "DinoCloud access", sub: "AWS, GitHub", color: :cyan
    #   window "Wed 18:40".."Wed 18:50"
    #   gap "Then 6 hours away", sub: "Back after dinner"
    #   event "Thu 09:48", :nowcast, "commit: dedupe", commit: 1
    #   milestone "Thu 11:46", :prep, "Ask: I have 15 min to prep"
    #   finale "Noon.", "{commit} commits before lunch"
    #
    # Times are "[Day ]HH:MM". Days are free-form labels ("Wed", "Thu 10-01");
    # their order is order of first appearance. With no `window`, one window
    # spanning the events is inferred.
    #
    # sw- CSS classes: sw-replay, sw-replay__header, __clock, __counters,
    # __lanes, __lane, __track, __chip(--human/--old), __card, __controls.
    class Replay < Base
      PALETTE = {
        cyan: "#2aa198", blue: "#268bd2", yellow: "#b58900", magenta: "#d33682",
        green: "#859900", orange: "#cb4b16", red: "#dc322f", violet: "#6c71c4"
      }.freeze

      DEFAULTS = { ms_per_minute: 340, max_visible: 4, height: "36rem", autoplay: true }.freeze

      attr_reader :title, :subtitle, :footnote, :ms_per_minute, :max_visible, :height, :autoplay

      # @param title [String] header title
      # @param subtitle [String, nil] dim text after the title
      # @param footnote [String, nil] small provenance line under the lanes
      # @param ms_per_minute [Integer] wall-clock ms per simulated minute at 1x
      # @param max_visible [Integer] chips kept per lane (older ones drop off)
      # @param height [String] CSS height of the stage ("100vh" for an iframe)
      # @param autoplay [Boolean] start playing on load
      def initialize(title:, subtitle: nil, footnote: nil, ms_per_minute: 340, max_visible: 4, height: "36rem",
                     autoplay: true, **options, &block)
        @title = title
        @subtitle = subtitle
        @footnote = footnote
        @ms_per_minute = ms_per_minute
        @max_visible = max_visible
        @height = height
        @autoplay = autoplay
        @counters = []
        @lanes = []
        @windows = []
        @window_args = []
        @gaps = []
        @events = []
        @finale = nil
        @days = []
        super(**options)
        block&.arity == 1 ? block.call(self) : instance_eval(&block) if block
      end

      def counter(key, label)
        @counters << { key: key.to_s, label: label }
      end

      def lane(id, name, sub: nil, color: :cyan)
        @lanes << { id: id.to_s, name: name, sub: sub, color: PALETTE.fetch(color) { color.to_s }, color_arg: color }
      end

      def window(range)
        @windows << [minute_of(range.begin), minute_of(range.end)]
        @window_args << [range.begin.to_s, range.end.to_s]
      end

      def gap(caption, sub: nil)
        @gaps << { caption: caption, sub: sub }
      end

      def event(at, lane, text, human: false, **inc)
        @events << { m: minute_of(at), at: at.to_s, t: at.to_s.split.last, lane: lane.to_s, text: text,
                     inc: inc.transform_keys(&:to_s), human: human }
      end

      def milestone(at, lane, text, **inc)
        event(at, lane, text, human: true, **inc)
      end

      def finale(caption, sub = nil)
        @finale = { caption: caption, sub: sub }
      end

      # Add many events at once, e.g. from Replay.events_from_skeleton.
      # @param rows [Array<Array>] [at, lane, text, {inc}, human?] tuples
      def events(rows)
        rows.each { |at, lane, text, inc, human| event(at, lane, text, human: human || false, **(inc || {}).transform_keys(&:to_sym)) }
      end

      # Plain-hash config consumed by sw-replay.js. Validates cross references.
      def to_config
        validate!
        sorted = @events.sort_by { |e| e[:m] }
        {
          title: title, subtitle: subtitle, msPerMinute: ms_per_minute, maxVisible: max_visible,
          autoplay: autoplay, days: @days.map { |d| d.split.first }, counters: @counters,
          lanes: @lanes.map { |l| l.except(:color_arg) },
          windows: windows, gaps: @gaps, events: sorted.map { |e| e.except(:at) },
          finale: finale_with_totals(sorted)
        }
      end

      # The values as authored (day-labelled times, color names, the finale
      # template with its {placeholders}), in authored order. The org Writer
      # emits from this so Reader -> Writer reaches a fixpoint.
      def authoring
        {
          options: { title: title, subtitle: subtitle, footnote: footnote, ms_per_minute: ms_per_minute,
                     max_visible: max_visible, height: height, autoplay: autoplay },
          counters: @counters,
          lanes: @lanes.map { |l| l.slice(:id, :name, :sub).merge(color: l[:color_arg]) },
          windows: @window_args,
          gaps: @gaps,
          events: @events.map { |e| e.slice(:at, :lane, :text, :inc, :human) },
          finale: @finale
        }
      end

      # Deterministic content hash (same in MRI and Opal, unlike String#hash).
      # Gives the stage an id derived from its content: a live runtime that
      # morphs the page pairs nodes by id, so an unchanged replay keeps its
      # running stage and an edited one gets a fresh node. Same contract as
      # Components::Mermaid#diagram_id.
      def fingerprint
        to_json_safe.each_char.reduce(5381) { |h, c| (h * 33 + c.ord) % 4_294_967_291 }.to_s(36)
      end

      def to_json_safe
        JSON.generate(to_config).gsub("</", '<\/')
      end

      def render(view, state)
        view.adapter.render_replay(view, self, state)
      end

      # Turn `session-skeleton --json` output into event tuples.
      # @param report [Hash] parsed session-skeleton JSON
      # @param map [Hash] effect kind => [lane, counter_key] (kinds not listed are skipped)
      # @param label [Proc] (effect_kind, item) -> chip text; default is the command
      # @return [Array<Array>] tuples for #events (times as "Thu 09:48")
      def self.events_from_skeleton(report, map:, label: ->(_kind, item) { item["cmd"] })
        report.fetch("effects").flat_map do |kind, data|
          lane, key = map[kind.to_sym]
          next [] unless lane

          data["items"].map do |item|
            [skeleton_time(item.fetch("at")), lane, label.call(kind, item), key ? { key => item["count"] || 1 } : {}]
          end
        end
      end

      # "Thu 10-01 09:48" -> "Thu 09:48" (the date part only disambiguates days)
      def self.skeleton_time(at)
        parts = at.split
        "#{parts.first} #{parts.last}"
      end

      private

      DAY_MINUTES = 1440

      def minute_of(at)
        parts = at.to_s.split
        hm = parts.pop
        raise ArgumentError, "bad replay time #{at.inspect} (want \"[Day ]HH:MM\")" unless hm =~ /\A(\d{1,2}):(\d{2})\z/

        day = parts.join(" ")
        @days << day unless @days.include?(day)
        @days.index(day) * DAY_MINUTES + $1.to_i * 60 + $2.to_i
      end

      def windows
        return @windows unless @windows.empty?
        return [] if @events.empty?

        ms = @events.map { |e| e[:m] }
        [[ms.min - 1, ms.max + 1]]
      end

      def validate!
        lane_ids = @lanes.map { |l| l[:id] }
        keys = @counters.map { |c| c[:key] }
        @events.each do |e|
          raise ArgumentError, "replay event #{e[:text].inspect}: unknown lane #{e[:lane]}" unless lane_ids.include?(e[:lane])

          (e[:inc].keys - keys).each { |k| raise ArgumentError, "replay event #{e[:text].inspect}: unknown counter #{k}" }
          next if windows.any? { |s, f| e[:m].between?(s, f) }

          raise ArgumentError, "replay event #{e[:text].inspect} at #{e[:t]} falls outside every window"
        end
        return if @gaps.size >= windows.size - 1

        raise ArgumentError, "replay needs #{windows.size - 1} gap(s) for #{windows.size} windows, got #{@gaps.size}"
      end

      def totals(events)
        events.each_with_object(Hash.new(0)) { |e, t| e[:inc].each { |k, n| t[k] += n } }
      end

      def finale_with_totals(events)
        return nil unless @finale

        t = totals(events)
        fill = ->(s) { s&.gsub(/\{(\w+)\}/) { @counters.any? { |c| c[:key] == $1 } ? t[$1].to_s : raise(ArgumentError, "finale: unknown counter {#{$1}}") } }
        { caption: fill.(@finale[:caption]), sub: fill.(@finale[:sub]) }
      end
    end
  end
end
