# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "cgi"

# Regression for the cultiv-ai /meetings card picker (2026-11-06): unchecking
# every card and pressing Approve still created all three Jira cards.
#
# Root cause: a browser omits unchecked boxes, so an EMPTY checkbox_group puts
# nothing on the wire. The server cannot tell "the group is empty" from "the
# group was not part of this request", so it kept the old (all-checked) state.
# Lone checkboxes escape this because the server knows their keys and treats a
# missing one as false; a group has no such rule.
#
# Fix: every multi-select group renders a presence marker
# (`_sw_present[]=<model>`, included by input_selector). The marker says the
# group was on the page; a present group with no values is [] and a request
# without the marker leaves the group alone.
RSpec.describe "empty selection in checkbox_group / multi chip_group" do
  # What the Approve button saw in state[:sel] / state[:tags], one entry per press.
  let(:seen) { [] }

  def group_app
    log = seen # the App block runs on the app, where `seen` is not reachable
    StreamWeaver::App.new("group") do
      checkbox_group(:sel, default: %w[dc_1 dc_2 dc_3], select_all: "All", select_none: "None") do
        %w[dc_1 dc_2 dc_3].each { |i| item(i) { text i } }
      end
      text_field :note
      button("Approve", id: "approve") { log << Array(state[:sel]).dup }
    end
  end

  def chip_app
    log = seen
    StreamWeaver::App.new("chips") do
      chip_group :tags, %w[a b c], multi: true, default: %w[a b c]
      chip_group :one, %w[x y], multi: false, default: "x"
      button("Approve", id: "approve") { log << Array(state[:tags]).dup }
    end
  end

  def session_for(app) = Rack::Test::Session.new(Rack::MockSession.new(app.generate))

  def post_form(session, path, pairs)
    body = pairs.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join("&")
    session.post(path, body, "CONTENT_TYPE" => "application/x-www-form-urlencoded")
  end

  def approve_path(html) = "/action/#{html[%r{/action/([^"']+)}, 1]}"

  # What htmx sends: every hx-include element that has a name and value. The
  # marker is part of the page, so it is part of the payload.
  def markers(html) = html.scan(/<input[^>]*name="_sw_present\[\]"[^>]*>/).map { |tag| ["_sw_present[]", tag[/value="([^"]*)"/, 1]] }

  def click_approve(session, html, checked, key: "sel")
    post_form(session, approve_path(html), markers(html) + checked.map { |v| ["#{key}[]", v] })
    seen.last
  end

  def scoped_app
    log = seen
    StreamWeaver::App.new("scoped") do
      scope :prefs, kind: :fragment, retain: true do |_s|
        chip_group :tags, %w[a b c], multi: true, default: %w[a b c]
        text_field :label
      end
      button("Approve", id: "approve") { log << Array(state.dig(:prefs, :tags)).dup }
    end
  end

  describe "checkbox_group" do
    it "renders one presence marker the include selector reaches" do
      html = session_for(group_app).get("/").body

      expect(markers(html)).to eq([["_sw_present[]", "sel"]])
      expect(html).to include("data-sw-present")
      expect(StreamWeaver::Adapter::AlpineJS.new.input_selector).to include("[data-sw-present]")
    end

    it "keeps the marker out of the canvas field harvest (no x-model on it)" do
      html = session_for(group_app).get("/").body
      marker = html[/<input[^>]*data-sw-present[^>]*>/]

      expect(marker).not_to include("x-model")
    end

    it "A: nothing unchecked keeps all three" do
      s = session_for(group_app)
      expect(click_approve(s, s.get("/").body, %w[dc_1 dc_2 dc_3])).to match_array(%w[dc_1 dc_2 dc_3])
    end

    it "B: unchecking one keeps the other two" do
      s = session_for(group_app)
      expect(click_approve(s, s.get("/").body, %w[dc_1 dc_3])).to match_array(%w[dc_1 dc_3])
    end

    it "C: unchecking every box (or pressing None) means nothing is selected" do
      s = session_for(group_app)
      expect(click_approve(s, s.get("/").body, [])).to eq([])
    end

    it "D: clearing the last box through /update means nothing is selected" do
      s = session_for(group_app)
      html = s.get("/").body
      post_form(s, "/update", markers(html) + [["sel[]", "dc_2"]])
      post_form(s, "/update", markers(html))

      expect(click_approve(s, html, [])).to eq([])
    end

    it "E: a request that does not carry the group leaves the selection alone" do
      s = session_for(group_app)
      html = s.get("/").body
      post_form(s, "/update", [["note", "hello"]])

      expect(click_approve(s, html, %w[dc_1 dc_2 dc_3])).to match_array(%w[dc_1 dc_2 dc_3])
      post_form(s, approve_path(html), [["note", "again"]])
      expect(seen.last).to match_array(%w[dc_1 dc_2 dc_3])
    end

    # The marker names `note` but the request carries no `note` value -- the
    # one shape that reaches the scalar guard (a request that also carried
    # `note` is skipped before it).
    it "F: a marker naming a scalar state key cannot blank it" do
      s = session_for(group_app)
      post_form(s, "/update", [["note", "keep me"]])
      post_form(s, "/update", [["_sw_present[]", "note"]])

      expect(s.get("/").body).to include("keep me")
    end

    it "wires All and None to fire the same /update a manual check does" do
      html = session_for(group_app).get("/").body
      buttons = html.scan(/<button[^>]*@click="sel = [^"]*"[^>]*>/)

      expect(buttons.size).to eq(2)
      expect(buttons).to all(include("$nextTick"))
      expect(buttons).to all(include("dispatchEvent"))
    end
  end

  describe "multi chip_group" do
    it "marks only the multi-select group, not the single-select one" do
      html = session_for(chip_app).get("/").body

      expect(markers(html)).to eq([["_sw_present[]", "tags"]])
    end

    it "clearing every chip means nothing is selected" do
      s = session_for(chip_app)
      expect(click_approve(s, s.get("/").body, [], key: "tags")).to eq([])
    end

    it "unchecking one chip keeps the others" do
      s = session_for(chip_app)
      expect(click_approve(s, s.get("/").body, %w[a c], key: "tags")).to match_array(%w[a c])
    end
  end

  describe "multi chip_group inside a scope block" do
    it "names the group by its scoped path" do
      expect(markers(session_for(scoped_app).get("/").body)).to eq([["_sw_present[]", "prefs.tags"]])
    end

    it "clearing every chip empties the scoped selection" do
      s = session_for(scoped_app)
      expect(click_approve(s, s.get("/").body, [], key: "prefs[tags]")).to eq([])
    end

    it "unchecking one chip keeps the others" do
      s = session_for(scoped_app)
      expect(click_approve(s, s.get("/").body, %w[a c], key: "prefs[tags]")).to match_array(%w[a c])
    end

    it "a sibling field posted without the marker leaves the chips alone" do
      s = session_for(scoped_app)
      html = s.get("/").body
      post_form(s, approve_path(html), [["prefs[label]", "hello"]])

      expect(seen.last).to match_array(%w[a b c])
    end

    it "a marker naming a scoped scalar cannot blank it" do
      s = session_for(scoped_app)
      html = s.get("/").body
      post_form(s, "/update", [["prefs[label]", "keep me"]])
      post_form(s, "/update", [["_sw_present[]", "prefs.label"]])

      expect(s.get("/").body).to include("keep me")
    end
  end
end
