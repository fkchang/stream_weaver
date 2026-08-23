# frozen_string_literal: true

require 'spec_helper'

# The dead-on-canvas bugs (disc-097) were all the same shape: a component called
# htmx_attrs without ever asking what mode it was in, so it shipped an hx-post
# to a route the canvas bridge does not serve. Nothing caught it because no spec
# knew the set of call sites existed.
#
# This sweep is that spec. It reads every htmx_attrs call site out of the adapter
# source and refuses to pass unless each one is declared below with its
# websocket-mode behavior -- so a new component cannot join the dead list
# silently. Adding a call site is a two-line change here; deciding what it should
# do on canvas is the point of being made to make it.
RSpec.describe 'htmx_attrs call site sweep' do
  ADAPTER_SOURCE = File.expand_path('../../lib/stream_weaver/adapter/alpinejs.rb', __dir__)

  # :sendEvent -- ported: dispatches through the bridge, inert in the reader.
  # :htmx      -- still posts on canvas. Harmless in practice only because these
  #               are state syncs whose values getFormState re-harvests at action
  #               time; each one is still a 404 per keystroke/change. Tracked as
  #               disc-106, which also names external_link_button as the one that
  #               loses real work rather than just noise.
  CALL_SITES = {
    'render_text_field' => { canvas: :htmx, app: -> { text_field :city } },
    'render_text_area' => { canvas: :htmx, app: -> { text_area :notes } },
    'render_date_field' => { canvas: :htmx, app: -> { date_field :due } },
    'render_checkbox' => { canvas: :htmx, app: -> { checkbox :subscribe, 'Subscribe' } },
    'render_select' => { canvas: :htmx, app: -> { select :color, %w[red blue] } },
    'render_checkbox_group' => {
      canvas: :htmx,
      app: -> { checkbox_group(:fruits) { item('apple') { text 'Apple' } } }
    },
    'render_external_link_button' => {
      canvas: :htmx,
      app: -> { external_link_button 'Open', url: 'https://example.com', submit: true }
    },
    'render_radio_group' => { canvas: :sendEvent, app: -> { radio_group :size, %w[S M] } },
    'button_attrs' => { canvas: :sendEvent, app: -> { button 'Go' } },
    'clickable_dispatch_attrs' => {
      canvas: :sendEvent,
      app: -> do
        action(:open_row) { nil }
        clickable(action: :open_row, key: 'r1') { text 'Row' }
      end
    },
    'menu_item_dispatch_attrs' => {
      canvas: :sendEvent,
      app: -> { dropdown { menu { menu_item('Archive') { nil } } } }
    },
    'form_submit_dispatch_attrs' => {
      canvas: :sendEvent,
      app: -> do
        form(:contact) do
          text_field :city
          submit 'Send'
        end
      end
    },
    'tag_button_dispatch_attrs' => { canvas: :sendEvent, app: -> { tag_buttons :reason, ['Too dark'] } },
    'chip_group_dispatch_attrs' => { canvas: :sendEvent, app: -> { chip_group :langs, %w[ruby js] } }
  }.freeze

  # The enclosing `def` of every htmx_attrs call in the adapter. Indentation is
  # the method marker because the adapter is one long class body.
  #
  # Textual, and therefore approximate: it would miss a call built by
  # metaprogramming or a `def` at another depth, and would count a mention of
  # htmx_attrs( inside a comment. That is an accepted limit -- the failure
  # message below is explicit enough that a wrong result is diagnosed in
  # seconds, and the alternative (no ledger at all) is what produced disc-097.
  def self.call_site_methods
    enclosing = nil

    File.readlines(ADAPTER_SOURCE).filter_map do |line|
      enclosing = Regexp.last_match(1) if line =~ /^\s{6}def (\w+[?!]?)/
      enclosing if line.include?('htmx_attrs(') && !line.include?('def htmx_attrs')
    end.uniq
  end

  def render(app, **adapter_options)
    adapter = StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/abc', **adapter_options)
    StreamWeaver::Views::AppContentView.new(app, app.state, adapter, false).call
  end

  # App.new only stores its block; rebuild_with_state is what evaluates it.
  def build(entry)
    StreamWeaver::App.new('sweep', &entry[:app]).tap { |app| app.rebuild_with_state({}) }
  end

  it 'declares every htmx_attrs call site in the adapter' do
    expect(self.class.call_site_methods.sort).to eq(CALL_SITES.keys.sort),
      "Every method that calls htmx_attrs must declare what it does in websocket mode.\n" \
      "Undeclared (new call sites -- decide sendEvent vs honest degrade, then add them here): " \
      "#{(self.class.call_site_methods - CALL_SITES.keys).sort.inspect}\n" \
      "Stale (declared but no longer call htmx_attrs -- drop them here): " \
      "#{(CALL_SITES.keys - self.class.call_site_methods).sort.inspect}"
  end

  CALL_SITES.select { |_, entry| entry[:canvas] == :sendEvent }.each_key do |method|
    context "#{method} (ported to sendEvent)" do
      it 'posts nothing on live canvas' do
        expect(render(build(CALL_SITES[method]), mode: :websocket)).not_to include('hx-post')
      end

      it 'dispatches through the bridge on live canvas' do
        expect(render(build(CALL_SITES[method]), mode: :websocket)).to include('sendEvent(')
      end

      it 'degrades honestly in the reader' do
        html = render(build(CALL_SITES[method]), mode: :websocket, inert: true)

        expect(html).not_to include('sendEvent')
        expect(html).not_to include('hx-post')
        expect(html).to include('title="Interactive on live canvas only"')
      end
    end
  end

  # Characterization, not endorsement: these still post on canvas. Pinning it
  # means the list can only shrink on purpose, and whoever shrinks it has to
  # come here and say so.
  CALL_SITES.select { |_, entry| entry[:canvas] == :htmx }.each_key do |method|
    it "#{method} still posts on live canvas (known, tracked)" do
      expect(render(build(CALL_SITES[method]), mode: :websocket)).to include('hx-post="/canvas/abc/')
    end
  end
end
