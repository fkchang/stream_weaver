# frozen_string_literal: true

require 'rack/test'

# A `url: true` tabs group answers to the request URL and nothing else. These
# specs drive the servers end to end because the failure they guard against -- a
# tab index surviving in the session and overriding the URL on the next visit --
# only exists once a session is in play. The same contract is exercised against
# both hosts: standalone below, and the multi-app service at the bottom.
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

    it 'parses a leading-zero parameter as decimal, matching the client' do
      # ?view=010 is where radix handling shows: Integer() reads it as octal 8
      # while the client's parseInt(raw, 10) reads 10. Twelve tabs keep both
      # candidates in range so the wrong parse can't hide behind the clamp.
      twelve_tabs = StreamWeaver::App.new('Route Tabs') do
        tabs :view, url: true do
          12.times { |i| tab("Tab #{i}") { text "panel #{i}" } }
        end
        text "server-active:#{state[:view]}"
      end
      Rack::Test::Session.new(Rack::MockSession.new(twelve_tabs.generate)).tap do |session|
        session.get '/?view=010'
        expect(session.last_response).to be_ok
        expect(session.last_response.body[/server-active:(\d+)/, 1]&.to_i).to eq(10)
      end
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

  # The service hosts the same app behind its own routes, which never reach
  # server.rb's render_app, so URL authority has to be wired at a second set of
  # render sites. A bookmark cannot mean one tab standalone and another under
  # the service.
  describe 'under the multi-app service' do
    let(:app) { StreamWeaver::Service }

    before do
      StreamWeaver::Service.clear_apps
      # What production's load_app gets for free: the app file has already
      # called App#generate, which rebuilds once to populate the route rules
      # `routable?` and the suffix route below read.
      stream_weaver_app.rebuild_with_state({})
      StreamWeaver::Service.apps['dashboard'] = {
        app: stream_weaver_app,
        path: 'dashboard.rb',
        name: 'Route Tabs',
        loaded_at: Time.now,
        last_accessed: Time.now
      }
    end

    after { StreamWeaver::Service.clear_apps }

    describe 'GET /apps/:app_id' do
      it 'renders the tab the url parameter names' do
        get '/apps/dashboard?view=1'

        expect(last_response).to be_ok
        expect(active_index).to eq(1)
      end

      it 'renders the first tab when the parameter is absent' do
        get '/apps/dashboard?view=2'
        get '/apps/dashboard'

        expect(last_response).to be_ok
        expect(active_index).to eq(0)
      end

      it 'renders the first tab when the parameter is out of range' do
        get '/apps/dashboard?view=999'

        expect(last_response).to be_ok
        expect(active_index).to eq(0)
      end

      it 'renders the first tab when the parameter is not a number' do
        get '/apps/dashboard?view=abc'

        expect(last_response).to be_ok
        expect(active_index).to eq(0)
      end

      it 'renders the first tab when the parameter arrives as an array' do
        get '/apps/dashboard?view[]='

        expect(last_response).to be_ok
        expect(active_index).to eq(0)
      end

      it 'renders the first tab on a bare url after an interaction moved the tab' do
        get '/apps/dashboard?view=2'
        post '/apps/dashboard/update', { 'view' => '1' }
        get '/apps/dashboard'

        expect(active_index).to eq(0)
      end

      # The other half of the contract, service-side (see the standalone example
      # above): a POST carries no authority, so a morph must not read the tab
      # key's absence from its own params as "tab 0".
      it 'leaves the tab alone on a morph no url drove' do
        get '/apps/dashboard?view=2'
        post '/apps/dashboard/update', { 'other' => 'x' }

        expect(active_index).to eq(2)
      end

      context 'with plain tabs' do
        let(:stream_weaver_app) { tabs_app(url: false) }

        it 'keeps the session index across the same sequence' do
          get '/apps/dashboard?view=2'
          post '/apps/dashboard/update', { 'view' => '1' }
          get '/apps/dashboard'

          expect(active_index).to eq(1)
        end
      end
    end

    # The suffix route is the service's other full-GET render path, and it
    # carries Sinatra's own `app_id` and `splat` params alongside the tab key --
    # a group resolves only the key it declared.
    describe 'GET /apps/:app_id/*' do
      let(:stream_weaver_app) do
        tabs_app { route_by :page, home: '/', reports: '/reports' }
      end

      it 'renders the tab the url parameter names' do
        get '/apps/dashboard/reports?view=2'

        expect(last_response).to be_ok
        expect(active_index).to eq(2)
      end

      it 'renders the first tab when the parameter is absent' do
        get '/apps/dashboard/reports?view=2'
        get '/apps/dashboard/reports'

        expect(last_response).to be_ok
        expect(active_index).to eq(0)
      end
    end

    # The admin dashboard is StreamWeaver's own app rather than a hosted one,
    # but it reaches the reader through the same full GET, and a tab strip is
    # exactly what it would grow. It must not be the one route where the URL
    # loses.
    describe 'GET /admin' do
      before { allow(StreamWeaver::Admin).to receive(:create_app).and_return(stream_weaver_app) }

      it 'renders the tab the url parameter names' do
        get '/admin?view=2'

        expect(last_response).to be_ok
        expect(active_index).to eq(2)
      end
    end
  end
end
