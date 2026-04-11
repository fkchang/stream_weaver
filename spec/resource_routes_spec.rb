# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "ResourceDefinition routing (T2)" do
  let(:fake_store) do
    store = Object.new
    def store.all;              []; end
    def store.find(id);         nil; end
    def store.create(attrs);    '1'; end
    def store.update(id, attrs) true; end
    def store.destroy(id);      true; end
    store
  end

  subject(:defn) { StreamWeaver::ResourceDefinition.new(:post, fake_store) }

  describe "parse_path" do
    it "parses /posts as index" do
      expect(defn.parse_path('/posts')).to eq({ SK::RESOURCE => :post, SK::ACTION => :index })
    end

    it "parses /posts/new as new" do
      expect(defn.parse_path('/posts/new')).to eq({ SK::RESOURCE => :post, SK::ACTION => :new })
    end

    it "parses /post/:id as show" do
      expect(defn.parse_path('/post/42')).to eq({ SK::RESOURCE => :post, SK::ACTION => :show, SK::ID => '42' })
    end

    it "parses /post/:id/edit as edit" do
      expect(defn.parse_path('/post/42/edit')).to eq({ SK::RESOURCE => :post, SK::ACTION => :edit, SK::ID => '42' })
    end

    it "returns nil for non-matching paths" do
      expect(defn.parse_path('/other')).to be_nil
      expect(defn.parse_path('/comments')).to be_nil
      expect(defn.parse_path('/post')).to be_nil
    end

    it "URL-decodes the id in show" do
      expect(defn.parse_path('/post/hello%20world')).to include(SK::ID => 'hello world')
    end

    it "URL-decodes the id in edit" do
      expect(defn.parse_path('/post/hello%20world/edit')).to include(SK::ID => 'hello world')
    end

    context "/posts/new ordering (collection before member)" do
      it "matches /posts/new as :new before /post/new-style-id as :show" do
        # /posts/new must match as :new, not as a member show for id='new'
        new_state = defn.parse_path('/posts/new')
        expect(new_state[SK::ACTION]).to eq(:new)
        expect(new_state[SK::ID]).to be_nil
      end

      it "does not match /post/new as :new (member singular path)" do
        # /post/new is the show path for a record with id='new', not the new action
        show_state = defn.parse_path('/post/new')
        expect(show_state[SK::ACTION]).to eq(:show)
        expect(show_state[SK::ID]).to eq('new')
      end
    end
  end

  describe "build_path" do
    it "builds /posts for index state" do
      st = { SK::RESOURCE => :post, SK::ACTION => :index }
      expect(defn.build_path(st)).to eq('/posts')
    end

    it "builds /posts/new for new state" do
      st = { SK::RESOURCE => :post, SK::ACTION => :new }
      expect(defn.build_path(st)).to eq('/posts/new')
    end

    it "builds /post/:id for show state" do
      st = { SK::RESOURCE => :post, SK::ACTION => :show, SK::ID => '42' }
      expect(defn.build_path(st)).to eq('/post/42')
    end

    it "builds /post/:id/edit for edit state" do
      st = { SK::RESOURCE => :post, SK::ACTION => :edit, SK::ID => '42' }
      expect(defn.build_path(st)).to eq('/post/42/edit')
    end

    it "returns nil when resource doesn't match" do
      st = { SK::RESOURCE => :comment, SK::ACTION => :index }
      expect(defn.build_path(st)).to be_nil
    end

    it "returns nil for show/edit without id" do
      expect(defn.build_path({ SK::RESOURCE => :post, SK::ACTION => :show })).to be_nil
      expect(defn.build_path({ SK::RESOURCE => :post, SK::ACTION => :edit })).to be_nil
    end

    it "URL-encodes id in show path" do
      st = { SK::RESOURCE => :post, SK::ACTION => :show, SK::ID => 'hello world' }
      expect(defn.build_path(st)).to eq('/post/hello+world')
    end
  end

  describe "parse_path + build_path round-trips" do
    it "round-trips index" do
      path = '/posts'
      state = defn.parse_path(path)
      expect(defn.build_path(state)).to eq(path)
    end

    it "round-trips new" do
      path = '/posts/new'
      state = defn.parse_path(path)
      expect(defn.build_path(state)).to eq(path)
    end

    it "round-trips show" do
      path = '/post/99'
      state = defn.parse_path(path)
      expect(defn.build_path(state)).to eq(path)
    end

    it "round-trips edit" do
      path = '/post/99/edit'
      state = defn.parse_path(path)
      expect(defn.build_path(state)).to eq(path)
    end
  end

  describe "plural: override" do
    subject(:person_defn) { StreamWeaver::ResourceDefinition.new(:person, fake_store, plural: 'people') }

    it "parses /people as index" do
      expect(person_defn.parse_path('/people')).to eq({ SK::RESOURCE => :person, SK::ACTION => :index })
    end

    it "parses /people/new as new" do
      expect(person_defn.parse_path('/people/new')).to eq({ SK::RESOURCE => :person, SK::ACTION => :new })
    end

    it "builds /people for index" do
      expect(person_defn.build_path({ SK::RESOURCE => :person, SK::ACTION => :index })).to eq('/people')
    end

    it "builds /people/new for new" do
      expect(person_defn.build_path({ SK::RESOURCE => :person, SK::ACTION => :new })).to eq('/people/new')
    end

    it "does not match /posts (wrong plural)" do
      expect(person_defn.parse_path('/posts')).to be_nil
    end
  end

  describe "state_for_path via App route chain" do
    let(:app) do
      the_store = fake_store
      a = StreamWeaver::App.new("Test") do
        resource :post, store: the_store
      end
      a.rebuild_with_state({})
      a
    end

    it "resolves /posts to index state" do
      expect(app.state_for_path('/posts')).to eq({ SK::RESOURCE => :post, SK::ACTION => :index })
    end

    it "resolves /posts/new to new state" do
      expect(app.state_for_path('/posts/new')).to eq({ SK::RESOURCE => :post, SK::ACTION => :new })
    end

    it "resolves /post/5 to show state" do
      expect(app.state_for_path('/post/5')).to eq({ SK::RESOURCE => :post, SK::ACTION => :show, SK::ID => '5' })
    end

    it "resolves /post/5/edit to edit state" do
      expect(app.state_for_path('/post/5/edit')).to eq({ SK::RESOURCE => :post, SK::ACTION => :edit, SK::ID => '5' })
    end
  end
end
