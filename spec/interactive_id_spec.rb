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

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
