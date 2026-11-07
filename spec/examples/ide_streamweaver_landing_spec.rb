# frozen_string_literal: true

# The landing page example is the proof that the ide_* components compose:
# it has to render, and carry its sections, tabs and install tabs.
RSpec.describe "examples/ide/streamweaver_landing.rb" do
  let(:html) do
    path = File.expand_path("../../examples/ide/streamweaver_landing.rb", __dir__)
    quietly { load path }
    app = Object.const_get(:App)
    state = {}
    app.rebuild_with_state(state)
    StreamWeaver::Views::AppView.new(app, state, StreamWeaver::Adapter::AlpineJS.new).call
  ensure
    %i[App DSL_SAMPLE PUSH_SCRIPT FEATURES WHY_BEATS].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
  end

  def quietly
    verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = verbose
  end

  it "has one tab and one section per file of the page" do
    %w[readme why features canvas install contributing].each do |name|
      expect(html).to include(%(id="#{name}"))
    end
    expect(html.scan(%(class="sw-ide-tab")).size).to eq(6)
  end

  it "renders the hero, the feature cards and the transcript from sw-ide-* hooks" do
    expect(html).to include("sw-ide-hero__title", "sw-ide-pill", "sw-ide-btn--primary")
    expect(html.scan(%(class="sw-ide-card")).size).to eq(6)
    expect(html).to include("sw-ide-transcript__panel")
  end

  it "puts StreamWeaver content in the status bar and a theme toggle in the title bar" do
    expect(html).to include("MIT", "StreamWeaver", "sw-ide-titlebar__theme-toggle")
  end

  it "gives the install tabs plain word keys" do
    expect(html).to include("sw-tabs")
    %w[gem bundler source].each { |label| expect(html).to include(">#{label}<") }
  end
end
