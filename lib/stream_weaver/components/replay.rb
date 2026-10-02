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
        @auto_idle = nil
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

      # Derive the windows from the events instead of declaring them: the
      # timeline splits wherever two consecutive events are more than `idle`
      # minutes apart, and each break gets a generated gap card ("6h 10m
      # later" / "Back at Thu 09:05"). An explicit `gap` at the same position
      # wins over the generated one. Mutually exclusive with `window`.
      def auto_windows(idle: 120)
        raise ArgumentError, "auto_windows idle must be at least 2 minutes" unless idle.is_a?(Integer) && idle >= 2

        @auto_idle = idle
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
          windows: windows, gaps: gap_list, events: sorted.map { |e| e.except(:at) },
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
          auto_windows: @auto_idle,
          gaps: @gaps,
          events: @events.map { |e| e.slice(:at, :lane, :text, :inc, :human) },
          finale: @finale
        }
      end

      # Integer division below is always `div`: under Opal `/` on integers is float division.

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

      # How an effect kind reads on a chip: [singular, plural]. The default
      # label is this, not the raw command: session-skeleton truncates `cmd` to
      # 140 characters and real ones are compound shell lines, so the prefix is
      # often unrelated to the effect (a `sed` ahead of the `git commit`).
      SKELETON_LABELS = {
        git_commit: ["commit", "commits"], git_push: ["push", "pushes"], pr_opened: ["PR opened", "PRs opened"],
        github_invite: ["GitHub invite", "GitHub invites"], teams_post: ["Teams post", "Teams posts"],
        email_draft: ["email draft", "email drafts"], email_sent: ["email sent", "emails sent"],
        jira_created: ["Jira card created", "Jira cards created"], jira_updated: ["Jira updated", "Jira updates"],
        aws_change: ["AWS change", "AWS changes"], sharepoint_upload: ["SharePoint upload", "SharePoint uploads"],
        ledger_write: ["ledger write", "ledger writes"], message_post: ["message posted", "messages posted"]
      }.freeze

      def self.skeleton_label(kind, item)
        singular, plural = SKELETON_LABELS[kind.to_sym] || [kind.to_s.tr("_", " "), "#{kind.to_s.tr('_', ' ')}s"]
        count = item["count"].to_i
        count > 1 ? "#{count} #{plural}" : singular
      end

      # Turn `session-skeleton --json` output into event tuples, oldest first.
      # Times keep the date ("Thu 10-01 09:48"): the day label shown is the
      # weekday, but the date is what keeps two different Thursdays apart.
      # @param report [Hash] parsed session-skeleton JSON
      # @param map [Hash] effect kind => [lane, counter_key] (kinds not listed are skipped)
      # @param label [Proc] (effect_kind, item) -> chip text; default is the command
      # @return [Array<Array>] tuples for #events
      def self.events_from_skeleton(report, map:, label: method(:skeleton_label))
        rows = report.fetch("effects").flat_map do |kind, data|
          lane, key = map[kind.to_sym]
          next [] unless lane

          data["items"].map do |item|
            [item.fetch("at"), lane, label.call(kind, item), key ? { key => item["count"] || 1 } : {}]
          end
        end
        rows.sort_by { |row| skeleton_sort_key(row.first) }
      end

      # Several sessions into one replay, one lane per session.
      # @param reports [Hash] lane => parsed session-skeleton JSON
      # @param counters [Hash] effect kind => counter key (nil: show the chip, count nothing)
      # @return [Array<Array>] merged tuples, oldest first
      def self.events_from_skeletons(reports, counters:, label: method(:skeleton_label))
        rows = reports.flat_map do |lane, report|
          events_from_skeleton(report, map: counters.to_h { |kind, key| [kind, [lane, key]] }, label: label)
        end
        rows.sort_by { |row| skeleton_sort_key(row.first) }
      end

      # "Thu 10-01 09:48" -> ["10-01", "09:48"]; a time with no date sorts by clock alone.
      def self.skeleton_sort_key(at)
        parts = at.split
        [parts.size >= 3 ? parts[1] : "", parts.last]
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
        raise ArgumentError, "use either window or auto_windows, not both" if @auto_idle && !@windows.empty?
        return @windows unless @windows.empty?
        return [] if @events.empty?

        ms = @events.map { |e| e[:m] }.sort
        return [[[ms.first - 1, 0].max, ms.last + 1]] unless @auto_idle

        ms.slice_when { |a, b| b - a > @auto_idle }.map { |run| [[run.first - 1, 0].max, run.last + 1] }
      end

      # Authored gaps first, then a generated card for each break without one.
      def gap_list
        ws = windows
        (0...[ws.size - 1, 0].max).map { |i| @gaps[i] || generated_gap(ws[i], ws[i + 1]) }
      end

      # Measured event to event (windows are padded one minute each side). Day
      # labels carry only ORDER, so when both carry an MM-DD date the real
      # calendar distance is used instead: "Thu 10-01" to "Thu 10-08" is a
      # week, not one day. Without dates, consecutive labels are assumed to be
      # consecutive days.
      def generated_gap(before, after)
        last_event = before.last - 1
        next_event = after.first + 1
        minutes = next_event - last_event + extra_calendar_days(last_event, next_event) * DAY_MINUTES
        { caption: "#{duration_text(minutes)} later", sub: "Back at #{clock_label(next_event)}" }
      end

      # Whole days the dates say passed beyond what the replay's day order implies.
      def extra_calendar_days(from_minute, to_minute)
        from_day = @days[from_minute.div(DAY_MINUTES)].to_s
        to_day = @days[to_minute.div(DAY_MINUTES)].to_s
        a = day_of_year(from_day)
        b = day_of_year(to_day)
        return 0 unless a && b

        real = (b - a) % 365
        [real - (to_minute.div(DAY_MINUTES) - from_minute.div(DAY_MINUTES)), 0].max
      end

      CUMULATIVE_DAYS = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334].freeze

      # "Thu 10-01" -> 274 (non-leap year; only differences matter). nil with no MM-DD.
      def day_of_year(day_key)
        m = day_key.match(/(\d{1,2})-(\d{1,2})/)
        return nil unless m && (1..12).cover?(m[1].to_i)

        CUMULATIVE_DAYS[m[1].to_i - 1] + m[2].to_i
      end

      def duration_text(minutes)
        d, rest = minutes.divmod(1440)
        h, m = rest.divmod(60)
        parts = []
        parts << "#{d}d" if d.positive?
        parts << "#{h}h" if h.positive?
        parts << "#{m}m" if m.positive? && d.zero?
        parts.join(" ")
      end

      # "Thu 09:05", or just "09:05" when the replay has no day labels. A label
      # that carries a date keeps it ("Thu 10-08 09:00"), since that is what
      # tells two Thursdays apart.
      def clock_label(minute)
        key = @days[minute.div(DAY_MINUTES)].to_s
        day = key.match?(/\d-\d/) ? key : key.split.first
        hm = format("%02d:%02d", (minute % DAY_MINUTES).div(60), minute % 60)
        day ? "#{day} #{hm}" : hm
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
        return if @auto_idle || @gaps.size >= windows.size - 1

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
