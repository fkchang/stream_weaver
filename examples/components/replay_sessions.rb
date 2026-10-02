# Canvas-doc fragment: a replay built straight from session-skeleton reports, with
# no windows or gap captions written by hand.
#
#   SESSION_SKELETON=/path/to/session-skeleton SESSIONS="uuid-one,uuid-two" \
#     streamweaver export examples/components/replay_sessions.rb --bare -o replay.html
#
# One lane per session, in the order given. `auto_windows` splits the timeline on idle
# gaps and writes the gap cards ("7d 8h later"), using the real calendar distance
# because skeleton times carry dates.
require "json"
require "open3"

skeleton = ENV.fetch("SESSION_SKELETON")
session_ids = ENV.fetch("SESSIONS").split(",").map(&:strip)

reports = session_ids.to_h do |id|
  path = Dir.glob(File.join(Dir.home, ".claude", "projects", "*", "#{id}*.jsonl")).first or abort "no transcript for #{id}"
  [id[0, 8].to_sym, JSON.parse(Open3.capture2(skeleton, path, "--json", err: File::NULL).first)]
end

replay title: "Sessions replay", subtitle: "from session-skeleton", height: "100vh",
       footnote: "Every chip is a confirmed effect from a session transcript." do
  counter :commit, "commits"
  counter :pr, "PRs"
  reports.each { |lane_id, report| lane lane_id, report["title"].to_s[0, 28], sub: "#{report['prompt_count']} prompts" }
  auto_windows idle: 180
  events StreamWeaver::Components::Replay.events_from_skeletons(
    reports, counters: { git_commit: :commit, pr_opened: :pr, git_push: nil }
  )
  finale "Done.", "{commit} commits, {pr} PRs."
end
