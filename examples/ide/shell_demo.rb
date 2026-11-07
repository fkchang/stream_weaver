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
      text "Pages"
      %w[README.md GETTING_STARTED.md COMPONENTS.md THEMES.md CANVAS.md].each { |page| text page }
    end

    ide_editor do
      header2 "README.md"
      3.times { FILLER.each { |paragraph| text paragraph } }
      header2 "GETTING_STARTED.md"
      3.times { FILLER.each { |paragraph| text paragraph } }
    end

    ide_rail_right do
      text "Files"
      %w[lib/stream_weaver.rb lib/stream_weaver/app.rb lib/stream_weaver/components.rb].each { |file| text file }
    end

    ide_statusbar(left: ["MIT", "StreamWeaver"], right: ["Ruby"])
  end
end

App.generate.run! if __FILE__ == $PROGRAM_NAME
