# frozen_string_literal: true

require 'tmpdir'

RSpec.describe StreamWeaver::Feed do
  let(:url) { "http://127.0.0.1:4567" }
  subject(:feed) { described_class.new(url) }

  describe "#url" do
    it "stores the URL" do
      expect(feed.url).to eq(url)
    end
  end

  describe "#replace" do
    it "POSTs replace action with raw HTML" do
      stub = stub_push(target: "#target", action: "replace", html: "<div>hi</div>")
      feed.replace("#target", "<div>hi</div>")
      expect(stub).to have_been_requested
    end

    it "renders DSL block to HTML" do
      stub = stub_push_matching(target: "#target", action: "replace")
      feed.replace("#target") { text "hello" }
      expect(stub).to have_been_requested
    end
  end

  describe "#append" do
    it "POSTs append action" do
      stub = stub_push(target: "#feed", action: "append", html: "<p>item</p>")
      feed.append("#feed", "<p>item</p>")
      expect(stub).to have_been_requested
    end
  end

  describe "#prepend" do
    it "POSTs prepend action" do
      stub = stub_push(target: "#feed", action: "prepend", html: "<p>new</p>")
      feed.prepend("#feed", "<p>new</p>")
      expect(stub).to have_been_requested
    end

    it "renders component DSL block" do
      stub = stub_push_matching(target: "#activity", action: "prepend")
      feed.prepend("#activity") do
        activity_item time: "14:30", title: "Deploy", summary: "Done", type: :task
      end
      expect(stub).to have_been_requested
    end
  end

  describe "#remove" do
    it "POSTs remove action with empty HTML" do
      stub = stub_push(target: "#old", action: "remove", html: "")
      feed.remove("#old")
      expect(stub).to have_been_requested
    end
  end

  # Stub helpers using WebMock-style approach (manual Net::HTTP stub)
  def stub_push(target:, action:, html:)
    request_made = false
    allow(Net::HTTP).to receive(:post_form).with(
      URI("#{url}/stream/push"),
      hash_including(target: target, action: action, html: html)
    ) do
      request_made = true
      double("response", code: "200")
    end
    # Return a verifiable object
    StubVerifier.new { request_made }
  end

  def stub_push_matching(target:, action:)
    request_made = false
    allow(Net::HTTP).to receive(:post_form).with(
      URI("#{url}/stream/push"),
      hash_including(target: target, action: action)
    ) do
      request_made = true
      double("response", code: "200")
    end
    StubVerifier.new { request_made }
  end

  # Simple verifier that works with expect(stub).to have_been_requested
  class StubVerifier
    def initialize(&check)
      @check = check
    end

    def requested?
      @check.call
    end
  end

  # Custom matcher
  RSpec::Matchers.define :have_been_requested do
    match { |verifier| verifier.requested? }
    failure_message { "expected the HTTP request to have been made" }
  end
end

RSpec.describe "StreamWeaver.connect" do
  let(:portfile_dir) { Dir.mktmpdir("sw_portfiles") }

  before do
    stub_const("StreamWeaver::Portfile::DIR", portfile_dir)
  end

  after do
    FileUtils.rm_rf(portfile_dir)
  end

  describe "with url:" do
    it "creates Feed with explicit URL" do
      feed = StreamWeaver.connect(url: "http://example.com:9999")
      expect(feed).to be_a(StreamWeaver::Feed)
      expect(feed.url).to eq("http://example.com:9999")
    end
  end

  describe "with port:" do
    it "creates Feed with localhost URL" do
      feed = StreamWeaver.connect(port: 4569)
      expect(feed).to be_a(StreamWeaver::Feed)
      expect(feed.url).to eq("http://127.0.0.1:4569")
    end
  end

  describe "with name" do
    it "reads portfile and returns Feed" do
      write_test_portfile("live_monitor", "http://127.0.0.1:4570", Process.pid)

      feed = StreamWeaver.connect("Live Monitor")
      expect(feed).to be_a(StreamWeaver::Feed)
      expect(feed.url).to eq("http://127.0.0.1:4570")
    end

    it "raises error when portfile not found" do
      expect { StreamWeaver.connect("Nonexistent App") }
        .to raise_error(StreamWeaver::Error, /No portfile/)
    end

    it "detects stale portfile (dead PID) and cleans up" do
      write_test_portfile("dead_app", "http://127.0.0.1:4571", 999999)

      expect { StreamWeaver.connect("Dead App") }
        .to raise_error(StreamWeaver::Error, /no longer running/)

      # Portfile should be cleaned up
      expect(File.exist?(File.join(portfile_dir, "dead_app.port"))).to be false
    end
  end

  describe "auto-discover (no arguments)" do
    it "connects to single running app" do
      write_test_portfile("my_app", "http://127.0.0.1:4572", Process.pid)

      feed = StreamWeaver.connect
      expect(feed.url).to eq("http://127.0.0.1:4572")
    end

    it "raises error when no apps running" do
      expect { StreamWeaver.connect }
        .to raise_error(StreamWeaver::Error, /No StreamWeaver apps running/)
    end

    it "raises error when multiple apps running" do
      write_test_portfile("app_one", "http://127.0.0.1:4573", Process.pid)
      write_test_portfile("app_two", "http://127.0.0.1:4574", Process.pid)

      expect { StreamWeaver.connect }
        .to raise_error(StreamWeaver::Error, /Multiple apps running/)
    end
  end

  describe "process_alive?" do
    it "returns true for current process" do
      expect(StreamWeaver::Portfile.process_alive?(Process.pid)).to be true
    end

    it "returns false for nonexistent PID" do
      expect(StreamWeaver::Portfile.process_alive?(999999)).to be false
    end
  end

  describe "clean_stale_portfiles" do
    it "removes portfiles for dead processes" do
      write_test_portfile("dead", "http://127.0.0.1:4575", 999999)
      write_test_portfile("alive", "http://127.0.0.1:4576", Process.pid)

      StreamWeaver::Portfile.clean_stale!

      expect(File.exist?(File.join(portfile_dir, "dead.port"))).to be false
      expect(File.exist?(File.join(portfile_dir, "alive.port"))).to be true
    end
  end

  def write_test_portfile(sanitized_name, url, pid)
    FileUtils.mkdir_p(portfile_dir)
    path = File.join(portfile_dir, "#{sanitized_name}.port")
    File.write(path, "url=#{url}\npid=#{pid}\nname=#{sanitized_name}\n")
  end
end

RSpec.describe "Streamer block support" do
  subject(:streamer) { StreamWeaver::Streamer.new }

  it "accepts block for replace" do
    conn = StringIO.new
    streamer.add_connection(conn)

    streamer.replace("#target") do
      text "from block"
    end

    json = JSON.parse(conn.string.sub("data: ", "").strip)
    expect(json["action"]).to eq("replace")
    expect(json["target"]).to eq("#target")
    expect(json["html"]).to include("from block")
  end

  it "accepts block for prepend" do
    conn = StringIO.new
    streamer.add_connection(conn)

    streamer.prepend("#feed") do
      badge "NEW", variant: :success
    end

    json = JSON.parse(conn.string.sub("data: ", "").strip)
    expect(json["action"]).to eq("prepend")
    expect(json["html"]).to include("NEW")
  end

  it "still accepts raw HTML string" do
    conn = StringIO.new
    streamer.add_connection(conn)

    streamer.replace("#target", "<div>raw</div>")

    json = JSON.parse(conn.string.sub("data: ", "").strip)
    expect(json["html"]).to eq("<div>raw</div>")
  end

  it "prefers html arg over block when both given" do
    conn = StringIO.new
    streamer.add_connection(conn)

    streamer.replace("#target", "<div>explicit</div>") { text "ignored" }

    json = JSON.parse(conn.string.sub("data: ", "").strip)
    expect(json["html"]).to eq("<div>explicit</div>")
  end
end
