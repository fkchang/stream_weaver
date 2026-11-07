# frozen_string_literal: true

# The landing page example is the proof that the ide_* components compose:
# it has to render, and carry its sections, tabs and install tabs. The
# example keeps everything inside the StreamWeaverLanding module, so loading
# it once leaks nothing else into the test process.
RSpec.describe "examples/ide/streamweaver_landing.rb" do
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

  it "has a section and a tab link for each file of the page" do
    %w[readme why features canvas install contributing].each do |name|
      expect(html).to include(%(id="#{name}"), %(data-sw-ide-target="#{name}"))
    end
  end

  it "renders the hero, the feature cards and the transcript from sw-ide-* hooks" do
    expect(html).to include("sw-ide-hero__title", "sw-ide-pill", "sw-ide-btn--primary",
                            "sw-ide-card", "sw-ide-transcript__panel")
    expect(StreamWeaverLanding::FEATURES).not_to be_empty
  end

  it "puts StreamWeaver content in the status bar and a theme toggle in the title bar" do
    statusbar = html[%r{<footer[^>]*sw-ide-statusbar.*?</footer>}m]
    expect(statusbar).to include("MIT", "StreamWeaver")
    expect(html).to include("sw-ide-titlebar__theme-toggle")
  end

  it "gives the install tabs plain word keys" do
    expect(html).to include("sw-tabs")
    %w[gem bundler source].each { |label| expect(html).to include(">#{label}<") }
  end
end
