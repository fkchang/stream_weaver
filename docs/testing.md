# Testing StreamWeaver Apps

This guide covers testing strategies for StreamWeaver applications.

## Unit Testing with `rebuild_with_state`

Test component logic without running a server:

```ruby
require 'spec_helper'

RSpec.describe "My App" do
  let(:my_app) do
    StreamWeaver::App.new("Test") do
      text_field :name
      if state[:name] == "Alice"
        text "Hello Alice!"
      end
    end
  end

  it "shows greeting when name is Alice" do
    my_app.rebuild_with_state({ name: "Alice" })
    expect(my_app.components.length).to eq(2)  # text_field + text
  end

  it "hides greeting when name is empty" do
    my_app.rebuild_with_state({ name: "" })
    expect(my_app.components.length).to eq(1)  # just text_field
  end
end
```

## Integration Testing with Rack::Test

Test HTTP endpoints and button actions without opening a browser:

```ruby
require 'spec_helper'
require 'rack/test'

RSpec.describe "My App Integration" do
  include Rack::Test::Methods

  let(:stream_app) do
    StreamWeaver.app "Test" do
      text_field :name
      button "Greet" do |s|
        s[:greeted] = true
        s[:greeting] = "Hello, #{s[:name]}!"
      end
    end
  end
  let(:app) { stream_app.generate }  # Get Sinatra app for Rack::Test

  it "renders initial form" do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.body).to include('name')
  end

  it "handles button click with session state" do
    # Inject state before request
    env 'rack.session', { streamlit_state: { name: "Alice" } }

    # Simulate button click (button names normalized: lowercase, underscores)
    post '/action/btn_greet_1', { name: "Alice" }

    # Verify state was updated
    state = last_request.session[:streamlit_state]
    expect(state[:greeted]).to be true
    expect(state[:greeting]).to eq("Hello, Alice!")
  end

  it "handles form field update" do
    env 'rack.session', { streamlit_state: { name: "" } }
    post '/update', { name: "Bob" }

    state = last_request.session[:streamlit_state]
    expect(state[:name]).to eq("Bob")
  end
end
```

## Key Testing Patterns

| Pattern | Purpose |
|---------|---------|
| `rebuild_with_state(hash)` | Re-evaluates DSL block with given state, for testing conditional rendering |
| `app.generate` | Returns the Sinatra app for Rack::Test |
| `env 'rack.session', { streamlit_state: {...} }` | Inject state before requests |
| `last_request.session[:streamlit_state]` | Read state after requests |
| `POST /action/btn_<name>_<id>` | Button actions (names normalized: lowercase, underscores) |
| `POST /update` | Form field updates |

## Testing Agentic Mode (`run_once!`)

The `/submit` endpoint can be tested directly:

```ruby
it "handles form submission" do
  env 'rack.session', { streamlit_state: { name: "Test", priority: "High" } }
  post '/submit', { name: "Test", priority: "High" }
  expect(last_response).to be_ok
end
```

Note: Testing the full `run_once!` flow (with browser wait loop) requires manual testing or browser automation.

## Session State Notes

State persists in browser cookies across server restarts. For testing:
- Clear browser cookies for localhost
- Use incognito mode for fresh sessions
- Add a reset button: `button "Reset" do |s| s.clear end`
