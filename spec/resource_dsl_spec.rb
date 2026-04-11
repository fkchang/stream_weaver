# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "ResourceDefinition DSL (T2)" do
  # Minimal duck-typed store stub
  let(:fake_store) do
    store = Object.new
    def store.all;              []; end
    def store.find(id);         nil; end
    def store.create(attrs);    '1'; end
    def store.update(id, attrs) true; end
    def store.destroy(id);      true; end
    store
  end

  describe "field capture" do
    it "captures fields in order" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      defn.field :title,  :string
      defn.field :body,   :text
      defn.field :status, :enum, values: %w[draft published]

      expect(defn.fields.length).to eq(3)
      expect(defn.fields[0].name).to eq(:title)
      expect(defn.fields[0].type).to eq(:string)
      expect(defn.fields[1].name).to eq(:body)
      expect(defn.fields[1].type).to eq(:text)
      expect(defn.fields[2].name).to eq(:status)
      expect(defn.fields[2].type).to eq(:enum)
      expect(defn.fields[2].opts[:values]).to eq(%w[draft published])
    end
  end

  describe "edit_view / new_view" do
    it "defaults to :modal" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      expect(defn.edit_view).to eq(:modal)
      expect(defn.new_view).to eq(:modal)
    end

    it "can be overridden" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      defn.edit_view :page
      defn.new_view  :page
      expect(defn.edit_view).to eq(:page)
      expect(defn.new_view).to eq(:page)
    end
  end

  describe "only / except" do
    it "defaults to all CRUD actions including destroy_confirm" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      expect(defn.only).to eq(%i[index show new edit destroy destroy_confirm])
    end

    it "only restricts to given actions" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      defn.only(%i[index show])
      expect(defn.only).to eq(%i[index show])
    end

    it "except removes given actions" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      defn.except(%i[destroy edit])
      expect(defn.only).to eq(%i[index show new destroy_confirm])
    end
  end

  describe "override blocks" do
    it "captures override blocks for each action" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)

      defn.index { |items| }
      defn.show  { |item|  }
      defn.new   { }
      defn.edit  { |item|  }

      expect(defn.overrides[:index]).to be_a(Proc)
      expect(defn.overrides[:show]).to be_a(Proc)
      expect(defn.overrides[:new]).to be_a(Proc)
      expect(defn.overrides[:edit]).to be_a(Proc)
    end

    it "stores nil for unset overrides" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      expect(defn.overrides[:index]).to be_nil
    end
  end

  describe "plural:" do
    it "defaults to singular + 's'" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      expect(defn.plural).to eq("posts")
      expect(defn.singular).to eq("post")
    end

    it "accepts explicit plural override" do
      defn = StreamWeaver::ResourceDefinition.new(:person, fake_store, plural: 'people')
      expect(defn.plural).to eq("people")
      expect(defn.singular).to eq("person")
    end
  end

  describe "name" do
    it "stores name as symbol" do
      defn = StreamWeaver::ResourceDefinition.new(:post, fake_store)
      expect(defn.name).to eq(:post)
    end
  end
end

RSpec.describe "App#resource registration (T2)" do
  let(:fake_store) do
    store = Object.new
    def store.all;              []; end
    def store.find(id);         nil; end
    def store.create(attrs);    '1'; end
    def store.update(id, attrs) true; end
    def store.destroy(id);      true; end
    store
  end

  def build_app(state = {}, &block)
    app = StreamWeaver::App.new("Test", &block)
    app.rebuild_with_state(state)
    app
  end

  it "registers resource definition once across multiple rebuilds" do
    the_store = fake_store
    app = StreamWeaver::App.new("Test") do
      resource :post, store: the_store do
        field :title, :string
      end
    end

    3.times { app.rebuild_with_state({}) }

    expect(app.resource_defs.size).to eq(1)
    expect(app.resource_defs[:post]).to be_a(StreamWeaver::ResourceDefinition)
  end

  it "registers one route rule for the resource" do
    the_store = fake_store
    app = StreamWeaver::App.new("Test") do
      resource :post, store: the_store
    end

    3.times { app.rebuild_with_state({}) }

    resource_rules = app.route_rules.select { |r| r.source == [:resource, :post] }
    expect(resource_rules.size).to eq(1)
  end

  it "does not render when state has no matching resource" do
    the_store = fake_store
    app = StreamWeaver::App.new("Test") do
      resource :post, store: the_store do
        field :title, :string
      end
    end

    app.rebuild_with_state({ _sw_resource: :other, _sw_action: :index })
    expect(app.components).to be_empty
  end

  describe "named-route helpers" do
    let(:app) do
      the_store = fake_store
      a = StreamWeaver::App.new("Test") do
        resource :post, store: the_store
      end
      a.rebuild_with_state({})
      a
    end

    it "defines posts_path returning /posts" do
      expect(app.posts_path).to eq("/posts")
    end

    it "defines new_post_path returning /posts/new" do
      expect(app.new_post_path).to eq("/posts/new")
    end

    it "defines post_path(rec) returning /post/:id" do
      expect(app.post_path({ id: '42' })).to eq("/post/42")
    end

    it "defines edit_post_path(rec) returning /post/:id/edit" do
      expect(app.edit_post_path({ id: '42' })).to eq("/post/42/edit")
    end
  end

  describe "plural: override for named-route helpers" do
    it "uses plural name in collection helper" do
      the_store = fake_store
      app = StreamWeaver::App.new("Test") do
        resource :person, store: the_store, plural: 'people'
      end
      app.rebuild_with_state({})

      expect(app.people_path).to eq("/people")
      expect(app.new_person_path).to eq("/people/new")
      expect(app.person_path({ id: '1' })).to eq("/person/1")
      expect(app.edit_person_path({ id: '1' })).to eq("/person/1/edit")
    end
  end
end

RSpec.describe "App#page and App#route (T2)" do
  it "registers a page route rule once across multiple rebuilds" do
    app = StreamWeaver::App.new("Test") do
      page :home, '/' do
        # no-op
      end
    end

    3.times { app.rebuild_with_state({}) }

    page_rules = app.route_rules.select { |r| r.source == [:page, :home] }
    expect(page_rules.size).to eq(1)
  end

  it "page renders block when state matches" do
    rendered = []
    app = StreamWeaver::App.new("Test") do
      page :home, '/' do
        rendered << :home_rendered
      end
    end

    app.rebuild_with_state({ _sw_action: :home, _sw_resource: nil })
    expect(rendered).to eq([:home_rendered])
  end

  it "page does not render when state does not match" do
    rendered = []
    app = StreamWeaver::App.new("Test") do
      page :home, '/' do
        rendered << :home_rendered
      end
    end

    app.rebuild_with_state({ _sw_action: :other })
    expect(rendered).to be_empty
  end

  it "page route parses path to correct state" do
    app = StreamWeaver::App.new("Test") do
      page :about, '/about' do
      end
    end
    app.rebuild_with_state({})

    state = app.state_for_path('/about')
    expect(state).to eq({ _sw_resource: nil, _sw_action: :about })
  end

  it "page route builds path from state" do
    app = StreamWeaver::App.new("Test") do
      page :about, '/about' do
      end
    end
    app.rebuild_with_state({})

    path = app.path_for_state({ _sw_action: :about, _sw_resource: nil })
    expect(path).to eq('/about')
  end

  it "route registers route without a render block" do
    app = StreamWeaver::App.new("Test") do
      route :dashboard, '/dashboard'
    end
    app.rebuild_with_state({})

    state = app.state_for_path('/dashboard')
    expect(state).to eq({ _sw_resource: nil, _sw_action: :dashboard })
  end

  it "page makes app routable?" do
    app = StreamWeaver::App.new("Test") do
      page :home, '/' do; end
    end
    app.rebuild_with_state({})
    expect(app.routable?).to be_truthy
  end
end
