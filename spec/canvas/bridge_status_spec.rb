# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

# Per-comment status (canvas-annotate-review): queued, sent, seen, working
# (the doc was re-pushed), done (the agent replied with a one-line summary).
RSpec.describe 'canvas comment status and summary' do
  include Rack::Test::Methods

  def app = StreamWeaver::Canvas::BridgeServer

  let(:server) { StreamWeaver::Canvas::BridgeServer }
  let(:bridge) { server.bridge }
  let(:session) { bridge.get_session('plan') }

  around do |ex|
    prev_bridge = server.bridge
    prev_conns = server.claude_connections
    server.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      server.bridge = prev_bridge
      server.claude_connections = prev_conns
    end
  end

  before do
    bridge.create_session('plan')
    session.add_note(text: 'fix the title')
  end

  def states = session.notes_snapshot.map { |n| n[:state] }

  def side_html = session.region('side')[:html]

  def push(dsl = 'text "v2"') = bridge.handle_claude_message(type: 'push', name: 'plan', dsl: dsl)

  def reply(summary) = bridge.handle_claude_message(type: 'notes_reply', name: 'plan', summary: summary)

  it 'walks queued, sent, seen, working, done' do
    expect(states).to eq(%w[queued])
    session.send_queued
    expect(states).to eq(%w[sent])
    session.wait_for_submit(timeout: 1)
    expect(states).to eq(%w[seen])
    expect(push[:type]).to eq('push_ok')
    expect(states).to eq(%w[working])
    expect(reply('Retitled the page')).to include(type: 'notes_replied', done: 1)
    expect(states).to eq(%w[done])
    expect(side_html).to include('Done')
  end

  it 'a re-push before Send leaves queued comments queued and shows no update marker' do
    push
    expect(states).to eq(%w[queued])
    expect(side_html).not_to include('Doc updated')
  end

  it 'a failed render does not count as the doc being updated' do
    session.send_queued
    session.wait_for_submit(timeout: 1)
    expect(push('raise "boom"')[:type]).to eq('push_error')
    expect(states).to eq(%w[seen])
    expect(side_html).not_to include('Doc updated')
  end

  it 'shows a panel-level Doc updated marker after a re-push of a sent batch (block accent is descoped)' do
    session.send_queued
    push
    expect(side_html).to include('Doc updated just now')
  end

  it 'the next Send starts a new round: the marker clears and the earlier summary is kept' do
    session.send_queued
    push
    reply('done it')
    session.add_note(text: 'another')
    session.send_queued
    expect(side_html).not_to include('Doc updated')
    expect(side_html).to include('done it')
  end

  it 'shows the agent summary as escaped plain text' do
    session.send_queued
    reply('<img src=x onerror=alert(1)> **bold** & done')
    expect(side_html).to include('Agent: &lt;img src=x onerror=alert(1)&gt; **bold** &amp; done')
    expect(side_html).not_to include('<img')
  end

  it 'keeps the summary to one line and caps its length' do
    session.send_queued
    reply("line one\nline two\n#{'x' * 900}")
    summary = side_html[%r{sw-notes-summary">(.*?)</p>}m, 1]
    expect(summary).not_to include("\n")
    expect(summary.length).to be <= 'Agent: '.length + 500
  end

  it 'replying marks only in-flight comments done, not queued ones' do
    session.send_queued
    session.add_note(text: 'later')
    reply('ok')
    expect(states).to eq(%w[done queued])
  end

  it 'reply for an unknown canvas is an error' do
    expect(bridge.handle_claude_message(type: 'notes_reply', name: 'nope', summary: 'x')[:type]).to eq('error')
  end

  it 'the summary and statuses reach a reloaded page' do
    session.send_queued
    reply('all good')
    get '/canvas/plan'
    expect(last_response.body[%r{<aside data-sw-region="side">.*?</aside>}m]).to include('Agent: all good', 'Done')
  end
end
