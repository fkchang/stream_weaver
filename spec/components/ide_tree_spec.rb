# frozen_string_literal: true

require_relative "../support/ide_markup"

RSpec.describe "ide_tree and ide_note" do
  include IdeMarkup

  def render_rail(&block)
    ide_region(render_ide_page { ide_rail_left(&block) }, "aside", "sw-ide-rail-left")
  end

  describe "ide_tree" do
    let(:rail) do
      tree_rows = [
        { label: "stream_weaver", icon: :folder, active: true, children: [
          { label: "landing", icon: :branch, active: true, children: [
            { label: "Landing", icon: :file, href: "/", selected: true },
            { label: "Blog", icon: :file_text, href: "/blog" },
            { label: "Docs", icon: :book, href: "/docs", disabled: true, tag: "Coming soon" }
          ] }
        ] }
      ]
      render_rail do
        ide_tree(heading: "Projects", action: { label: "New project", icon: :plus, href: "/new" }, rows: tree_rows)
      end
    end
    let(:tree) { first(rail, "nav[@class='sw-ide-tree']") }
    let(:rows) { find_all(tree, "div[@class='sw-ide-tree__rows']/*") }

    it "names the tree by its heading and renders the action as a named link" do
      expect(tree.attributes["aria-label"]).to eq("Projects")
      heading = first(tree, "div[@class='sw-ide-tree__heading']")
      expect(text_of(first(heading, "span"))).to eq("Projects")
      action = first(heading, "a[@class='sw-ide-tree__action']")
      expect(action.attributes["href"]).to eq("/new")
      expect(action.attributes["aria-label"]).to eq("New project")
      expect(first(action, "*[local-name()='svg']")).not_to be_nil
    end

    it "refuses an action without an href, which would do nothing" do
      expect { StreamWeaver::Components::IdeTree.new(action: { label: "Add" }) }
        .to raise_error(ArgumentError, /needs an href/)
    end

    it "refuses an unknown named icon" do
      expect { render_rail { ide_tree(rows: [{ label: "x", icon: :no_such_icon }]) } }
        .to raise_error(ArgumentError, /unknown ide icon :no_such_icon/)
    end

    it "flattens nested rows in order, indenting each by its depth" do
      expect(rows.map { |r| text_of(first(r, "span[@class='sw-ide-tree__label']")) })
        .to eq(%w[stream_weaver landing Landing Blog Docs])
      expect(rows.map { |r| r.attributes["style"] }).to eq(
        ["--sw-ide-depth: 0", "--sw-ide-depth: 1", "--sw-ide-depth: 2", "--sw-ide-depth: 2", "--sw-ide-depth: 2"]
      )
    end

    it "renders active rows without an href as divs with the active class" do
      folder, workspace = rows
      [folder, workspace].each do |row|
        expect(row.name).to eq("div")
        expect(classes(row)).to include("sw-ide-tree__row--active")
      end
    end

    it "says whether a row with children is expanded, and leaves leaf rows alone" do
      expect(rows.map { |r| r.attributes["aria-expanded"] }).to eq(["true", "true", nil, nil, nil])
      closed = first(render_rail { ide_tree(rows: [{ label: "x", children: [{ label: "y" }] }]) },
                     ".//div[@class='sw-ide-tree__row']")
      expect(closed.attributes["aria-expanded"]).to eq("false")
    end

    it "renders the selected row as the current page link" do
      landing = rows[2]
      expect(landing.name).to eq("a")
      expect(landing.attributes["href"]).to eq("/")
      expect(classes(landing)).to include("sw-ide-tree__row--selected")
      expect(landing.attributes["aria-current"]).to eq("page")
      expect(rows[3].attributes["aria-current"]).to be_nil
    end

    it "renders a disabled row as a non-link with its tag, even when given an href" do
      docs = rows[4]
      expect(docs.name).to eq("div")
      expect(docs.attributes["href"]).to be_nil
      expect(classes(docs)).to include("sw-ide-tree__row--disabled")
      expect(text_of(first(docs, "span[@class='sw-ide-tree__tag']"))).to eq("Coming soon")
    end

    it "renders named icons as inline SVG and text icons as hidden text" do
      expect(find_all(rows[0], "*[local-name()='svg'][@class='sw-ide-tree__icon']").size).to eq(1)
      text_row = first(render_rail { ide_tree(rows: [{ label: "x", icon: "*" }]) }, ".//div[@class='sw-ide-tree__row']")
      expect(text_of(first(text_row, "span[@aria-hidden='true']/span[@class='sw-ide-tree__icon']"))).to eq("*")
    end

    it "omits the heading when none is given" do
      tree = render_rail { ide_tree(rows: [{ label: "x" }]) }
      expect(find_all(tree, ".//div[@class='sw-ide-tree__heading']")).to be_empty
      expect(first(tree, ".//nav").attributes["aria-label"]).to be_nil
    end
  end

  describe "ide_note" do
    let(:note) do
      first(render_rail { ide_note(dismiss: "Got it") { text "A workspace is a git worktree." } },
            "div[@class='sw-ide-note']")
    end

    it "renders the icon, the body from its block and a named dismiss button" do
      expect(note.attributes["role"]).to eq("note")
      expect(first(note, "*[local-name()='svg'][@class='sw-ide-note__icon']")).not_to be_nil
      expect(text_of(first(note, "div[@class='sw-ide-note__body']"))).to include("A workspace is a git worktree.")
      button = first(note, "button[@class='sw-ide-note__dismiss']")
      expect(text_of(button)).to eq("Got it")
      expect(button.attributes["type"]).to eq("button")
      expect(button.attributes["on-click"]).not_to be_nil
    end

    it "shows only while not dismissed, and stays cloaked until Alpine has read that state" do
      expect(note.attributes["x-show"]).to eq("!dismissed")
      expect(note.attributes["x-cloak"]).to eq("")
    end

    it "with remember:, keeps the dismissal under a key named for the note" do
      data = first(render_rail { ide_note(remember: "workspaces") { text "x" } }, "div[@class='sw-ide-note']")
             .attributes["x-data"]
      expect(data).to include(%("sw-ide-note:workspaces"))
      expect(note.attributes["x-data"]).not_to include("localStorage")
    end
  end
end
