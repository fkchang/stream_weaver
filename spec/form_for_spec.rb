# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

module FormForStore
  @records = [{ id: '1', name: 'Ada', age: 30, budget: 12.5 }]

  def self.reset!
    @records = [{ id: '1', name: 'Ada', age: 30, budget: 12.5 }]
  end

  def self.all;              @records.dup; end
  def self.find(id);         @records.find { |r| r[:id] == id }; end
  def self.create(attrs);    id = SecureRandom.hex(4); @records << { id: id, **attrs }; id; end
  def self.update(id, attrs) r = find(id); r&.merge!(attrs); !!r; end
  def self.destroy(id);      @records.reject! { |r| r[:id] == id }; true; end
end

RSpec.describe "form_for (FAC-P3.2)" do
  before(:each) { FormForStore.reset! }

  def build_app(state = {}, &block)
    app = StreamWeaver::App.new("Test", &block)
    app.rebuild_with_state(state)
    app
  end

  def flatten_components(components)
    components.flat_map do |c|
      children = c.respond_to?(:children) ? Array(c.children) : []
      [c, *flatten_components(children)]
    end
  end

  def find_form(app)
    flatten_components(app.components).find { |c| c.is_a?(StreamWeaver::Components::Form) }
  end

  def person_fields
    [
      StreamWeaver::Field.new(:name, :string, {}),
      StreamWeaver::Field.new(:age, :integer, {}),
      StreamWeaver::Field.new(:budget, :number, {})
    ]
  end

  describe "standalone usage (store:/fields:, no resource)" do
    it "renders a Form scoped by name:" do
      fields = person_fields
      app = build_app do
        form_for store: FormForStore, fields: fields, name: :person_form
      end

      expect(find_form(app)).not_to be_nil
      expect(app.state[:person_form]).to eq(name: "", age: "", budget: "")
    end

    it "raises a clear error when neither a resource nor store:/fields: are given" do
      expect {
        build_app { form_for }
      }.to raise_error(ArgumentError, /no store given/)
    end

    it "does not auto-transition state on success (no resource to fall back to)" do
      fields = person_fields
      app = build_app do
        form_for store: FormForStore, fields: fields, name: :person_form
      end

      form = find_form(app)
      form.instance_variable_get(:@submit_action).call('name' => 'Grace', 'age' => '40', 'budget' => '9.5')

      expect(app.state[SK::ACTION]).to be_nil
      expect(FormForStore.all.length).to eq(2)
    end

    it "on_success: is instance_exec'd with the new/updated id" do
      seen_id = nil
      fields = person_fields
      app = build_app do
        form_for store: FormForStore, fields: fields, name: :person_form,
                  on_success: ->(id) { seen_id = id; state[:_landed] = true }
      end

      find_form(app).instance_variable_get(:@submit_action).call('name' => 'Grace', 'age' => '40', 'budget' => '9.5')

      expect(seen_id).not_to be_nil
      expect(app.state[:_landed]).to eq(true)
    end
  end

  describe "resource-bound usage" do
    def build_resource_app(state, &edit_or_new_block)
      build_app(state) do
        resource :person, store: FormForStore do
          field :name,   :string
          field :age,    :integer
          field :budget, :number
        end
      end
    end

    it "defaults the submit label to Create in create mode" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :new) {}
      form = find_form(app)
      expect(form.submit_label).to eq("Create")
    end

    it "defaults the submit label to Save in update mode" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :edit, SK::ID => '1') {}
      form = find_form(app)
      expect(form.submit_label).to eq("Save")
    end

    it "seeds the scope from the record on first render" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :edit, SK::ID => '1') {}
      expect(app.state[:person_form]).to eq(name: 'Ada', age: 30, budget: 12.5)
    end

    it "does not re-seed (preserves in-progress edits) across an unrelated rebuild for the same id" do
      app = StreamWeaver::App.new("Test") do
        resource :person, store: FormForStore do
          field :name,   :string
          field :age,    :integer
          field :budget, :number
        end
      end
      state = { SK::RESOURCE => :person, SK::ACTION => :edit, SK::ID => '1' }
      app.rebuild_with_state(state)
      state[:person_form][:name] = "unsaved edit"

      app.rebuild_with_state(state)

      expect(state[:person_form][:name]).to eq("unsaved edit")
    end

    it "re-seeds fresh when the record id changes (no cross-record leakage)" do
      app = StreamWeaver::App.new("Test") do
        resource :person, store: FormForStore do
          field :name,   :string
          field :age,    :integer
          field :budget, :number
        end
      end
      FormForStore.create(name: 'Beatrice', age: 22, budget: 5.0)
      other_id = FormForStore.all.last[:id]

      state = { SK::RESOURCE => :person, SK::ACTION => :edit, SK::ID => '1' }
      app.rebuild_with_state(state)
      # A second rebuild at the same id establishes the lifecycle-tracking
      # baseline (mirrors the first real interaction after page load) --
      # apply_scope_lifecycle can't detect a change until it has seen the
      # scope in the registry on a *prior* rebuild (FAC-P3.1 §4).
      app.rebuild_with_state(state)
      state[:person_form][:name] = "unsaved edit for Ada"

      state[SK::ID] = other_id
      app.rebuild_with_state(state)

      expect(state[:person_form][:name]).to eq("Beatrice")
    end

    it "coerces submitted values, calls store.create, flashes, and transitions to show" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :new) {}
      form = find_form(app)

      form.instance_variable_get(:@submit_action).call('name' => 'Grace', 'age' => '40', 'budget' => '9.5')

      created = FormForStore.all.last
      expect(created[:name]).to eq('Grace')
      expect(created[:age]).to eq(40)
      expect(created[:budget]).to eq(9.5)
      expect(app.state[SK::ACTION]).to eq(:show)
      expect(app.state[SK::RESOURCE]).to eq(:person)
      expect(app.state[SK::ID]).to eq(created[:id])
      expect(app.state[:_flash]).to eq(notice: "Person created.")
    end

    it "update mode calls store.update and transitions to show" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :edit, SK::ID => '1') {}
      form = find_form(app)

      form.instance_variable_get(:@submit_action).call('name' => 'Ada Lovelace', 'age' => '31', 'budget' => '12.5')

      expect(FormForStore.find('1')[:name]).to eq('Ada Lovelace')
      expect(app.state[SK::ACTION]).to eq(:show)
      expect(app.state[:_flash]).to eq(notice: "Person updated.")
    end

    it "an integer coercion failure populates the errors scope and never calls the store" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :new) {}
      form = find_form(app)
      initial_count = FormForStore.all.length

      form.instance_variable_get(:@submit_action).call('name' => 'Grace', 'age' => 'not-a-number', 'budget' => '9.5')

      expect(FormForStore.all.length).to eq(initial_count)
      expect(app.state[SK::ACTION]).to eq(:new) # unchanged -- same-request re-render, no transition
      expect(app.state[:person_form_errors][:age]).to include("must be a whole number")
      expect(app.state[:_flash]).to be_nil
    end

    it "preserves the user's in-progress values on a validation failure (never clobbers the scope)" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :new) {}
      state = app.state
      state[:person_form] = { name: 'Grace', age: 'not-a-number', budget: '9.5' }
      form = find_form(app)

      form.instance_variable_get(:@submit_action).call('name' => 'Grace', 'age' => 'not-a-number', 'budget' => '9.5')

      expect(state[:person_form][:name]).to eq('Grace')
    end

    it "renders an error Alert summary when the errors scope is populated" do
      app = build_resource_app(SK::RESOURCE => :person, SK::ACTION => :new) do
      end
      state = { SK::RESOURCE => :person, SK::ACTION => :new, person_form_errors: { age: ["must be a whole number"] } }
      app.rebuild_with_state(state)

      alerts = flatten_components(app.components).select { |c| c.is_a?(StreamWeaver::Components::Alert) }
      expect(alerts.map(&:variant)).to include(:error)
    end

    it "a validate: proc's errors block the submit alongside coercion errors" do
      app = StreamWeaver::App.new("Test") do
        resource :person, store: FormForStore do
          field :name,   :string
          field :age,    :integer
          field :budget, :number

          new do |_data|
            form_for :person, validate: ->(values) { values[:name].to_s.empty? ? { name: ["can't be blank"] } : {} }
          end
        end
      end
      app.rebuild_with_state({ SK::RESOURCE => :person, SK::ACTION => :new })
      form = find_form(app)

      form.instance_variable_get(:@submit_action).call('name' => '', 'age' => '40', 'budget' => '9.5')

      expect(app.state[:person_form_errors][:name]).to include("can't be blank")
    end

    it "submit_label/cancel_label inside the form_for block override the defaults" do
      app = StreamWeaver::App.new("Test") do
        resource :person, store: FormForStore do
          field :name, :string

          edit do |person|
            form_for :person, record: person do
              submit_label "Save changes"
              cancel_label "Nevermind"
            end
          end
        end
      end
      app.rebuild_with_state({ SK::RESOURCE => :person, SK::ACTION => :edit, SK::ID => '1' })

      form = find_form(app)
      expect(form.submit_label).to eq("Save changes")
      expect(form.cancel_label).to eq("Nevermind")
    end

    it "extra fields declared in the block render alongside the generated ones" do
      app = StreamWeaver::App.new("Test") do
        resource :person, store: FormForStore do
          field :name, :string

          new do
            form_for :person do
              text_field :extra_note, submit: false
            end
          end
        end
      end
      app.rebuild_with_state({ SK::RESOURCE => :person, SK::ACTION => :new })

      form = find_form(app)
      fields = flatten_components(form.children).select { |c| c.respond_to?(:key) }
      expect(fields.map(&:key)).to include(:extra_note)
    end

    it "raises when submit_label/cancel_label/validate are used outside a form_for block" do
      app = StreamWeaver::App.new("Test") { }
      expect { app.instance_exec { submit_label "x" } }.to raise_error(/form_for block/)
      expect { app.instance_exec { cancel_label "x" } }.to raise_error(/form_for block/)
      expect { app.instance_exec { validate {} } }.to raise_error(/form_for block/)
    end

    it "an on_success: override takes precedence over the resource's default transition" do
      app = StreamWeaver::App.new("Test") do
        resource :person, store: FormForStore do
          field :name, :string

          new do
            form_for :person, on_success: ->(_id) { state[SK::ACTION] = :index }
          end
        end
      end
      app.rebuild_with_state({ SK::RESOURCE => :person, SK::ACTION => :new })

      find_form(app).instance_variable_get(:@submit_action).call('name' => 'Zora')

      expect(app.state[SK::ACTION]).to eq(:index)
    end
  end
end
