# frozen_string_literal: true
require "spec_helper"
require "rack/test"
require "tmpdir"

RSpec.describe StreamWeaver::Service do
  include Rack::Test::Methods

  def app
    described_class
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      example.run
    end
  end

  before do
    described_class.clear_apps
    described_class.instance_variable_set(:@slug_registry, {})
  end

  def write_app_file(filename, title:)
    path = File.join(@tmpdir, filename)
    File.write(path, <<~RUBY)
      app "#{title}" do
        text "hello"
      end
    RUBY
    path
  end

  describe ".slugify" do
    it "lowercases and hyphenates non-alphanumeric characters" do
      expect(described_class.slugify("Sales Dashboard!")).to eq("sales-dashboard")
    end

    it "squeezes repeated separators and strips leading/trailing hyphens" do
      expect(described_class.slugify("  --Weird///Name--  ")).to eq("weird-name")
    end
  end

  describe ".load_app" do
    it "derives the slug from the app's declared title" do
      path = write_app_file("dashboard.rb", title: "Sales Dashboard")
      app_id = described_class.load_app(path)
      expect(described_class.apps[app_id][:slug]).to eq("sales-dashboard")
    end

    it "falls back to the filename when the title yields no usable slug" do
      path = write_app_file("weird_file_name.rb", title: "!!!")
      app_id = described_class.load_app(path)
      expect(described_class.apps[app_id][:slug]).to eq("weird-file-name")
    end

    it "disambiguates collisions from different files with a numeric suffix" do
      path_a = write_app_file("a.rb", title: "Dashboard")
      path_b = write_app_file("b.rb", title: "Dashboard")

      id_a = described_class.load_app(path_a)
      id_b = described_class.load_app(path_b)

      expect(described_class.apps[id_a][:slug]).to eq("dashboard")
      expect(described_class.apps[id_b][:slug]).to eq("dashboard-2")
    end

    it "reuses the same slug when the same file is reloaded, without accumulating suffixes" do
      path = write_app_file("dashboard.rb", title: "Dashboard")

      first_id = described_class.load_app(path)
      second_id = described_class.load_app(path)
      third_id = described_class.load_app(path)

      expect(described_class.apps[first_id][:slug]).to eq("dashboard")
      expect(described_class.apps[second_id][:slug]).to eq("dashboard")
      expect(described_class.apps[third_id][:slug]).to eq("dashboard")
    end
  end

  describe ".resolve_app_id" do
    it "resolves a slug to its canonical hex app_id" do
      path = write_app_file("dashboard.rb", title: "Dashboard")
      app_id = described_class.load_app(path)

      expect(described_class.resolve_app_id("dashboard")).to eq(app_id)
    end

    it "resolves a hex app_id to itself" do
      path = write_app_file("dashboard.rb", title: "Dashboard")
      app_id = described_class.load_app(path)

      expect(described_class.resolve_app_id(app_id)).to eq(app_id)
    end

    it "returns nil for an unknown slug or app_id" do
      expect(described_class.resolve_app_id("nonexistent")).to be_nil
    end
  end

  describe "POST /load-app" do
    it "returns a slug-based url with the canonical hex app_id URL as a fallback" do
      path = write_app_file("dashboard.rb", title: "Sales Dashboard")
      post '/load-app', file_path: path

      body = JSON.parse(last_response.body)
      expect(body['success']).to eq(true)
      expect(body['slug']).to eq("sales-dashboard")
      expect(body['url']).to eq("/apps/sales-dashboard")
      expect(body['canonical_url']).to eq("/apps/#{body['app_id']}")
    end
  end

  describe "GET /apps/:app_id" do
    it "renders the app when addressed by its slug" do
      path = write_app_file("dashboard.rb", title: "Sales Dashboard")
      post '/load-app', file_path: path

      get '/apps/sales-dashboard'

      expect(last_response).to be_ok
      expect(last_response.body).to include("hello")
    end

    it "still renders the app when addressed by its canonical hex app_id" do
      path = write_app_file("dashboard.rb", title: "Sales Dashboard")
      post '/load-app', file_path: path
      app_id = JSON.parse(last_response.body)['app_id']

      get "/apps/#{app_id}"

      expect(last_response).to be_ok
      expect(last_response.body).to include("hello")
    end

    it "404s for an unknown slug" do
      get '/apps/does-not-exist'
      expect(last_response.status).to eq(404)
    end
  end
end
