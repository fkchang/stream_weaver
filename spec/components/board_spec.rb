# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Board do
  it "initializes with empty children" do
    expect(described_class.new.children).to eq([])
  end
end

RSpec.describe StreamWeaver::Components::Lane do
  it "stores the title" do
    expect(described_class.new("To Do").title).to eq("To Do")
  end

  it "initializes with empty children" do
    expect(described_class.new("To Do").children).to eq([])
  end

  it "accepts a tone from BOARD_TONES" do
    expect(described_class.new("To Do", tone: :warning).tone).to eq(:warning)
  end

  it "ignores an unrecognized tone" do
    expect(described_class.new("To Do", tone: :nope).tone).to be_nil
  end

  it "stores a subtitle" do
    expect(described_class.new("To Do", subtitle: "Pending").subtitle).to eq("Pending")
  end

  it "stores an icon" do
    expect(described_class.new("To Do", icon: "🐉").icon).to eq("🐉")
  end

  it "has a nil icon by default" do
    expect(described_class.new("To Do").icon).to be_nil
  end

  it "derives count from children, never drifting from what renders" do
    lane = described_class.new("To Do")
    lane.children = [StreamWeaver::Components::BoardCard.new, StreamWeaver::Components::BoardCard.new]
    expect(lane.count).to eq(2)
  end
end

RSpec.describe StreamWeaver::Components::BoardCard do
  it "initializes with empty children" do
    expect(described_class.new.children).to eq([])
  end

  it "accepts a tone from BOARD_TONES" do
    expect(described_class.new(tone: :error).tone).to eq(:error)
  end

  it "ignores an unrecognized tone" do
    expect(described_class.new(tone: :nope).tone).to be_nil
  end
end

RSpec.describe "board/lane/board_card DSL" do
  let(:app) { StreamWeaver::App.new("Test") {} }

  it "adds a Board component" do
    app.board {}
    expect(app.components.first).to be_a(StreamWeaver::Components::Board)
  end

  it "captures lane children" do
    app.board do
      lane("To Do") {}
      lane("Done") {}
    end

    board = app.components.first
    expect(board.children.length).to eq(2)
    expect(board.children[0]).to be_a(StreamWeaver::Components::Lane)
    expect(board.children[0].title).to eq("To Do")
    expect(board.children[1].title).to eq("Done")
  end

  it "captures board_card children inside a lane" do
    app.board do
      lane("To Do") do
        board_card { text "Task 1" }
        board_card { text "Task 2" }
      end
    end

    lane_component = app.components.first.children.first
    expect(lane_component.children.length).to eq(2)
    expect(lane_component.children[0]).to be_a(StreamWeaver::Components::BoardCard)
    expect(lane_component.children[0].children.first).to be_a(StreamWeaver::Components::Text)
  end

  it "allows arbitrary components directly inside a lane (not just board_card)" do
    app.board do
      lane("To Do") do
        text "No cards yet"
      end
    end

    lane_component = app.components.first.children.first
    expect(lane_component.children.first).to be_a(StreamWeaver::Components::Text)
  end
end

RSpec.describe "board HTML rendering" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  it "renders lanes and cards with sw- prefixed classes" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("To Do")
    card = StreamWeaver::Components::BoardCard.new
    card.children = [StreamWeaver::Components::Text.new("Task 1")]
    lane.children = [card]
    board.children = [lane]

    html = render_html(board)
    expect(html).to include("sw-board")
    expect(html).to include("sw-board__lane")
    expect(html).to include("sw-board__card")
    expect(html).to include("To Do")
    expect(html).to include("Task 1")
  end

  it "renders no drag-related attributes (static columns, drag is future work)" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("To Do")
    board.children = [lane]

    html = render_html(board)
    expect(html).not_to include("draggable")
  end

  it "renders board style:/class: passthrough" do
    board = StreamWeaver::Components::Board.new(style: "background: url(x.png);", class: "my-board")
    html = render_html(board)
    expect(html).to include("my-board")
    expect(html).to include("background: url(x.png);")
  end

  it "renders a lane's tone as a header modifier class, subtitle, and auto count" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("Blocked", tone: :error, subtitle: "Frontier")
    lane.children = [StreamWeaver::Components::BoardCard.new, StreamWeaver::Components::BoardCard.new]
    board.children = [lane]

    html = render_html(board)
    expect(html).to include("sw-board__lane-header--error")
    expect(html).to include("Frontier")
    expect(html).to include(">2<") # auto count from children.size
  end

  it "omits the tone modifier class when no tone is given" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("To Do")
    board.children = [lane]

    html = render_html(board)
    expect(html).to include('class="sw-board__lane-header"')
  end

  it "renders a board_card's tone as an accent modifier class, plus style:/class: passthrough" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("Done")
    card = StreamWeaver::Components::BoardCard.new(tone: :success, class: "done-card", style: "opacity: .8;")
    lane.children = [card]
    board.children = [lane]

    html = render_html(board)
    expect(html).to include("sw-board__card--success")
    expect(html).to include("done-card")
    expect(html).to include("opacity: .8;")
  end

  it "renders a lane's icon: as a glyph before the title when it's plain text" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("Blocked Frontier", icon: "🐉")
    board.children = [lane]

    html = render_html(board)
    expect(html).to match(/<span class="sw-board__lane-icon">🐉<\/span>.*sw-board__lane-heading/m)
  end

  it "renders a lane's icon: as an <img> when it looks like a URL/path" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("Blocked Frontier", icon: "/sw-asset/abc123/dragon.png")
    board.children = [lane]

    html = render_html(board)
    expect(html).to include('<img src="/sw-asset/abc123/dragon.png" alt="" class="sw-board__lane-icon"')
  end

  it "omits the lane icon element entirely when icon: is absent" do
    board = StreamWeaver::Components::Board.new
    lane = StreamWeaver::Components::Lane.new("Queue")
    board.children = [lane]

    html = render_html(board)
    # The .sw-board__lane-icon rule is always in the injected stylesheet;
    # only the <span>/<img> element itself is conditional on icon:.
    expect(html).not_to match(/<(span|img)[^>]*class="sw-board__lane-icon/)
  end
end

RSpec.describe "topbar/nav_item DSL and rendering" do
  let(:app) { StreamWeaver::App.new("Test") {} }
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  it "adds a Topbar component with brand/breadcrumbs stored" do
    app.topbar(icon: "🦁", wordmark: "TYRION", breadcrumbs: ["field-ops", "warroom"]) {}

    topbar = app.components.first
    expect(topbar).to be_a(StreamWeaver::Components::Topbar)
    expect(topbar.icon).to eq("🦁")
    expect(topbar.wordmark).to eq("TYRION")
    expect(topbar.breadcrumbs).to eq(["field-ops", "warroom"])
  end

  it "captures trailing block content as children" do
    app.topbar(wordmark: "TYRION") do
      badge("main")
    end

    topbar = app.components.first
    expect(topbar.children.first).to be_a(StreamWeaver::Components::Badge)
  end

  it "defaults to no breadcrumbs and no icon" do
    topbar = StreamWeaver::Components::Topbar.new(wordmark: "TYRION")
    expect(topbar.breadcrumbs).to eq([])
    expect(topbar.icon).to be_nil
  end

  it "renders the brand (icon + wordmark), breadcrumb trail with the last crumb active, and trailing content" do
    topbar = StreamWeaver::Components::Topbar.new(icon: "🦁", wordmark: "TYRION", breadcrumbs: ["field-ops", "warroom-components"])
    topbar.children = [StreamWeaver::Components::Badge.new("✗ 2")]

    html = render_html(topbar)
    expect(html).to include("sw-topbar-brand")
    expect(html).to include('<span class="sw-topbar-icon">🦁</span>')
    expect(html).to include('<div class="sw-topbar-wordmark">TYRION</div>')
    expect(html).to include("sw-topbar-breadcrumbs")
    expect(html).to include('<span class="sw-topbar-crumb">field-ops</span>')
    expect(html).to include('<span class="sw-topbar-crumb sw-topbar-crumb--active">warroom-components</span>')
    expect(html).to include("sw-topbar-separator")
    expect(html).to include("sw-topbar-trailing")
  end

  it "renders an image icon when icon: looks like a URL/path" do
    topbar = StreamWeaver::Components::Topbar.new(icon: "/sw-asset/xyz/crest.png", wordmark: "TYRION")
    html = render_html(topbar)
    expect(html).to include('<img src="/sw-asset/xyz/crest.png" alt="" class="sw-topbar-icon"')
  end

  it "omits the breadcrumbs and trailing wrapper when neither is given" do
    topbar = StreamWeaver::Components::Topbar.new(wordmark: "TYRION")
    html = render_html(topbar)
    # Both class names also appear in the always-injected stylesheet;
    # only the <div> element itself is conditional.
    expect(html).not_to match(/<div[^>]*class="sw-topbar-breadcrumbs/)
    expect(html).not_to match(/<div[^>]*class="sw-topbar-trailing/)
  end

  it "forwards class:/style: onto the topbar container" do
    topbar = StreamWeaver::Components::Topbar.new(wordmark: "TYRION", class: "tyrion-topbar", style: "height: 60px;")
    html = render_html(topbar)
    expect(html).to include("sw-topbar tyrion-topbar")
    expect(html).to include("height: 60px;")
  end
end
