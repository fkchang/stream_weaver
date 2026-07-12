# frozen_string_literal: true

require "spec_helper"
require "rack/test"

# stream_weaver-ho5: a modal's chip_group/text_field fields are seeded by a
# button handler (row action) into top-level state keys that never existed
# when the page's own #app-container x-data was first emitted (their DSL
# calls only run once the enclosing `if state[:editing]` fragment condition
# is true). The browser reported "Uncaught ReferenceError: edit_tags is not
# defined" and a save that silently discarded the user's edit.
#
# Root cause: the response that opens the modal DOES carry the fresh values
# for those keys (in #sw-state-patch's `set`), but the client only merged
# that payload into Alpine's reactive store on `htmx:afterSettle` -- *after*
# alpine-morph had already initialized the newly-morphed-in elements (and
# evaluated their bare `x-model="edit_tags"` bindings) as part of the swap
# itself. The fix (adapter/alpinejs.rb) moves the merge to `htmx:beforeSwap`,
# parsed from the still-unswapped response text, so the key exists before
# any element referencing it enters the DOM.
#
# These specs pin the two provable halves of that fix without a browser:
# (1) every bare x-model root a response introduces is present in that same
# response's state sync payload (the precondition the timing fix relies on),
# and (2) the merge runs pre-swap, not only post-settle. A full save
# round-trip proves the pipeline delivers edited values end to end once the
# client can actually see them.
RSpec.describe "Alpine x-data completeness (stream_weaver-ho5)" do
  # Bare `x-model="identifier"` bindings (no `.`/`[` -- i.e. not `_form.foo`
  # or `scope.foo`) are StreamWeaver's only shorthand for "this binds a
  # top-level state key directly" (see adapter/alpinejs.rb render_text_field
  # et al). Anything bound that way must be resolvable in Alpine's store the
  # instant it appears in the DOM.
  def bare_x_model_roots(html)
    html.scan(/x-model="([^".\[]+)"/).flatten.uniq
  end

  def state_sync_keys(html)
    patch = html[%r{<script[^>]+id="sw-state-patch"[^>]*>(.*?)</script>}m, 1]
    return JSON.parse(patch)["set"].keys if patch

    snapshot = html[%r{<script[^>]+id="sw-state-data"[^>]*>(.*?)</script>}m, 1]
    return [] unless snapshot

    JSON.parse(snapshot).keys - %w[_transient _sw_version]
  end

  # Fixture mirrors the rivet parity slice shape: a row action seeds
  # previously-unset top-level keys and opens a sibling modal fragment built
  # from text_field + chip_group, and a named action saves them back to a
  # plain record (store never lives in state, per the parity methodology).
  def build_app(record)
    StreamWeaver::App.new("Modal chip fixture") do
      fragment(:people) do
        text "#{record[:name]} / #{record[:relationship]} / #{record[:tags].join(',')}"
        button "Edit", key: 1, updates: :modal do |s|
          s[:edit_name] = record[:name]
          s[:edit_relationship] = record[:relationship]
          s[:edit_tags] = record[:tags].dup
          s[:editing] = true
        end
      end

      fragment(:modal) do
        if state[:editing]
          text_field :edit_name, submit: false
          text_field :edit_relationship, submit: false
          chip_group :edit_tags, %w[Family Friend Colleague], multi: true, submit: false
          button "Save", action: :save, key: :save
        end
      end

      action(:save, updates: :people) do |s, _key|
        record[:name] = s[:edit_name].to_s
        record[:relationship] = s[:edit_relationship].to_s
        record[:tags] = Array(s[:edit_tags])
        s[:editing] = false
      end
    end
  end

  def open_modal(session, html)
    edit_token = html[%r{/action/([^?"']+)\?}, 1]
    fragment_param = CGI.unescape(html[/_sw_fragment=([^"']+)/, 1])
    session.post("/action/#{edit_token}", _sw_fragment: fragment_param).body
  end

  it "carries a fresh value for every bare x-model root the modal response introduces" do
    record = { id: 1, name: "Ada", relationship: "Mentor", tags: %w[Family] }
    session = Rack::Test::Session.new(Rack::MockSession.new(build_app(record).generate))
    initial_html = session.get("/").body

    # None of these keys exist yet -- the modal fragment's `if state[:editing]`
    # guard means chip_group/text_field never ran during this render.
    expect(bare_x_model_roots(initial_html)).to be_empty

    modal_html = open_modal(session, initial_html)
    introduced_roots = bare_x_model_roots(modal_html)

    expect(introduced_roots).to include("edit_name", "edit_relationship", "edit_tags")
    expect(introduced_roots - state_sync_keys(modal_html)).to eq([]),
      "every bare x-model root a response introduces must have a fresh value " \
      "in that response's state sync payload, or the client has nothing to " \
      "merge before alpine-morph initializes the element"
  end

  it "merges server state into Alpine's store before the swap, not only after settle" do
    adapter = StreamWeaver::Adapter::AlpineJS.new
    view = double("view")
    javascript = []
    allow(view).to receive(:script) { |*_args, **_kwargs, &block| block&.call }
    allow(view).to receive(:raw)
    allow(view).to receive(:safe) { |value| javascript << value; value }

    adapter.render_cdn_scripts(view)
    javascript = javascript.join

    before_swap = javascript[/htmx:beforeSwap.*?\}\);/m]
    after_settle = javascript[/htmx:afterSettle.*?\}\);/m]

    expect(before_swap).to include("sw-state-data", "sw-state-patch", "Alpine.$data(container)")
    expect(after_settle).not_to include("Alpine.$data(container)")
  end

  it "round-trips an edited modal save through to the record and the response" do
    record = { id: 1, name: "Ada", relationship: "Mentor", tags: %w[Family] }
    session = Rack::Test::Session.new(Rack::MockSession.new(build_app(record).generate))
    modal_html = open_modal(session, session.get("/").body)

    save_token = CGI.unescape(modal_html.scan(%r{/action/([^"'?]+)\??[^"']*"}).last.first)
    save_response = session.post("/action/#{CGI.escape(save_token)}",
      edit_name: "Adaeze", edit_relationship: "Investor", "edit_tags[]" => ["Colleague"]).body

    expect(record).to eq(id: 1, name: "Adaeze", relationship: "Investor", tags: ["Colleague"])
    expect(save_response).to include("Adaeze / Investor / Colleague")
  end
end
