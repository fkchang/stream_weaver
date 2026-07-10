# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe "StreamWeaver::Service — URL-routing DSLs (stream_weaver-oow)" do
  include Rack::Test::Methods

  def app
    StreamWeaver::Service
  end

  let(:routed_app) do
    StreamWeaver::App.new("Routed App") do
      route_by :page, home: "/", about: "/about"

      case state[:page]
      when :home
        text "Home Content"
      when :about
        text "About Content"
      end

      button "Go About" do |s|
        s[:page] = :about
      end
    end
  end

  let(:app_id) { "routed01" }

  before do
    StreamWeaver::Service.clear_apps
    routed_app.rebuild_with_state({})
    StreamWeaver::Service.apps[app_id] = {
      app: routed_app,
      path: "routed_app.rb",
      name: "Routed App",
      loaded_at: Time.now,
      last_accessed: Time.now
    }
  end

  after { StreamWeaver::Service.clear_apps }

  describe "root render seeds routing state from '/'" do
    it "renders the home page's content without a manual state default" do
      get "/apps/#{app_id}"
      expect(last_response).to be_ok
      expect(last_response.body).to include("Home Content")
      expect(last_response.body).not_to include("About Content")
    end
  end

  describe "GET /apps/:app_id/* seeds routing state from the path suffix" do
    it "renders the about page's content for the routed suffix path" do
      get "/apps/#{app_id}/about"
      expect(last_response).to be_ok
      expect(last_response.body).to include("About Content")
      expect(last_response.body).not_to include("Home Content")
    end

    it "works via the app's slug as well as its hex id" do
      StreamWeaver::Service.slug_registry["routed-app"] = app_id
      get "/apps/routed-app/about"
      expect(last_response).to be_ok
      expect(last_response.body).to include("About Content")
    end

    it "404s for an unrouted suffix on an app with no matching endpoint" do
      get "/apps/#{app_id}/nowhere"
      expect(last_response.status).to eq(404)
    end
  end

  describe "a resource app mounted in service mode" do
    let(:fake_store) do
      store = Object.new
      def store.all;              [{ id: '1', title: 'Hello' }]; end
      def store.find(id);         { id: id, title: 'Hello' }; end
      def store.create(attrs);    '2'; end
      def store.update(id, attrs) true; end
      def store.destroy(id);      true; end
      store
    end

    let(:resource_app) do
      store = fake_store
      StreamWeaver::App.new("Resource App") do
        resource :post, store: store do
          field :title, :string
        end
      end
    end

    let(:resource_app_id) { "resapp01" }

    before do
      resource_app.rebuild_with_state({})
      StreamWeaver::Service.apps[resource_app_id] = {
        app: resource_app,
        path: "resource_app.rb",
        name: "Resource App",
        loaded_at: Time.now,
        last_accessed: Time.now
      }
    end

    it "renders the index action for /apps/:app_id/posts" do
      get "/apps/#{resource_app_id}/posts"
      expect(last_response).to be_ok
      expect(last_response.body).to include("Posts")
      expect(last_response.body).to include("New Post")
    end
  end

  describe "HX-Push-Url prefix round-trip" do
    it "includes the /apps/:app_id mount prefix when routing state changes on POST" do
      get "/apps/#{app_id}"
      button_id = last_response.body.match(%r{hx-post="/apps/#{app_id}/action/(\w+)"})[1]

      post "/apps/#{app_id}/action/#{button_id}"
      expect(last_response.headers['HX-Push-Url']).to eq("/apps/#{app_id}/about")
    end
  end

  describe "standalone behavior is unchanged" do
    let(:app) do
      StreamWeaver::App.new("Routed App") do
        route_by :page, home: "/", about: "/about"

        case state[:page]
        when :home
          text "Home Content"
        when :about
          text "About Content"
        end

        button "Go About" do |s|
          s[:page] = :about
        end
      end.generate
    end

    it "seeds routing state from '/' on GET /" do
      get '/'
      expect(last_response.body).to include("Home Content")
    end

    it "seeds routing state from a deep-linked path" do
      get '/about'
      expect(last_response.body).to include("About Content")
    end

    it "pushes the un-prefixed path on POST when routing state changes" do
      get '/'
      button_id = last_response.body.match(/hx-post="\/action\/(\w+)"/)[1]

      post "/action/#{button_id}"
      expect(last_response.headers['HX-Push-Url']).to eq("/about")
    end
  end
end
