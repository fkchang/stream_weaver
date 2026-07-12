# frozen_string_literal: true

require "spec_helper"
require "rack/test"

# stream_weaver-78a + stream_weaver-m3t: a button whose action affects a
# sibling fragment (tyrion's board "View" button refreshing a detail pane)
# used to always resend its own *enclosing* fragment as the primary swap --
# the sibling never actually refreshed in the browser. `primary:` lets a
# button/action name the sibling that should be the real primary target,
# resolved post-rebuild exactly like `updates:` (a name that no longer
# matches any fragment falls back to a full-container response instead of
# silently doing nothing).
#
# Separately, flash messages set inside a scoped response were invisible
# until the next full render, because the auto-chrome flash (or an app's own
# `fragment(:flash) { flash_messages }`) never rode along with a
# fragment-scoped response unless every single action remembered to list it
# in `updates:`. A fragment named `:flash` is now auto-delivered as an OOB
# swap whenever a scoped response sets a non-empty flash.
RSpec.describe "primary: sibling target + flash OOB (stream_weaver-78a, stream_weaver-m3t)" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:generation) { "primary-oob-session" }

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

  describe "named action" do
    def build_app
      StreamWeaver::App.new("Board") do
        action(:select, primary: :detail) { |state, key| state[:selected] = key }
        fragment(:board) do
          button "View 1", action: :select, key: 1
        end
        fragment(:detail) do
          text(state[:selected] ? "Selected: #{state[:selected]}" : "Nothing selected")
        end
        text "UNRELATED BOARD-LEVEL COPY"
      end
    end

    it "delivers the sibling fragment as the primary content with a retarget header" do
      app = build_app
      state = {}
      html = render(app, state)
      token = html[%r{/action/([^"']+)}, 1]
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      expect(headers).to eq("HX-Retarget" => "#sw-frag-detail")
      expect(response).to include("Selected: 1")
      expect(response).not_to include("UNRELATED BOARD-LEVEL COPY", "View 1")
    end

    it "falls back to a full-container response when the named fragment no longer exists" do
      app = StreamWeaver::App.new("Conditional detail") do
        action(:select, primary: :detail) { |state, key| state[:selected] = key }
        fragment(:board) { button "View 1", action: :select, key: 1 }
        fragment(:detail) { text "detail" } if state[:show_detail]
        text "FULL PAGE"
      end
      state = { show_detail: false }
      html = render(app, state)
      token = html[%r{/action/([^"']+)}, 1]
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      expect(headers).to eq("HX-Retarget" => "#app-container")
      expect(response).to include("FULL PAGE")
    end

    it "composes with updates: in the same response" do
      app = StreamWeaver::App.new("Compose") do
        action(:select, updates: :sidebar, primary: :detail) { |state, key| state[:selected] = key }
        fragment(:board) { button "View 1", action: :select, key: 1 }
        fragment(:detail) { text "Selected: #{state[:selected]}" }
        fragment(:sidebar) { text "count: #{state[:selected].to_i}" }
      end
      state = {}
      html = render(app, state)
      token = html[%r{/action/([^"']+)}, 1]
      headers = {}

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup, headers: headers)

      expect(headers).to eq("HX-Retarget" => "#sw-frag-detail")
      expect(response).to include("Selected: 1", "count: 1", 'hx-swap-oob="innerHTML"')
    end
  end

  describe "legacy block button" do
    it "supports primary: the same way named actions do" do
      app = StreamWeaver::App.new("Legacy board") do
        fragment(:board) do
          button "View 1", key: 1, primary: :detail do |s|
            s[:selected] = 1
          end
        end
        fragment(:detail) { text(state[:selected] ? "Selected: #{state[:selected]}" : "Nothing selected") }
        text "UNRELATED BOARD-LEVEL COPY"
      end
      state = {}
      html = render(app, state)
      button_id = html[%r{/action/([^?"']+)\?}, 1]
      fragment_param = CGI.unescape(html[/_sw_fragment=([^"']+)/, 1])
      headers = {}

      response = StreamWeaver::InteractionRunner.new(
        app: app, state: state, params: { "_sw_fragment" => fragment_param },
        interaction: :action, target: button_id, adapter: adapter, persist: ->(_value) {},
        response_headers: ->(values) { headers.merge!(values) }
      ).call

      expect(headers).to eq("HX-Retarget" => "#sw-frag-detail")
      expect(response).to include("Selected: 1")
      expect(response).not_to include("UNRELATED BOARD-LEVEL COPY")
    end
  end

  describe "flash OOB under scoped responses" do
    def build_app
      StreamWeaver::App.new("Flash OOB", chrome: false) do
        action(:save) { |state, _key| flash[:notice] = "Saved!" }
        fragment(:flash) { flash_messages }
        fragment(:panel) { button "Save", action: :save, key: 1 }
        text "UNRELATED PAGE COPY"
      end
    end

    it "auto-delivers a non-empty flash as an OOB swap without updates: [:flash]" do
      app = build_app
      state = {}
      html = render(app, state)
      token = html[%r{/action/([^"']+)}, 1]

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup)

      expect(response).to include("Saved!", 'id="sw-frag-flash"', 'hx-swap-oob="innerHTML"')
      expect(response).not_to include("UNRELATED PAGE COPY")
    end

    it "does not append a flash OOB block when there is no flash to show" do
      app = StreamWeaver::App.new("No flash", chrome: false) do
        action(:noop) { |_state, _key| nil }
        fragment(:flash) { flash_messages }
        fragment(:panel) { button "Go", action: :noop, key: 1 }
      end
      state = {}
      html = render(app, state)
      token = html[%r{/action/([^"']+)}, 1]

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup)

      expect(response).not_to include("sw-frag-flash")
    end

    it "does not double-deliver flash when an action also declares updates: [:flash] explicitly" do
      app = StreamWeaver::App.new("Explicit updates", chrome: false) do
        action(:save, updates: :flash) { |state, _key| flash[:notice] = "Saved!" }
        fragment(:flash) { flash_messages }
        fragment(:panel) { button "Save", action: :save, key: 1 }
      end
      state = {}
      html = render(app, state)
      token = html[%r{/action/([^"']+)}, 1]

      response = run(app, state, token, manifest: app.render_state.action_tokens.dup)

      expect(response.scan('id="sw-frag-flash"').length).to eq(1)
    end
  end
end
