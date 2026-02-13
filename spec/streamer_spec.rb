# frozen_string_literal: true

RSpec.describe StreamWeaver::Streamer do
  subject(:streamer) { described_class.new }

  describe "#connection_count" do
    it "starts at zero" do
      expect(streamer.connection_count).to eq(0)
    end
  end

  describe "#add_connection / #remove_connection" do
    it "tracks connections" do
      conn = StringIO.new
      streamer.add_connection(conn)
      expect(streamer.connection_count).to eq(1)

      streamer.remove_connection(conn)
      expect(streamer.connection_count).to eq(0)
    end
  end

  describe "#replace" do
    it "broadcasts replace action as SSE JSON" do
      conn = StringIO.new
      streamer.add_connection(conn)

      streamer.replace("#target", "<div>hello</div>")

      data = conn.string
      expect(data).to start_with("data: ")
      expect(data).to end_with("\n\n")

      json = JSON.parse(data.sub("data: ", "").strip)
      expect(json["action"]).to eq("replace")
      expect(json["target"]).to eq("#target")
      expect(json["html"]).to eq("<div>hello</div>")
    end
  end

  describe "#append" do
    it "broadcasts append action" do
      conn = StringIO.new
      streamer.add_connection(conn)

      streamer.append("#feed", "<p>new item</p>")

      json = JSON.parse(conn.string.sub("data: ", "").strip)
      expect(json["action"]).to eq("append")
      expect(json["target"]).to eq("#feed")
    end
  end

  describe "#prepend" do
    it "broadcasts prepend action" do
      conn = StringIO.new
      streamer.add_connection(conn)

      streamer.prepend("#feed", "<p>new item</p>")

      json = JSON.parse(conn.string.sub("data: ", "").strip)
      expect(json["action"]).to eq("prepend")
    end
  end

  describe "#remove" do
    it "broadcasts remove action with empty html" do
      conn = StringIO.new
      streamer.add_connection(conn)

      streamer.remove("#old-element")

      json = JSON.parse(conn.string.sub("data: ", "").strip)
      expect(json["action"]).to eq("remove")
      expect(json["html"]).to eq("")
    end
  end

  describe "multiple connections" do
    it "broadcasts to all connected clients" do
      conn1 = StringIO.new
      conn2 = StringIO.new
      streamer.add_connection(conn1)
      streamer.add_connection(conn2)

      streamer.replace("#target", "<div>update</div>")

      expect(conn1.string).to include("replace")
      expect(conn2.string).to include("replace")
    end
  end

  describe "dead connection cleanup" do
    it "removes connections that raise IOError" do
      good_conn = StringIO.new
      dead_conn = StringIO.new
      dead_conn.close # Will raise IOError on write

      streamer.add_connection(good_conn)
      streamer.add_connection(dead_conn)
      expect(streamer.connection_count).to eq(2)

      streamer.replace("#target", "<div>test</div>")

      expect(streamer.connection_count).to eq(1)
      expect(good_conn.string).to include("replace")
    end
  end

  describe "thread safety" do
    it "handles concurrent broadcasts without error" do
      connections = 10.times.map { StringIO.new }
      connections.each { |c| streamer.add_connection(c) }

      threads = 5.times.map do
        Thread.new { streamer.replace("#target", "<div>concurrent</div>") }
      end
      threads.each(&:join)

      connections.each do |conn|
        expect(conn.string).to include("replace")
      end
    end
  end

  describe "ACTIONS constant" do
    it "includes all public action methods" do
      expect(described_class::ACTIONS).to contain_exactly(:replace, :append, :prepend, :remove)
    end
  end
end
