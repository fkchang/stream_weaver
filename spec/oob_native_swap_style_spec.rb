# frozen_string_literal: true

require "spec_helper"
require "cgi"

# stream_weaver-e4p: htmx core's `hx-swap-oob` scanning never consults
# swap-style extensions -- an OOB element whose `hx-swap-oob` value is an
# extension-only style like "morph:innerHTML" is silently skipped by a real
# browser (proven via playwright-cli against examples/parity/rivet_people_slice.rb;
# see bd show stream_weaver-e4p). Every `hx-swap-oob` this gem emits must
# therefore use one of htmx's *native* swap styles -- morph stays available
# for PRIMARY targets only (those go through the extension's own swap-style
# dispatch, which does work).
RSpec.describe "hx-swap-oob emits only htmx-native swap styles (stream_weaver-e4p)" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:generation) { "oob-native-session" }

  NATIVE_OOB_STYLES = %w[innerHTML outerHTML beforebegin afterbegin beforeend afterend delete none].freeze

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

  # Every `hx-swap-oob="..."` value found in `html` must be (or start with,
  # for the `style:selector` form) one of htmx's built-in styles -- never an
  # extension-only style like "morph:innerHTML".
  def assert_all_oob_styles_native(html)
    values = html.scan(/hx-swap-oob="([^"]+)"/).flatten
    expect(values).not_to be_empty
    values.each do |value|
      style = value.split(":", 2).first
      expect(NATIVE_OOB_STYLES).to include(style), "non-native hx-swap-oob style #{value.inspect} in:\n#{html}"
    end
  end

  it "updates: a non-row-local extra (fallback full-fragment OOB)" do
    app = StreamWeaver::App.new("Updates extra") do
      action(:increment, updates: :sidebar_count) { |state, _key| state[:count] = state[:count].to_i + 1 }
      fragment(:results) do
        text "result #{state[:count]}"
        button "Increment", action: :increment, key: 1
      end
      fragment(:sidebar_count) { text "sidebar #{state[:count]}" }
    end
    state = { count: 1 }
    html = render(app, state)
    token = html[%r{/action/([^"']+)}, 1]

    response = run(app, state, token, manifest: app.render_state.action_tokens.dup)

    expect(response).to include("sidebar 2")
    assert_all_oob_styles_native(response)
  end

  it "primary: + updates: composed in the same response" do
    app = StreamWeaver::App.new("Primary plus updates") do
      action(:select, updates: :sidebar, primary: :detail) { |state, key| state[:selected] = key }
      fragment(:board) { button "View 1", action: :select, key: 1 }
      fragment(:detail) { text "Selected: #{state[:selected]}" }
      fragment(:sidebar) { text "count: #{state[:selected].to_i}" }
    end
    state = {}
    html = render(app, state)
    token = html[%r{/action/([^"']+)}, 1]

    response = run(app, state, token, manifest: app.render_state.action_tokens.dup)

    expect(response).to include("Selected: 1", "count: 1")
    assert_all_oob_styles_native(response)
  end

  it "flash auto-delivered as OOB under a scoped response" do
    app = StreamWeaver::App.new("Flash OOB", chrome: false) do
      action(:save) { |state, _key| flash[:notice] = "Saved!" }
      fragment(:flash) { flash_messages }
      fragment(:panel) { button "Save", action: :save, key: 1 }
    end
    state = {}
    html = render(app, state)
    token = html[%r{/action/([^"']+)}, 1]

    response = run(app, state, token, manifest: app.render_state.action_tokens.dup)

    expect(response).to include("Saved!", 'id="sw-frag-flash"')
    assert_all_oob_styles_native(response)
  end

  it "a modal opened via updates: (legacy block-button, mirrors rivet_people_slice's Edit button)" do
    app = StreamWeaver::App.new("Modal via updates", chrome: false) do
      fragment(:panel) do
        button "Edit", key: 1, updates: :quick_edit_modal do |s|
          s[:editing_id] = 1
        end
      end
      fragment(:quick_edit_modal) do
        if state[:editing_id]
          open_modal(:quick_edit)
          modal(:quick_edit, title: "Quick edit") do
            text_field :edit_name, label: "Name", submit: false
          end
        end
      end
    end
    state = {}
    html = render(app, state)
    button_id = html[%r{/action/([^?"']+)}, 1]
    signed_scope = CGI.unescape(html[%r{_sw_fragment=([^"']+)}, 1])

    response = StreamWeaver::InteractionRunner.new(
      app: app, state: state, params: { "_sw_fragment" => signed_scope },
      interaction: :action, target: button_id, adapter: adapter, persist: ->(_value) {}
    ).call

    expect(response).to include('data-sw-open="true"', "Quick edit")
    assert_all_oob_styles_native(response)
  end

  it "a row-local edit delivered as an extra (not the primary target)" do
    app = StreamWeaver::App.new("Row-local extra") do
      action(:promote, updates: :people_summary) { |state, key| state[:people].find { |p| p[:id] == key }[:role] = "lead" }
      fragment(:roster) do
        table state[:people], row_key: ->(p) { p[:id] } do
          column :name
          column :actions do |person|
            button "Promote", action: :promote, key: person[:id]
          end
        end
      end
      fragment(:people_summary) do
        table state[:people], row_key: ->(p) { p[:id] } do
          column :name
          column :role
        end
      end
    end
    state = { people: [{ id: 1, name: "Ada", role: "eng" }] }
    html = render(app, state)
    token = html[%r{/action/([^"']+)}, 1]

    response = run(app, state, token, manifest: app.render_state.action_tokens.dup)

    expect(response).to include("lead")
    assert_all_oob_styles_native(response)
  end
end
