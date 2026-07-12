# frozen_string_literal: true

require "spec_helper"
require "rack/test"

# stream_weaver-tv4: browser evidence reported that typing in the rivet
# parity slice's search field (a debounced text_field living inside a
# fragment, filtering the same fragment's table) "filters nothing" -- with
# rack-level specs green, meaning if there is a bug it's in what the client
# actually receives, not server behavior.
#
# Extensive curl-driven diagnosis against the real slice (single request,
# a realistic 4-keystroke sequential session, and a fragment-vs-non-fragment
# attribute diff) found the emitted wiring and the full request/response
# round trip to be complete and correct at every layer curl can observe --
# hx-trigger/hx-post/hx-target/hx-include/x-model all present and correctly
# scoped, and a request built from those exact attributes filters correctly
# across a multi-keystroke session with state-version tracking intact. No
# emitted-attribute defect reproduces outside a browser.
#
# The most likely explanation is collateral damage from stream_weaver-ho5:
# an uncaught exception during `htmx:afterSettle` (e.g. a focus/selection
# restore against stale bounds) could abort the rest of that listener before
# it ran -- and before this fix, this was the same listener that merged
# server state into Alpine's store. adapter/alpinejs.rb now (a) does that
# merge in `htmx:beforeSwap`, decoupled from focus/scroll restoration
# entirely (see stream_weaver-ho5), and (b) wraps focus/selection restore in
# its own try/catch so a failure there can never cascade into anything else
# in the listener.
#
# These specs pin the provable half: the emitted attribute set is complete,
# and a request built strictly from those attributes (not hand-typed
# params) reaches the server and filters correctly -- so this spec fails the
# moment a future change drops or misconfigures any of them.
RSpec.describe "live input fragment wiring (stream_weaver-tv4)" do
  def build_app
    StreamWeaver::App.new("Live search fixture") do
      fragment(:people) do
        text_field :query, placeholder: "Search...", debounce: 250
        [{ name: "Nora Albrecht" }, { name: "Milo Fenwick" }].each do |person|
          text person[:name] if state[:query].to_s.empty? || person[:name].downcase.include?(state[:query].to_s.downcase)
        end
      end
      text "UNRELATED PAGE COPY"
    end
  end

  # Parse the emitted attribute set off the live input tag exactly as a
  # browser would see it -- no assumptions about what the values *should* be.
  def parsed_input_attrs(html)
    tag = html[/<input[^>]+name="query"[^>]*>/]
    attrs = {}
    tag.scan(/([\w-]+)="([^"]*)"/).each { |k, v| attrs[k] = CGI.unescapeHTML(v) }
    attrs
  end

  it "emits a complete, correctly-scoped attribute set for a live input inside a fragment" do
    session = Rack::Test::Session.new(Rack::MockSession.new(build_app.generate))
    html = session.get("/").body
    attrs = parsed_input_attrs(html)

    expect(attrs["hx-trigger"]).to eq("keyup changed delay:250ms")
    expect(attrs["hx-post"]).to match(%r{\A/update\?_sw_fragment=})
    expect(attrs["hx-target"]).to eq("#sw-frag-people")
    expect(attrs["hx-include"]).to eq("[x-model]")
    expect(attrs["hx-swap"]).to eq("morph:innerHTML")
    expect(attrs["x-model"]).to eq("query")
  end

  it "filters correctly when the request is built strictly from the emitted attributes" do
    session = Rack::Test::Session.new(Rack::MockSession.new(build_app.generate))
    html = session.get("/").body
    attrs = parsed_input_attrs(html)

    # Fails if hx-post, hx-trigger's implied param name, or the fragment
    # scope were ever dropped or malformed -- nothing here is hardcoded from
    # knowledge of the server implementation, only from what the browser
    # would read off this element.
    post_url = attrs.fetch("hx-post")
    param_name = attrs.fetch("name")

    response = session.post(post_url, param_name => "Nora").body

    expect(response).to include("Nora Albrecht")
    expect(response).not_to include("Milo Fenwick", "UNRELATED PAGE COPY")
  end

  it "keeps filtering correctly across a realistic multi-keystroke session" do
    session = Rack::Test::Session.new(Rack::MockSession.new(build_app.generate))
    html = session.get("/").body
    attrs = parsed_input_attrs(html)
    post_url = attrs.fetch("hx-post")
    param_name = attrs.fetch("name")

    responses = %w[N No Nor Nora].map { |q| session.post(post_url, param_name => q).body }

    expect(responses[0..2]).to all(include("Nora Albrecht"))
    expect(responses.last).to include("Nora Albrecht")
    expect(responses.last).not_to include("Milo Fenwick")

    versions = responses.map { |r| JSON.parse(r[%r{<script[^>]+id="sw-state-patch"[^>]*>(.*?)</script>}m, 1])["version"] }
    expect(versions).to eq([1, 2, 3, 4])
  end
end
