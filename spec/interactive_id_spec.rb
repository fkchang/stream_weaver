# frozen_string_literal: true

require 'rack/test'

# FAC-P0.1: interactive component IDs derive from label + block source_location.
# Inside a loop, every iteration shares the same source_location, so buttons
# collide on id and dispatch (find_button_recursive) always fires the first
# match. These specs cover the fix: a `key:` param for stable order-independent
# ids, auto-disambiguation + warning for unkeyed duplicates, and `strict_ids:`.
RSpec.describe "StreamWeaver interactive component id safety (FAC-P0.1)" do
  describe "StreamWeaver::App#button" do
    it "raises ArgumentError when key: is a non-scalar" do
      test_app = StreamWeaver::App.new("Test") {}
      expect {
        test_app.button("Delete", key: ["not", "scalar"]) {}
      }.to raise_error(ArgumentError, /key/)
    end

    it "accepts String, Symbol, and Integer keys" do
      test_app = StreamWeaver::App.new("Test") {}
      expect { test_app.button("A", key: "str") {} }.not_to raise_error
      expect { test_app.button("B", key: :sym) {} }.not_to raise_error
      expect { test_app.button("C", key: 3) {} }.not_to raise_error
    end

    it "gives same-label loop buttons without key: distinct, independently dispatchable ids" do
      test_app = StreamWeaver::App.new("Test") do
        [{ id: 1 }, { id: 2 }, { id: 3 }].each do |item|
          button("Delete") { |state| state[:deleted] = item[:id] }
        end
      end

      allow(test_app).to receive(:warn)
      test_app.rebuild_with_state({})

      ids = test_app.components.map(&:id)
      expect(ids.uniq.length).to eq(3)
    end

    it "warns once per id per process for unkeyed duplicate buttons, naming label/location/key: example" do
      test_app = StreamWeaver::App.new("Test") do
        [{ id: 1 }, { id: 2 }].each do |item|
          button("Delete") { |state| state[:deleted] = item[:id] }
        end
      end

      message = capture_stderr { test_app.rebuild_with_state({}) }
      expect(message).to match(/Delete/)
      expect(message).to match(%r{interactive_id_spec\.rb:\d+})
      expect(message).to match(/key:/)
    end

    it "does not warn again for the same id across a second rebuild" do
      test_app = StreamWeaver::App.new("Test") do
        [{ id: 1 }, { id: 2 }].each do |item|
          button("Delete") { |state| state[:deleted] = item[:id] }
        end
      end

      capture_stderr { test_app.rebuild_with_state({}) }
      expect { test_app.rebuild_with_state({}) }.not_to output.to_stderr
    end

    it "does not warn when key: disambiguates the loop buttons" do
      test_app = StreamWeaver::App.new("Test") do
        [{ id: 1 }, { id: 2 }, { id: 3 }].each do |item|
          button("Delete", key: item[:id]) { |state| state[:deleted] = item[:id] }
        end
      end

      expect { test_app.rebuild_with_state({}) }.not_to output.to_stderr
      expect(test_app.components.map(&:id).uniq.length).to eq(3)
    end

    it "keeps a keyed button's id stable when the collection is reordered" do
      forward = StreamWeaver::App.new("Test") do
        [{ id: 1 }, { id: 2 }].each do |item|
          button("Delete", key: item[:id]) {}
        end
      end
      forward.rebuild_with_state({})
      forward_id_for_1 = forward.components.first.id

      reversed = StreamWeaver::App.new("Test") do
        [{ id: 2 }, { id: 1 }].each do |item|
          button("Delete", key: item[:id]) {}
        end
      end
      reversed.rebuild_with_state({})
      reversed_id_for_1 = reversed.components.last.id

      expect(reversed_id_for_1).to eq(forward_id_for_1)
    end

    it "raises instead of warning when strict_ids: true and a duplicate id is produced" do
      test_app = StreamWeaver::App.new("Test", strict_ids: true) do
        [{ id: 1 }, { id: 2 }].each do |item|
          button("Delete") { |state| state[:deleted] = item[:id] }
        end
      end

      expect { test_app.rebuild_with_state({}) }.to raise_error(ArgumentError, /Delete/)
    end

    it "does not raise under strict_ids: true when buttons are keyed distinctly" do
      test_app = StreamWeaver::App.new("Test", strict_ids: true) do
        [{ id: 1 }, { id: 2 }].each do |item|
          button("Delete", key: item[:id]) {}
        end
      end

      expect { test_app.rebuild_with_state({}) }.not_to raise_error
    end

    it "treats id: as an explicit full override -- the literal id, not a hash of it" do
      test_app = StreamWeaver::App.new("Test") {}
      test_app.button("Delete", id: "row-7") {}
      expect(test_app.components.first.id).to eq("btn_delete_row-7")
    end

    it "lets id: win over key: when both are given (id: > key: > auto-derivation)" do
      test_app = StreamWeaver::App.new("Test") {}
      test_app.button("Delete", id: "explicit", key: 42) {}
      expect(test_app.components.first.id).to eq("btn_delete_explicit")
    end

    it "raises ArgumentError when id: is a non-scalar" do
      test_app = StreamWeaver::App.new("Test") {}
      expect {
        test_app.button("Delete", id: { not: "scalar" }) {}
      }.to raise_error(ArgumentError, /key/)
    end

    it "auto-disambiguates duplicate buttons nested inside a modal" do
      test_app = StreamWeaver::App.new("Test") do
        modal(:confirm, title: "Confirm") do
          [{ id: 1 }, { id: 2 }].each do |item|
            button("Remove") { |state| state[:removed] = item[:id] }
          end
        end
      end

      allow(test_app).to receive(:warn)
      test_app.rebuild_with_state({})

      modal_component = test_app.components.first
      ids = modal_component.children.map(&:id)
      expect(ids.uniq.length).to eq(2)
    end
  end

  describe "DisplayDSL#button (FeedBuilder / canvas-push context)" do
    it "gives same-label loop buttons distinct ids" do
      components = nil
      ids = nil
      capture_stderr do
        components = StreamWeaver::FeedBuilder.build({}) do
          [1, 2, 3].each do |i|
            button("Delete") { |state| state[:deleted] = i }
          end
        end
      end
      ids = components.map(&:id)
      expect(ids.uniq.length).to eq(3)
    end

    it "accepts a stable scalar key: and raises on a non-scalar key:" do
      components = StreamWeaver::FeedBuilder.build({}) do
        [1, 2].each { |i| button("Delete", key: i) {} }
      end
      expect(components.map(&:id).uniq.length).to eq(2)

      expect {
        StreamWeaver::FeedBuilder.build({}) { button("Delete", key: [1, 2]) {} }
      }.to raise_error(ArgumentError, /key/)
    end

    it "treats id: as an explicit full override" do
      components = StreamWeaver::FeedBuilder.build({}) { button("Delete", id: "row-7") {} }
      expect(components.first.id).to eq("btn_delete_row-7")
    end
  end

  describe "strict_ids configuration" do
    around do |example|
      original_env = ENV['RACK_ENV']
      original_global = StreamWeaver.instance_variable_get(:@strict_ids)
      original_env_flag = ENV['SW_STRICT_IDS']
      example.run
    ensure
      ENV['RACK_ENV'] = original_env
      ENV['SW_STRICT_IDS'] = original_env_flag
      StreamWeaver.instance_variable_set(:@strict_ids, original_global)
    end

    def colliding_app(**opts)
      StreamWeaver::App.new("Test", **opts) do
        [{ id: 1 }, { id: 2 }].each do |item|
          button("Delete") { |state| state[:deleted] = item[:id] }
        end
      end
    end

    it "warns instead of raising in production, still auto-disambiguating" do
      ENV['RACK_ENV'] = 'production'
      test_app = colliding_app(strict_ids: true)

      message = capture_stderr { test_app.rebuild_with_state({}) }
      expect(message).to match(/Delete/)
      expect(test_app.components.map(&:id).uniq.length).to eq(2)
    end

    it "raises in dev (non-production)" do
      ENV['RACK_ENV'] = 'development'
      expect { colliding_app(strict_ids: true).rebuild_with_state({}) }
        .to raise_error(ArgumentError, /Delete/)
    end

    it "honors the StreamWeaver.strict_ids global config for apps that don't pass strict_ids:" do
      StreamWeaver.strict_ids = true
      expect { colliding_app.rebuild_with_state({}) }.to raise_error(ArgumentError, /Delete/)
    end

    it "honors SW_STRICT_IDS=1 from the environment" do
      StreamWeaver.instance_variable_set(:@strict_ids, nil)
      ENV['SW_STRICT_IDS'] = '1'
      expect { colliding_app.rebuild_with_state({}) }.to raise_error(ArgumentError, /Delete/)
    end

    it "lets an explicit strict_ids: false override the global config" do
      StreamWeaver.strict_ids = true
      test_app = colliding_app(strict_ids: false)
      expect { capture_stderr { test_app.rebuild_with_state({}) } }.not_to raise_error
    end
  end

  describe "documentation (docs/for_llms.md -> llms.txt)" do
    let(:docs) { File.read(File.expand_path('../llms.txt', __dir__)) }

    it "documents the keying convention: precedence, key-by-position, and strict_ids" do
      expect(docs).to match(/Interactive IDs and keying/i)
      expect(docs).to match(/id:`?\s*>\s*`?key:`?\s*>\s*auto/i)
      expect(docs).to match(/strict_ids/)
      expect(docs).to match(/position/i)
    end
  end

  describe "end-to-end dispatch through the server (the reported bug)" do
    include Rack::Test::Methods

    let(:app) { described_app.generate }
    let(:described_app) do
      StreamWeaver::App.new("Test App") do
        items = [{ id: 1, name: "Alpha" }, { id: 2, name: "Beta" }, { id: 3, name: "Gamma" }]
        items.each do |item|
          text item[:name]
          button("Delete") { |state| state[:deleted_id] = item[:id] }
        end
      end
    end

    def button_ids(html)
      html.scan(%r{hx-post="/action/(btn_delete_[a-f0-9]+(?:-dup-\d+)?)"}).flatten
    end

    it "dispatches each loop button's own callback, not always the first match" do
      capture_stderr { get '/' }
      ids = button_ids(last_response.body)
      expect(ids.uniq.length).to eq(3)

      post "/action/#{ids[1]}", {}
      expect(last_request.session[:streamlit_state][:deleted_id]).to eq(2)

      post "/action/#{ids[2]}", {}
      expect(last_request.session[:streamlit_state][:deleted_id]).to eq(3)

      post "/action/#{ids[0]}", {}
      expect(last_request.session[:streamlit_state][:deleted_id]).to eq(1)
    end
  end

  describe "loop-rendered fragments (same collision class as buttons)" do
    include Rack::Test::Methods

    let(:app) { described_app.generate }
    let(:described_app) do
      StreamWeaver::App.new("Fragment Loop") do
        [{ id: 1 }, { id: 2 }].each do |item|
          fragment(:row) do
            button("Delete") { |state| state[:deleted_id] = item[:id] }
          end
        end
      end
    end

    it "gives each iteration a distinct fragment id and an independently dispatchable button" do
      capture_stderr { get '/' }
      body = last_response.body
      expect(body).to include('id="sw-frag-row"')
      expect(body).to include('id="sw-frag-row-dup-2"')

      paths = body.scan(%r{hx-post="(/action/btn_delete_[^"]+)"}).flatten
      expect(paths.uniq.length).to eq(2)

      post paths[1], {}
      expect(last_request.session[:streamlit_state][:deleted_id]).to eq(2)
      post paths[0], {}
      expect(last_request.session[:streamlit_state][:deleted_id]).to eq(1)
    end
  end

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
