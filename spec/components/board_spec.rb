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
end
