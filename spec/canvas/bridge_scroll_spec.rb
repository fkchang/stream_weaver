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
end
