# frozen_string_literal: true

RSpec.describe "Layout primitive options" do
  def app_html(&block)
    app = StreamWeaver::App.new("Test", &block)
    app.rebuild_with_state({})
    StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call
  end

  it "passes style and merges class for vstack" do
    html = app_html { vstack(class: "custom-stack", style: "flex: 1;") { text "content" } }

    expect(html).to match(/<div class="sw-vstack custom-stack" style="[^"]*flex: 1;/)
  end

  it "passes style and merges class for hstack" do
    html = app_html { hstack(class: "custom-stack", style: "flex-wrap: wrap;") { text "content" } }

    expect(html).to match(/<div class="sw-hstack custom-stack" style="[^"]*flex-wrap: wrap;/)
  end

  it "passes style and merges class for grid" do
    html = app_html { grid(class: "custom-grid", style: "align-items: start;") { text "content" } }

    expect(html).to match(/<div class="sw-grid custom-grid" style="[^"]*align-items: start;/)
  end

  it "passes style and merges class for columns" do
    html = app_html { columns(class: "custom-columns", style: "align-items: start;") { column { text "content" } } }

    expect(html).to match(/<div class="sw-columns custom-columns" style="[^"]*align-items: start;/)
  end
end
