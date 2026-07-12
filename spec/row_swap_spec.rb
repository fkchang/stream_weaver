# frozen_string_literal: true

require "spec_helper"
require "cgi"

# stream_weaver-95k: row-granular table swaps. A named action whose token
# carries a row key that matches a rendered row in the target fragment's
# table narrows the response to that row (edit-in-place), a removal envelope
# (delete), or an appended row (create) instead of the whole fragment -- but
# only when the table's row identity list proves the mutation is row-local
# (gsd/analysis/decisions/table-cells.md sections 3+6).
RSpec.describe "row-granular table swaps" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:generation) { "row-swap-session" }

  def render(app, state)
    app.rebuild_with_state(state, generation: generation)
    StreamWeaver::Views::AppContentView.new(app, state, adapter, false).call
  end

  def run(app, state, token, manifest:, headers: {}, params: {})
    StreamWeaver::InteractionRunner.new(
      app: app, state: state, params: params, interaction: :action, target: token,
      adapter: adapter, persist: ->(_value) {}, action_manifest: manifest,
      generation: generation, response_headers: ->(values) { headers.merge!(values) },
      state_version: 4
    ).call
  end

  def action_token(html, action_name)
    html.scan(%r{hx-post="/action/([^"]+)"}).flatten.find do |token|
      StreamWeaver::ActionToken.decode(token)[:a] == action_name
    end
  end

  describe "edit-in-place" do
    let(:app) do
      StreamWeaver::App.new("Roster") do
        action(:promote) { |state, key| state[:people].find { |p| p[:id] == key }[:role] = "lead" }
        fragment(:people) do
          table state[:people], row_key: ->(p) { p[:id] } do
            column :name
            column :role
            column :actions do |person|
              button "Promote", action: :promote, key: person[:id]
            end
          end
        end
      end
    end

    it "narrows to the mutated row and retargets/reswaps it, without re-sending the fragment" do
      state = { people: [{ id: 1, name: "Ada", role: "eng" }, { id: 2, name: "Bo", role: "eng" }] }
      html = render(app, state)
      token = action_token(html, "promote")
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      target = headers.fetch("HX-Retarget")
      expect(target).to match(/-row-1\z/)
      expect(headers).to eq("HX-Retarget" => target, "HX-Reswap" => "outerHTML")
      expect(response.lstrip).to start_with("<tr ")
      expect(response).to include("lead", "Ada")
      # Bo's row itself isn't re-sent -- "Bo" only shows up (as expected) inside
      # the JSON state patch, which always carries the whole `people` array
      # since it's a single top-level state key (a separate, pre-existing cost
      # this ticket doesn't touch -- see stream_weaver-95k's narrowing scope).
      expect(response).not_to include(">Bo<")
      expect(response).to include('id="sw-state-patch"')
    end
  end

  describe "delete" do
    let(:app) do
      StreamWeaver::App.new("Roster") do
        action(:remove) { |state, key| state[:people].reject! { |p| p[:id] == key } }
        fragment(:people) do
          table state[:people], row_key: ->(p) { p[:id] } do
            column :name
            column :actions do |person|
              button "Remove", action: :remove, key: person[:id]
            end
          end
        end
      end
    end

    it "returns a removal envelope: no row content, HX-Reswap delete targeting the row" do
      state = { people: [{ id: 1, name: "Ada" }, { id: 2, name: "Bo" }] }
      html = render(app, state)
      token = action_token(html, "remove")
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      expect(headers["HX-Retarget"]).to match(/-row-1\z/)
      expect(headers["HX-Reswap"]).to eq("delete")
      expect(response).not_to include("Ada")
      expect(response).to include('id="sw-state-patch"')
    end
  end

  describe "create" do
    let(:app) do
      StreamWeaver::App.new("Roster") do
        action(:add) { |state, _key| state[:people] << { id: 2, name: "Bo" } }
        fragment(:people) do
          table state[:people], row_key: ->(p) { p[:id] } do
            column :name
          end
          button "Add", action: :add, key: :add
        end
      end
    end

    it "appends only the new row via beforeend, not the whole table" do
      state = { people: [{ id: 1, name: "Ada" }] }
      html = render(app, state)
      token = action_token(html, "add")
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      expect(headers["HX-Reswap"]).to eq("beforeend")
      expect(headers["HX-Retarget"]).to match(/tbody\z/)
      expect(response).to include("Bo")
      # Ada's existing row isn't re-sent -- "Ada" only shows up (as expected)
      # inside the JSON state patch (see the edit test's comment above).
      expect(response).not_to include(">Ada<")
    end
  end

  describe "fallback when the mutation is not provably row-local" do
    let(:app) do
      StreamWeaver::App.new("Roster") do
        action(:sort_desc) { |state, _key| state[:people].sort_by! { |p| -p[:id] } }
        fragment(:people) do
          table state[:people], row_key: ->(p) { p[:id] } do
            column :name
            column :actions do |person|
              button "Sort", action: :sort_desc, key: person[:id]
            end
          end
        end
      end
    end

    it "falls back to the full fragment when row order changes" do
      state = { people: [{ id: 1, name: "Ada" }, { id: 2, name: "Bo" }] }
      html = render(app, state)
      token = action_token(html, "sort_desc")
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      expect(headers["HX-Retarget"]).to be_nil
      expect(headers["HX-Reswap"]).to be_nil
      expect(response).to include("Ada", "Bo")
    end
  end

  describe "row mutation with declared updates:" do
    let(:app) do
      StreamWeaver::App.new("Roster") do
        action(:promote, updates: :count) { |state, key| state[:people].find { |p| p[:id] == key }[:role] = "lead" }
        fragment(:people) do
          table state[:people], row_key: ->(p) { p[:id] } do
            column :name
            column :role
            column :actions do |person|
              button "Promote", action: :promote, key: person[:id]
            end
          end
        end
        fragment(:count) { text "total #{state[:people].length}" }
      end
    end

    it "still carries the declared OOB update alongside the narrowed row" do
      state = { people: [{ id: 1, name: "Ada", role: "eng" }] }
      html = render(app, state)
      token = action_token(html, "promote")
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      expect(headers["HX-Reswap"]).to eq("outerHTML")
      expect(response).to include("total 1", 'hx-swap-oob="morph:innerHTML"')
    end
  end

  describe "legacy block-button path" do
    let(:app) do
      StreamWeaver::App.new("Roster") do
        fragment(:people) do
          table state[:people], row_key: ->(p) { p[:id] } do
            column :name
            column :actions do |person|
              button("Promote") { |state| state[:people].find { |p| p[:id] == person[:id] }[:role] = "lead" }
            end
          end
        end
      end
    end

    it "stays on the full-fragment response, untouched by row narrowing" do
      state = { people: [{ id: 1, name: "Ada", role: "eng" }] }
      html = render(app, state)
      button_id = html[%r{/action/([^?"']+)}, 1]
      signed_scope = CGI.unescape(html[%r{_sw_fragment=([^"']+)}, 1])
      headers = {}

      response = run(app, state, button_id, manifest: app.render_state.action_tokens.dup, headers: headers,
                      params: { "_sw_fragment" => signed_scope })

      expect(headers["HX-Reswap"]).to be_nil
      expect(headers["HX-Retarget"]).to be_nil
      expect(response).to include("lead", "Ada")
    end
  end
end
