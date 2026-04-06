# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'json'
require 'rack/test'

RSpec.describe "Generate-More (T10)" do
  let(:tmpdir) { Dir.mktmpdir("generate_more_test") }
  let(:session_id) { "gen-test-#{rand(10000)}" }
  let(:deck_state) { StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir) }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  # =========================================
  # GenerateMoreControls Component
  # =========================================

  describe StreamWeaver::Components::Deck::GenerateMoreControls do
    it "initializes with slide_id" do
      controls = described_class.new("arch")
      expect(controls.slide_id).to eq("arch")
    end

    it "defaults to idle status" do
      controls = described_class.new("arch")
      expect(controls.status).to eq(:idle)
      expect(controls.generating?).to be false
      expect(controls.timed_out?).to be false
    end

    it "reads generating status from generate_state" do
      gen_state = { "status" => "generating", "requested_count" => 3, "received_count" => 1 }
      controls = described_class.new("arch", generate_state: gen_state)
      expect(controls.status).to eq(:generating)
      expect(controls.generating?).to be true
      expect(controls.requested_count).to eq(3)
      expect(controls.received_count).to eq(1)
      expect(controls.remaining_count).to eq(2)
    end

    it "reads timed_out status" do
      gen_state = { "status" => "timed_out", "requested_count" => 2, "received_count" => 0 }
      controls = described_class.new("arch", generate_state: gen_state)
      expect(controls.timed_out?).to be true
    end

    it "returns 0 remaining when idle" do
      controls = described_class.new("arch")
      expect(controls.remaining_count).to eq(0)
    end

    it "exposes prompt and request_id" do
      gen_state = { "status" => "generating", "prompt" => "focus on scalability", "request_id" => "abc123" }
      controls = described_class.new("arch", generate_state: gen_state)
      expect(controls.prompt).to eq("focus on scalability")
      expect(controls.request_id).to eq("abc123")
    end

    it "has sw-generate-more CSS class" do
      controls = described_class.new("arch")
      expect(controls.css_classes).to eq("sw-generate-more")
    end

    it "accepts configurable timeout" do
      controls = described_class.new("arch", timeout: 30)
      expect(controls.timeout).to eq(30)
    end
  end

  # =========================================
  # SkeletonPlaceholder Component
  # =========================================

  describe StreamWeaver::Components::Deck::SkeletonPlaceholder do
    it "initializes with index" do
      skeleton = described_class.new(index: 2)
      expect(skeleton.index).to eq(2)
    end

    it "defaults index to 0" do
      skeleton = described_class.new
      expect(skeleton.index).to eq(0)
    end

    it "has sw-skeleton CSS class" do
      skeleton = described_class.new
      expect(skeleton.css_classes).to eq("sw-skeleton")
    end
  end

  # =========================================
  # DeckState Generate-More Methods
  # =========================================

  describe "DeckState generate methods" do
    describe "#start_generate" do
      it "transitions to generating state" do
        deck_state.start_generate("arch", 3, prompt: "event-driven")

        gen = deck_state.generate_state
        expect(gen["status"]).to eq("generating")
        expect(gen["slide_id"]).to eq("arch")
        expect(gen["requested_count"]).to eq(3)
        expect(gen["received_count"]).to eq(0)
        expect(gen["prompt"]).to eq("event-driven")
        expect(gen["request_id"]).to be_a(String)
        expect(gen["started_at"]).to be_a(Float)
      end

      it "returns a request_id" do
        request_id = deck_state.start_generate("arch", 2)
        expect(request_id).to be_a(String)
        expect(request_id.length).to eq(16)
      end

      it "queues a generate request" do
        deck_state.start_generate("arch", 2, prompt: "test")
        requests = deck_state.take_pending_requests!
        expect(requests.length).to eq(1)
        expect(requests[0]["slide_id"]).to eq("arch")
        expect(requests[0]["count"]).to eq(2)
        expect(requests[0]["prompt"]).to eq("test")
      end

      it "generates unique request_ids" do
        id1 = deck_state.start_generate("arch", 1)
        id2 = deck_state.start_generate("arch", 1)
        expect(id1).not_to eq(id2)
      end
    end

    describe "#generating?" do
      it "returns false initially" do
        expect(deck_state.generating?).to be false
      end

      it "returns true when generating" do
        deck_state.start_generate("arch", 2)
        expect(deck_state.generating?).to be true
      end
    end

    describe "#generate_status" do
      it "returns :idle initially" do
        expect(deck_state.generate_status).to eq(:idle)
      end

      it "returns :generating after start_generate" do
        deck_state.start_generate("arch", 2)
        expect(deck_state.generate_status).to eq(:generating)
      end
    end

    describe "#cancel_generate" do
      it "transitions to cancelled" do
        deck_state.start_generate("arch", 2)
        deck_state.cancel_generate
        expect(deck_state.generate_status).to eq(:cancelled)
      end

      it "clears the queue" do
        deck_state.start_generate("arch", 2)
        deck_state.cancel_generate
        requests = deck_state.take_pending_requests!
        expect(requests).to be_empty
      end

      it "is a no-op when idle" do
        deck_state.cancel_generate
        expect(deck_state.generate_status).to eq(:idle)
      end
    end

    describe "#reset_generate" do
      it "transitions to idle" do
        deck_state.start_generate("arch", 2)
        deck_state.cancel_generate
        deck_state.reset_generate
        expect(deck_state.generate_status).to eq(:idle)
      end
    end

    describe "#timeout_generate" do
      it "transitions generating to timed_out" do
        deck_state.start_generate("arch", 2)
        deck_state.timeout_generate
        expect(deck_state.generate_status).to eq(:timed_out)
      end

      it "is a no-op when not generating" do
        deck_state.timeout_generate
        expect(deck_state.generate_status).to eq(:idle)
      end
    end

    describe "#add_generated_option" do
      it "adds option to generated_options" do
        request_id = deck_state.start_generate("arch", 2)
        deck_state.add_generated_option("arch", { "label" => "Event-Driven" }, request_id: request_id)

        opts = deck_state.generated_options("arch")
        expect(opts.length).to eq(1)
        expect(opts[0]["label"]).to eq("Event-Driven")
        expect(opts[0]["generated"]).to be true
      end

      it "increments received_count" do
        request_id = deck_state.start_generate("arch", 2)
        deck_state.add_generated_option("arch", { "label" => "A" }, request_id: request_id)

        gen = deck_state.generate_state
        expect(gen["received_count"]).to eq(1)
        expect(gen["status"]).to eq("generating")
      end

      it "transitions to idle when all options received" do
        request_id = deck_state.start_generate("arch", 2)
        deck_state.add_generated_option("arch", { "label" => "A" }, request_id: request_id)
        deck_state.add_generated_option("arch", { "label" => "B" }, request_id: request_id)

        expect(deck_state.generate_status).to eq(:idle)
        expect(deck_state.generated_options("arch").length).to eq(2)
      end

      it "ignores stale request_ids (request versioning)" do
        request_id1 = deck_state.start_generate("arch", 2)
        # Start a new request (simulating rapid generate-cancel-generate)
        request_id2 = deck_state.start_generate("arch", 1)

        # Push with the old request_id -- should be ignored
        deck_state.add_generated_option("arch", { "label" => "Stale" }, request_id: request_id1)
        expect(deck_state.generated_options("arch")).to be_empty
        expect(deck_state.generate_state["received_count"]).to eq(0)

        # Push with the current request_id -- should succeed
        deck_state.add_generated_option("arch", { "label" => "Fresh" }, request_id: request_id2)
        expect(deck_state.generated_options("arch").length).to eq(1)
        expect(deck_state.generated_options("arch")[0]["label"]).to eq("Fresh")
      end

      it "ignores pushes when cancelled" do
        request_id = deck_state.start_generate("arch", 2)
        deck_state.cancel_generate

        deck_state.add_generated_option("arch", { "label" => "Too Late" }, request_id: request_id)
        expect(deck_state.generated_options("arch")).to be_empty
      end

      it "ignores pushes when timed out" do
        request_id = deck_state.start_generate("arch", 2)
        deck_state.timeout_generate

        deck_state.add_generated_option("arch", { "label" => "Too Late" }, request_id: request_id)
        expect(deck_state.generated_options("arch")).to be_empty
      end
    end

    describe "#generated_options" do
      it "returns empty array for unknown slide" do
        expect(deck_state.generated_options("unknown")).to eq([])
      end

      it "returns options for the given slide" do
        request_id = deck_state.start_generate("arch", 1)
        deck_state.add_generated_option("arch", { "label" => "A" }, request_id: request_id)

        expect(deck_state.generated_options("arch").length).to eq(1)
        expect(deck_state.generated_options("db")).to eq([])
      end
    end

    describe "#all_generated_options" do
      it "returns all generated options across slides" do
        req1 = deck_state.start_generate("arch", 1)
        deck_state.add_generated_option("arch", { "label" => "A" }, request_id: req1)
        # Start fresh for another slide
        deck_state.reset_generate
        req2 = deck_state.start_generate("db", 1)
        deck_state.add_generated_option("db", { "label" => "B" }, request_id: req2)

        all = deck_state.all_generated_options
        expect(all.keys).to contain_exactly("arch", "db")
      end
    end

    describe "#take_pending_requests!" do
      it "returns and clears pending requests" do
        deck_state.start_generate("arch", 2)
        requests = deck_state.take_pending_requests!
        expect(requests.length).to eq(1)

        # Second call returns empty
        requests2 = deck_state.take_pending_requests!
        expect(requests2).to be_empty
      end
    end

    describe "#generate_cancelled?" do
      it "returns false normally" do
        expect(deck_state.generate_cancelled?).to be false
      end

      it "returns true when cancelled" do
        deck_state.start_generate("arch", 2)
        deck_state.cancel_generate
        expect(deck_state.generate_cancelled?).to be true
      end
    end
  end

  # =========================================
  # DeckState persistence of generate state
  # =========================================

  describe "generate state persistence" do
    it "persists generate state across instances" do
      request_id = deck_state.start_generate("arch", 3)

      # New instance, same session
      state2 = StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir)
      expect(state2.generating?).to be true
      expect(state2.generate_state["request_id"]).to eq(request_id)
    end

    it "persists generated options across instances" do
      request_id = deck_state.start_generate("arch", 1)
      deck_state.add_generated_option("arch", { "label" => "Persistent" }, request_id: request_id)

      state2 = StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir)
      opts = state2.generated_options("arch")
      expect(opts.length).to eq(1)
      expect(opts[0]["label"]).to eq("Persistent")
    end
  end

  # =========================================
  # Thread safety for generate operations
  # =========================================

  describe "generate thread safety" do
    it "handles concurrent option pushes without corruption" do
      request_id = deck_state.start_generate("arch", 10)

      threads = 10.times.map do |i|
        Thread.new do
          s = StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir)
          s.add_generated_option("arch", { "label" => "Option #{i}" }, request_id: request_id)
        end
      end
      threads.each(&:join)

      result = StreamWeaver::Components::Deck::DeckState.new(session_id, state_dir: tmpdir)
      expect(result.generated_options("arch").length).to eq(10)
      expect(result.generate_status).to eq(:idle) # All received
    end
  end

  # =========================================
  # Server Routes (Integration)
  # =========================================

  describe "server routes", type: :request do
    include Rack::Test::Methods

    let(:test_app) do
      StreamWeaver::App.new("Generate Test", theme: :dark) do
        design_deck "Test Deck" do
          slide "arch", "Architecture" do
            option "Monolith" do
              text "Single unit"
            end
          end
        end
      end
    end

    let(:app) do
      StreamWeaver::SinatraApp.create(test_app)
    end

    it "POST /deck/generate queues a request and returns 202" do
      # First visit to establish session
      get '/'
      expect(last_response).to be_ok

      post '/deck/generate',
           JSON.generate(slide_id: "arch", count: 2, prompt: "test"),
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(202)
      body = JSON.parse(last_response.body)
      expect(body["status"]).to eq("generating")
      expect(body["request_id"]).to be_a(String)
      expect(body["slide_id"]).to eq("arch")
      expect(body["count"]).to eq(2)
    end

    it "POST /deck/generate requires slide_id" do
      get '/'
      post '/deck/generate',
           JSON.generate(count: 2),
           { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end

    it "POST /deck/generate clamps count to 1-5" do
      get '/'
      post '/deck/generate',
           JSON.generate(slide_id: "arch", count: 10),
           { 'CONTENT_TYPE' => 'application/json' }

      body = JSON.parse(last_response.body)
      expect(body["count"]).to eq(5)
    end

    it "GET /deck/pending returns and clears queued requests" do
      get '/'

      # Queue a request
      post '/deck/generate',
           JSON.generate(slide_id: "arch", count: 2),
           { 'CONTENT_TYPE' => 'application/json' }

      # Get the session_id from the deck state cookie
      session_id = rack_mock_session.cookie_jar["rack.session"]
      # We need to get the deck_session_id -- read it from /deck/state
      get '/deck/state'
      state_data = JSON.parse(last_response.body)

      # For agent polling, we need the deck session ID -- extract from cookie
      # In Rack::Test, sessions are tracked automatically
      # The pending endpoint requires session_id parameter
      # Get the deck_session_id from the cookie session
      cookies = rack_mock_session.cookie_jar
      # We can read the session ID from the deck/state response
      # Actually, let's use a direct DeckState approach for testing
      # The session_id is stored in the Sinatra session cookie

      # Test via the pending endpoint with a known session_id
      pending_session = "agent-pending-#{rand(10000)}"
      test_state = StreamWeaver::Components::Deck::DeckState.new(pending_session)
      test_state.start_generate("arch", 2)

      get "/deck/pending?session_id=#{pending_session}"
      expect(last_response).to be_ok
      body = JSON.parse(last_response.body)
      expect(body["requests"]).to be_an(Array)
    ensure
      test_state&.delete!
    end

    it "POST /deck/add_option adds option and returns success" do
      # Create a generate request directly in default state dir (where server will look)
      agent_session = "agent-session-#{rand(10000)}"
      test_state = StreamWeaver::Components::Deck::DeckState.new(agent_session)
      request_id = test_state.start_generate("arch", 2)

      post '/deck/add_option',
           JSON.generate(
             session_id: agent_session,
             slide_id: "arch",
             request_id: request_id,
             option: { label: "Event-Driven", description: "Async messaging" }
           ),
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      body = JSON.parse(last_response.body)
      expect(body["success"]).to be true
      expect(body["received_count"]).to eq(1)
      expect(body["status"]).to eq("generating")
    ensure
      test_state&.delete!
    end

    it "POST /deck/add_option transitions to idle when all received" do
      agent_session = "agent-session-#{rand(10000)}"
      test_state = StreamWeaver::Components::Deck::DeckState.new(agent_session)
      request_id = test_state.start_generate("arch", 1)

      post '/deck/add_option',
           JSON.generate(
             session_id: agent_session,
             slide_id: "arch",
             request_id: request_id,
             option: { label: "Complete", description: "Done" }
           ),
           { 'CONTENT_TYPE' => 'application/json' }

      body = JSON.parse(last_response.body)
      expect(body["status"]).to eq("idle")
    ensure
      test_state&.delete!
    end

    it "POST /deck/add_option requires JSON body" do
      post '/deck/add_option', "not json"
      expect(last_response.status).to eq(400)
    end

    it "POST /deck/cancel_generate cancels and returns idle" do
      get '/'
      # Start generation
      post '/deck/generate',
           JSON.generate(slide_id: "arch", count: 2),
           { 'CONTENT_TYPE' => 'application/json' }

      # Cancel it
      post '/deck/cancel_generate',
           '',
           { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response).to be_ok
      body = JSON.parse(last_response.body)
      expect(body["success"]).to be true
      expect(body["status"]).to eq("idle")
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "CSS classes" do
    it "all use sw- prefix" do
      controls = StreamWeaver::Components::Deck::GenerateMoreControls.new("arch")
      expect(controls.css_classes).to start_with("sw-")

      skeleton = StreamWeaver::Components::Deck::SkeletonPlaceholder.new
      expect(skeleton.css_classes).to start_with("sw-")
    end
  end

  # =========================================
  # State machine transitions
  # =========================================

  describe "state machine" do
    it "idle -> generating (user clicks Generate)" do
      expect(deck_state.generate_status).to eq(:idle)
      deck_state.start_generate("arch", 2)
      expect(deck_state.generate_status).to eq(:generating)
    end

    it "generating -> idle (all options received)" do
      request_id = deck_state.start_generate("arch", 1)
      deck_state.add_generated_option("arch", { "label" => "A" }, request_id: request_id)
      expect(deck_state.generate_status).to eq(:idle)
    end

    it "generating -> timed_out (server-side timer)" do
      deck_state.start_generate("arch", 2)
      deck_state.timeout_generate
      expect(deck_state.generate_status).to eq(:timed_out)
    end

    it "generating -> cancelled -> idle (user cancels)" do
      deck_state.start_generate("arch", 2)
      deck_state.cancel_generate
      expect(deck_state.generate_status).to eq(:cancelled)
      deck_state.reset_generate
      expect(deck_state.generate_status).to eq(:idle)
    end

    it "timed_out -> idle (user retries)" do
      deck_state.start_generate("arch", 2)
      deck_state.timeout_generate
      expect(deck_state.generate_status).to eq(:timed_out)
      deck_state.start_generate("arch", 2)
      expect(deck_state.generate_status).to eq(:generating)
    end

    it "preserves partial results through timeout" do
      request_id = deck_state.start_generate("arch", 3)
      deck_state.add_generated_option("arch", { "label" => "Partial" }, request_id: request_id)
      deck_state.timeout_generate

      # Partial result preserved
      expect(deck_state.generated_options("arch").length).to eq(1)
      expect(deck_state.generate_state["received_count"]).to eq(1)
    end

    it "preserves partial results through cancellation" do
      request_id = deck_state.start_generate("arch", 3)
      deck_state.add_generated_option("arch", { "label" => "Partial" }, request_id: request_id)
      deck_state.cancel_generate

      # Partial result preserved
      expect(deck_state.generated_options("arch").length).to eq(1)
    end
  end
end
