# Canvas-doc fragment: `streamweaver export examples/components/replay_thursday.rb -o out.html`
# or `canvas-push replay < examples/components/replay_thursday.rb`.
# Reproduces the hand-written ~250-line "Thursday Before Noon" page in ~50 lines.
replay title: "Wednesday night to Thursday noon", subtitle: "five deliverables, one person",
       footnote: "Every event is a confirmed effect from the session transcripts (session-skeleton), or a milestone from the case files (dashed).",
       ms_per_minute: 340, height: "100vh" do
  counter :commit, "commits"
  counter :invite, "invites"
  counter :draft,  "email drafts"
  counter :post,   "vendor posts"
  counter :card,   "Jira cards"
  counter :aws,    "AWS changes"

  lane :access,  "DinoCloud access",   sub: "AWS, GitHub, vendor asks", color: :cyan
  lane :nowcast, "Nowcast cards",      sub: "orchestrator + 3 workers", color: :blue
  lane :view,    "Event engagement",   sub: "quarterly run to a TUI",   color: :yellow
  lane :license, "Writing principles", sub: "learns from my edits",     color: :magenta
  lane :prep,    "Meeting prep",       sub: "15-minute deadline",       color: :green

  window "Wed 18:40".."Wed 18:50"
  gap "Then 6 hours away.", sub: "Back after dinner, past midnight."
  window "Thu 00:36".."Thu 01:00"
  gap "Too tired to finish. Sleep.", sub: "Picked up at 9am, before two noon meetings."
  window "Thu 09:05".."Thu 12:02"

  event "Wed 18:44", :access, "Vendor logins, attempt 1 (later undone)", aws: 1
  event "Wed 18:45", :access, "Access group + admin role", aws: 1
  milestone "Thu 00:40", :access, "3 AWS accounts created, guided step by step"
  event "Thu 00:43", :access, "Admin access wired into 3 accounts", aws: 2
  event "Thu 00:44", :access, "Dead-end attempt removed", aws: 1
  milestone "Thu 00:50", :access, "IAM logins for 7 people in 4 accounts"
  event "Thu 00:55", :access, "5 encrypted credential emails drafted", draft: 5
  milestone "Thu 09:12", :nowcast, "Ask: start HEDG-5130 + 5131, orchestrate them"
  milestone "Thu 09:12", :view, "Ask: run the quarterly viewership metrics"
  event "Thu 09:33", :nowcast, "Both cards moved to In Progress"
  milestone "Thu 09:35", :nowcast, "3 worker sessions launched"
  event "Thu 09:48", :nowcast, "commit: remove one-time dedupe task", commit: 1
  event "Thu 09:51", :nowcast, "2 commits: Airbrake alert, key collision check", commit: 2
  event "Thu 09:53", :nowcast, "2 commits: fail syncs safely, skip redundant writes", commit: 2
  event "Thu 09:58", :nowcast, "commit: reviewer-caught dedupe bug fixed", commit: 1
  event "Thu 10:00", :access, "AWS ready, posted to the vendor", post: 1
  event "Thu 10:16", :nowcast, "Fixed its own launcher (tabs, not windows)", commit: 1
  event "Thu 10:33", :nowcast, "Company AI plugin repo created", commit: 1
  event "Thu 10:44", :view, "commit: quarterly run logic + run log", commit: 1
  event "Thu 10:51", :view, "commit: the TUI wizard", commit: 1
  event "Thu 10:51", :access, "GitHub seats card filed", card: 1
  event "Thu 10:51", :access, "GitHub invite", invite: 1
  event "Thu 10:59", :view, "commit: validate gate before execute", commit: 1
  event "Thu 11:01", :access, "4 more GitHub invites", invite: 4
  event "Thu 11:15", :access, "All 10 vendor asks answered; Teams tool upgraded", post: 1, commit: 2
  event "Thu 11:38", :license, "Principles updated from this morning's edits", commit: 1
  milestone "Thu 11:46", :prep, "Ask: \"I have 15 min to prep\""
  milestone "Thu 11:56", :prep, "First deck, 9.5 minutes later"
  milestone "Thu 11:59", :prep, "Final deck, into the meeting"

  finale "Noon. Both meetings ready, vendor unblocked.",
         "{commit} commits, {invite} invites, {draft} email drafts, {post} vendor posts, before lunch. Then the afternoon happened."
end
