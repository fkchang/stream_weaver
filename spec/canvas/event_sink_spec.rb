# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'timeout'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/event_sinks'

# canvas_event_sink (story: canvas-event-sink): an installed extension may register a sink; a canvas
# session whose reply_to is "<extension id>:<payload>" has its browser events handed to that sink,
# off the request thread, without ever changing what the browser or a waiting agent sees.
RSpec.describe 'canvas_event_sink' do
  around do |example|
    StreamWeaver::Extensions.reset!
    example.run
  ensure
    StreamWeaver::Extensions.reset!
  end

  # The threads started while the block runs. Dispatch decides synchronously whether a sink runs and
  # starts one thread if so, so "no thread" proves "no sink call" without waiting on a clock.
  def spawned_threads
    before = Thread.list
    yield
    Thread.list - before
  end

  describe 'extension registration' do
    it 'stores a callable sink and returns it by extension id' do
      sink = ->(_ctx) {}
      StreamWeaver.register_extension(:relay, canvas_event_sink: sink)
      expect(StreamWeaver::Extensions.canvas_event_sink_for('relay')).to be(sink)
      expect(StreamWeaver::Extensions.canvas_event_sink_for(:relay)).to be(sink)
    end

    it 'returns nil for an unknown extension and for one registered without a sink' do
      StreamWeaver.register_extension(:plain)
      expect(StreamWeaver::Extensions.canvas_event_sink_for('plain')).to be_nil
      expect(StreamWeaver::Extensions.canvas_event_sink_for('nope')).to be_nil
    end

    it 'rejects a sink that is not callable' do
      expect { StreamWeaver.register_extension(:bad, canvas_event_sink: 'nope') }
        .to raise_error(StreamWeaver::Extensions::InvalidSinkError, /call/)
    end

    it 'keeps the one-registration-per-id rule' do
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(_) {})
      expect { StreamWeaver.register_extension(:relay, canvas_event_sink: ->(_) {}) }
        .to raise_error(StreamWeaver::Extensions::DuplicateRegistrationError)
    end
  end

  describe StreamWeaver::Canvas::EventSinks do
    let(:log) { [] }
    let(:logger) { ->(line) { log << line } }
    let(:message) { { type: 'event', name: 'c1', event: 'action', data: { type: 'action', button: 'btn_go_1', state: { a: 1 } } } }
    let(:pushed) { [] }
    let(:pusher) { ->(dsl) { pushed << dsl } }

    def dispatch(reply_to)
      described_class.dispatch(name: 'c1', reply_to: reply_to, message: message, state: { a: 1 }, pusher: pusher, logger: logger)
    end

    it 'calls the named extension sink with a context carrying everything it needs' do
      got = Queue.new
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(ctx) { got << ctx })
      dispatch('relay:some:payload')
      ctx = Timeout.timeout(2) { got.pop }
      expect(ctx.name).to eq('c1')
      expect(ctx.extension_id).to eq('relay')
      expect(ctx.payload).to eq('some:payload') # split on the FIRST colon only
      expect(ctx.event).to eq(message)
      expect(ctx.state).to eq(a: 1)
      ctx.push('header1 "Hi"')
      expect(pushed).to eq(['header1 "Hi"'])
    end

    it 'runs the sink off the calling thread, so dispatch returns while the sink is still working' do
      release = Queue.new
      finished = Queue.new
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(_) { release.pop; finished << true })
      Timeout.timeout(2) { dispatch('relay:x') } # would hang here if the sink ran inline
      expect(finished).to be_empty
      release << true
      Timeout.timeout(2) { finished.pop }
    end

    it 'logs and swallows a sink that raises' do
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(_) { raise 'sink blew up' })
      threads = spawned_threads { expect { dispatch('relay:x') }.not_to raise_error }
      threads.each(&:join)
      expect(log.size).to eq(1)
      expect(log.first).to include('c1').and include('relay').and include('sink blew up')
    end

    it 'does nothing at all when reply_to is nil or blank' do
      called = []
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(c) { called << c })
      expect(spawned_threads { dispatch(nil); dispatch('  ') }).to be_empty
      expect(called).to be_empty
      expect(log).to be_empty
    end

    it 'logs one line, and nothing else, when reply_to names an extension with no sink' do
      StreamWeaver.register_extension(:plain)
      expect(spawned_threads { dispatch('plain:x'); dispatch('ghost:x') }).to be_empty
      expect(log.size).to eq(2)
      expect(log.last).to include('ghost').and include('no canvas_event_sink')
    end

    it 'routes only to the named extension' do
      mine = []
      other = []
      StreamWeaver.register_extension(:mine, canvas_event_sink: ->(c) { mine << c })
      StreamWeaver.register_extension(:other, canvas_event_sink: ->(c) { other << c })
      spawned_threads { dispatch('mine:x') }.each(&:join)
      expect(mine.size).to eq(1)
      expect(other).to be_empty
    end
  end

  describe 'bridge boot discovery' do
    let(:server) { StreamWeaver::Canvas::BridgeServer }

    it 'discovers extensions, so a sink registered by an installed gem exists in the bridge process' do
      expect(StreamWeaver::Extensions).to receive(:discover)
        .and_return(StreamWeaver::Extensions::Discovery.new(loaded: [], failures: []))
      expect { server.discover_extensions! }.not_to raise_error
    end

    it 'run! discovers extensions after setup and before the server starts, so sinks exist in the bridge process' do
      calls = []
      allow(server).to receive(:find_available_port).and_return(4999)
      allow(server).to receive(:set)
      allow(server).to receive(:setup!) { calls << :setup }
      allow(server).to receive(:discover_extensions!) { calls << :discover }
      allow(server).to receive(:write_pid_file) { calls << :pid_file }
      allow(server).to receive(:start_unix_socket_server) { calls << :socket }
      allow(server).to receive(:at_exit)
      allow(Sinatra::Base).to receive(:run!) { calls << :listen }
      server.run!
      expect(calls).to eq(%i[setup discover pid_file socket listen])
    end

    it 'logs a failing extension and carries on instead of dying' do
      failure = StreamWeaver::Extensions::Failure.new(gem_name: 'broken_gem', loader: 'broken_gem/stream_weaver', error: 'boom')
      allow(StreamWeaver::Extensions).to receive(:discover)
        .and_return(StreamWeaver::Extensions::Discovery.new(loaded: [], failures: [failure]))
      expect { server.discover_extensions! }.to output(/broken_gem failed to load: boom/).to_stderr
    end

    it 'logs and carries on when discovery itself raises' do
      allow(StreamWeaver::Extensions).to receive(:discover).and_raise(StandardError, 'registry exploded')
      expect { server.discover_extensions! }.to output(/extension discovery failed: registry exploded/).to_stderr
    end
  end

  describe 'through the bridge HTTP route' do
    include Rack::Test::Methods

    def app = StreamWeaver::Canvas::BridgeServer

    around do |ex|
      prev_bridge = app.bridge
      prev_conns = app.claude_connections
      app.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      begin
        ex.run
      ensure
        app.bridge = prev_bridge
        app.claude_connections = prev_conns
      end
    end

    let(:order) { [] }
    let(:sink_got) { Queue.new }
    let(:event) { { type: 'action', button: 'btn_go_1', state: { choice: 'A' } } }

    # A stand-in for a connected canvas-wait client: records that it was written to, and when.
    let(:connection) do
      log = order
      Class.new do
        define_method(:write) { |_data| log << :claude }
      end.new
    end

    def post_event(name = 's1', body = event)
      post "/canvas/#{name}/event", body.to_json, 'CONTENT_TYPE' => 'application/json'
    end

    before { app.claude_connections = [connection] }

    it 'hands the event to the sink for a session whose reply_to names it, after the connected client got it' do
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(ctx) { order << :sink; sink_got << ctx })
      app.bridge.handle_claude_message(type: 'create', name: 's1', reply_to: 'relay:target-1')
      post_event
      expect(last_response.status).to eq(200)
      ctx = Timeout.timeout(2) { sink_got.pop }
      expect(ctx.payload).to eq('target-1')
      expect(ctx.event[:data]).to include(button: 'btn_go_1')
      expect(ctx.state).to include(choice: 'A')
      expect(order).to eq(%i[claude sink])
    end

    it 'lets the sink re-render the canvas through ctx.push' do
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(ctx) { ctx.push(%(header1 "Sent")); sink_got << :pushed })
      app.bridge.handle_claude_message(type: 'create', name: 's1', reply_to: 'relay:t')
      post_event
      Timeout.timeout(2) { sink_got.pop }
      expect(app.bridge.get_session('s1').html).to include('Sent')
    end

    it 'keeps the session source_dir when the sink re-renders (a push without one would reset it)' do
      app.bridge.handle_claude_message(type: 'create', name: 's1', reply_to: 'relay:t')
      app.bridge.handle_claude_message(type: 'push', name: 's1', dsl: %(header1 "First"), source_dir: '/repos/mine')
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(ctx) { ctx.push(%(header1 "Sent")); sink_got << :pushed })
      post_event
      Timeout.timeout(2) { sink_got.pop }
      expect(app.bridge.get_session('s1').source_dir).to eq('/repos/mine')
    end

    it 'answers the browser normally even when the sink raises, and still delivers to the connected client' do
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(_) { sink_got << true; raise 'boom' })
      app.bridge.handle_claude_message(type: 'create', name: 's1', reply_to: 'relay:t')
      expect { post_event }.not_to raise_error
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq('success' => true)
      Timeout.timeout(2) { sink_got.pop }
      expect(order.first).to eq(:claude)
    end

    it 'does not wait for a slow sink' do
      release = Queue.new
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(_) { release.pop })
      app.bridge.handle_claude_message(type: 'create', name: 's1', reply_to: 'relay:t')
      Timeout.timeout(2) { post_event }
      expect(last_response.status).to eq(200)
      release << true
    end

    it 'never reaches a sink for a session without reply_to' do
      StreamWeaver.register_extension(:relay, canvas_event_sink: ->(ctx) { sink_got << ctx })
      app.bridge.handle_claude_message(type: 'create', name: 's1')
      expect(spawned_threads { post_event }).to be_empty
      expect(sink_got).to be_empty
      expect(order).to eq([:claude])
    end

    it 'keeps state updates and delivery to connected clients when reply_to names an unknown extension' do
      app.bridge.handle_claude_message(type: 'create', name: 's1', reply_to: 'ghost:t')
      expect(spawned_threads { post_event }).to be_empty
      expect(last_response.status).to eq(200)
      expect(app.bridge.get_session('s1').state).to include(choice: 'A')
      expect(order).to eq([:claude])
    end
  end
end
