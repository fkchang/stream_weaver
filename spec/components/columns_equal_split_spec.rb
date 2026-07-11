# frozen_string_literal: true

RSpec.describe "columns equal-split default (FAC-P2.2)" do
  let(:app) { StreamWeaver::App.new("Test") {} }

  it "still divides evenly with no widths (unchanged, pre-existing flex behavior)" do
    app.columns do
      column { text "Left" }
      column { text "Right" }
    end

    expect(app.components.first.widths).to be_nil
  end

  it "accepts a bare positional column count with no items, without erroring" do
    expect { app.columns(3) {} }.not_to raise_error
    expect(app.components.first).to be_a(StreamWeaver::Components::Columns)
  end

  it "still honors explicit widths" do
    app.columns(widths: ['30%', '70%']) do
      column { text "Sidebar" }
      column { text "Main" }
    end

    expect(app.components.first.widths).to eq(['30%', '70%'])
  end

  describe "items: auto-distribution (honorable mention: presidential_mockup's hand-rolled each_slice)" do
    # The columns(items:) block must be written the way real StreamWeaver
    # apps write it -- nested directly inside `App.new(name) { ... }`, which
    # is itself instance_eval'd against the App -- so the block closes over
    # the correct `self` (matching the docs' each_with_index example). Calling
    # `app.columns(...) { ... }` from a bare RSpec example would close the
    # block over the example group instead, which is not how this DSL is used.
    def build_app(roles, n = nil)
      StreamWeaver::App.new("Test") do
        if n
          columns(n, items: roles) { |role| text role }
        else
          columns(items: roles) { |role| text role }
        end
      end.tap { |a| a.rebuild_with_state({}) }
    end

    it "distributes items evenly into n columns" do
      roles = %w[Engineer Designer PM Writer Analyst]
      app = build_app(roles, 2)

      columns = app.components.first
      expect(columns.children.length).to eq(2)
      # each_slice((5/2.0).ceil) = each_slice(3) -> [3, 2]
      expect(columns.children[0].children.length).to eq(3)
      expect(columns.children[1].children.length).to eq(2)
    end

    it "preserves item order within each column" do
      app = build_app(%w[A B C D], 2)

      columns = app.components.first
      first_column_texts = columns.children[0].children.map { |c| c.instance_variable_get(:@content) }
      expect(first_column_texts).to eq(%w[A B])
    end

    it "defaults to 2 columns when n is not given" do
      app = build_app(%w[A B C D])
      expect(app.components.first.children.length).to eq(2)
    end

    it "the DSL block resolves against the enclosing app (self stays correct)" do
      app = StreamWeaver::App.new("Test") do
        columns(2, items: %w[A B]) { |role| text "Role: #{role}" }
      end
      app.rebuild_with_state({})

      first_text = app.components.first.children[0].children[0]
      expect(first_text.instance_variable_get(:@content)).to eq("Role: A")
    end

    it "supports arbitrary components inside the item block, not just text" do
      app = StreamWeaver::App.new("Test") do
        columns(2, items: %w[A B]) { |role| card { text role } }
      end
      app.rebuild_with_state({})

      first_child = app.components.first.children[0].children[0]
      expect(first_child).to be_a(StreamWeaver::Components::Card)
    end
  end
end
