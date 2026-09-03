# frozen_string_literal: true

module StreamWeaver
  module University
    # Curriculum data: what `streamweaver get-started` teaches, and what's
    # coming next. Plain data only -- no rendering, no ledger knowledge. The
    # `prompt:` on each Getting Started step is exactly what
    # `driver-worker-runner`'s Runner sends to a worker session, so it stays
    # a plain string here rather than markup or DSL. `why_it_matters:` and
    # `what_you_should_see:` are the step screen's other two content slots
    # (design-spec section 2, "Step screen") -- a short motivation
    # (rendered as two paragraphs via `md`) and the payoff checklist
    # (rendered as a bulleted list), respectively.
    #
    # Two rules every step's content obeys (Forrest, 2026-09-03, after the
    # full live UAT -- see features/university-getting-started.context.md,
    # "Course content law"):
    #
    # 1. Never show what a TUI already does, and does faster. Each step has
    #    to earn its minute with a capability delta -- live arbitrary UI,
    #    charts, diagrams, a blocking visual decision, a growing styled doc,
    #    portability. "The agent could have just printed that" means the
    #    step failed.
    # 2. Every prompt opens by closing the previous step's demo session or
    #    background server, and says what is about to happen before it
    #    happens. The demo sessions are `dashboard` (step 1), `decision`
    #    (step 3) and `doc-demo` (step 4); `university` is the controller
    #    canvas the user drives the course from and is never closed.
    module Course
      # Mined from the two real worker sessions
      # (docs/university/worker-session-mining.md): both reached for `curl`
      # and the app's own action log before any browser, and one burned a
      # tool call plus a visible reasoning detour reflexively reaching for a
      # browser MCP its own config forbids. Same line on every step so
      # neither is rediscovered per step. Interpolated into each prompt
      # rather than repeated, so the five can never drift.
      VERIFY_RULE = "Verification rule for this whole course: prove it with `curl` and " \
                    "the app's own logs first -- a POST to `.../action/...` returning 200, " \
                    "plus the expected text in the HTML that comes back, is proof the DSL " \
                    "block re-ran server-side. Only then click through it, and only with " \
                    "the browser tooling this session is already configured for. Never " \
                    "fetch or install a new browser tool mid-course."

      GETTING_STARTED_STEPS = [
        {
          number: 1,
          title: "A dashboard in your pane",
          payoff: "Stat tiles, a chart and a diagram appear beside your terminal -- then change while you watch.",
          why_it_matters: <<~WHY.strip,
            A terminal can print a table faster than any browser can draw one. What it
            cannot do is show you a row of KPI tiles, a chart and a diagram at the same
            time -- and then update all three in place while you keep typing.

            That is the whole pitch in sixty seconds. Your agent pushes arbitrary UI into
            a pane it controls, and re-pushes as the numbers move. No HTML, no server to
            stand up by hand, no page reload.
          WHY
          prompt: <<~PROMPT.strip,
            #{VERIFY_RULE}

            Housekeeping first: run `streamweaver canvas-list` and close any leftover
            University demo session with `streamweaver canvas-close <name>` (the demo
            sessions this course uses are `dashboard`, `decision` and `doc-demo`). Never
            close `university` -- that is the controller I am driving the course from.

            Now tell me in the terminal what you are about to do, then do it.

            Open a pane with `streamweaver panel dashboard`. Write ONE DSL file holding
            all three of: a row of KPI tiles (`stat_display value:, label:`); a bar chart
            written in the explicit form `chart type: :bar, data: { labels: [...],
            datasets: [{ data: [...] }] }` (not the `bar_chart` shorthand); and a
            `mermaid` sequenceDiagram of the very command you are about to run -- you,
            the streamweaver CLI, the canvas bridge, this pane. Push it with
            `streamweaver canvas-push dashboard < your_file.rb` and say so in the
            terminal.

            Then push the SAME file twice more, a few seconds apart, changing the tile
            numbers and the chart bars each time -- and narrate each push in the terminal
            as you make it, so I can watch the pane change while I read what you are
            doing.
          PROMPT
          what_you_should_see: [
            "One push, and the pane holds KPI tiles, a chart and a diagram at once -- three things a terminal cannot draw.",
            "The mermaid diagram describes the canvas-push that put it there: agent, CLI, bridge, pane.",
            "Two more pushes a few seconds later change the numbers in place -- no reload, no flicker.",
            "Your agent said what it was about to do before each push, so the terminal reads like a narration of the pane."
          ]
        },
        {
          number: 2,
          title: "Six lines of Ruby",
          payoff: "Run a real app and watch the block re-run on every click.",
          why_it_matters: <<~WHY.strip,
            StreamWeaver's whole trick is one idea: your DSL block re-executes on
            every interaction. There is no event-handler code to write -- state
            changes, the block runs again, the page reflects it.

            Once that model clicks, everything else in StreamWeaver -- forms,
            canvas, the doc theme -- is just this same loop wearing different clothes.
          WHY
          prompt: <<~PROMPT.strip,
            #{VERIFY_RULE}

            Close step 1's demo pane first: `streamweaver canvas-close dashboard`. Leave
            `university` alone -- that is the controller. Then tell me what you are about
            to do before you do it.

            For any DSL syntax question, run `streamweaver llm` FIRST -- it is the
            canonical reference, it is one command, and its counter example is exactly
            this app. Do not dispatch a search agent to grep the repo for it.

            Now write the app: a button that increments a counter held in `state`, and a
            line of text showing the count. The app block really is six lines, but the
            file is eight, and the two extra lines are the ones people leave out: `require
            'stream_weaver'` on line 1, and `.run!` chained onto the block's closing `end`
            (`end.run!`). Without the first you get `NoMethodError: undefined method
            'app'`; without the second the process builds the app, starts no server, and
            exits silently. Write both deliberately.

            Start it with `ruby app.rb` as a BACKGROUND task -- say out loud that it is a
            background task, tell me the port StreamWeaver picked, and tell me you will
            kill it when we are done. StreamWeaver finds a free port and opens the browser
            itself; if the startup banner does not show up in the captured output, find
            the port with `lsof -i :4567-4620 -sTCP:LISTEN` rather than sleeping on the
            log.

            Click the button a few times and watch the count update after every click --
            that is the same DSL block re-running, not JavaScript.

            When I tell you I have seen it, kill that background task and confirm in the
            terminal that it is gone. Never leave a course demo server listening.
          PROMPT
          what_you_should_see: [
            "The browser opens on its own -- no port to guess, no URL to type.",
            "Each click updates the count immediately, with no page reload or spinner.",
            "The Ruby block you wrote ran again on every click; nothing else touched the page.",
            "Your agent said plainly that the app runs as a background task, offered to kill it, and did kill it at the end -- no orphaned server left behind.",
            "It wrote `require 'stream_weaver'` and `end.run!` on purpose, and said why -- the two lines the \"six-line app\" framing hides, and the two that cost real sessions a debug cycle each."
          ]
        },
        {
          number: 3,
          title: "Claude asks you a real question",
          payoff: "Your agent stops, shows you two architectures, and blocks until you decide.",
          why_it_matters: <<~WHY.strip,
            An agent that needs a decision from you has exactly one move in a terminal:
            print the question and wait for text. It cannot show you the two designs it
            is choosing between, lay them side by side, and let you pick one.

            Here it can. The same form has two modes -- blocking, where your agent's
            terminal freezes until you submit, and non-blocking, where the form stays
            live in the pane and the agent reads your answer whenever it needs it. This
            is the step where the canvas stops being a display and becomes an input.
          WHY
          prompt: <<~PROMPT.strip,
            #{VERIFY_RULE}

            Close step 2's demo first: kill the background `ruby app.rb` task if it is
            still running, and run `streamweaver canvas-close dashboard` if that session
            survived. Leave `university` open -- it is the controller.

            Before you build anything, say this in the terminal in your own words: that
            you are about to build the same decision twice -- once as a standalone app so
            I can compare, then as a canvas form you will BLOCK on -- and that following
            along here in the worker terminal is the best way to take this course, because
            your narration is half the lesson.

            First, standalone. Write an app with a `radio_group` offering two candidate
            architectures for something real in this repo, a `text_field` for my
            rationale, and a submit `button`. Run it as a background `ruby app.rb`. I
            click, it re-renders in place, nothing blocks. Kill it when I say I have seen
            it.

            Now the same question on the canvas, carrying the things a terminal prompt
            cannot. Open `streamweaver panel decision`, then push a DSL file holding: a
            `callout` reading, in your own words, "this is a blocking form -- Claude is
            waiting on you, and its terminal is frozen until you submit"; a `mermaid`
            diagram of the two candidate architectures; a `table` comparing them on three
            axes; then the same `radio_group`, `text_field` and submit `button`.

            Then run `streamweaver canvas-wait decision` and STOP. Your terminal must
            visibly block -- no output, no new prompt -- until I submit. When it returns,
            print the JSON verbatim and react to it: say what you would actually do
            differently given my choice AND the rationale I typed.

            Close with one beat: the same form left live, with no `canvas-wait` behind it,
            keeps its state in the pane, and you can read my answer back later whenever
            you need it. Blocking is a choice, not a limitation.
          PROMPT
          what_you_should_see: [
            "Your agent told you the plan before building anything -- standalone first, then the blocking canvas form.",
            "The canvas form carries a diagram and a comparison table right next to the choice; a terminal prompt can carry neither.",
            "A callout on the form says it in plain words: this is a blocking form, Claude is waiting on you.",
            "The worker terminal visibly freezes on `canvas-wait` until you press submit, then prints your answer as JSON -- including the free-text rationale -- and reacts to it.",
            "The closing beat: the same form left live without `canvas-wait` becomes state the agent can query later."
          ]
        },
        {
          number: 4,
          title: "A doc that writes itself",
          payoff: "Watch a script append sections, then save the result as a document.",
          why_it_matters: <<~WHY.strip,
            A canvas isn't limited to one static push -- a script can keep adding to the
            same session over time, and the pane updates each time without you touching
            anything. What grows is a real document: an outline, a two-column section,
            syntax-highlighted code, a callout, a rendered diagram.

            And then it is gone, unless you save it. That is the actual lesson of this
            step -- a canvas lives as long as the bridge does, and one button turns it
            into a file you keep.
          WHY
          prompt: <<~PROMPT.strip,
            #{VERIFY_RULE}

            Close step 3's demo first: `streamweaver canvas-close decision`, and kill the
            standalone app if it is still running. Leave `university` open. Then tell me
            what is about to happen before it happens.

            Open the pane with `streamweaver panel doc-demo --theme=doc`. Then run the
            growing-doc script that ships inside the stream_weaver gem -- no path to type:

            ruby -e "require 'stream_weaver'; require 'stream_weaver/university/scripts/growing_doc'" doc-demo

            Narrate it while it runs: the script pushes the same session four times, a
            few seconds apart, and each push carries everything before it plus one more
            piece -- a doc header and outline, then a two-column section, then a
            syntax-highlighted code block and a callout, then a mermaid diagram.

            When it settles, tell me to click the floating "Save as doc" button at the
            bottom right of the pane, and explain the dialog I will get: typing a name
            and pressing Save writes a permanent, git-tracked
            `docs/streamweaver_canvas/<name>.rb`, while "Save as Org" writes the same
            content as a plain-text `.org` sibling. That file is the whole point -- it is
            what step 5 takes with it. Everything else on a canvas lives only as long as
            the bridge does.
          PROMPT
          what_you_should_see: [
            "The pane grows a new section every few seconds -- you can watch it happen, not just see the end state.",
            "What grows is a document, not three cards: a header and outline, a two-column section, a code block, a callout, and a rendered diagram.",
            "The outline on the left fills in as each section arrives.",
            "The floating \"Save as doc\" dialog offers two formats -- Save writes docs/streamweaver_canvas/<name>.rb, Save as Org writes the .org sibling -- and your agent explained which is which before you clicked."
          ]
        },
        {
          number: 5,
          title: "Take the doc with you",
          payoff: "Export to org, drop it in a gist, read it anywhere.",
          why_it_matters: <<~WHY.strip,
            A canvas doc only exists while StreamWeaver is running -- until you
            export it. `.org` is a plain-text format GitHub already renders
            reasonably, and a gist is the fastest way to hand it to someone who
            has never heard of StreamWeaver.

            The last step is seeing the difference for yourself: plain GitHub
            rendering versus the same file through the StreamWeaver Doc Viewer
            extension.
          WHY
          prompt: <<~PROMPT.strip,
            #{VERIFY_RULE}

            Before anything else, run `gh auth status`. If the `gh` CLI is missing or not
            authenticated, tell me exactly that, tell me how to fix it (`brew install gh`
            then `gh auth login`), and stop -- do not fake the gist half of this step.

            Then tell me what you are about to do, and find the doc I saved in the
            previous step. Do not assume the path: the Save-as-doc dialog writes relative
            to the canvas bridge's working directory, which is often not this shell's, so
            check `docs/streamweaver_canvas/` AND `~/.streamweaver/canvas/` and tell me
            where it actually landed. Run `streamweaver org-export <that file>` to produce
            a sibling `.org` next to it, and show me the first few lines so I can see it
            is plain text.

            Push that `.org` to a gist with `gh gist create --public <that .org file>`
            (public on purpose -- this step ends with the file being opened and compared
            in a browser), then give me the gist URL and show me the plain GitHub
            rendering. That much is yours to finish.

            The last beat is NOT. Stop and hand it to me, and say why in plain words: no
            automated or headless browser can install a Chrome Web Store extension or see
            my logged-in Chrome, so this part is structurally out of your reach no matter
            which browser tool you have. Do not attempt it and do not skip it silently.
            Give me the StreamWeaver Doc Viewer link from this project's README, tell me
            to install it, reload the gist in my own Chrome and click "View rendered", and
            then wait for me to tell you what I saw -- the same file, now carrying the
            outline, two-column section, code block, callout and diagram it had in the
            canvas.

            Finish by cleaning up after the whole course: `streamweaver canvas-close
            doc-demo`, then `streamweaver canvas-list` and close every remaining demo
            session (`dashboard`, `decision`, `doc-demo`). Leave only `university` -- the
            controller. Kill any background app task still running, and confirm in the
            terminal that nothing but the controller is left.
          PROMPT
          what_you_should_see: [
            "Your agent checked `gh auth status` first and told you up front if gh was missing or logged out, instead of failing halfway through.",
            "`org-export` writes a .org file next to the doc -- no network access, no server.",
            "`gh gist create --public` prints a gist URL you can open right away, and your agent shows you the plain GitHub rendering itself.",
            "Then it stops and hands the extension step back to you, saying why: no automated or headless browser can install a Web Store extension or reach your logged-in Chrome. It gives you the link and waits -- it does not try, and it does not quietly skip.",
            "Plain GitHub already reads the .org file close to markdown; once you install it, the extension's \"View rendered\" button brings back the outline, two-column section, code block, callout and diagram exactly as they looked in the canvas.",
            "Every demo session from steps 1-4 is closed at the end -- `streamweaver canvas-list` shows only `university`, the controller you have been driving from."
          ]
        }
      ].freeze

      def self.step(number)
        GETTING_STARTED_STEPS.find { |s| s[:number] == number.to_i }
      end

      # What the runner sends to the worker session, and what the canvas
      # offers for copying when it can't send. nil for a step number the
      # course doesn't have (the runner reports that as :unknown_step);
      # `fetch` rather than `dig` so a curriculum entry written without a
      # `prompt:` raises for its author instead of masquerading as one.
      def self.prompt_for(number)
        step(number)&.fetch(:prompt)
      end

      # Rendered dormant on the course-list shelf, no controls -- names and
      # blurbs only, per docs/university/design-spec.md section 2.
      FUTURE_COURSES = [
        {
          name: "Docs deep dive",
          blurb: "Org export, gists, and the reader extension, end to end."
        },
        {
          name: "Canvas modes",
          blurb: "Stateful, blocking, and streaming — when to reach for each."
        },
        {
          name: "Skills and panels",
          blurb: "Teach your agent to drive the canvas without you."
        }
      ].freeze
    end
  end
end
