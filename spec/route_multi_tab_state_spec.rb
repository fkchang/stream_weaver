# frozen_string_literal: true

require 'rack/test'

# 2026-08-31: route_with session state is one hash per browser (cookie), not
# per tab. Without reconciliation, a special-view flag set by tab B (e.g.
# visiting /now) leaks into tab A's next click — tab A gets pushed to /now
# even though it never navigated there. Found live in cultiv-ai's
# Cultivation Dashboard; see wiki/streamweaver-route-with-pitfalls.md.
module RouteMultiTabStateSpecRouting
  SPECIAL_VIEW_RESET = { special_view: nil }.freeze

  def self.parse(path)
    case path
    when "/" then SPECIAL_VIEW_RESET.merge(main_nav: 0)
    when "/special" then SPECIAL_VIEW_RESET.merge(special_view: true)
    end
  end

  def self.build(state)
    return "/special" if state[:special_view]

    "/"
  end
end

RSpec.describe "route_with multi-tab state reconciliation" do
  include Rack::Test::Methods

  def extract_button_id(html, label)
    slug = label.downcase.gsub(/\s+/, "_")
    match = html.match(/hx-post="\/action\/(btn_#{slug}_[a-f0-9]+)"/)
    match ? match[1] : "btn_#{slug}_1"
  end

  let(:stream_weaver_app) do
    StreamWeaver::App.new("Multi-tab Test App") do
      route_with(
        parser: RouteMultiTabStateSpecRouting.method(:parse),
        builder: RouteMultiTabStateSpecRouting.method(:build)
      )
      button "Click me" do |state|
        state[:clicked] = true
      end
    end
  end

  let(:app) { stream_weaver_app.generate }

  it "does not push a same-session sibling tab's dedicated view onto this tab's /update click" do
    # Tab 1 loads the default view.
    get '/'
    expect(last_response).to be_ok

    # Tab 2 (same browser, same cookie jar) navigates to the dedicated view.
    get '/special'
    expect(last_response).to be_ok

    # Tab 1 clicks something, reporting (via htmx) that it is still on "/".
    post '/update', {}, { 'HTTP_HX_CURRENT_URL' => 'http://example.org/' }

    expect(last_response.headers['HX-Push-Url']).to eq('/')
  end

  it "does not push a same-session sibling tab's dedicated view onto this tab's button click" do
    get '/'
    button_id = extract_button_id(last_response.body, "Click me")

    get '/special'

    post "/action/#{button_id}", {}, { 'HTTP_HX_CURRENT_URL' => 'http://example.org/' }

    expect(last_response.headers['HX-Push-Url']).to eq('/')
  end

  it "still resolves correctly for the tab that IS on the dedicated view" do
    get '/'
    get '/special'

    post '/update', {}, { 'HTTP_HX_CURRENT_URL' => 'http://example.org/special' }

    expect(last_response.headers['HX-Push-Url']).to eq('/special')
  end

  it "self-heals: after tab 1 clobbers shared state back to '/', tab 2's next click still resolves to /special" do
    get '/'
    get '/special'

    # Tab 1's click reseeds the shared session back to the default view.
    post '/update', {}, { 'HTTP_HX_CURRENT_URL' => 'http://example.org/' }
    expect(last_response.headers['HX-Push-Url']).to eq('/')

    # Tab 2, still on /special, clicks next — its own HX-Current-URL wins
    # over whatever tab 1 just did to the shared session.
    post '/update', {}, { 'HTTP_HX_CURRENT_URL' => 'http://example.org/special' }
    expect(last_response.headers['HX-Push-Url']).to eq('/special')
  end

  it "leaves state untouched when the request carries no HX-Current-URL (non-htmx POST)" do
    get '/'
    get '/special'

    post '/update', {}

    # No reconciliation signal available -> falls back to whatever the
    # shared session state says, same as before this fix.
    expect(last_response.headers['HX-Push-Url']).to eq('/special')
  end

  it "does not raise on a malformed HX-Current-URL" do
    get '/'
    get '/special'

    expect {
      post '/update', {}, { 'HTTP_HX_CURRENT_URL' => 'not a valid uri ::' }
    }.not_to raise_error

    expect(last_response).to be_ok
  end

  context "an app that does not use route_with" do
    let(:stream_weaver_app) do
      StreamWeaver::App.new("Non-routable Test App") do
        button "Click me" do |state|
          state[:clicked] = true
        end
      end
    end

    it "ignores HX-Current-URL entirely (routable? guard short-circuits)" do
      post '/update', {}, { 'HTTP_HX_CURRENT_URL' => 'http://example.org/anything' }

      expect(last_response).to be_ok
      expect(last_response.headers['HX-Push-Url']).to be_nil
    end
  end
end
