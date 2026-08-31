# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

RSpec.describe 'Save-as-doc widget injection' do
  include Rack::Test::Methods

  def app
    StreamWeaver::Canvas::BridgeServer
  end

  around do |ex|
    described_class_app = StreamWeaver::Canvas::BridgeServer
    described_class_app.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    ex.run
  ensure
    described_class_app.bridge = nil
  end

  before do
    StreamWeaver::Canvas::BridgeServer.bridge.create_session('mysession')
  end

  let(:html) do
    get '/canvas/mysession'
    last_response.body
  end

  it 'renders the canvas page successfully' do
    get '/canvas/mysession'
    expect(last_response.status).to eq(200)
  end

  it 'includes a Save as doc button anchored to the session name' do
    expect(html).to include('sw-save-doc-btn')
    expect(html).to match(/Save as doc/i)
  end

  it 'embeds the session name in the save-doc POST URL' do
    expect(html).to include('/canvas/mysession/save-doc')
  end

  it 'pre-fills the dialog with <session>-YYYYMMDD-HHMM' do
    # The default-name JS should reference the session and timestamp pattern.
    expect(html).to include("'mysession-'")
  end

  it 'mounts an Alpine.js x-data component for the dialog' do
    expect(html).to include('x-data')
    expect(html).to include('sw-save-doc-modal')
  end

  it 'styles the floating button (CSS class present)' do
    expect(html).to match(/\.sw-save-doc-btn\b/)
  end

  # stream_weaver-j3b3: the This repo/Global scope toggle.
  describe 'the scope toggle' do
    it "shows only the Gist radio (no 'This repo') when the session has no source_dir yet (nothing pushed, or pushed from outside a repo) -- bridge-canvas-gist-endpoint wires gist: through unconditionally, so the row no longer disappears entirely" do
      expect(StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').source_dir).to be_nil
      expect(html).not_to include('This repo')
      expect(html).to include('x-model="scope"')
      expect(html).to include('value="gist"')
    end

    it "shows 'This repo (<basename>)' with the resolved directory once the session has a source_dir" do
      StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').set_source_dir('/Users/someone/work/billing_engine')

      expect(html).to include('x-model="scope"')
      expect(html).to include('This repo (billing_engine)')
      expect(html).to include('/Users/someone/work/billing_engine')
      expect(html).to include('value="repo"')
      expect(html).to include('value="global"')
    end

    it 'defaults the scope to repo when source_dir is present' do
      StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').set_source_dir('/repo/one')
      expect(html).to include("scope: 'repo'")
    end

    it 'defaults the scope to global when source_dir is absent' do
      expect(html).to include("scope: 'global'")
    end

    it 'includes scope in the POST body sent by save()' do
      expect(html).to include('scope: this.scope')
    end

    it 'HTML-escapes a source_dir path containing special characters' do
      StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').set_source_dir("/tmp/a & b's <repo>")
      expect(html).to include('&amp;')
      expect(html).to include('&#39;')
    end
  end

  # share-to-gist: the Gist destination radio. Exercised by calling
  # SaveDocWidget.render directly (rather than through the bridge, whose
  # wiring is covered by bridge_save_doc_gist_spec.rb) since this story's
  # contract is the widget's rendering, not the bridge's wiring.
  describe 'the gist scope option (share-to-gist)' do
    def render_widget(gist: nil, source_dir: nil)
      StreamWeaver::Canvas::SaveDocWidget.render(
        endpoint: '/canvas/mysession/save-doc',
        button_title: 'Save this canvas as a persistent doc',
        dialog_title: 'Save canvas as doc',
        hint_html: 'hint',
        name_init: "''",
        source_dir: source_dir,
        gist: gist
      )
    end

    let(:available_gist) { { available: true, unavailable_reason: nil, known: {}, prefill_name: nil } }

    it 'omits the scope row entirely when neither source_dir nor gist is present' do
      html = render_widget
      expect(html).not_to include('x-model="scope"')
      expect(html).not_to include('value="gist"')
    end

    it 'renders the Gist radio even when there is no source_dir' do
      html = render_widget(gist: available_gist)
      expect(html).to include('x-model="scope"')
      expect(html).to include('value="gist"')
      expect(html).not_to include('This repo')
    end

    it 'renders repo, global, and gist radios together when both source_dir and gist are present' do
      html = render_widget(source_dir: '/repo/one', gist: available_gist)
      expect(html).to include('value="repo"')
      expect(html).to include('value="global"')
      expect(html).to include('value="gist"')
    end

    it 'renders the Gist radio disabled, with unavailable_reason as helper text, when gist is unavailable' do
      html = render_widget(gist: {
                              available: false,
                              unavailable_reason: 'Install the gh CLI and run gh auth login',
                              known: {},
                              prefill_name: nil
                            })
      expect(html).to match(/value="gist" disabled/)
      expect(html).to include('Install the gh CLI and run gh auth login')
    end

    it 'does not disable the Gist radio when available' do
      html = render_widget(gist: available_gist)
      expect(html).not_to match(/value="gist" disabled/)
    end

    it 'embeds gist[:known] for the currentGist() lookup' do
      html = render_widget(gist: {
                              available: true,
                              unavailable_reason: nil,
                              known: { 'mailroom-incident-20260813-1123' => { url: 'https://gist.github.com/abc123', revisions: 3 } },
                              prefill_name: nil
                            })
      expect(html).to include('gistKnown')
      expect(html).to include('mailroom-incident-20260813-1123')
      expect(html).to include('https://gist.github.com/abc123')
    end

    it 'hides the Save/Save-as-Org pair and shows a single gist button, labeled live from currentGist()' do
      html = render_widget(gist: available_gist)
      expect(html).to include(%(x-show="scope !== 'gist'"))
      expect(html).to include(%(x-show="scope === 'gist'"))
      expect(html).to include('sw-save-doc-save-gist')
      expect(html).to include('Update gist')
      expect(html).to include('Create gist')
    end

    it "prefills openDialog()'s name from gist[:prefill_name] instead of reset_name_js when a gist is already known" do
      html = render_widget(gist: {
                              available: true,
                              unavailable_reason: nil,
                              known: {},
                              prefill_name: 'mailroom-incident-20260813-1123'
                            })
      expect(html).to include('gistPrefill')
      expect(html).to include('mailroom-incident-20260813-1123')
      expect(html).to include('if (this.gistPrefill)')
    end

    it 'does not auto-close on a gist save, and shows clipboard-copy + Open gist / Revisions links' do
      html = render_widget(gist: available_gist)
      expect(html).to include('data.gist_url')
      expect(html).to include('navigator.clipboard.writeText')
      expect(html).to include('Open gist')
      expect(html).to include('Revisions')
      expect(html).to include("gistResult.url + '/revisions'")
    end

    it 'never initializes scope to gist, regardless of source_dir/gist kwargs' do
      [
        render_widget,
        render_widget(source_dir: '/repo/one'),
        render_widget(gist: available_gist),
        render_widget(source_dir: '/repo/one', gist: {
                        available: false, unavailable_reason: 'x', known: {}, prefill_name: 'name'
                      })
      ].each do |markup|
        expect(markup).not_to match(/scope:\s*'gist'/)
      end
    end

    it 'HTML-escapes gist data so a quote in a name cannot close the x-data attribute' do
      html = render_widget(gist: {
                              available: true,
                              unavailable_reason: nil,
                              known: { %(a's "doc") => { url: 'https://gist.github.com/x', revisions: 1 } },
                              prefill_name: %(a's "doc")
                            })
      expect(html).to include('&quot;')
      expect(html).to include('&#39;')
      expect(html).not_to match(/gistKnown: \{"/)
      expect(html).not_to match(/gistPrefill: "/)
    end

    it "leaves format alone on a gist save, so scope alone selects the destination (doesn't 422 against a server rb/org whitelist)" do
      expect(render_widget(gist: available_gist)).not_to match(/format\s*=\s*'gist'/)
    end
  end
end
