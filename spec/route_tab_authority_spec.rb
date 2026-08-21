# frozen_string_literal: true

require 'rack/test'

# A `url: true` tabs group answers to the request URL and nothing else. These
# specs drive the standalone server end to end because the failure they guard
# against -- a tab index surviving in the session and overriding the URL on the
# next visit -- only exists once a session is in play.
RSpec.describe 'route tab URL authority' do
  include Rack::Test::Methods

  # The rendered markup deliberately carries no server-chosen active class for
  # route tabs (the client derives it from the URL), so the app reports the
  # index the server resolved instead.
  def tabs_app(url: true, &routing)
    StreamWeaver::App.new('Route Tabs') do
      instance_exec(&routing) if routing
      tabs :view, url: url do
        tab('Alpha') { text 'alpha panel' }
        tab('Beta') { text 'beta panel' }
        tab('Gamma') { text 'gamma panel' }
      end
      text "server-active:#{state[:view]}"
    end
  end

  def active_index
    last_response.body[/server-active:(\d+)/, 1]&.to_i
  end

  let(:stream_weaver_app) { tabs_app }
  let(:app) { stream_weaver_app.generate }

  describe 'GET /' do
    it 'renders the tab the url parameter names' do
      get '/?view=2'

      expect(last_response).to be_ok
      expect(active_index).to eq(2)
    end

    it 'renders the first tab when the parameter is absent' do
      get '/?view=2'
      get '/'

      expect(last_response).to be_ok
      expect(active_index).to eq(0)
    end

    it 'renders the first tab when the parameter is out of range' do
      get '/?view=999'

      expect(last_response).to be_ok
      expect(active_index).to eq(0)
    end

    it 'renders the first tab when the parameter is not a number' do
      get '/?view=abc'

      expect(last_response).to be_ok
      expect(active_index).to eq(0)
    end

    it 'renders the first tab when the parameter arrives as an array' do
      get '/?view[]='

      expect(last_response).to be_ok
      expect(active_index).to eq(0)
    end
  end

  describe 'idempotence across interactions' do
    it 'renders the same tab for the same url however the session was touched between' do
      get '/?view=2'
      first = active_index

      post '/update', { 'view' => '1' }
      get '/?view=2'

      expect(first).to eq(2)
      expect(active_index).to eq(2)
    end

    it 'renders the first tab on a bare url after an interaction moved the tab' do
      get '/?view=2'
      post '/update', { 'view' => '1' }
      get '/'

      expect(active_index).to eq(0)
    end

    # The other half of the contract: only a URL carries authority. A morph
    # driven by some unrelated control must leave the group where it is -- the
    # tab key is not in those params, and treating its absence as "tab 0" would
    # snap the reader back to the first tab mid-interaction.
    it 'leaves the tab alone on a morph no url drove' do
      get '/?view=2'
      post '/update', { 'other' => 'x' }

      expect(active_index).to eq(2)
    end

    context 'with plain tabs' do
      let(:stream_weaver_app) { tabs_app(url: false) }

      it 'keeps the session index across the same sequence' do
        get '/?view=2'
        post '/update', { 'view' => '1' }
        get '/'

        expect(active_index).to eq(1)
      end
    end
  end

  describe 'GET on a routed path' do
    let(:stream_weaver_app) do
      tabs_app { route_by :page, home: '/', reports: '/reports' }
    end

    it 'renders the tab the url parameter names' do
      get '/reports?view=2'

      expect(last_response).to be_ok
      expect(active_index).to eq(2)
    end

    it 'renders the first tab when the parameter is absent' do
      get '/reports?view=2'
      get '/reports'

      expect(last_response).to be_ok
      expect(active_index).to eq(0)
    end
  end
end
