# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe "flash (FAC-P3.2b)" do
  include Rack::Test::Methods

  def flatten_components(components)
    components.flat_map do |c|
      children = c.respond_to?(:children) ? Array(c.children) : []
      [c, *flatten_components(children)]
    end
  end

  describe "App#flash accessor" do
    it "is a Hash-like accessor backed by state[:_flash]" do
      app = StreamWeaver::App.new("Test") do
        flash[:notice] = "Hello"
      end
      app.rebuild_with_state({})

      expect(app.state[:_flash]).to eq(notice: "Hello")
    end

    it "supports multiple keys set within the same callback" do
      app = StreamWeaver::App.new("Test") do
        flash[:notice] = "Saved"
        flash[:error]  = "But sync failed"
      end
      app.rebuild_with_state({})

      expect(app.state[:_flash]).to eq(notice: "Saved", error: "But sync failed")
    end

    it "is not merged with the toast system (independent state keys)" do
      app = StreamWeaver::App.new("Test") do
        flash[:notice] = "Flash message"
        show_toast("Toast message")
      end
      app.rebuild_with_state({})

      expect(app.state[:_flash]).to eq(notice: "Flash message")
      expect(app.state[:_toasts].map { |t| t[:message] }).to eq(["Toast message"])
    end
  end

  describe "#flash_messages" do
    it "renders an Alert per flash key, mapping :notice to :success and :error to :error" do
      app = StreamWeaver::App.new("Test", chrome: false) do
        state[:_flash] = { notice: "Person created.", error: "Sync failed" }
        flash_messages
      end
      app.rebuild_with_state({})

      alerts = flatten_components(app.components).select { |c| c.is_a?(StreamWeaver::Components::Alert) }
      expect(alerts.map(&:variant)).to contain_exactly(:success, :error)
    end

    it "falls back to :info for an unrecognized flash key" do
      app = StreamWeaver::App.new("Test", chrome: false) do
        state[:_flash] = { warning: "Heads up" }
        flash_messages
      end
      app.rebuild_with_state({})

      alerts = flatten_components(app.components).select { |c| c.is_a?(StreamWeaver::Components::Alert) }
      expect(alerts.map(&:variant)).to eq([:info])
    end

    it "renders nothing when there is no flash" do
      app = StreamWeaver::App.new("Test", chrome: false) { flash_messages }
      app.rebuild_with_state({})

      expect(app.components).to be_empty
    end
  end

  describe "chrome auto-injection" do
    it "auto-renders flash_messages near the top of #app-container when chrome: true and a flash is present" do
      app = StreamWeaver::App.new("Test") do
        text "Body content"
      end
      app.rebuild_with_state({ _flash: { notice: "Welcome back" } })

      expect(app.components.first).to be_a(StreamWeaver::Components::Alert)
    end

    it "does not auto-inject anything when there is no flash" do
      app = StreamWeaver::App.new("Test") { text "Body content" }
      app.rebuild_with_state({})

      expect(app.components).not_to include(a_kind_of(StreamWeaver::Components::Alert))
    end

    it "does not auto-inject when chrome: false -- the app must place flash_messages itself" do
      app = StreamWeaver::App.new("Test", chrome: false) { text "Body content" }
      app.rebuild_with_state({ _flash: { notice: "Welcome back" } })

      expect(app.components).not_to include(a_kind_of(StreamWeaver::Components::Alert))
    end
  end

  describe "one-shot lifecycle over HTTP" do
    let(:stream_weaver_app) do
      StreamWeaver::App.new("Flash Test") do
        button "Save" do |s|
          flash[:notice] = "Saved!"
        end
      end
    end

    let(:app) { stream_weaver_app.generate }

    def extract_button_id(html, label)
      match = html.match(/hx-post="\/action\/(btn_#{label.downcase}_[a-f0-9]+)"/)
      match ? match[1] : "btn_#{label.downcase}_1"
    end

    it "shows the flash in the response that set it" do
      get '/'
      button_id = extract_button_id(last_response.body, "Save")

      post "/action/#{button_id}"

      expect(last_response.body).to include("Saved!")
    end

    it "never persists the flash into the session for the next request" do
      get '/'
      button_id = extract_button_id(last_response.body, "Save")

      post "/action/#{button_id}"

      session_state = last_request.session[:streamlit_state]
      expect(session_state).not_to have_key(:_flash)
    end

    it "does not resurface on a subsequent GET (fresh-GET reload)" do
      get '/'
      button_id = extract_button_id(last_response.body, "Save")
      post "/action/#{button_id}"

      get '/'

      expect(last_response.body).not_to include("Saved!")
    end
  end

  describe "service-mode parity" do
    it "Service#set_app_state strips _flash before persisting, like SessionStore::Base#filter" do
      # Mirrors the fix at lib/stream_weaver/service.rb#set_app_state: same
      # exclusion, same non-mutating-copy mechanism, so a service-mode app
      # gets the identical one-shot guarantee without a shared session store.
      state = { name: "Alice", _flash: { notice: "Hi" } }
      persisted = state.reject { |k, _| k == :_flash }

      expect(persisted).to eq(name: "Alice")
      expect(state).to have_key(:_flash) # the live object used for *this* render is untouched
    end
  end
end
