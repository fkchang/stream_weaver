# frozen_string_literal: true

require 'rack/test'
require 'tmpdir'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/reader'

# The four documents a StreamWeaver author can actually put in front of a
# reader, built the way production builds them.
#
# The compatibility matrix (docs/research/frontend-only-matrix.md) is written in
# terms of three backend-less contexts -- A live canvas, B canvas-read, C
# exported HTML -- plus the http-mode baseline they are all compared against.
# Every claim in that matrix, and every piece of advice docs/frontend-only.md
# builds on top of it, is a claim about one of these four documents. So this is
# where the matrix meets running code: not adapter options in isolation, but the
# whole delivered page, rendered by the same view the real server renders.
#
# Why the whole page and not just the component markup: the two invariants that
# bite hardest are pairings between the body and the <head> -- markup that calls
# sendEvent needs the bridge script that defines it, and an hx-post is only
# dangerous if htmx was shipped alongside it. Neither is visible from either
# half alone.
module Compat
  MATRIX_DOC = 'docs/research/frontend-only-matrix.md'
  ADVICE_DOC = 'docs/frontend-only.md'

  # Every delivery context, named once. Kept here rather than restated in the
  # spec so a fifth context is one line and not a hunt through example groups
  # for the lists that forgot to grow.
  NAMES          = %i[standalone canvas reader export].freeze
  BACKEND_LESS   = (NAMES - %i[standalone]).freeze
  WITHOUT_BRIDGE = (BACKEND_LESS - %i[canvas]).freeze

  # @!attribute name
  #   which of NAMES this is
  # @!attribute document
  #   the full page as delivered, <head> included
  # @!attribute body
  #   just the component markup the DSL produced, as that context's renderer
  #   returns it -- the region a matrix row is actually talking about
  # @!attribute adapter
  #   an adapter configured the way that context configures its own, for
  #   asking what the context declares about itself (deck_read_only?, ...)
  # @!attribute matrix_column
  #   the matrix's own name for this context. The `uphold` matcher prints it,
  #   so a failure says "B (canvas-read)" and not "the second one".
  Context = Struct.new(:name, :document, :body, :adapter, :matrix_column, keyword_init: true)

  # DSL fixtures. Each is a string because that is what the canvas is pushed
  # and what the reader is pointed at -- one source of truth per fixture,
  # rendered four ways, is the only way a per-context difference is a real
  # difference and not a difference in how the spec built the app.
  FIXTURES = {
    # Broad enough that every method in spec/canvas/htmx_call_site_sweep_spec.rb's
    # ledger renders here, in the shape that reaches htmx_attrs. That shape
    # matters: a text_field written inside a `form` block takes the adapter's
    # "Inside form: use form-scoped x-model, no HTMX" branch and never touches
    # htmx_attrs at all, so a fixture that only had the form version would pin
    # a set of hx-* attributes with most of the emitters missing from it.
    gallery: <<~RUBY,
      action(:open_row) { nil }
      header1 'Compatibility Gallery'
      text 'Flat prose survives every context.'
      code_block "puts 'hi'", language: 'ruby'
      bar_chart labels: %w[A B], values: [1, 2]
      button 'Go'
      radio_group :size, %w[S M]
      tag_buttons :reason, ['Too dark']
      chip_group :langs, %w[ruby js]
      clickable(action: :open_row, key: 'r1') { text 'Row' }
      dropdown { menu { menu_item('Archive') { nil } } }
      text_field :city
      text_area :notes
      date_field :due
      checkbox :subscribe, 'Subscribe'
      select :color, %w[red blue]
      checkbox_group(:fruits) { item('apple') { text 'Apple' } }
      external_link_button 'Open', url: 'https://example.com', submit: true
      form(:contact) do
        text_field :contact_city
        submit 'Send'
      end
    RUBY

    # No interactivity at all: the matrix's "flat content survives everywhere"
    # baseline, and the negative case for the chart-library gate.
    flat: <<~RUBY,
      header1 'Flat'
      text 'Nothing here needs a backend.'
      table headers: %w[Name Count], rows: [%w[a 1]]
    RUBY

    # Charts are their own gate (disc-094) and their own matrix row.
    chart: <<~RUBY,
      header1 'Charts'
      bar_chart labels: %w[A B], values: [1, 2]
      pie_chart labels: %w[A B], values: [1, 2]
    RUBY

    # The deck is the one component family that calls server-only routes from
    # inlined JS rather than from attributes (M7).
    deck: <<~RUBY
      design_deck 'Design' do
        slide 'arch', 'Architecture' do
          option('Monolith') { text 'Simple' }
          option('Microservices') { text 'Complex' }
        end
      end
    RUBY
  }.freeze

  class << self
    # All four contexts for a fixture, built once per process. Building costs
    # four full renders plus two Rack::Test round trips, and every example
    # below reads the same documents, so memoizing is the difference between a
    # suite that runs with the others and one nobody waits for.
    def contexts(fixture)
      @contexts ||= {}
      @contexts[fixture] ||= NAMES.to_h { |name| [name, send(name, FIXTURES.fetch(fixture))] }
    end

    def context(fixture, name)
      contexts(fixture).fetch(name)
    end

    # An App built from a fixture, for the questions that are about components
    # rather than markup ("does this app contain a chart at all").
    def app(fixture)
      @apps ||= {}
      @apps[fixture] ||= app_from(FIXTURES.fetch(fixture))
    end

    private

    # The http baseline: what Server#render_app serves for a full GET.
    def standalone(dsl)
      built = app_from(dsl)
      adapter = StreamWeaver::Adapter::AlpineJS.new
      Context.new(
        name: :standalone,
        document: StreamWeaver::Views::AppView.new(built, {}, adapter, false).call,
        body: StreamWeaver::Views::AppContentView.new(built, {}, adapter, false).call,
        adapter: adapter,
        matrix_column: 'the http baseline'
      )
    end

    # Context A: pushed through the real bridge (the same handle_claude_message
    # the CLI sends) and fetched back off the real canvas route, so the <head>
    # is the bridge's own and not a restatement of it.
    def canvas(dsl)
      bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      previous = StreamWeaver::Canvas::BridgeServer.bridge
      StreamWeaver::Canvas::BridgeServer.bridge = bridge

      bridge.handle_claude_message(type: 'create', name: 'compat')
      pushed = bridge.handle_claude_message(type: 'push', name: 'compat', dsl: dsl)
      raise "the canvas refused the fixture: #{pushed.inspect}" unless pushed[:type] == 'push_ok'

      Context.new(
        name: :canvas,
        document: get(StreamWeaver::Canvas::BridgeServer, '/canvas/compat'),
        body: bridge.get_session('compat').html,
        adapter: StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/compat', mode: :websocket),
        matrix_column: 'A (live canvas)'
      )
    ensure
      StreamWeaver::Canvas::BridgeServer.bridge = previous
    end

    # Context B: the render-only reader, driven through its real route.
    def reader(dsl)
      document = nil
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'doc.rb'), dsl)
        StreamWeaver::Canvas::Reader.configure_files!(StreamWeaver::Canvas::Reader::FileList.build([dir]))
        StreamWeaver::Canvas::Reader.configure_defaults!(theme: nil, layout: nil)
        begin
          document = get(StreamWeaver::Canvas::Reader, '/?file=0')
        ensure
          # The reader's file list and theme defaults are class-level state
          # shared with every other reader spec. Cleared rather than restored,
          # same as those specs do: the tmpdir this list points at is about to
          # be deleted, so putting anything back would just hand the next spec
          # a list of files that no longer exist.
          StreamWeaver::Canvas::Reader.configure_files!(nil)
          StreamWeaver::Canvas::Reader.configure_defaults!(theme: nil, layout: nil)
        end
      end

      Context.new(
        name: :reader,
        document: document,
        body: StreamWeaver::Canvas::Reader.render_doc(dsl).html,
        adapter: StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/reader', mode: :websocket, inert: true),
        matrix_column: 'B (canvas-read)'
      )
    end

    # Context C: a real export. Document and body are the same string here --
    # an export has no chrome around the doc, which is the whole point of it.
    def export(dsl)
      html = StreamWeaver::Export::HtmlExporter.new(app_from(dsl)).to_html
      Context.new(
        name: :export,
        document: html,
        body: html,
        adapter: StreamWeaver::Adapter::AlpineJS.new(deck_server: false),
        matrix_column: 'C (exported HTML)'
      )
    end

    # Built with the block form on purpose: App#rebuild_with_state re-runs the
    # constructor block, so an app assembled by instance_eval'ing the DSL
    # *after* construction loses every component the moment anything rebuilds
    # it. Exporting one of those silently produces a document with no content
    # and no error.
    def app_from(dsl)
      StreamWeaver::App.new('Compat') { instance_eval(dsl) }.tap { |a| a.rebuild_with_state({}) }
    end

    # Both servers answer 200 for a doc that failed to render -- the reader
    # turns a DSL error into a red <div> and serves it happily. A fixture that
    # stopped parsing would therefore produce a document with no controls in
    # it, and every "must not contain" invariant below would pass on emptiness.
    # Silent, permanent, vacuous green, so both failures are raised here.
    def get(server, path)
      session = Rack::Test::Session.new(Rack::MockSession.new(server, '127.0.0.1'))
      session.get(path)
      raise "#{server} answered #{session.last_response.status} for #{path}" unless session.last_response.ok?

      body = session.last_response.body
      raise "#{server} could not render the fixture: #{body[/DSL error:.{0,300}/m]}" if body.include?('DSL error:')

      body
    end
  end
end
