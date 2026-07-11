# frozen_string_literal: true

require "spec_helper"
require "rack/test"

RSpec.describe "fragments" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:generation) { "fragment-session" }

  def render(app, state = {})
    app.rebuild_with_state(state, generation: generation)
    StreamWeaver::Views::AppContentView.new(app, state, adapter, false).call
  end

  def run(app, state, token, manifest:, headers: {})
    StreamWeaver::InteractionRunner.new(
      app: app, state: state, params: {}, interaction: :action, target: token,
      adapter: adapter, persist: ->(_value) {}, action_manifest: manifest,
      generation: generation, response_headers: ->(values) { headers.merge!(values) },
      state_version: 4
    ).call
  end

  it "renders stable hierarchical ids and disambiguates duplicate names" do
    app = StreamWeaver::App.new("Fragments") do
      fragment(:results) { text "first" }
      fragment(:results) { text "second" }
      fragment(:outer) { fragment(:inner) { text "nested" } }
    end

    html = render(app)
    expect(html).to include('id="sw-frag-results"')
    expect(html).to include('id="sw-frag-results-dup-2"')
    expect(html).to include('id="sw-frag-outer--inner"')
  end

  it "turns punctuation-bearing names into safe target ids" do
    app = StreamWeaver::App.new("Safe IDs") { fragment(:"user.card #1") { text "safe" } }
    expect(render(app)).to include('id="sw-frag-user-card-1"')
  end

  it "raises for duplicate names under strict_ids" do
    app = StreamWeaver::App.new("Strict", strict_ids: true) do
      fragment(:same) { text "one" }
      fragment(:same) { text "two" }
    end
    expect { render(app) }.to raise_error(ArgumentError, /duplicate component id/)
  end

  it "targets interactive children and carries server-owned scope in named tokens" do
    app = StreamWeaver::App.new("Target") do
      action(:go) { |state, _| state[:went] = true }
      fragment(:results) { button "Go", action: :go, key: 1 }
    end

    html = render(app)
    token = html[%r{/action/([^"']+)}, 1]
    expect(html).to include('hx-target="#sw-frag-results"')
    expect(html).to include('hx-swap="morph:innerHTML"')
    expect(StreamWeaver::ActionToken.decode(token)).to include(f: "sw-frag-results")
  end

  it "carries fragment scope through table-cell component capture" do
    app = StreamWeaver::App.new("Table target") do
      action(:edit) { |state, key| state[:edited] = key }
      fragment(:people) do
        table [{ id: 1, name: "Ada" }], row_key: ->(person) { person[:id] } do
          column :name
          column :actions do |person|
            hstack { button "Edit", action: :edit, key: person[:id] }
          end
        end
      end
      text "UNRELATED PAGE COPY"
    end
    state = {}
    html = render(app, state)
    token = html[%r{/action/([^"']+)}, 1]

    expect(StreamWeaver::ActionToken.decode(token)).to include(f: "sw-frag-people")

    response = run(app, state, token, manifest: app.render_state.action_tokens.dup)
    expect(response).to include("Ada")
    expect(response).not_to include("UNRELATED PAGE COPY")
  end

  it "signs fragment scope and button-level updates for legacy callbacks" do
    app = StreamWeaver::App.new("Legacy scope") do
      fragment(:results) do
        button("Go", updates: :sidebar) { |state| state[:went] = true }
      end
      fragment(:sidebar) { text(state[:went] ? "updated" : "waiting") }
    end
    state = {}
    html = render(app, state)
    button_id = html[%r{/action/([^?"']+)}, 1]
    signed_scope = CGI.unescape(html[%r{_sw_fragment=([^"']+)}, 1])

    response = StreamWeaver::InteractionRunner.new(
      app: app, state: state, params: { "_sw_fragment" => signed_scope },
      interaction: :action, target: button_id, adapter: adapter, persist: ->(_value) {}
    ).call

    expect(response).to include("updated", 'hx-swap-oob="morph:innerHTML"')
    expect(response).not_to include('id="sw-state-data"')
  end

  it "targets live inputs at their fragment and scopes update responses" do
    app = StreamWeaver::App.new("Live scope") do
      fragment(:search) do
        text_field :query
        text "results for #{state[:query]}"
      end
      text "UNRELATED PAGE COPY"
    end
    session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
    html = session.get("/").body
    input = html[/<input[^>]+name="query"[^>]*>/]
    update_path = CGI.unescapeHTML(input[/hx-post="([^"]+)"/, 1])

    expect(input).to include('hx-target="#sw-frag-search"')

    response = session.post(update_path, query: "Ada")
    expect(response.body).to include("results for Ada", 'id="sw-state-patch"')
    expect(response.body).not_to include("UNRELATED PAGE COPY", 'id="sw-state-data"')
  end

  it "keeps live inputs outside fragments on full-container updates" do
    app = StreamWeaver::App.new("Live full") do
      text_field :query
      text "results for #{state[:query]}"
    end
    session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
    html = session.get("/").body
    input = html[/<input[^>]+name="query"[^>]*>/]

    expect(input).to include('hx-target="#app-container"')

    response = session.post("/update", query: "Ada")
    expect(response.body).to include("results for Ada", 'id="sw-state-data"')
    expect(response.body).not_to include('id="sw-state-patch"')
  end

  it "reruns once and returns only the target plus patch and declared OOB updates" do
    app = StreamWeaver::App.new("Scoped") do
      action(:increment, updates: :sidebar_count) do |state, _|
        state[:count] += 1
        state.delete(:obsolete)
      end
      fragment(:results) do
        text "result #{state[:count]}"
        button "Increment", action: :increment, key: 1
      end
      fragment(:sidebar_count) { text "sidebar #{state[:count]}" }
      text "UNRELATED PAGE COPY"
    end
    state = { count: 1, obsolete: "old" }
    html = render(app, state)
    token = html[%r{/action/([^"']+)}, 1]
    manifest = app.render_state.action_tokens.dup
    allow(app).to receive(:rebuild_with_state).and_call_original

    response = run(app, state, token, manifest: manifest)

    expect(app).to have_received(:rebuild_with_state).once
    expect(response).to include("result 2", "sidebar 2", 'hx-swap-oob="morph:innerHTML"')
    expect(response).not_to include("UNRELATED PAGE COPY")
    patch = JSON.parse(response[%r{<script[^>]+id="sw-state-patch"[^>]*>(.*?)</script>}m, 1])
    expect(patch).to eq("set" => { "count" => 2 }, "delete" => ["obsolete"], "version" => 5)
  end

  it "does not allow state values to terminate the JSON patch script" do
    hostile = "</script><script>alert(1)</script>"
    view = StreamWeaver::Views::StatePatchView.new(set: { value: hostile }, delete: [], version: 1).call
    expect(view).not_to include("</script><script>")
    expect(view).to include("\\u003c/script>")
  end

  it "retargets to the full view when the declared fragment disappears" do
    app = StreamWeaver::App.new("Fallback") do
      action(:leave) { |state, _| state[:show] = false }
      fragment(:panel) { button "Leave", action: :leave, key: 1 } if state.fetch(:show, true)
      text "FULL PAGE"
    end
    state = { show: true }
    html = render(app, state)
    token = html[%r{/action/([^"']+)}, 1]
    headers = {}

    response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

    expect(headers).to eq("HX-Retarget" => "#app-container")
    expect(response).to include("FULL PAGE", 'id="sw-state-data"')
  end

  it "retargets invalid named capabilities instead of swapping a full view into a fragment" do
    app = StreamWeaver::App.new("Invalid") do
      action(:go) { |state, _| state[:went] = true }
      fragment(:panel) { button "Go", action: :go, key: 1 }
      text "FULL PAGE"
    end
    state = {}
    token = render(app)[%r{/action/([^"']+)}, 1]
    headers = {}

    response = run(app, state, token, manifest: Set.new, headers: headers)

    expect(headers).to eq("HX-Retarget" => "#app-container")
    expect(response).to include("FULL PAGE", 'id="sw-state-data"')
    expect(state).not_to have_key(:went)
  end

  it "keeps fragment-free rendering byte-identical" do
    app = StreamWeaver::App.new("Legacy") { text "unchanged" }
    app.rebuild_with_state({})
    before = StreamWeaver::Views::AppContentView.new(app, {}, adapter, false).call
    app.rebuild_with_state({})
    expect(StreamWeaver::Views::AppContentView.new(app, {}, adapter, false).call).to eq(before)
  end
end
