# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/session'

# The panel groups comments by what the person can do (ready to send, with the
# agent, done) and folds finished work into rounds with one summary each.
RSpec.describe StreamWeaver::Canvas::NotesPanel, 'history' do
  let(:session) { StreamWeaver::Canvas::Session.new('plan') }

  def html = session.region('side')[:html]

  def note(text, **extra) = session.add_note({ text: text }.merge(extra))

  # round 1: two notes, replied; round 2: one note, replied; round 3: one note
  # with the agent; one more ready to send.
  before do
    note('a1')
    note('a2')
    session.send_queued
    session.reply('first <b>round</b>')
    note('b1')
    session.send_queued
    session.reply('second round')
    note('c1')
    session.send_queued
    note('d1')
  end

  it 'orders the groups: Ready to send, With the agent, then one Done row' do
    ready = html.index('Ready to send')
    agent = html.index('With the agent')
    done = html.index('sw-notes-done')
    expect([ready, agent, done]).to eq([ready, agent, done].sort)
    expect(html.scan('<details class="sw-notes-done"').size).to eq(1)
    expect(html).not_to match(/<details[^>]* open/)
  end

  it 'says Done: N comments in M rounds with correct plurals' do
    expect(html).to include('Done: 3 comments in 2 rounds')
    fresh = StreamWeaver::Canvas::Session.new('x')
    fresh.add_note(text: 'one')
    fresh.send_queued
    fresh.reply('ok')
    expect(fresh.region('side')[:html]).to include('Done: 1 comment in 1 round')
  end

  it 'lists rounds newest first, each with its own summary and comment count' do
    r2 = html.index('data-sw-round="2"')
    r1 = html.index('data-sw-round="1"')
    expect(r2).to be < r1
    expect(html).to include('second round').and include('(1 comment)').and include('(2 comments)')
  end

  it 'keeps every round summary, escaped, and the latest one near the top' do
    expect(html).to include('first &lt;b&gt;round&lt;/b&gt;')
    expect(html).not_to include('<b>round</b>')
    expect(html.index('Agent: second round')).to be < html.index('Ready to send')
  end

  it 'a Send does not wipe earlier summaries; one reply closing two rounds fills both' do
    # c1 (round 3) is in flight; send d1 as round 4, then one reply closes both
    session.send_queued
    session.reply('both done')
    expect(html).to include('first &lt;b&gt;round').and include('second round')
    expect(html.scan('both done').size).to be >= 3 # top line + rounds 3 and 4
    expect(html).to include('Done: 5 comments in 4 rounds')
  end

  it 'closes only in-flight rounds: round numbers are shared by notes sent together' do
    rounds = session.notes_snapshot.to_h { |n| [n[:text], n[:round]] }
    expect(rounds).to eq('a1' => 1, 'a2' => 1, 'b1' => 2, 'c1' => 3, 'd1' => nil)
  end

  it 'shows Send to Agent (N), disabled at zero, with the empty-state line' do
    expect(html).to include('Send to Agent (1)')
    session.send_queued
    expect(html).to include('Send to Agent (0)').and include('Click anything on the page to leave a comment')
    expect(html).to match(/<button[^>]*disabled[^>]*>Send to Agent \(0\)/)
  end

  it 'keeps numbers stable: a comment keeps its id as its number, even after a removal' do
    session.remove_note(5)
    expect(html).to include('<span class="sw-card-n">4</span>')
    note('late')
    expect(html).to include('<span class="sw-card-n">6</span>')
  end

  it 'the page swaps regions through the before and after hooks in the same task' do
    server = File.read(File.join(__dir__, '../../lib/stream_weaver/canvas/bridge_server.rb'))
    expect(server).to include('window.swRegionBefore(name)').and include('window.swRegionSwapped(name, kept)')
    expect(server.index('window.swRegionBefore(name)')).to be < server.index('el.innerHTML = r.html')
    expect(server.index('el.innerHTML = r.html')).to be < server.index('window.swRegionSwapped(name, kept)')
  end

  it 'the pinned footer holds only the two buttons; hint and legend live in a collapsed help row at the end of the list' do
    foot = html[html.index('class="sw-notes-foot"')..]
    expect(foot).to include('Send to Agent (1)').and include('Send &amp; End')
    expect(foot).not_to include('hint')
    expect(foot).to include('title="Send these and keep reviewing"')
    expect(foot).not_to include('Dashed outline')
    help = html[/<details class="sw-notes-help"[^>]*>.*?<\/details>/m]
    expect(help).not_to include(' open')
    expect(help).to include('How this works').and include('Send to Agent: send these').and include('Dashed outline: hover preview')
    expect(html.index('sw-notes-help')).to be > html.index('sw-notes-done')
    expect(html.index('sw-notes-help')).to be < html.index('class="sw-notes-foot"')
  end

  it 'done cards keep the .sw-card hooks and have no Edit or Remove' do
    expect(html.scan('data-sw-state="done"').size).to eq(3)
    done_html = html[html.index('sw-notes-done')..]
    expect(done_html).not_to include('data-sw-action="edit"')
    expect(done_html).to include('class="sw-card sw-compact"')
  end
end
