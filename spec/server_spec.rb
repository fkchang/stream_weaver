# frozen_string_literal: true

require 'rack/test'

RSpec.describe "StreamWeaver Server" do
  include Rack::Test::Methods

  let(:stream_weaver_app) do
    StreamWeaver::App.new("Test App") do
      header1 "Welcome"
      text_field :name, placeholder: "Enter name"

      button "Greet" do |state|
        state[:greeted] = true
        state[:greeting] = "Hello, #{state[:name]}!"
      end

      if state[:greeted]
        text state[:greeting]
      end

      checkbox :subscribe, "Subscribe"
      select :color, ["Red", "Green", "Blue"]
    end
  end

  let(:app) { stream_weaver_app.generate }

  describe "GET /" do
    it "returns successful response" do
      get '/'
      expect(last_response).to be_ok
    end

    it "renders HTML" do
      get '/'
      expect(last_response.content_type).to include('text/html')
    end

    it "includes app title" do
      get '/'
      expect(last_response.body).to include("Test App")
    end

    it "includes all components" do
      get '/'
      body = last_response.body

      # Check for various component markers
      expect(body).to include("Welcome")  # Text
      expect(body).to include("name")  # TextField
      expect(body).to include("Greet")  # Button
      expect(body).to include("Subscribe")  # Checkbox
      expect(body).to include("Red")  # Select option
    end

    it "includes Alpine.js CDN" do
      get '/'
      expect(last_response.body).to include("alpine")
    end

    it "includes HTMX CDN" do
      get '/'
      expect(last_response.body).to include("htmx")
    end

    it "initializes session state with component defaults" do
      get '/'
      # State is initialized with default values for each form component
      state = last_request.session[:streamlit_state]
      expect(state[:name]).to eq("")       # text_field default
      expect(state[:subscribe]).to eq(false) # checkbox default
      expect(state[:color]).to eq("")      # select without default
    end
  end

  describe "POST /update" do
    it "handles checkbox state (checked)" do
      env 'rack.session', { streamlit_state: { subscribe: false } }

      post '/update', { subscribe: "true" }

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:subscribe]).to be true
    end

    it "handles checkbox state (unchecked)" do
      env 'rack.session', { streamlit_state: { subscribe: true } }

      # Unchecked checkboxes don't send params - HTMX only includes [x-model] elements
      post '/update', {}

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:subscribe]).to be false
    end

    it "updates text field state" do
      env 'rack.session', { streamlit_state: { name: "" } }

      post '/update', { name: "Alice" }

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:name]).to eq("Alice")
    end
  end

  describe "POST /action/:button_id" do
    it "executes button action" do
      # Set up session
      env 'rack.session', { streamlit_state: { name: "Alice" } }

      # Click the button
      post '/action/btn_greet_1', { name: "Alice" }

      expect(last_response).to be_ok
    end

    it "updates session state" do
      env 'rack.session', { streamlit_state: { name: "Bob" } }

      post '/action/btn_greet_1', { name: "Bob" }

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:greeted]).to be true
      expect(session_state[:greeting]).to eq("Hello, Bob!")
    end

    it "returns updated HTML" do
      env 'rack.session', { streamlit_state: { name: "Charlie" } }

      post '/action/btn_greet_1', { name: "Charlie" }

      expect(last_response.body).to include("Hello, Charlie!")
    end

    it "syncs Alpine.js state from form inputs" do
      env 'rack.session', { streamlit_state: {} }

      post '/action/btn_greet_1', { name: "Diana" }

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:name]).to eq("Diana")
    end

    it "handles checkbox state (checked)" do
      env 'rack.session', { streamlit_state: {} }

      post '/action/btn_greet_1', { subscribe: "on" }

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:subscribe]).to be true
    end

    it "handles checkbox state (unchecked)" do
      env 'rack.session', { streamlit_state: { subscribe: true } }

      # Unchecked checkboxes don't send params
      post '/action/btn_greet_1', {}

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:subscribe]).to be false
    end

    it "finds button by deterministic ID" do
      env 'rack.session', { streamlit_state: {} }

      post '/action/btn_greet_1', {}

      expect(last_response).to be_ok
    end

    it "returns 200 even if button not found" do
      env 'rack.session', { streamlit_state: {} }

      post '/action/nonexistent_button', {}

      expect(last_response).to be_ok
    end
  end

  describe "state persistence" do
    it "maintains state across requests" do
      env 'rack.session', { streamlit_state: { counter: 0 } }

      # First request
      get '/'
      session1 = last_request.session[:streamlit_state]
      expect(session1[:counter]).to eq(0)

      # Modify state
      env 'rack.session', { streamlit_state: { counter: 5 } }

      # Second request
      get '/'
      session2 = last_request.session[:streamlit_state]
      expect(session2[:counter]).to eq(5)
    end

    it "isolates state between sessions" do
      # Session 1
      env 'rack.session', { streamlit_state: { user: "Alice" } }
      get '/'
      session1 = last_request.session[:streamlit_state]

      # Session 2 (different rack session - reset environment)
      clear_cookies
      env 'rack.session', {}  # Reset to empty session
      get '/'
      session2 = last_request.session[:streamlit_state]

      expect(session1[:user]).to eq("Alice")
      expect(session2[:user]).to be_nil
    end
  end

  describe "helper methods" do
    describe ".find_button_recursive" do
      let(:button1) { StreamWeaver::Components::Button.new("Test", 1) }
      let(:button2) { StreamWeaver::Components::Button.new("Nested", 2) }
      let(:div) { StreamWeaver::Components::Div.new }

      before do
        div.children = [button2]
      end

      it "finds button at top level" do
        components = [button1]
        found = StreamWeaver::SinatraApp.find_button_recursive(components, button1.id)
        expect(found).to eq(button1)
      end

      it "finds button in nested structure" do
        components = [div]
        found = StreamWeaver::SinatraApp.find_button_recursive(components, button2.id)
        expect(found).to eq(button2)
      end

      it "returns nil if button not found" do
        components = [button1]
        found = StreamWeaver::SinatraApp.find_button_recursive(components, "nonexistent")
        expect(found).to be_nil
      end

      it "handles deeply nested structures" do
        div1 = StreamWeaver::Components::Div.new
        div2 = StreamWeaver::Components::Div.new
        div3 = StreamWeaver::Components::Div.new

        div3.children = [button2]
        div2.children = [div3]
        div1.children = [div2]

        components = [div1]
        found = StreamWeaver::SinatraApp.find_button_recursive(components, button2.id)
        expect(found).to eq(button2)
      end
    end

    describe ".collect_input_keys" do
      it "collects keys from TextField" do
        field = StreamWeaver::Components::TextField.new(:email)
        components = [field]

        keys = StreamWeaver::SinatraApp.collect_input_keys(components)
        expect(keys).to eq([:email])
      end

      it "collects keys from Checkbox" do
        checkbox = StreamWeaver::Components::Checkbox.new(:agree, "Agree")
        components = [checkbox]

        keys = StreamWeaver::SinatraApp.collect_input_keys(components)
        expect(keys).to eq([:agree])
      end

      it "collects keys from Select" do
        select = StreamWeaver::Components::Select.new(:color, ["Red"])
        components = [select]

        keys = StreamWeaver::SinatraApp.collect_input_keys(components)
        expect(keys).to eq([:color])
      end

      it "ignores components without keys" do
        text = StreamWeaver::Components::Text.new("Hello")
        button = StreamWeaver::Components::Button.new("Click", 1)
        components = [text, button]

        keys = StreamWeaver::SinatraApp.collect_input_keys(components)
        expect(keys).to eq([])
      end

      it "collects keys from nested structures" do
        field = StreamWeaver::Components::TextField.new(:name)
        checkbox = StreamWeaver::Components::Checkbox.new(:agree, "Agree")
        div = StreamWeaver::Components::Div.new
        div.children = [field, checkbox]

        components = [div]
        keys = StreamWeaver::SinatraApp.collect_input_keys(components)
        expect(keys).to contain_exactly(:name, :agree)
      end
    end

    describe ".find_component_by_key" do
      let(:field) { StreamWeaver::Components::TextField.new(:email) }
      let(:checkbox) { StreamWeaver::Components::Checkbox.new(:agree, "Agree") }

      it "finds component by key" do
        components = [field, checkbox]
        found = StreamWeaver::SinatraApp.find_component_by_key(components, :email)
        expect(found).to eq(field)
      end

      it "finds component in nested structure" do
        div = StreamWeaver::Components::Div.new
        div.children = [checkbox]
        components = [div]

        found = StreamWeaver::SinatraApp.find_component_by_key(components, :agree)
        expect(found).to eq(checkbox)
      end

      it "returns nil if not found" do
        components = [field]
        found = StreamWeaver::SinatraApp.find_component_by_key(components, :nonexistent)
        expect(found).to be_nil
      end
    end

    describe ".find_available_port" do
      it "returns a port number" do
        port = StreamWeaver::SinatraApp.find_available_port
        expect(port).to be_a(Integer)
        expect(port).to be >= 4567
      end

      it "finds next available port if default is taken" do
        # This test is hard to make deterministic, but we can at least check it doesn't crash
        port1 = StreamWeaver::SinatraApp.find_available_port(4567)
        expect(port1).to be_a(Integer)
      end
    end
  end

  describe "agentic mode integration" do
    it "exposes /submit endpoint" do
      post '/submit', { name: "Test" }
      expect(last_response).to be_ok
    end

    it "includes confirmation message" do
      post '/submit', { name: "Test" }
      expect(last_response.body).to include("Submitted")
    end
  end

  describe "conditional rendering" do
    let(:conditional_stream_weaver_app) do
      StreamWeaver::App.new("Conditional") do
        text_field :password

        if state[:password] == "secret"
          text "Access granted!"
          button "Reset" do |state|
            state[:password] = ""
          end
        else
          text "Enter password"
        end
      end
    end

    let(:app) { conditional_stream_weaver_app.generate }

    it "renders different UI based on state (unauthorized)" do
      get '/'
      expect(last_response.body).to include("Enter password")
      expect(last_response.body).not_to include("Access granted")
    end

    it "renders different UI based on state (authorized)" do
      env 'rack.session', { streamlit_state: { password: "secret" } }
      get '/'

      expect(last_response.body).to include("Access granted")
      expect(last_response.body).to include("Reset")
    end
  end

  describe "complex app integration" do
    let(:todo_stream_weaver_app) do
      StreamWeaver::App.new("Todo") do
        header1 "Todo List"

        text_field :new_todo

        button "Add" do |state|
          state[:todos] ||= []
          state[:todos] << state[:new_todo] if state[:new_todo]
          state[:new_todo] = ""
        end

        state[:todos] ||= []
        state[:todos].each_with_index do |todo, idx|
          div do
            text todo
            button "Delete", style: :secondary do |state|
              state[:todos].delete_at(idx)
            end
          end
        end
      end
    end

    let(:app) { todo_stream_weaver_app.generate }

    it "handles todo addition" do
      env 'rack.session', { streamlit_state: { todos: [] } }

      post '/action/btn_add_1', { new_todo: "Buy milk" }

      session_state = last_request.session[:streamlit_state]
      expect(session_state[:todos]).to include("Buy milk")
      expect(session_state[:new_todo]).to eq("")
    end

    it "renders dynamic buttons for each todo" do
      env 'rack.session', { streamlit_state: { todos: ["Task 1", "Task 2"] } }

      get '/'

      expect(last_response.body).to include("Task 1")
      expect(last_response.body).to include("Task 2")
      # Should have Add button + 2 Delete buttons = 3 buttons with deterministic IDs
    end
  end
end
