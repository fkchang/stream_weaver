# frozen_string_literal: true

# `tabs lazy: true` is deprecated in favour of route tabs (and an eventual lazy
# route-tab mode). The warning is the ONLY behaviour change -- everything else
# here locks the mode as it shipped, so the deprecation cannot quietly become a
# removal.
RSpec.describe 'lazy tabs deprecation' do
  # The warning latches once per process, so every example re-arms it rather
  # than depending on which spec file ran first.
  before { StreamWeaver::App.lazy_tabs_deprecation_warned = false }
  after { StreamWeaver::App.lazy_tabs_deprecation_warned = false }

  def build(**tabs_options)
    StreamWeaver::App.new('lazy tabs spec') do
      tabs(:nav, **tabs_options) do
        tab('Alpha') { text 'alpha panel' }
        tab('Beta') { text 'beta panel' }
      end
    end.tap { |app| app.rebuild_with_state({}) }
  end

  # `warn` writes to $stderr; swapping it keeps spec output pristine and lets
  # the warning be asserted on.
  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end

  # Renders the group on its own, from the app's own state -- same shape as
  # spec/adapter/route_tabs_spec.rb.
  def render(app)
    component = app.components.last
    adapter = StreamWeaver::Adapter::AlpineJS.new
    state = app.state

    Class.new(Phlex::HTML) do
      define_method(:adapter) { adapter }
      define_method(:view_template) { component.render(self, state) }
    end.new.call
  end

  describe 'the warning' do
    it 'fires for a lazy tabs group and names route tabs as the direction' do
      output = capture_stderr { build(lazy: true) }

      expect(output).to include('lazy: true is deprecated')
      expect(output).to include('url: true')
      expect(output).to include('lazy route tabs')
      expect(output).to include('stream_weaver-pkh')
    end

    it 'fires once per process, not once per render' do
      output = capture_stderr do
        3.times { build(lazy: true) }
      end

      expect(output.scan('lazy: true is deprecated').size).to eq(1)
    end

    it 'stays silent for plain tabs' do
      expect(capture_stderr { build }).to eq('')
    end

    it 'stays silent for route tabs' do
      expect(capture_stderr { build(url: true) }).to eq('')
    end
  end

  describe 'behaviour is unchanged (compat lock)' do
    # Pre-latched: these examples are about the mode, not the notice, and a
    # real warning here would just noise up the suite's output.
    before { StreamWeaver::App.lazy_tabs_deprecation_warned = true }

    it 'still evaluates only the active tab block' do
      evaluated = []
      app = StreamWeaver::App.new('lazy tabs spec') do
        tabs(:nav, lazy: true) do
          tab('Alpha') { evaluated << :alpha }
          tab('Beta') { evaluated << :beta }
        end
      end
      app.rebuild_with_state({ nav: 1 })

      expect(evaluated).to eq([:beta])
    end

    it 'still renders the inactive panel as a placeholder comment' do
      html = render(build(lazy: true))

      expect(html).to include('alpha panel')
      expect(html).to include('<!-- lazy: tab 1 not rendered -->')
      expect(html).not_to include('beta panel')
    end

    it 'still emits the POST-morph attributes on every tab trigger' do
      html = render(build(lazy: true))

      # Both triggers, not just one: the whole point of the mode is that the
      # inactive tab is the one that has to fetch itself.
      expect(html.scan('hx-post="/update"').size).to eq(2)
      expect(html).to include('hx-vals="{&quot;nav&quot;:0}"')
      expect(html).to include('hx-vals="{&quot;nav&quot;:1}"')
      expect(html.scan('hx-include="[x-model]"').size).to eq(2)
      expect(html.scan('hx-target="#app-container"').size).to eq(2)
      expect(html.scan('hx-swap="morph:innerHTML"').size).to eq(2)
    end

    it 'still syncs the active index back through the hidden input' do
      html = render(build(lazy: true))

      expect(html).to include('<input type="hidden" name="nav" x-model="activeTab">')
    end
  end
end
