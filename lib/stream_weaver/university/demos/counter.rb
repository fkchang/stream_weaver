require 'stream_weaver'

app "Counter" do
  state[:count] ||= 0
  header1 "Six lines of Ruby"
  text "Count: #{state[:count]}"
  button("+1") { |s| s[:count] += 1 }
end.run!

# ^ That is the whole app: a six-line block, in an eight-line file. Nothing
# has been elided, and nothing below this line runs -- `.run!` blocks.
#
# StreamWeaver University, step 2 (story: step-2-dsl-reexec). The worker
# runs THIS file, verbatim, rather than writing its own: two real worker
# sessions each lost a debug cycle to the "six-line app" framing, one by
# omitting `require 'stream_weaver'` (NoMethodError: undefined method
# 'app') and the other by omitting `.run!` (builds the app, starts no
# server, exits silently). Both lines are above, on purpose.
#
#   ruby "$(streamweaver university-demo counter)"
#
# There is no event-handler code here and no route. The block on line 3 is
# re-executed on every click; `state[:count]` is one higher when it runs,
# so line 5 renders a different number. That single idea -- the block
# re-runs -- is every other thing StreamWeaver does, wearing different
# clothes.
