# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe "Interaction stack parity" do
  def build_app
    StreamWeaver::App.new("Parity") do
      text_field :name
      checkbox :enabled, "Enabled"
      text "#{state[:name]}:#{state[:enabled]}"
    end
  end

  shared_examples "the shared interaction pipeline" do
    it "produces identical state and response content in standalone and service mode" do
      standalone_app = build_app
      standalone = Rack::Test::Session.new(Rack::MockSession.new(standalone_app.generate))
      standalone.get "/"
      standalone.post "/update", { name: "Ada", enabled: "true" }

      service_app = build_app
      service_app.rebuild_with_state({})
      app_id = "parity01"
      StreamWeaver::Service.apps[app_id] = {
        app: service_app,
        path: "parity.rb",
        name: "Parity",
        loaded_at: Time.now,
        last_accessed: Time.now
      }
      service = Rack::Test::Session.new(Rack::MockSession.new(StreamWeaver::Service))
      service.get "/apps/#{app_id}"
      service.post "/apps/#{app_id}/update", { name: "Ada", enabled: "true" }

      standalone_state = standalone.last_request.session[:streamlit_state]
      service_state = service.last_request.session[:app_states][app_id]
      state_script = %r{<script type="application/json" id="sw-state-data">.*?</script>}
      standalone_body = standalone.last_response.body.sub(state_script, "")
      normalized_service_body = service.last_response.body.gsub("/apps/#{app_id}", "").sub(state_script, "")

      expect(service_state).to eq(standalone_state)
      expect(service.last_response.status).to eq(standalone.last_response.status)
      expect(normalized_service_body).to eq(standalone_body)
    ensure
      StreamWeaver::Service.clear_apps
    end
  end

  include_examples "the shared interaction pipeline"
end
