# frozen_string_literal: true

require "stream_weaver"
require_relative "../../lib/stream_weaver/org/recording_context"

RSpec.describe StreamWeaver::Org::RecordingContext do
  it "captures top-level components in source order" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      md "first"
      md "second"
    RUBY
    expect(ctx.components.map(&:class)).to eq([StreamWeaver::Components::Markdown, StreamWeaver::Components::Markdown])
    expect(ctx.components.map(&:content)).to eq(["first", "second"])
  end

  it "captures nested children inside a card" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      card do
        card_header "Title", badge: "1"
        card_body do
          md "body text"
        end
      end
    RUBY
    card = ctx.components.first
    expect(card).to be_a(StreamWeaver::Components::Card)
    header, body = card.children
    expect(header.content).to eq("Title")
    expect(header.badge).to eq("1")
    expect(body.children.first.content).to eq("body text")
  end

  it "captures comparison before/after children separately" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      comparison(before_label: "Old", after_label: "New") do
        before { md "old text" }
        after { md "new text" }
      end
    RUBY
    comparison = ctx.components.first
    expect(comparison.before_children.first.content).to eq("old text")
    expect(comparison.after_children.first.content).to eq("new text")
  end

  it "captures a table component without crashing (table's DSL method always calls #state/#render_state, even for static headers/rows tables)" do
    ctx = described_class.new
    ctx.instance_eval(%(table(headers: ["A"], rows: [["1"]])\n))
    expect(ctx.components.first).to be_a(StreamWeaver::Components::Table)
  end

  it "does not crash on a real saved doc's leading use_theme/use_layout lines (DocStore.dsl_with_metadata prepends these to every real Save-as-doc output)" do
    ctx = described_class.new
    ctx.instance_eval(<<~RUBY)
      use_theme :doc
      use_layout :full
      md "hello"
    RUBY
    expect(ctx.components.first.content).to eq("hello")
  end
end
