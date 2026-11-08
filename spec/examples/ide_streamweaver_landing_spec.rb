# frozen_string_literal: true

require "stream_weaver/canvas/bridge"

# The landing page example is the proof that the ide_* components compose:
# it has to render, and carry its sections, tabs and install tabs, both as a
# standalone app and as a canvas push of the same bare DSL body. The example
# keeps its only constants inside the StreamWeaverLanding module, so loading
# it once leaks nothing else into the test process.
RSpec.describe "examples/ide/streamweaver_landing.rb" do
  let(:section_ids) { %w[readme why features canvas install contributing] }

  before(:all) do
    unless defined?(StreamWeaverLanding)
      $VERBOSE, verbose = nil, $VERBOSE
      load File.expand_path("../../examples/ide/streamweaver_landing.rb", __dir__)
      $VERBOSE = verbose
    end
  end

  let(:html) do
    app = StreamWeaverLanding::APP
    state = {}
    app.rebuild_with_state(state)
    StreamWeaver::Views::AppView.new(app, state, StreamWeaver::Adapter::AlpineJS.new).call
  end

  def self.landing_page_examples
    it "has a section and a tab link for each file of the page" do
      section_ids.each do |name|
        expect(page_html).to include(%(id="#{name}"), %(data-sw-ide-target="#{name}"))
      end
    end

    it "renders the hero, the feature cards and the transcript from sw-ide-* hooks" do
      expect(page_html).to include("sw-ide-hero__title", "sw-ide-pill", "sw-ide-btn--primary",
                                   "sw-ide-card", "sw-ide-transcript__panel")
    end

    it "puts StreamWeaver content in the status bar and a theme toggle in the title bar" do
      statusbar = page_html[%r{<footer[^>]*sw-ide-statusbar.*?</footer>}m]
      expect(statusbar).to include("MIT", "StreamWeaver")
      expect(page_html).to include("sw-ide-titlebar__theme-toggle")
    end

    it "gives the install tabs plain word keys" do
      expect(page_html).to include("sw-tabs")
      %w[gem bundler source].each { |label| expect(page_html).to include(">#{label}<") }
    end
  end

  describe "standalone app" do
    let(:page_html) { html }

    landing_page_examples
  end

  describe "canvas push of the same body" do
    let(:result) do
      body = File.read(StreamWeaverLanding::BODY_PATH)
      StreamWeaver::Canvas::Bridge.new.send(:render_dsl, body, session_name: "landing")
    end
    let(:page_html) { result.html }

    it "evaluates without error and renders the shell" do
      expect(result.error).to be_nil
      expect(page_html).to include(%(class="sw-ide-shell"), %(class="sw-ide-tabstrip"))
    end

    landing_page_examples
  end
end
