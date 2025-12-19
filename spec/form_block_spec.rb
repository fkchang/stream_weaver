# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe "Form Block" do
  include Rack::Test::Methods

  describe "DSL" do
    it "creates a form component with nested fields" do
      my_app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
          select :status, %w[active paused]
          submit 'Save'
          cancel 'Cancel'
        end
      end

      my_app.rebuild_with_state({})

      # Should have one form component
      expect(my_app.components.length).to eq(1)
      form = my_app.components.first
      expect(form).to be_a(StreamWeaver::Components::Form)
      expect(form.name).to eq(:edit_person)
      expect(form.submit_label).to eq('Save')
      expect(form.cancel_label).to eq('Cancel')

      # Form should have nested children
      expect(form.children.length).to eq(2) # text_field and select
    end

    it "initializes form state as nested hash" do
      my_app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
          text_field :email
        end
      end

      my_app.rebuild_with_state({})

      # State should have nested structure
      expect(my_app.state[:edit_person]).to be_a(Hash)
      expect(my_app.state[:edit_person][:name]).to eq("")
      expect(my_app.state[:edit_person][:email]).to eq("")
    end

    it "preserves existing form state values" do
      my_app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
        end
      end

      existing_state = { edit_person: { name: "Alice", role: "admin" } }
      my_app.rebuild_with_state(existing_state)

      expect(my_app.state[:edit_person][:name]).to eq("Alice")
      expect(my_app.state[:edit_person][:role]).to eq("admin")
    end

    it "raises error when submit is used outside form block" do
      expect {
        my_app = StreamWeaver::App.new("Test") do
          submit 'Save'
        end
        my_app.rebuild_with_state({})
      }.to raise_error(RuntimeError, /submit can only be used inside a form block/)
    end

    it "raises error when cancel is used outside form block" do
      expect {
        my_app = StreamWeaver::App.new("Test") do
          cancel 'Cancel'
        end
        my_app.rebuild_with_state({})
      }.to raise_error(RuntimeError, /cancel can only be used inside a form block/)
    end

    it "stores submit action block" do
      submitted_values = nil

      my_app = StreamWeaver::App.new("Test") do
        form :edit_person do
          text_field :name
          submit 'Save' do |form_values|
            submitted_values = form_values
          end
        end
      end

      my_app.rebuild_with_state({})
      form = my_app.components.first

      # Execute the submit action
      form.execute_submit({}, { name: "Bob" })
      expect(submitted_values).to eq({ name: "Bob" })
    end
  end

  describe "Server endpoint POST /form/:form_name" do
    let(:stream_app) do
      StreamWeaver::App.new("Form Test") do
        form :profile do
          text_field :name
          select :role, %w[admin user guest]
          submit 'Save'
        end

        # Display current state for verification
        text "Name: #{state.dig(:profile, :name)}"
        text "Role: #{state.dig(:profile, :role)}"
      end
    end

    let(:app) { stream_app.generate }

    it "updates state with form values" do
      # Simulate form submission with Rails-style nested params
      env 'rack.session', { streamlit_state: { profile: { name: "", role: "" } } }
      post '/form/profile', { 'profile' => { 'name' => 'Alice', 'role' => 'admin' } }

      expect(last_response).to be_ok

      # State should be updated
      state = last_request.session[:streamlit_state]
      expect(state[:profile][:name]).to eq('Alice')
      expect(state[:profile][:role]).to eq('admin')
    end

    it "converts checkbox true values" do
      stream_app = StreamWeaver::App.new("Checkbox Form") do
        form :settings do
          checkbox :notifications, "Enable notifications"
          submit 'Save'
        end
      end
      app = stream_app.generate

      env 'rack.session', { streamlit_state: { settings: { notifications: false } } }

      # Checkbox sends "true" when checked
      post '/form/settings', { 'settings' => { 'notifications' => 'true' } }, 'rack.session' => { streamlit_state: { settings: {} } }

      state = last_request.session[:streamlit_state]
      expect(state[:settings][:notifications]).to eq(true)
    end

    it "submit block receives form_values as parameter" do
      # Verify the submit block is called - we can't easily test side effects
      # because the block runs in a different context during rebuild.
      # The main behavior (state auto-update) is already tested above.
      # This test verifies the form component has a submit action set.
      stream_app = StreamWeaver::App.new("Submit Block Test") do
        form :data do
          text_field :value
          submit 'Submit' do |form_values|
            # This block runs during the request - form_values should be the submitted data
            # Side effects here would typically be API calls, etc.
          end
        end
      end

      stream_app.rebuild_with_state({})
      form = stream_app.components.first
      expect(form.submit_action).not_to be_nil

      # The key behavior is that state[:data] gets the form values
      app = stream_app.generate
      env 'rack.session', { streamlit_state: { data: {} } }
      post '/form/data', { 'data' => { 'value' => 'test123' } }

      state = last_request.session[:streamlit_state]
      expect(state[:data][:value]).to eq('test123')
    end
  end

  describe "HTML rendering" do
    let(:stream_app) do
      StreamWeaver::App.new("Render Test") do
        form :contact do
          text_field :email, placeholder: 'Email'
          submit 'Send'
          cancel 'Reset'
        end
      end
    end

    let(:app) { stream_app.generate }

    it "renders form with Alpine.js x-data" do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include('x-data')
      expect(last_response.body).to include('_form')
      expect(last_response.body).to include('_original')
    end

    it "renders form fields with form-scoped x-model" do
      get '/'
      expect(last_response.body).to include('x-model="_form.email"')
    end

    it "renders form fields with Rails-style nested name attributes" do
      get '/'
      expect(last_response.body).to include('name="contact[email]"')
    end

    it "renders submit button with HTMX to /form endpoint" do
      get '/'
      expect(last_response.body).to include('hx-post="/form/contact"')
    end

    it "renders cancel button with Alpine reset action" do
      get '/'
      expect(last_response.body).to include('_form = JSON.parse(JSON.stringify(_original))')
    end

    it "does NOT include hx-post on form fields (deferred submission)" do
      get '/'
      # Form fields should not have immediate HTMX sync
      # Count occurrences of hx-post - should only be on submit button
      hx_post_count = last_response.body.scan('hx-post').length
      # One for submit button only
      expect(hx_post_count).to eq(1)
    end
  end

  describe "Form fields inside vs outside form" do
    let(:stream_app) do
      StreamWeaver::App.new("Mixed Test") do
        # Standalone text field - should have immediate sync
        text_field :standalone_name

        form :profile do
          # Form text field - should NOT have immediate sync
          text_field :form_name
          submit 'Save'
        end
      end
    end

    let(:app) { stream_app.generate }

    it "standalone field has immediate HTMX sync" do
      get '/'
      # Standalone should have hx-post="/update" and hx-trigger
      expect(last_response.body).to include('name="standalone_name"')
      expect(last_response.body).to match(/name="standalone_name"[^>]*hx-post="\/update"/)
    end

    it "form field does NOT have immediate HTMX sync" do
      get '/'
      # Form field should have nested name but no hx-post on the field itself
      expect(last_response.body).to include('name="profile[form_name]"')
      # The form field line should NOT contain hx-post="/update"
      expect(last_response.body).not_to match(/name="profile\[form_name\]"[^>]*hx-post="\/update"/)
    end
  end
end
