# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe StreamWeaver::Components::Deck::DeckState do
  let(:tmpdir) { Dir.mktmpdir("deck_state_test") }
  let(:session_id) { "test-session-#{rand(10000)}" }
  let(:state) { described_class.new(session_id, state_dir: tmpdir) }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  # =========================================
  # Initialization
  # =========================================

  describe "#initialize" do
    it "stores the session ID" do
      expect(state.session_id).to eq(session_id)
    end

    it "creates the state directory if it does not exist" do
      custom_dir = File.join(tmpdir, "nested", "dir")
      described_class.new("s1", state_dir: custom_dir)
      expect(Dir.exist?(custom_dir)).to be true
    end
  end

  describe ".generate_session_id" do
    it "returns a UUID-like string" do
      id = described_class.generate_session_id
      expect(id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "generates unique IDs" do
      ids = 10.times.map { described_class.generate_session_id }
      expect(ids.uniq.length).to eq(10)
    end
  end

  describe ".for_session" do
    it "creates a state with the given session ID" do
      s = described_class.for_session("my-session", state_dir: tmpdir)
      expect(s.session_id).to eq("my-session")
    end

    it "generates a session ID when nil" do
      s = described_class.for_session(nil, state_dir: tmpdir)
      expect(s.session_id).not_to be_nil
      expect(s.session_id.length).to be > 0
    end
  end

  # =========================================
  # Selections
  # =========================================

  describe "#select" do
    it "stores a selection for a slide" do
      state.select("arch", "Monolith")
      expect(state.selection("arch")).to eq("Monolith")
    end

    it "overwrites previous selection (radio semantics)" do
      state.select("arch", "Monolith")
      state.select("arch", "Microservices")
      expect(state.selection("arch")).to eq("Microservices")
    end

    it "stores independent selections per slide" do
      state.select("arch", "Monolith")
      state.select("db", "PostgreSQL")
      expect(state.selection("arch")).to eq("Monolith")
      expect(state.selection("db")).to eq("PostgreSQL")
    end
  end

  describe "#selection" do
    it "returns nil for unselected slides" do
      expect(state.selection("arch")).to be_nil
    end

    it "returns the selected option label" do
      state.select("arch", "Monolith")
      expect(state.selection("arch")).to eq("Monolith")
    end
  end

  describe "#selected?" do
    it "returns true for the selected option" do
      state.select("arch", "Monolith")
      expect(state.selected?("arch", "Monolith")).to be true
    end

    it "returns false for unselected options" do
      state.select("arch", "Monolith")
      expect(state.selected?("arch", "Microservices")).to be false
    end

    it "returns false when nothing is selected" do
      expect(state.selected?("arch", "Monolith")).to be false
    end
  end

  describe "#selections" do
    it "returns all selections" do
      state.select("arch", "Monolith")
      state.select("db", "PostgreSQL")
      expect(state.selections).to eq({
        "arch" => "Monolith",
        "db" => "PostgreSQL"
      })
    end

    it "returns empty hash when nothing selected" do
      expect(state.selections).to eq({})
    end
  end

  # =========================================
  # Notes
  # =========================================

  describe "#set_note" do
    it "stores a note for an option" do
      state.set_note("arch", "Monolith", "Simple deployment")
      expect(state.note("arch", "Monolith")).to eq("Simple deployment")
    end

    it "overwrites previous note" do
      state.set_note("arch", "Monolith", "First note")
      state.set_note("arch", "Monolith", "Updated note")
      expect(state.note("arch", "Monolith")).to eq("Updated note")
    end

    it "stores independent notes per option" do
      state.set_note("arch", "Monolith", "Note for monolith")
      state.set_note("arch", "Microservices", "Note for micro")
      expect(state.note("arch", "Monolith")).to eq("Note for monolith")
      expect(state.note("arch", "Microservices")).to eq("Note for micro")
    end
  end

  describe "#note" do
    it "returns nil for options without notes" do
      expect(state.note("arch", "Monolith")).to be_nil
    end
  end

  describe "#notes" do
    it "returns all notes" do
      state.set_note("arch", "Monolith", "Note 1")
      state.set_note("db", "PostgreSQL", "Note 2")
      expect(state.notes).to eq({
        "arch" => { "Monolith" => "Note 1" },
        "db" => { "PostgreSQL" => "Note 2" }
      })
    end
  end

  # =========================================
  # File Persistence
  # =========================================

  describe "file-backed persistence" do
    it "creates a JSON file" do
      state.select("arch", "Monolith")
      expect(File.exist?(state.state_file_path)).to be true
    end

    it "persists across instances" do
      state.select("arch", "Monolith")
      state.set_note("arch", "Monolith", "My note")

      # Create a new instance with the same session ID
      state2 = described_class.new(session_id, state_dir: tmpdir)
      expect(state2.selection("arch")).to eq("Monolith")
      expect(state2.note("arch", "Monolith")).to eq("My note")
    end

    it "stores valid JSON" do
      state.select("arch", "Monolith")
      content = File.read(state.state_file_path)
      data = JSON.parse(content)
      expect(data).to have_key("selections")
      expect(data).to have_key("notes")
    end
  end

  # =========================================
  # State Management
  # =========================================

  describe "#to_h" do
    it "returns the full state" do
      state.select("arch", "Monolith")
      state.set_note("arch", "Monolith", "Note")
      data = state.to_h
      expect(data["selections"]["arch"]).to eq("Monolith")
      expect(data["notes"]["arch"]["Monolith"]).to eq("Note")
    end

    it "returns empty state initially" do
      data = state.to_h
      expect(data["selections"]).to eq({})
      expect(data["notes"]).to eq({})
    end
  end

  describe "#clear!" do
    it "resets all state" do
      state.select("arch", "Monolith")
      state.set_note("arch", "Monolith", "Note")
      state.clear!
      expect(state.selections).to eq({})
      expect(state.notes).to eq({})
    end
  end

  describe "#delete!" do
    it "removes the state file" do
      state.select("arch", "Monolith")
      expect(File.exist?(state.state_file_path)).to be true
      state.delete!
      expect(File.exist?(state.state_file_path)).to be false
    end

    it "is safe when file does not exist" do
      expect { state.delete! }.not_to raise_error
    end
  end

  # =========================================
  # Thread Safety
  # =========================================

  describe "thread safety" do
    it "handles concurrent writes without corruption" do
      threads = 10.times.map do |i|
        Thread.new do
          s = described_class.new(session_id, state_dir: tmpdir)
          s.select("slide_#{i}", "option_#{i}")
        end
      end
      threads.each(&:join)

      result = described_class.new(session_id, state_dir: tmpdir)
      # All 10 selections should be present (no lost writes)
      expect(result.selections.size).to eq(10)
    end

    it "handles concurrent reads during writes" do
      # Write initial data
      state.select("arch", "Monolith")

      threads = []
      # Writers
      5.times do |i|
        threads << Thread.new do
          s = described_class.new(session_id, state_dir: tmpdir)
          s.select("slide_#{i}", "opt_#{i}")
        end
      end
      # Readers
      5.times do
        threads << Thread.new do
          s = described_class.new(session_id, state_dir: tmpdir)
          # Should not raise
          s.selections
        end
      end
      threads.each(&:join)

      # Original selection should still be present
      result = described_class.new(session_id, state_dir: tmpdir)
      expect(result.selection("arch")).to eq("Monolith")
    end
  end

  # =========================================
  # Cleanup
  # =========================================

  describe ".cleanup_stale" do
    it "removes old state files" do
      # Create a state file
      state.select("arch", "Monolith")
      path = state.state_file_path

      # Backdate the file
      FileUtils.touch(path, mtime: Time.now - 90000) # > 24 hours

      count = described_class.cleanup_stale(max_age_seconds: 86400, state_dir: tmpdir)
      expect(count).to eq(1)
      expect(File.exist?(path)).to be false
    end

    it "does not remove recent files" do
      state.select("arch", "Monolith")

      count = described_class.cleanup_stale(max_age_seconds: 86400, state_dir: tmpdir)
      expect(count).to eq(0)
      expect(File.exist?(state.state_file_path)).to be true
    end

    it "returns 0 when directory does not exist" do
      count = described_class.cleanup_stale(state_dir: "/nonexistent/path")
      expect(count).to eq(0)
    end
  end

  # =========================================
  # State File Path
  # =========================================

  describe "#state_file_path" do
    it "is based on session ID" do
      expect(state.state_file_path).to eq(File.join(tmpdir, "#{session_id}.json"))
    end
  end
end
