# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/session'

# The side region: pinned header and Send footer around a scrolling body,
# comment cards with number, state, context line, and the Send hint.
RSpec.describe StreamWeaver::Canvas::NotesPanel do
  let(:session) { StreamWeaver::Canvas::Session.new('plan') }
  def html = session.region('side')[:html]

  before do
    session.add_note(text: 'make <b>bold</b>', tag: 'td', kind: 'table', element_text: 'Platform team',
                     breadcrumb: 'Summary > Results')
    session.add_note(text: 'second', kind: 'p', element_text: 'x' * 100)
  end

  it 'pins the header and the Send buttons outside the scrolling body' do
    head = html.index('sw-notes-head')
    body = html.index('sw-notes-body')
    foot = html.index('sw-notes-foot')
    expect(head).to be < body
    expect(body).to be < foot
    expect(html.index('data-sw-action="send"')).to be > foot
    expect(html.index('class="sw-notes-list"')).to be < foot
  end

  it 'draws each comment as a numbered card with a state label and a context line' do
    expect(html.scan('class="sw-card"').size).to eq(2)
    expect(html).to include('<span class="sw-card-n">1</span>').and include('<span class="sw-card-n">2</span>')
    expect(html).to include('Queued')
    expect(html).to include('td: Platform team | Summary &gt; Results').or include('td: Platform team | Summary > Results')
    expect(html).to include("p: #{'x' * 40}<").or include("p: #{'x' * 40} ")
    expect(html[/class="sw-notes-ctx">p: [^<]*/]).to eq("class=\"sw-notes-ctx\">p: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
  end

  it 'escapes viewer text in the comment and the context line' do
    session.add_note(text: 'ok', tag: 'td', element_text: '<img src=x onerror=alert(1)>', breadcrumb: '<script>x</script>')
    expect(html).to include('make &lt;b&gt;bold&lt;/b&gt;')
    expect(html).not_to include('<b>bold</b>')
    expect(html).to include('&lt;img src=x onerror=alert(1)&gt;')
    expect(html).not_to include('>alert(1)<')
    expect(html).to include('&lt;script&gt;x&lt;/script&gt;')
  end

  it 'says in plain words what Send and Send & End do' do
    expect(html).to include('Send to Agent: send these and keep reviewing.')
    expect(html).to include('Send &amp; End: send these and tell the agent the review is over; this page stays open.')
  end

  it 'a new comment after Send & End starts a fresh review, banner and unread end flag included' do
    session.send_queued(end_review: true)
    expect(html).to include('Review ended')
    session.add_note(text: 'again')
    expect(html).not_to include('Review ended')
    expect(session.wait_for_submit(timeout: 1)).to include(ended: false)
  end

  it 'ships badge, edit and hint pieces in the overlay script' do
    js = File.read(File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-canvas-notes.js'))
    expect(js).to include('sw-badge').and include('sw-edit-row').and include('input.select()')
    expect(js).to include('border-radius:8px').and include('flex-direction:column')
    expect(js).not_to match(/\.sw-card\{[^}]*999px/)
  end
end
