# A StreamWeaver landing page built from the ide_* components and the :ide
# theme: README hero, Why, FEATURES, a canvas-push transcript, INSTALL and
# CONTRIBUTING, each one a file_section of the editor.
#
# A bare DSL body: no app wrapper, no constants, no methods defined outside
# it, so the same file runs two ways:
#
#   bundle exec ruby examples/ide/streamweaver_landing.rb   # server, opens a tab
#
#   bundle exec streamweaver canvas NAME                    # open a canvas
#   bundle exec streamweaver canvas-push NAME < examples/ide/streamweaver_landing_body.rb
#
# (bundle exec because this page needs the checkout's lib, not an older
# installed gem.) The use_theme line below themes a plain canvas session,
# because a pushed use_theme applies live; in the standalone app, which is
# already :ide, it changes nothing.
use_theme :ide

# This page's own styles: the hero, pills, buttons, cards and transcript
# are plain divs with these classes, no component behind them. They are
# wrapped in the framework's cascade layer on purpose: they shipped inside
# the ide stylesheet until the page-assets epic, and unlayered they would
# outrank every :ide theme rule (dark mode included) instead of sitting
# below theme overrides and user CSS, so the page would no longer render
# exactly as it did.
use_stylesheet <<~CSS
  @layer #{StreamWeaver::CSS::LAYER_NAME} {
    .sw-ide-h2 {
      margin: 0 0 12px;
      padding: 0;
      border: 0;
      font-size: clamp(28px, 4vw, 40px);
      font-weight: 700;
      letter-spacing: -0.02em;
      line-height: 1.15;
      color: var(--ide-text, var(--sw-color-text));
    }
    .sw-ide-lead {
      margin: 0 0 var(--sw-spacing-lg, 24px);
      font-size: 17px;
      line-height: 1.55;
      color: var(--ide-muted, var(--sw-color-text-muted));
    }
    .sw-ide-hero__title {
      margin: 18px 0 8px;
      font-size: clamp(44px, 8vw, 84px);
      font-weight: 700;
      letter-spacing: -0.04em;
      line-height: 1;
      color: var(--ide-text, var(--sw-color-text));
    }
    .sw-ide-hero__tagline {
      margin: 0 0 14px;
      font-size: clamp(20px, 2.6vw, 28px);
      font-weight: 600;
      line-height: 1.25;
      color: var(--ide-text, var(--sw-color-text));
    }
    .sw-ide-hero__lede {
      max-width: 620px;
      margin: 0 0 var(--sw-spacing-lg, 24px);
      font-size: 17px;
      line-height: 1.6;
      color: var(--ide-muted, var(--sw-color-text-muted));
    }
    .sw-ide-hero__meta {
      margin: 22px 0 0;
      font-family: var(--ide-font-mono, var(--sw-font-mono));
      font-size: 12px;
      color: var(--ide-hint, var(--sw-color-text-light));
    }
    .sw-ide-pills {
      display: flex;
      flex-wrap: wrap;
      gap: var(--sw-spacing-sm, 8px);
    }
    .sw-ide-pill {
      padding: 3px 10px;
      border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
      border-radius: 999px;
      font-family: var(--ide-font-mono, var(--sw-font-mono));
      font-size: 11px;
      color: var(--ide-muted, var(--sw-color-text-muted));
    }
    .sw-ide-pill p,
    .sw-ide-card__icon p,
    .sw-ide-transcript__label p,
    .sw-ide-transcript__line p,
    .sw-ide-transcript__choice p,
    .sw-ide-transcript__cta p {
      margin: 0;
      color: inherit;
    }
    .sw-ide-h3 {
      margin: var(--sw-spacing-lg, 24px) 0 var(--sw-spacing-sm, 8px);
    }
    .sw-ide-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
    }
    .sw-ide-btn {
      display: inline-flex;
      align-items: center;
      padding: 11px 20px;
      border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
      border-radius: 4px;
      background: transparent;
      color: var(--ide-text, var(--sw-color-text));
      font-weight: 500;
      text-decoration: none;
    }
    .sw-ide-btn:hover {
      background: var(--ide-hover, var(--sw-color-bg-hover));
    }
    .sw-ide-btn--primary {
      border-color: var(--ide-accent, var(--sw-color-primary));
      background: var(--ide-accent, var(--sw-color-primary));
      color: var(--ide-on-accent, #fff);
    }
    .sw-ide-btn--primary:hover {
      background: var(--ide-accent-hover, var(--sw-color-primary-hover));
    }
    .sw-ide-btn:focus-visible {
      outline: 2px solid var(--ide-accent, var(--sw-color-primary));
      outline-offset: 2px;
    }
    .sw-ide-beat {
      margin: 0 0 var(--sw-spacing-lg, 24px);
    }
    .sw-ide-beat h3 {
      margin: 0 0 6px;
      font-size: 20px;
      font-weight: 600;
    }
    .sw-ide-beat p {
      margin: 0;
      line-height: 1.6;
      color: var(--ide-muted, var(--sw-color-text-muted));
    }
    .sw-ide-cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 14px;
      margin: 0 0 var(--sw-spacing-xl, 32px);
    }
    .sw-ide-card {
      padding: var(--sw-spacing-md, 16px) 18px;
      border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
      border-radius: 4px;
      background: var(--ide-header, var(--sw-color-bg-card));
    }
    .sw-ide-card__head {
      display: flex;
      align-items: center;
      gap: var(--sw-spacing-sm, 8px);
      margin-bottom: 8px;
    }
    .sw-ide-card__head h3 {
      margin: 0;
      font-size: 15px;
      font-weight: 600;
    }
    .sw-ide-card__icon {
      font-family: var(--ide-font-mono, var(--sw-font-mono));
      font-size: 13px;
      color: var(--ide-accent, var(--sw-color-primary));
    }
    .sw-ide-card > p {
      margin: 0;
      font-size: 14px;
      line-height: 1.6;
      color: var(--ide-muted, var(--sw-color-text-muted));
    }
    .sw-ide-transcript {
      display: grid;
      gap: 14px;
      margin: 0 0 var(--sw-spacing-lg, 24px);
    }
    .sw-ide-transcript__panel {
      border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
      border-radius: 4px;
      background: var(--ide-header, var(--sw-color-bg-card));
      overflow: hidden;
    }
    .sw-ide-transcript__label {
      padding: 6px 14px;
      border-bottom: 1px solid var(--ide-border, var(--sw-color-border));
      font-family: var(--ide-font-mono, var(--sw-font-mono));
      font-size: 11px;
      letter-spacing: 0.4px;
      color: var(--ide-hint, var(--sw-color-text-light));
    }
    .sw-ide-transcript__body {
      padding: 12px 14px;
      font-family: var(--ide-font-mono, var(--sw-font-mono));
      font-size: 13px;
      line-height: 1.6;
      color: var(--ide-text, var(--sw-color-text));
    }
    .sw-ide-transcript__line {
      white-space: pre-wrap;
    }
    .sw-ide-transcript__line--out {
      color: var(--ide-green, var(--sw-color-success));
    }
    .sw-ide-transcript__panel--page .sw-ide-transcript__body {
      font-family: var(--ide-font-sans, var(--sw-font-body));
      background: var(--ide-workspace, var(--sw-color-bg));
    }
    .sw-ide-transcript__panel--page h3 {
      margin: 0 0 10px;
      font-size: 16px;
    }
    .sw-ide-transcript__choices {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      margin-bottom: 12px;
    }
    .sw-ide-transcript__choice {
      padding: 14px;
      border: 1px solid var(--ide-border2, var(--sw-color-border-strong));
      border-radius: 4px;
      background: var(--ide-header, var(--sw-color-bg-card));
    }
    .sw-ide-transcript__cta {
      display: inline-block;
      padding: 8px 16px;
      border-radius: 4px;
      background: var(--ide-accent, var(--sw-color-primary));
      color: var(--ide-on-accent, #fff);
      font-weight: 500;
    }
  }
CSS

dsl_sample = <<~RUBY
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

push_script = <<~SH
  $ streamweaver canvas-push review <<'RUBY'
  header2 "Pick a layout"
  columns 2 do
    column { card { text "A: sidebar nav" } }
    column { card { text "B: top tabs" } }
  end
  button "Ship B"
  RUBY
SH

features = [
  { icon: "{ }", title: "A Ruby DSL", body: "Text, inputs, tables, charts and containers are method calls. A block is a page; there is no template language to learn." },
  { icon: "@", title: "Server-side state", body: "A click runs your Ruby, the block re-renders, and only the changed markup goes back to the browser." },
  { icon: ">_", title: "The agent canvas", body: "An agent pushes the same DSL to a page you already have open, then waits for your click with canvas-wait." },
  { icon: "#", title: "Themes", body: "Themes are CSS custom properties with a light and a dark palette. Switch with one line, or register your own." },
  { icon: "~", title: "Live updates", body: "Streaming output and deferred fragments render as they arrive, so slow work never blocks the page." },
  { icon: "<>", title: "Exports", body: "A page exports to standalone HTML, so what you built for yourself can be sent to someone without Ruby." }
].freeze

why_beats = [
  ["Say what you need",
   "A small UI is some text, a few inputs and a button. StreamWeaver lets the code say exactly that, and nothing else."],
  ["Spend fewer tokens",
   "An agent writes a short DSL instead of HTML, CSS and JavaScript, so a mockup costs a fraction of the usual output."],
  ["Keep the result on screen",
   "Terminal output scrolls away. A canvas stays open beside your terminal and updates in place."]
].freeze


# Content blocks. Lambdas close over the page, so their blocks run on it.
beat = lambda do |title, body|
  div(class: "sw-ide-beat") do
    header3 title
    text body
  end
end

feature_card = lambda do |icon:, title:, body:|
  div(class: "sw-ide-card") do
    div(class: "sw-ide-card__head") do
      div(class: "sw-ide-card__icon") { text icon }
      header3 title
    end
    text body
  end
end

transcript_panel = lambda do |label, variant: nil, &block|
  div(class: ["sw-ide-transcript__panel", variant && "sw-ide-transcript__panel--#{variant}"].compact.join(" ")) do
    div(class: "sw-ide-transcript__label") { text label }
    div(class: "sw-ide-transcript__body", &block)
  end
end

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
          link_to "See features", href: "#features", class: "sw-ide-btn"
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
      why_beats.each { |title, body| beat.call(title, body) }
      callout "The code samples on this page are real StreamWeaver DSL, and so is the page itself. The canvas panel below is a drawing of what a push looks like.",
              variant: :info
    end

    file_section "features", label: "FEATURES", icon: :folder_tree, comment: "FEATURES" do
      header2 "Everything a small tool needs", class: "sw-ide-h2"
      text "One DSL covers the page, the state behind it, and the way an agent talks to it.",
           class: "sw-ide-lead"
      div(class: "sw-ide-cards") do
        features.each { |card| feature_card.call(**card) }
      end
      header3 "A whole app, in one file", class: "sw-ide-h3"
      text "This is the entire program: a form, a button with a Ruby handler, and a table that follows the state."
      code_block dsl_sample, lang: "ruby", copy: true
      text "Save it as standup.rb and run ruby standup.rb. StreamWeaver picks a free port from 4567 and prints the URL."
    end

    file_section "canvas", label: "canvas-push", icon: :terminal, comment: "FEATURES / canvas-push" do
      header2 "An agent that shows, not tells", class: "sw-ide-h2"
      text "Instead of a wall of terminal text, an agent pushes a small page and reads back your answer.",
           class: "sw-ide-lead"
      div(class: "sw-ide-transcript") do
        transcript_panel.call("1. The agent pushes") do
          push_script.each_line { |line| div(class: "sw-ide-transcript__line") { text line.chomp } }
        end
        transcript_panel.call("2. You see, on the canvas", variant: "page") do
          header3 "Pick a layout"
          div(class: "sw-ide-transcript__choices") do
            div(class: "sw-ide-transcript__choice") { text "A: sidebar nav" }
            div(class: "sw-ide-transcript__choice") { text "B: top tabs" }
          end
          div(class: "sw-ide-transcript__cta") { text "Ship B" }
        end
        transcript_panel.call("3. The agent gets your answer") do
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
      header3 "Platform support", class: "sw-ide-h3"
      text "streamweaver panel and the worker-tab automation are macOS and iTerm2 only. " \
           "canvas-read is a plain local web server and works anywhere Ruby does."
    end

    file_section "contributing", label: "CONTRIBUTING", icon: :branch, comment: "CONTRIBUTING" do
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
