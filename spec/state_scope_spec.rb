# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "State scopes (FAC-P3.1)" do
  sk = StreamWeaver::Resource::StateKeys

  describe "#scope primitive" do
    it "creates a nested sub-hash at state[name], same shape form already produces" do
      app = StreamWeaver::App.new("Test") do
        scope(:widget, kind: :app) { |s| s[:count] ||= 0 }
      end

      app.rebuild_with_state({})

      expect(app.state[:widget]).to eq({ count: 0 })
    end

    it "yields the scope's own sub-hash to the block" do
      seen = nil
      app = StreamWeaver::App.new("Test") do
        scope(:widget, kind: :app) { |s| seen = s }
      end
      app.rebuild_with_state({})

      expect(seen).to equal(app.state[:widget])
    end

    it "preserves existing values across rebuilds (zero-migration shape)" do
      app = StreamWeaver::App.new("Test") do
        scope(:widget, kind: :app) { |s| s[:count] ||= 0 }
      end

      app.rebuild_with_state({ widget: { count: 5 } })

      expect(app.state[:widget][:count]).to eq(5)
    end

    it "raises a clear error when a scope name collides with an existing plain state key" do
      app = StreamWeaver::App.new("Test") do
        scope(:settings, kind: :app) { |s| s[:x] = 1 }
      end

      expect {
        app.rebuild_with_state({ settings: "not a scope" })
      }.to raise_error(ArgumentError, /settings.*collides with an existing top-level state key/)
    end

    it "does not raise when re-registered across rebuilds (idempotent, like resource/route registration)" do
      app = StreamWeaver::App.new("Test") do
        scope(:widget, kind: :app) { |s| s[:count] ||= 0 }
      end

      expect { 2.times { app.rebuild_with_state({}) } }.not_to raise_error
    end
  end

  describe "form as sugar over scope(kind: :form)" do
    it "registers the form's name in the scope registry" do
      app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
        end
      end

      app.rebuild_with_state({})

      expect(app.scope_names).to include(:edit_person)
    end

    it "still produces the exact same state shape as before (backward compat)" do
      app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
          text_field :email
        end
      end

      app.rebuild_with_state({})

      expect(app.state[:edit_person]).to eq({ name: "", email: "" })
    end

    it "preserves existing form state values, unchanged from pre-scope behavior" do
      app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
        end
      end

      existing_state = { edit_person: { name: "Alice", role: "admin" } }
      app.rebuild_with_state(existing_state)

      expect(app.state[:edit_person][:name]).to eq("Alice")
      expect(app.state[:edit_person][:role]).to eq("admin")
    end

    it "does not auto-reset a form-kind scope when routing state never changes" do
      app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
        end
      end

      state = {}
      app.rebuild_with_state(state)
      state[:edit_person][:name] = "Bob"
      app.rebuild_with_state(state)

      expect(state[:edit_person][:name]).to eq("Bob")
    end
  end

  describe "resource-kind auto-reset (replaces rivet's hand-nulled edit_* keys)" do
    let(:app) do
      built = StreamWeaver::App.new("Rivet-style edit") do
        scope(:person_form, kind: :resource) do |s|
          s[:name] ||= "draft for #{state[sk::ID]}"
        end
      end
      # Mirrors the pre-warm rebuild App#generate performs at boot in a real
      # server, before any real request arrives: it's what first populates
      # the scope registry so lifecycle tracking can begin.
      built.rebuild_with_state({})
      built
    end

    it "clears the scope when the resource id changes between rebuilds" do
      state = { sk::RESOURCE => :person, sk::ACTION => :edit, sk::ID => "A" }
      app.rebuild_with_state(state)
      state[:person_form][:name] = "unsaved edits for A"

      state[sk::ID] = "B"
      app.rebuild_with_state(state)

      # No leakage of A's draft into B's freshly-initialized scope.
      expect(state[:person_form][:name]).to eq("draft for B")
    end

    it "clears the scope when the resource itself changes (not just the id)" do
      state = { sk::RESOURCE => :person, sk::ACTION => :edit, sk::ID => "A" }
      app.rebuild_with_state(state)
      state[:person_form][:name] = "unsaved edits"

      state[sk::RESOURCE] = :company
      app.rebuild_with_state(state)

      expect(state[:person_form][:name]).to eq("draft for A")
    end

    it "does not reset when the id is unchanged across rebuilds" do
      state = { sk::RESOURCE => :person, sk::ACTION => :edit, sk::ID => "A" }
      app.rebuild_with_state(state)
      state[:person_form][:name] = "unsaved edits"

      app.rebuild_with_state(state)

      expect(state[:person_form][:name]).to eq("unsaved edits")
    end

    it "leaves the _sw_* routing keys flat and unscoped" do
      state = { sk::RESOURCE => :person, sk::ACTION => :edit, sk::ID => "A" }
      app.rebuild_with_state(state)

      expect(state[sk::RESOURCE]).to eq(:person)
      expect(state[sk::ID]).to eq("A")
      expect(state[:person_form]).not_to have_key(sk::RESOURCE)
      expect(state[:person_form]).not_to have_key(sk::ID)
    end
  end

  describe "retain: true opts a scope out of auto-reset" do
    it "keeps a retained resource-kind scope across an id change" do
      app = StreamWeaver::App.new("Test") do
        scope(:person_form, kind: :resource, retain: true) { |s| s[:name] ||= "" }
      end

      state = { sk::RESOURCE => :person, sk::ACTION => :edit, sk::ID => "A" }
      app.rebuild_with_state(state)
      state[:person_form][:name] = "kept across navigation"

      state[sk::ID] = "B"
      app.rebuild_with_state(state)

      expect(state[:person_form][:name]).to eq("kept across navigation")
    end
  end

  describe "dream DSL example (decision doc §9, review-added primitive form)" do
    # Verbatim per gsd/analysis/decisions/state-scopes.md: a filter panel whose
    # settings survive route changes (retain: true) while its transient
    # open/closed UI state does not.
    let(:app) do
      built = StreamWeaver::App.new("Filter panel") do
        scope :people_filters, kind: :fragment, retain: true do |s|
          s[:query]  ||= ""
          s[:domain] ||= :all
          text_field :query, label: "Search", live: true
          select :domain, %i[all work personal ma]
        end

        scope :filter_panel_ui, kind: :fragment do |s|
          s[:expanded] ||= false
          button(s[:expanded] ? "Hide filters" : "Show filters") { s[:expanded] = !s[:expanded] }
        end
      end
      # Pre-warm rebuild (mirrors App#generate at boot) so the scope registry
      # is populated before lifecycle tracking needs to detect a real change.
      built.rebuild_with_state({})
      built
    end

    it "executes without raising and produces the documented state shape" do
      app.rebuild_with_state({})

      expect(app.state[:people_filters]).to eq({ query: "", domain: :all })
      expect(app.state[:filter_panel_ui]).to eq({ expanded: false })
    end

    it "reads from outside use the full path" do
      state = {}
      app.rebuild_with_state(state)
      state[:people_filters][:query] = "widgets"
      state[:people_filters][:domain] = :work

      app.rebuild_with_state(state)

      expect(state[:people_filters][:query]).to eq("widgets")
      expect(state[:people_filters][:domain]).to eq(:work)
    end

    it "toggling the UI scope's button mutates its own sub-hash" do
      state = {}
      app.rebuild_with_state(state)
      toggle_button = app.components.find { |c| c.is_a?(StreamWeaver::Components::Button) }

      toggle_button.execute(state)

      expect(state[:filter_panel_ui][:expanded]).to eq(true)
    end

    it "retained filter scope survives a route change; transient UI scope resets" do
      state = { sk::ACTION => :list }
      app.rebuild_with_state(state)  # establishes this session's discriminant baseline
      state[:people_filters][:query] = "widgets"
      state[:filter_panel_ui][:expanded] = true

      # Simulate a route change (fragment-kind's discriminant includes ACTION).
      state[sk::ACTION] = :detail
      app.rebuild_with_state(state)

      expect(state[:people_filters][:query]).to eq("widgets")
      expect(state[:filter_panel_ui][:expanded]).to eq(false)
    end
  end
end
