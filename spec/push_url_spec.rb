# frozen_string_literal: true

require 'rack/test'

RSpec.describe StreamWeaver::PushUrl do
  describe '.keep_query' do
    it 'carries the current query when the push lands on the path the browser is already on' do
      expect(described_class.keep_query('/', 'http://example.org/?view=2')).to eq('/?view=2')
    end

    it 'leaves a push to a different path alone (a real navigation drops the old query)' do
      expect(described_class.keep_query('/special', 'http://example.org/?view=2')).to eq('/special')
    end

    it 'leaves the path alone when there is no query or no header' do
      expect(described_class.keep_query('/', 'http://example.org/')).to eq('/')
      expect(described_class.keep_query('/', nil)).to eq('/')
    end

    it 'works for a non-root page and keeps the fragment' do
      expect(described_class.keep_query('/special', 'http://example.org/special?view=1#row-4')).to eq('/special?view=1#row-4')
    end

    it 'ignores one trailing slash and keeps the path the browser shows' do
      expect(described_class.keep_query('/apps/ab12/', 'http://example.org/apps/ab12?view=2')).to eq('/apps/ab12?view=2')
    end

    it 'never rewrites a pushed path that already has a query' do
      expect(described_class.keep_query('/?x=1', 'http://example.org/?view=2')).to eq('/?x=1')
    end

    it 'reads the mount prefix the browser is on, slug or id' do
      expect(described_class.mount_prefix('http://example.org/apps/my-slug?view=2')).to eq('/apps/my-slug')
      expect(described_class.mount_prefix('http://example.org/')).to be_nil
    end

    it 'does not raise on a malformed header' do
      expect(described_class.keep_query('/', 'http://exa mple.org/?view=2')).to eq('/')
    end
  end

  describe 'a url: true tab click' do
    include Rack::Test::Methods

    let(:app) do
      StreamWeaver::App.new('Push Url') do
        route_with(parser: ->(path) { path == '/' ? { main: true } : nil }, builder: ->(_state) { '/' })
        tabs :view, url: true do
          tab('Alpha') { text 'alpha' }
          tab('Beta') { button('Tap') { |s| s[:tapped] = true } }
        end
      end.generate
    end

    it 'keeps ?view=1 on the pushed URL instead of snapping to the first tab' do
      get '/?view=1'
      post '/update', {}, { 'HTTP_HX_CURRENT_URL' => 'http://example.org/?view=1' }

      expect(last_response.headers['HX-Push-Url']).to eq('/?view=1')
    end
  end
end
