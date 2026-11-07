#!/usr/bin/env ruby
# frozen_string_literal: true

# A StreamWeaver landing page built from the ide_* components and the :ide
# theme: README hero, Why, FEATURES, a canvas-push transcript, INSTALL and
# CONTRIBUTING, each one a file_section of the editor.
#
# Run with: SW_NO_OPEN=1 bundle exec ruby examples/ide/streamweaver_landing.rb
# (drop SW_NO_OPEN to open a browser tab). The theme toggle in the title bar
# flips light and dark; below 1180px the right rail moves behind the menu
# button and below 840px the left rail is hidden.

require_relative "../../lib/stream_weaver"

DSL_SAMPLE = <<~RUBY
  require "stream_weaver"

  app "Standup" do
    text_field :name, placeholder: "Who is reporting?"
    select :mood, %w[Great Fine Stuck]

    button "Post update" do |state|
      state[:updates] ||= []
      state[:updates] << { who: state[:name], mood: state[:mood] }
    end

    table(state[:updates] || [], headers: %w[Who Mood])
  end.run!
RUBY

PUSH_SCRIPT = <<~SH
  $ streamweaver canvas-push review <<'RUBY'
  header2 "Pick a layout"
  columns 2 do
    column { card { text "A: sidebar nav" } }
    column { card { text "B: top tabs" } }
  end
  button "Ship B"
  RUBY
SH

FEATURES = [
  { icon: "{ }", title: "A Ruby DSL", body: "Text, inputs, tables, charts and containers are method calls. A block is a page; there is no template language to learn." },
  { icon: "@", title: "Server-side state", body: "A click runs your Ruby, the block re-renders, and only the changed markup goes back to the browser." },
  { icon: ">_", title: "The agent canvas", body: "An agent pushes the same DSL to a page you already have open, then waits for your click with canvas-wait." },
  { icon: "#", title: "Themes", body: "Themes are CSS custom properties with a light and a dark palette. Switch with one line, or register your own." },
  { icon: "~", title: "Live updates", body: "Streaming output and deferred fragments render as they arrive, so slow work never blocks the page." },
  { icon: "<>", title: "Exports", body: "A page exports to standalone HTML, so what you built for yourself can be sent to someone without Ruby." }
].freeze

WHY_BEATS = [
  ["Say what you need",
   "A small UI is some text, a few inputs and a button. StreamWeaver lets the code say exactly that, and nothing else."],
  ["Spend fewer tokens",
   "An agent writes a short DSL instead of HTML, CSS and JavaScript, so a mockup costs a fraction of the usual output."],
  ["Keep the result on screen",
   "Terminal output scrolls away. A canvas stays open beside your terminal and updates in place."]
].freeze

def beat(title, body)
  div(class: "sw-ide-beat") do
    header3 title
    text body
  end
end

def feature_card(icon:, title:, body:)
  div(class: "sw-ide-card") do
    div(class: "sw-ide-card__head") do
      div(class: "sw-ide-card__icon") { text icon }
      header3 title
    end
    text body
  end
end

def transcript_panel(label, css_class = nil, &block)
  div(class: ["sw-ide-transcript__panel", css_class].compact.join(" ")) do
    div(class: "sw-ide-transcript__label") { text label }
    div(class: "sw-ide-transcript__body", &block)
  end
end

App = StreamWeaver::App.new("StreamWeaver", chrome: false, theme: :ide) do
  ide_shell do
    ide_titlebar(
      crumbs: %w[stream_weaver landing],
      branch: "main",
      links: [{ label: "GitHub", href: "https://github.com/fkchang/stream_weaver", icon: "★" }]
    ) { text "SW" }

    ide_rail_left do
      ide_tree(
        heading: "Pages",
        action: { label: "New page", icon: :plus, href: "/?page=new" },
        rows: [
          { label: "stream_weaver", icon: :folder, active: true, children: [
            { label: "website", icon: :branch, active: true, children: [
              { label: "Landing", icon: :file, href: "/", selected: true },
              { label: "Tutorial", icon: :file_text, href: "/?page=tutorial" },
              { label: "Docs", icon: :book, disabled: true, tag: "Coming soon" }
            ] }
          ] }
        ]
      )
      ide_note(dismiss: "Understood", remember: "streamweaver-landing") do
        text "A canvas is a page an agent can push to. Open one with streamweaver panel."
      end
    end

    ide_editor do
      file_section "readme", label: "README.md", icon: :file, comment: "README.md" do
        div(class: "sw-ide-hero") do
          div(class: "sw-ide-pills") do
            ["Ruby DSL", "MIT license", "open source"].each { |pill| div(class: "sw-ide-pill") { text pill } }
          end
          header1 "StreamWeaver", class: "sw-ide-hero__title"
          text "Express intention, get interface.", class: "sw-ide-hero__tagline"
          text "Write a Ruby block, get a live page. Text, inputs, tables, charts and forms are plain " \
               "method calls, and an agent can push the same code to a canvas beside your terminal. " \
               "No HTML, no CSS, no JavaScript, no webpack.", class: "sw-ide-hero__lede"
          div(class: "sw-ide-actions") do
            link_to "Get started", href: "#install", class: "sw-ide-btn sw-ide-btn--primary"
            link_to "View on GitHub", href: "https://github.com/fkchang/stream_weaver", class: "sw-ide-btn"
            link_to "Read the docs", href: "#features", class: "sw-ide-btn"
          end
          text "Tested on macOS with iTerm2 and Chrome; the canvas also runs in a plain browser tab.",
               class: "sw-ide-hero__meta"
        end
      end

      file_section "why", label: "WHY StreamWeaver", icon: :info, comment: "WHY StreamWeaver" do
        header2 "Why StreamWeaver", class: "sw-ide-h2"
        text "Streamlit showed that an interface can be just text, inputs and a button. " \
             "StreamWeaver brings that idea to Ruby, and it turns out to suit AI agents as well.",
             class: "sw-ide-lead"
        WHY_BEATS.each { |title, body| beat(title, body) }
        callout "Every example in this page is real StreamWeaver DSL. The page you are reading is one too.",
                variant: :info
      end

      file_section "features", label: "FEATURES", icon: :folder_tree, comment: "FEATURES" do
        header2 "Everything a small tool needs", class: "sw-ide-h2"
        text "One DSL covers the page, the state behind it, and the way an agent talks to it.",
             class: "sw-ide-lead"
        div(class: "sw-ide-cards") do
          FEATURES.each { |card| feature_card(**card) }
        end
        header3 "A whole app, in one file"
        text "This is the entire program: a form, a button with a Ruby handler, and a table that follows the state."
        code_block DSL_SAMPLE, lang: "ruby", copy: true
        text "Save it as standup.rb and run ruby standup.rb. StreamWeaver picks a free port from 4567 and prints the URL."
      end

      file_section "canvas", label: "canvas-push", icon: :terminal, comment: "FEATURES / canvas-push" do
        header2 "An agent that shows, not tells", class: "sw-ide-h2"
        text "Instead of a wall of terminal text, an agent pushes a small page and reads back your answer.",
             class: "sw-ide-lead"
        div(class: "sw-ide-transcript") do
          transcript_panel("1. The agent pushes") do
            PUSH_SCRIPT.each_line { |line| div(class: "sw-ide-transcript__line") { text line.chomp } }
          end
          transcript_panel("2. You see, on the canvas", "sw-ide-transcript__panel--page") do
            header3 "Pick a layout"
            div(class: "sw-ide-transcript__choices") do
              div(class: "sw-ide-transcript__choice") { text "A: sidebar nav" }
              div(class: "sw-ide-transcript__choice") { text "B: top tabs" }
            end
            div(class: "sw-ide-transcript__cta") { text "Ship B" }
          end
          transcript_panel("3. The agent gets your answer") do
            div(class: "sw-ide-transcript__line") { text "$ streamweaver canvas-wait review" }
            div(class: "sw-ide-transcript__line sw-ide-transcript__line--out") { text '{"clicked":"Ship B"}' }
          end
        end
        text "Every push is saved to a history snapshot, so the page you showed can be reopened later.",
             class: "sw-ide-lead"
      end

      file_section "install", label: "INSTALL.md", icon: :package, comment: "INSTALL" do
        header2 "Install", class: "sw-ide-h2"
        text "One gem, one command to wire it into Claude Code.", class: "sw-ide-lead"
        code_block "gem install stream_weaver\nstreamweaver install\nstreamweaver get-started", lang: "bash", copy: true
        tabs :install_via do
          tab "gem" do
            code_block "gem install stream_weaver", lang: "bash"
            text "Then require it in a script: require \"stream_weaver\"."
          end
          tab "bundler" do
            code_block "bundle add stream_weaver", lang: "bash"
            text "Or add gem \"stream_weaver\" to your Gemfile and run bundle install."
          end
          tab "source" do
            code_block "git clone https://github.com/fkchang/stream_weaver\ncd stream_weaver\nbundle install", lang: "bash"
            text "Run any example with bundle exec ruby examples/basic/hello_world.rb."
          end
        end
        header3 "Platform support"
        text "streamweaver panel and the worker-tab automation are macOS and iTerm2 only. " \
             "canvas-read is a plain local web server and works anywhere Ruby does."
      end

      file_section "contributing", label: "CONTRIBUTING", icon: :branch, comment: "CONTRIBUTING", class: "sw-ide-file-section--last" do
        header2 "Contributing", class: "sw-ide-h2"
        text "StreamWeaver is MIT licensed and developed in the open. Run the suite with bundle exec rspec " \
             "before you send a change, and keep each commit to one purpose.", class: "sw-ide-lead"
        div(class: "sw-ide-actions") do
          link_to "Open an issue", href: "https://github.com/fkchang/stream_weaver/issues", class: "sw-ide-btn"
          link_to "Fork the repo", href: "https://github.com/fkchang/stream_weaver", class: "sw-ide-btn"
        end
        text "Copyright StreamWeaver contributors. MIT License.", class: "sw-ide-hero__meta"
      end
    end

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
        { command: "streamweaver get-started" },
        "StreamWeaver App Running"
      ])
    end

    ide_statusbar(left: ["MIT", "StreamWeaver"], right: ["Ruby"])
  end
end

App.generate.run! if __FILE__ == $PROGRAM_NAME
