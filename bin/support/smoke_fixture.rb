# frozen_string_literal: true

# Fixture app for bin/smoke (stream_weaver-gsv).
#
# Exercises: JSON endpoints, non-JSON POST bodies, binary/attachment downloads,
# and a reserved-path collision (POST /update always loses to StreamWeaver's
# internal /update route, and registering it must warn at boot).
#
# Loaded two ways by bin/smoke:
#   1. standalone — `ruby smoke_fixture.rb` with PORT set, calls run! directly
#   2. service    — `load`ed by StreamWeaver::Service#load_app, where
#                    __FILE__ != $0, so run! must NOT fire
#
# The `.tap { |a| a.run! if __FILE__ == $0 }` guard is required: without it,
# service mode dies because loading this file would also boot a second Puma
# server on top of the running service (stream_weaver-5ad). Do not "simplify"
# this away.

require 'stream_weaver'

app "Smoke Sales Dashboard" do
  endpoint(:get, "/api/status") { |req| { ok: true, service: "smoke", echo: req.params } }
  endpoint(:post, "/webhook/test") { |req| [202, { 'X-Smoke' => 'yes' }, "queued:#{req.body.read}"] }
  endpoint(:get, "/export/report.csv") do |_req|
    [200,
     { 'Content-Type' => 'text/csv', 'Content-Disposition' => 'attachment; filename="report.csv"' },
     "region,total\nwest,42\n"]
  end
  endpoint(:post, "/update") { |_req| "never reached" } # reserved — must warn, must lose
  header1 "Smoke Demo"
  md "smoke fixture"
end.tap { |a| a.run! if __FILE__ == $0 } # stream_weaver-5ad guard — see comment above
