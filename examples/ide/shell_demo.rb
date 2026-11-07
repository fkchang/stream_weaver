#!/usr/bin/env ruby
# frozen_string_literal: true

# ide_shell with all five regions and enough filler to scroll the editor.
#
# Run with: ruby examples/ide/shell_demo.rb
# (SW_NO_OPEN=1 skips opening a browser tab.)
#
# Resize below 1180px to send the right rail off-canvas behind the menu
# button, and below 840px to hide the left rail.

require_relative "../../lib/stream_weaver"

FILLER = [
  "StreamWeaver turns a Ruby block into a live page. Every call in the block is a component: " \
  "text, tables, charts, forms, and containers that hold other components.",
  "State lives on the server. A button press runs your Ruby, the block re-renders, and only " \
  "the changed markup goes back to the browser.",
  "Themes are CSS custom properties. The :ide theme used here carries a light and a dark " \
  "palette; the toggle in the title bar flips between them.",
  "The canvas lets an agent push the same DSL to a page you already have open, so a session " \
  "can show you a mockup without starting a server per question."
].freeze

App = StreamWeaver::App.new("IDE shell demo", chrome: false, theme: :ide) do
  ide_shell do
    ide_titlebar(
      crumbs: %w[stream_weaver examples],
      branch: "main",
      links: [{ label: "Docs", href: "/docs", icon: "?" }]
    ) { text "SW" }

    ide_rail_left do
      ide_tree(
        heading: "Projects",
        action: { label: "New project", icon: :plus, href: "/?page=new" },
        rows: [
          { label: "stream_weaver", icon: :folder, active: true, children: [
            { label: "examples", icon: :branch, active: true, children: [
              { label: "Shell demo", icon: :file, href: "/", selected: true },
              { label: "Components", icon: :file_text, href: "/?page=components" },
              { label: "Docs", icon: :book, disabled: true, tag: "Coming soon" }
            ] }
          ] }
        ]
      )
      ide_note(dismiss: "Understood", remember: "shell-demo") do
        text "Each region of the shell is an ide_* call, so a page keeps only the parts it needs."
      end
    end

    # Each file_section becomes a tab; the tab of the section on screen is
    # marked as you scroll. Lengths vary, and the last two are short, to
    # exercise the scroll spy at the bottom of the editor.
    ide_editor do
      file_section "readme", label: "README.md", icon: :file do
        header2 "StreamWeaver"
        2.times { FILLER.each { |paragraph| text paragraph } }
      end
      file_section "getting-started", label: "docs/GETTING_STARTED.md", icon: :book, comment: "GETTING STARTED" do
        header2 "Getting started"
        3.times { FILLER.each { |paragraph| text paragraph } }
      end
      file_section "components", label: "docs/COMPONENTS.md", icon: :file_text do
        header2 "Components"
        FILLER.each { |paragraph| text paragraph }
      end
      file_section "themes", label: "docs/THEMES.md", icon: :file_text do
        header2 "Themes"
        text FILLER[2]
      end
      file_section "install", label: "INSTALL.md", icon: :package do
        header2 "Install"
        text "gem install stream_weaver"
      end
    end

    # The file tree is built from the editor's sections and follows the
    # same scroll spy as the tab strip.
    ide_rail_right do
      ide_rail_tabs([
        { label: "Outline", hint: "Planned: headings of the open file" },
        { label: "Files", active: true },
        { label: "Changes", hint: "Planned: the live diff" }
      ])
      ide_filetree
      ide_terminal(lines: [
        { command: "gem install stream_weaver" },
        "Successfully installed stream_weaver",
        { command: "ruby examples/ide/shell_demo.rb" },
        "StreamWeaver App Running"
      ])
    end

    ide_statusbar(left: ["MIT", "StreamWeaver"], right: ["Ruby"])
  end
end

App.generate.run! if __FILE__ == $PROGRAM_NAME
