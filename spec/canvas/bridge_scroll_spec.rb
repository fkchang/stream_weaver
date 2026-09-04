# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/bridge_server'

RSpec.describe 'BridgeServer#polling_script auto-scroll (round-7 UAT)' do
  subject(:js) { StreamWeaver::Canvas::BridgeServer.new!.send(:polling_script, 'doc-demo', 1) }

  it 'captures whether the viewer was near the bottom BEFORE the content swap' do
    before_swap, swap = js.split('container.innerHTML = data.html;', 2)
    expect(before_swap).to include('wasNearBottom')
    expect(swap).not_to be_nil
  end

  it 'scrolls to the bottom only when the viewer was already there' do
    expect(js).to include("if (wasNearBottom)")
    expect(js).to include("window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'smooth' });")
  end

  it 'never yanks a scrolled-up viewer -- the scroll call is gated on the guard, not unconditional' do
    scroll_call_index = js.index("window.scrollTo({ top: document.documentElement.scrollHeight")
    guard_index = js.index('if (wasNearBottom)')
    expect(guard_index).to be < scroll_call_index
  end

  # Round-9 UAT: a full page reshape (the completion recap the moment the
  # last step is marked done) must not inherit the "follow the viewer's own
  # near-bottom scroll" behavior above -- it built for a growing doc
  # continuing in place, not a page that just became a different shape.
  #
  # Every assertion below reads the marker id off
  # StreamWeaver::Canvas::SCROLL_TOP_HINT_ID rather than a
  # literal, the same constant Listener::SCROLL_TOP_HINT_DSL interpolates --
  # a renamed id fails this suite instead of leaving the two ends silently
  # out of sync.
  describe 'scroll-to-top hint' do
    let(:marker_selector) { "##{StreamWeaver::Canvas::SCROLL_TOP_HINT_ID}" }

    it 'looks for the marker in the SWAPPED-IN html, not the old page' do
      before_query, after_query = js.split("const scrollToTop = !!container.querySelector('#{marker_selector}');", 2)
      expect(after_query).not_to be_nil
      expect(before_query).to include('container.innerHTML = data.html;')
    end

    it 'scrolls to the top, unconditionally, when the marker is present' do
      expect(js).to include('if (scrollToTop)')
      expect(js).to include("window.scrollTo({ top: 0, behavior: 'auto' });")
    end

    it 'takes priority over the near-bottom follow so a reshaped page never falls through to it' do
      top_branch = js.index('if (scrollToTop)')
      bottom_branch = js.index(/\}\s*else\s+if\s*\(wasNearBottom\)/)
      expect(top_branch).not_to be_nil
      expect(bottom_branch).not_to be_nil
      expect(top_branch).to be < bottom_branch
    end
  end
end
