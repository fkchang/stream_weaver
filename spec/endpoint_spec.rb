# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe "App#endpoint — real HTTP escape hatch" do
  describe "App DSL" do
    it "initializes @endpoints as an empty array" do
      app = StreamWeaver::App.new("Test") {}
      expect(app.endpoints).to eq([])
    end

    it "registers a verb + path + block" do
      app = StreamWeaver::App.new("Test") {}
      app.endpoint(:get, "/api/status") { |_req| { ok: true } }

      expect(app.endpoints.length).to eq(1)
      expect(app.endpoints.first[:verb]).to eq(:get)
      expect(app.endpoints.first[:path]).to eq("/api/status")
    end

    it "accepts all supported verbs" do
      app = StreamWeaver::App.new("Test") {}
      %i[get post put patch delete].each do |verb|
        app.endpoint(verb, "/x/#{verb}") { |_req| "ok" }
      end
      expect(app.endpoints.map { |e| e[:verb] }).to match_array(%i[get post put patch delete])
    end

    it "raises ArgumentError for an unsupported verb" do
      app = StreamWeaver::App.new("Test") {}
      expect {
        app.endpoint(:options, "/x") { |_req| "ok" }
      }.to raise_error(ArgumentError, /unsupported verb/)
    end

    it "raises ArgumentError when no block is given" do
      app = StreamWeaver::App.new("Test") {}
      expect { app.endpoint(:get, "/x") }.to raise_error(ArgumentError, /block required/)
    end

    it "#find_endpoint looks up by verb + exact path" do
      app = StreamWeaver::App.new("Test") {}
      app.endpoint(:post, "/webhook/github") { |_req| "queued" }

      found = app.find_endpoint(:post, "/webhook/github")
      expect(found).not_to be_nil
      expect(found[:path]).to eq("/webhook/github")
      expect(app.find_endpoint(:get, "/webhook/github")).to be_nil
    end

    it "is idempotent across repeated registration of the same verb+path (rebuild_with_state)" do
      app = StreamWeaver::App.new("Test") do
        endpoint(:get, "/api/status") { |_req| { ok: true } }
      end

      app.rebuild_with_state({})
      app.rebuild_with_state({})
      app.rebuild_with_state({})

      expect(app.endpoints.length).to eq(1)
    end

    it "warns when registering an endpoint that collides with an internal route prefix" do
      app = StreamWeaver::App.new("Test") {}
      expect {
        app.endpoint(:post, "/action/whatever") { |_req| "ok" }
      }.to output(/collides with a StreamWeaver-internal route/).to_stderr
    end

    it "warns when registering an endpoint that collides with an internal exact path" do
      app = StreamWeaver::App.new("Test") {}
      expect {
        app.endpoint(:post, "/update") { |_req| "ok" }
      }.to output(/collides with a StreamWeaver-internal route/).to_stderr
    end

    it "does not warn for a non-colliding path" do
      app = StreamWeaver::App.new("Test") {}
      expect {
        app.endpoint(:get, "/api/status") { |_req| "ok" }
      }.not_to output.to_stderr
    end
  end

  describe "HTTP dispatch (standalone mode)" do
    include Rack::Test::Methods

    let(:stream_weaver_app) do
      StreamWeaver::App.new("Endpoint Test App") do
        endpoint(:get, "/api/status") { |_req| { ok: true, uptime: 42 } }

        endpoint(:post, "/webhook/github") do |req|
          payload = req.body.read
          [202, { 'X-Received' => 'yes' }, "queued:#{payload}"]
        end

        endpoint(:get, "/hello") { |_req| "<h1>Hello</h1>" }

        endpoint(:put, "/api/thing/1") { |req| { method: req.request_method, updated: true } }
        endpoint(:patch, "/api/thing/1") { |req| { method: req.request_method } }
        endpoint(:delete, "/api/thing/1") { |req| [204, {}, ""] }

        endpoint(:get, "/api/echo") { |req| { name: req.params["name"] } }

        endpoint(:get, "/api/anything") { |_req| 42 }

        header1 "Welcome"
        text_field :name, placeholder: "Enter name"
        button("Greet") { |state| state[:greeted] = true }
      end
    end

    let(:app) { stream_weaver_app.generate }

    it "GET endpoint returning a Hash renders JSON with 200" do
      get '/api/status'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to eq("ok" => true, "uptime" => 42)
    end

    it "GET endpoint returning a String renders text/html with 200" do
      get '/hello'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to eq("<h1>Hello</h1>")
    end

    it "POST endpoint returning a Rack triplet passes through verbatim" do
      # Use a non-form Content-Type so Sinatra doesn't consume the body building `params`
      # before our block runs (see docs/endpoints.md — form-urlencoded/multipart bodies
      # are pre-parsed by Sinatra and req.body.read would come back empty).
      post '/webhook/github', "payload-body", 'CONTENT_TYPE' => 'text/plain'
      expect(last_response.status).to eq(202)
      expect(last_response.headers['X-Received']).to eq('yes')
      expect(last_response.body).to eq("queued:payload-body")
    end

    it "PUT endpoint is dispatched and receives the request" do
      put '/api/thing/1'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["method"]).to eq("PUT")
      expect(body["updated"]).to eq(true)
    end

    it "PATCH endpoint is dispatched" do
      patch '/api/thing/1'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["method"]).to eq("PATCH")
    end

    it "DELETE endpoint returning a Rack triplet with empty body" do
      delete '/api/thing/1'
      expect(last_response.status).to eq(204)
      expect(last_response.body).to eq("")
    end

    it "gives the block access to request params" do
      get '/api/echo?name=Forrest'
      expect(JSON.parse(last_response.body)["name"]).to eq("Forrest")
    end

    it "falls back to text/plain 200 for other return types (e.g. Integer)" do
      get '/api/anything'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.body).to eq("42")
    end

    it "renders normal StreamWeaver UI on GET / alongside registered endpoints" do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include("Welcome")
      expect(last_response.body).to include("Greet")
    end

    it "button actions still work via /action/:id alongside registered endpoints" do
      get '/' # establish session
      html = last_response.body
      match = html.match(/hx-post="\/action\/(btn_greet_[a-f0-9]+)"/)
      button_id = match[1]

      post "/action/#{button_id}"
      expect(last_response).to be_ok
    end
  end

  describe "internal-route collision precedence" do
    include Rack::Test::Methods

    let(:stream_weaver_app) do
      StreamWeaver::App.new("Collision Test App") do
        # /update is an exact-match StreamWeaver-internal route.
        endpoint(:post, "/update") { |_req| [418, {}, "custom-teapot"] }
        # /sw/session is prefix-reserved (/sw/*), also a real internal route.
        endpoint(:get, "/sw/session") { |_req| [418, {}, "custom-teapot"] }

        text_field :name
      end
    end

    let(:app) { stream_weaver_app.generate }

    it "the internal /update route wins over a colliding endpoint" do
      post '/update', name: "Forrest"
      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include("custom-teapot")
      expect(last_response.content_type).to include('text/html')
    end

    it "the internal /sw/session route wins over a colliding endpoint" do
      get '/sw/session'
      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include("custom-teapot")
      expect(last_response.content_type).to include('application/json')
    end
  end
end
