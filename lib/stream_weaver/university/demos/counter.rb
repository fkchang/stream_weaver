require 'stream_weaver'

app "Counter" do
  callout "This whole app is the file your agent just ran -- nothing hidden. Click +1 -- the whole block re-runs on the server and the count updates. When you're done playing: come back to your Claude session and say \"done\".", variant: :info
  state[:count] ||= 0
  header1 "Six lines of Ruby"
  text "Count: #{state[:count]}"
  button("+1") { |s| s[:count] += 1 }
end.run!

# ^ The mechanism above is still the whole app: a six-line block (four
# statements wrapped by `app "Counter" do` and `end.run!`), in an eight-line
# file. Nothing has been elided, and nothing below this line runs -- `.run!`
# blocks. StreamWeaver University, step 2 (story: step-2-dsl-reexec). The
# worker runs THIS file, verbatim, rather than writing its own: two real
# worker sessions each lost a debug cycle to the "six-line app" framing, one
# by omitting `require 'stream_weaver'` (NoMethodError: undefined method
# 'app') and the other by omitting `.run!` (builds the app, starts no
# server, exits silently). Both lines are above, on purpose.
#
#   ruby "$(streamweaver university-demo counter)"
#
# There is no event-handler code here and no route. The block on line 5 is
# re-executed on every click; `state[:count]` is one higher when it runs, so
# line 7 renders a different number. That single idea -- the block re-runs
# -- is every other thing StreamWeaver does, wearing different clothes.
#
# Round-6 UAT (2026-09-03): the app used to pop up with no explanation of
# its own, so anyone who tabbed over before the agent's narration caught up
# saw a bare counter and nothing else. The `callout` above is the file's
# ninth line -- deliberately not part of the six-line mechanism, and not one
# of the two bookend lines named above either. It is the one line meant to
# be read on screen, not walked through.
