# frozen_string_literal: true

require_relative "../support/ide_markup"

RSpec.describe "ide_rail_right contents: ide_rail_tabs, ide_filetree, ide_terminal" do
  include IdeMarkup

  def render_rail(&block)
    page = render_ide_page do
      ide_editor do
        file_section "readme", label: "README.md"
        file_section "install", label: "docs/INSTALL.md", icon: :package
        file_section "themes", label: "docs/guides/THEMES.md"
        file_section "canvas", label: "docs/CANVAS.md"
        file_section "faq", label: "FAQ.md"
      end
      ide_rail_right(&block)
    end
    ide_region(page, "aside", "sw-ide-rail-right")
  end

  describe "ide_rail_tabs" do
    let(:tabs) do
      find_all(render_rail { ide_rail_tabs(["Specs", { label: "Files", active: true }, { label: "Changes", hint: "Planned" }]) },
               "div[@class='sw-ide-rail-tabs']/span")
    end

    it "renders each tab, marking the active one for sight and for screen readers" do
      expect(tabs.map { |tab| tab.texts.map(&:value).join }).to eq(%w[Specs Files Changes])
      expect(classes(tabs[1])).to eq(%w[sw-ide-rail-tab sw-ide-rail-tab--active])
      expect(tabs.map { |tab| tab.attributes["aria-current"] }).to eq([nil, "true", nil])
    end

    it "dims a tab with a hint and gives the hint as its title and as hidden text" do
      expect(classes(tabs[2])).to eq(%w[sw-ide-rail-tab sw-ide-rail-tab--dim])
      expect(tabs[2].attributes["title"]).to eq("Planned")
      expect(text_of(first(tabs[2], "span[@class='sw-ide-visually-hidden']"))).to eq(" (Planned)")
      expect(tabs[0].attributes["title"]).to be_nil
      expect(find_all(tabs[0], "span")).to be_empty
    end
  end

  describe "ide_filetree" do
    let(:tree) { first(render_rail { ide_filetree }, "nav[@class='sw-ide-filetree']") }
    let(:rows) { find_all(tree, "*") }

    it "is a named link list the scroll spy reveals within, with a click handler for the off-canvas rail" do
      expect(tree.attributes["aria-label"]).to eq("Files")
      expect(tree.attributes["data-sw-ide-links"]).to eq("")
      expect(tree.attributes["on-click"].to_s).not_to be_empty
    end

    it "mirrors the editor's sections in order, under folder rows, with depth" do
      expect(rows.map { |row| [row.name, text_of(row), row.attributes["style"]] }).to eq([
        ["a", "README.md", "--sw-ide-depth: 0"],
        ["div", "docs", "--sw-ide-depth: 0"],
        ["a", "INSTALL.md", "--sw-ide-depth: 1"],
        ["div", "guides", "--sw-ide-depth: 1"],
        ["a", "THEMES.md", "--sw-ide-depth: 2"],
        ["a", "CANVAS.md", "--sw-ide-depth: 1"],
        ["a", "FAQ.md", "--sw-ide-depth: 0"]
      ])
    end

    it "links each file row to its section through the editor's scroll spy target" do
      files = rows.select { |row| row.name == "a" }
      expect(files.map { |row| row.attributes["href"] }).to eq(%w[#readme #install #themes #canvas #faq])
      expect(files.map { |row| row.attributes["data-sw-ide-target"] }).to eq(%w[readme install themes canvas faq])
      expect(files.map { |row| row.attributes["class"] }).to all(eq("sw-ide-filetree__row"))
    end

    it "gives file rows their section's icon and folder rows a folder icon, and folders no link" do
      folder = rows[1]
      expect(classes(folder)).to eq(%w[sw-ide-filetree__row sw-ide-filetree__row--folder])
      expect(folder.attributes["data-sw-ide-target"]).to be_nil
      [folder, rows[2]].each do |row|
        expect(first(row, "*[local-name()='svg'][@class='sw-ide-filetree__icon']")).not_to be_nil
      end
    end

    it "finds the editor through any container in the rail" do
      page = render_ide_page do
        ide_editor { file_section "readme", label: "README.md" }
        ide_rail_right { vstack { ide_filetree } }
      end
      expect(page).to include('data-sw-ide-target="readme"')
    end

    it "refuses to render without an ide_editor in the shell" do
      expect { render_ide_page { ide_rail_right { ide_filetree } } }
        .to raise_error(ArgumentError, /ide_filetree needs an ide_editor in the same ide_shell/)
    end
  end

  describe "ide_terminal" do
    let(:terminal) do
      first(render_rail { ide_terminal(lines: [{ command: "gem install stream_weaver" }, "Installed"]) },
            "figure[@class='sw-ide-terminal']")
    end

    it "captions its transcript with its label" do
      expect(text_of(first(terminal, "figcaption[@class='sw-ide-terminal__head']/span"))).to eq("Terminal")
    end

    it "renders prompt and output lines, one per text line" do
      screen = first(terminal, "pre[@class='sw-ide-terminal__screen']")
      line, output = find_all(screen, "span")
      expect(line.attributes["class"]).to eq("sw-ide-terminal__line")
      expect(text_of(first(line, "span[@class='sw-ide-terminal__prompt']"))).to eq("❯")
      expect(text_of(first(line, "span[@class='sw-ide-terminal__command']"))).to eq("gem install stream_weaver")
      expect(output.attributes["class"]).to eq("sw-ide-terminal__output")
      expect(text_of(screen)).to eq("❯ gem install stream_weaver\nInstalled")
    end

    it "takes its own label and prompt, and string-keyed lines" do
      term = first(render_rail { ide_terminal(label: "Shell", prompt: "$", lines: [{ "command" => "ls" }]) },
                   "figure[@class='sw-ide-terminal']")
      expect(text_of(first(term, ".//span[@class='sw-ide-terminal__label']"))).to eq("Shell")
      expect(text_of(first(term, ".//pre"))).to eq("$ ls")
    end

    it "refuses a hash line without a command" do
      expect { StreamWeaver::Components::IdeTerminal.new(lines: [{ output: "x" }]) }
        .to raise_error(ArgumentError, /needs a command: key/)
    end
  end
end
