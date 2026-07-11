# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

# FAC-P3.1 handoff gap, closed here: a field inside a bare `scope` block (not
# a `form` block) previously rendered/synced against a flat top-level key
# instead of its scope's sub-hash -- see bd stream_weaver-2st notes.
RSpec.describe "Scope-nested live field rendering (FAC-P3.1 handoff)" do
  include Rack::Test::Methods

  describe "HTML rendering" do
    let(:stream_app) do
      StreamWeaver::App.new("Filter Panel") do
        scope :people_filters, kind: :fragment, retain: true do |s|
          s[:query] ||= ""
          text_field :query, label: "Search"
          checkbox :active_only, "Active only"
          select :domain, %w[all work personal]
        end
      end
    end

    let(:app) { stream_app.generate }

    it "renders a scope-nested text field with Rails-style nested name and dot-path x-model" do
      get '/'
      expect(last_response.body).to include('name="people_filters[query]"')
      expect(last_response.body).to include('x-model="people_filters.query"')
      expect(last_response.body).to include('hx-post="/update"')
    end

    it "renders a scope-nested checkbox with a nested name and dot-path x-model" do
      get '/'
      expect(last_response.body).to include('name="people_filters[active_only]"')
      expect(last_response.body).to include('x-model="people_filters.active_only"')
    end

    it "renders a scope-nested select with a nested name and dot-path x-model" do
      get '/'
      expect(last_response.body).to include('name="people_filters[domain]"')
      expect(last_response.body).to include('x-model="people_filters.domain"')
    end
  end

  describe "POST /update nested-param-sync" do
    let(:stream_app) do
      StreamWeaver::App.new("Filter Panel") do
        scope :people_filters, kind: :fragment, retain: true do |s|
          s[:query]  ||= ""
          s[:domain] ||= "all"
          text_field :query
          select :domain, %w[all work personal]
        end
      end
    end

    let(:app) { stream_app.generate }

    it "merges one changed field into the scope sub-hash without clobbering sibling fields" do
      env 'rack.session', { streamlit_state: { people_filters: { query: "", domain: "work" } } }
      post '/update', 'people_filters' => { 'query' => 'widgets' }

      state = last_request.session[:streamlit_state]
      expect(state[:people_filters][:query]).to eq('widgets')
      expect(state[:people_filters][:domain]).to eq('work') # untouched sibling
    end
  end

  describe "unchecked scope-nested checkbox" do
    let(:stream_app) do
      StreamWeaver::App.new("Filter Panel") do
        scope :people_filters, kind: :fragment, retain: true do |s|
          s[:active_only] ||= true
          s[:query] ||= "widgets"
          checkbox :active_only, "Active only"
        end
      end
    end

    let(:app) { stream_app.generate }

    it "clears the scoped checkbox to false without touching sibling scope fields" do
      env 'rack.session', { streamlit_state: { people_filters: { active_only: true, query: "widgets" } } }
      post '/update', {}

      state = last_request.session[:streamlit_state]
      expect(state[:people_filters][:active_only]).to eq(false)
      expect(state[:people_filters][:query]).to eq('widgets')
    end
  end
end
