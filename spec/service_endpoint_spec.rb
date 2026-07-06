# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe "StreamWeaver::Service — App#endpoint (multi-app service mode)" do
  include Rack::Test::Methods

  def app
    StreamWeaver::Service
  end

  let(:streamlit_app) do
    StreamWeaver::App.new("Service Endpoint App") do
      endpoint(:get, "/api/status") { |_req| { ok: true, source: "service" } }
      endpoint(:post, "/webhook/thing") { |_req| [202, {}, "accepted"] }
      text_field :name
    end
  end

  let(:app_id) { "svcend1" }

  before do
    StreamWeaver::Service.clear_apps
    streamlit_app.rebuild_with_state({})
    StreamWeaver::Service.apps[app_id] = {
      app: streamlit_app,
      path: "svcend.rb",
      name: "Service Endpoint App",
      loaded_at: Time.now,
      last_accessed: Time.now
    }
  end

  after { StreamWeaver::Service.clear_apps }

  it "dispatches a GET endpoint scoped under /apps/:app_id/*" do
    get "/apps/#{app_id}/api/status"
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include('application/json')
    expect(JSON.parse(last_response.body)).to eq("ok" => true, "source" => "service")
  end

  it "dispatches a POST endpoint scoped under /apps/:app_id/*" do
    post "/apps/#{app_id}/webhook/thing"
    expect(last_response.status).to eq(202)
    expect(last_response.body).to eq("accepted")
  end

  it "404s for an endpoint path that isn't registered for that app" do
    get "/apps/#{app_id}/no/such/endpoint"
    expect(last_response.status).to eq(404)
  end

  it "404s for an unknown app_id" do
    get "/apps/does-not-exist/api/status"
    expect(last_response.status).to eq(404)
  end

  it "does not shadow the app's own main render route" do
    get "/apps/#{app_id}"
    expect(last_response).to be_ok
  end
end
