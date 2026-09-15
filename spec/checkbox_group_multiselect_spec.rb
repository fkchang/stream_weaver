# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "cgi"

# Regression for the cultiv-ai daily-checkin bug (flagged live 2026-09-12 and
# again 2026-09-14 by the user: "you can't pick more than one... it's been so
# long that it's been happening"). Root cause: render_checkbox_group gave every
# checkbox in a group the same unbracketed `name`, so a /update POST with
# multiple boxes checked put multiple `key=value` pairs on the wire without
# `[]`. Rack::Utils.parse_nested_query keeps only the LAST duplicate key
# ("a=1&a=2" -> {"a"=>"2"}), so checking several items collapsed the group's
# state down to whichever one happened to serialize last -- exactly "can only
# select one" / "unchecking one unchecks everyone" (an unchecked box is
# omitted entirely by the browser, so with one item left checked the payload
# has no other survivors to fall back on).
RSpec.describe "checkbox_group multi-select (stream_weaver checkbox-group-multiselect)" do
  def build_app
    StreamWeaver::App.new("Checkbox group fixture") do
      checkbox_group(:selected, select_all: "Select All") do
        item("alpha") { text "Alpha" }
        item("beta") { text "Beta" }
        item("gamma") { text "Gamma" }
      end
    end
  end

  def session_for(app)
    Rack::Test::Session.new(Rack::MockSession.new(app.generate))
  end

  it "renders each checkbox with a bracketed, array-producing name" do
    html = session_for(build_app).get("/").body

    expect(html.scan(/name="selected\[\]"/).size).to eq(3)
    expect(html).not_to include('name="selected"')
  end

  # Posts the way a real browser does: one repeated "name=value" pair per
  # checked box, joined by "&", using whatever `name` attribute the rendered
  # HTML actually carries -- NOT a Hash literal (a Ruby Hash can't have
  # duplicate keys, so a Hash-based post can't reproduce the pre-fix wire
  # shape at all; it has to be a raw urlencoded body).
  def post_checked_boxes(session, html, key, checked_values)
    name = html[/name="(#{Regexp.escape(key)}\[?\]?)"/, 1] || key.to_s
    body = checked_values.map { |v| "#{CGI.escape(name)}=#{CGI.escape(v)}" }.join("&")
    session.post("/update", body, "CONTENT_TYPE" => "application/x-www-form-urlencoded")
  end

  it "keeps every checked item when multiple boxes in the group are checked" do
    session = session_for(build_app)
    html = session.get("/").body

    response = post_checked_boxes(session, html, :selected, %w[alpha gamma])

    expect(response.status).to eq(200)
    expect(state_sync_selected(response.body)).to contain_exactly("alpha", "gamma")
  end

  it "does not silently collapse to one value the way the unbracketed name did" do
    session = session_for(build_app)
    html = session.get("/").body

    response = post_checked_boxes(session, html, :selected, %w[alpha beta gamma])

    expect(state_sync_selected(response.body).size).to eq(3)
  end

  def state_sync_selected(html)
    patch = html[%r{<script[^>]+id="sw-state-patch"[^>]*>(.*?)</script>}m, 1]
    return JSON.parse(patch)["set"]["selected"] if patch && JSON.parse(patch)["set"].key?("selected")

    snapshot = html[%r{<script[^>]+id="sw-state-data"[^>]*>(.*?)</script>}m, 1]
    JSON.parse(snapshot)["selected"]
  end
end
