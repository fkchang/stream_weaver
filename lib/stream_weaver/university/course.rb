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
    module Course
      GETTING_STARTED_STEPS = [
        {
          number: 1,
          title: "A card in your pane",
          payoff: "Push a card to the canvas beside your terminal without writing any HTML.",
          why_it_matters: <<~WHY.strip,
            Every terminal tool eventually needs to show something richer than text --
            a status, a diff, a form. StreamWeaver's canvas is that surface: a second
            pane next to your terminal that your agent controls directly.

            Nothing to design, no server to stand up by hand. Push a card, watch it
            appear -- the whole loop is one command.
          WHY
          prompt: <<~PROMPT.strip,
            Using stream_weaver, open a canvas session named `hello` with
            `streamweaver panel hello` -- it splits this pane and opens a browser
            tab beside it. Then write a tiny script -- a header and one line of
            text, nothing else -- and push it in with
            `streamweaver canvas-push hello < your_file.rb`.

            Confirm the card shows up in the pane you just opened.
          PROMPT
          what_you_should_see: [
            "The canvas pane switches to your card the moment the push command returns.",
            "The card shows exactly the header and text your script wrote -- nothing you didn't ask for.",
            "One push, one card -- no page reload, no boilerplate."
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
            Using stream_weaver, write a 6-line app: a button that increments a
            counter held in `state`, and a line of text showing the count. Run it
            with `ruby app.rb` -- StreamWeaver finds a free port and opens the
            browser for you; read the URL it prints.

            Click the button a few times and watch the count update after every
            click -- that's the same DSL block re-running, not JavaScript.
          PROMPT
          what_you_should_see: [
            "The browser opens on its own -- no port to guess, no URL to type.",
            "Each click updates the count immediately, with no page reload or spinner.",
            "The Ruby block you wrote ran again on every click; nothing else touched the page."
          ]
        },
        {
          number: 3,
          title: "One form, two modes",
          payoff: "The same form stays live, or blocks and waits for one answer.",
          why_it_matters: <<~WHY.strip,
            Terminal tools make you pick one: a form that stays live, or a prompt
            that blocks until you answer. StreamWeaver runs the same form both ways.

            You will write it once, change the call that consumes it, and watch the
            behaviour flip. That is the thing a TUI cannot do.
          WHY
          prompt: <<~PROMPT.strip,
            Using stream_weaver, write a small app with a radio_group and a button
            that stores the choice in state and keeps rendering after each click.
            Run it with `ruby app.rb` and click through it -- the page updates in
            place every time.

            Then push the same form to a canvas session (`streamweaver panel
            form-demo`, then `streamweaver canvas-push form-demo < your_file.rb`)
            and block on it with `streamweaver canvas-wait form-demo`. This time
            the script freezes until you click, then prints your answer as JSON
            in the terminal.
          PROMPT
          what_you_should_see: [
            "Click a different option and the page re-renders in place -- nothing blocks.",
            "The second version freezes your terminal until you click, then prints your answer as JSON.",
            "Same six lines of DSL -- only the call that consumes the form changed."
          ]
        },
        {
          number: 4,
          title: "A doc that writes itself",
          payoff: "Watch a script append sections, then save the result as a document.",
          why_it_matters: <<~WHY.strip,
            A canvas isn't limited to one static push -- a script can keep adding
            to the same session over time, and the pane updates each time without
            you touching anything.

            That's how a long report gets built: push, wait, push again -- then
            save the result once you like what you see.
          WHY
          prompt: <<~PROMPT.strip,
            Using stream_weaver, open a canvas session named `doc-demo` with
            `streamweaver panel doc-demo`. Then run the growing-doc script that
            ships inside the stream_weaver gem -- no path to type:

                ruby -e "require 'stream_weaver'; require 'stream_weaver/university/scripts/growing_doc'" doc-demo

            Watch the pane grow a new section every couple of seconds. When it's
            done, click the canvas's floating "Save as doc" button to save what
            you built.
          PROMPT
          what_you_should_see: [
            "A new paragraph appears in the pane every couple of seconds, with nothing else on the page changing.",
            "By the third push the pane reads as one growing document, not three separate cards.",
            "The floating \"Save as doc\" button turns your last push into a permanent file under docs/streamweaver_canvas/."
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
            Using stream_weaver, take the doc you saved in the previous step --
            `docs/streamweaver_canvas/doc-demo.rb` if you kept the suggested name
            -- and run `streamweaver org-export docs/streamweaver_canvas/doc-demo.rb`
            to produce a sibling `.org` file next to it.

            Push that `.org` file to a gist with
            `gh gist create docs/streamweaver_canvas/doc-demo.org`, then open the
            gist URL it prints. Look at it once as plain GitHub rendering, then
            install the StreamWeaver Doc Viewer extension (linked in this
            project's README) and look again -- same file, a "View rendered"
            button now renders it exactly as it looked in the canvas.
          PROMPT
          what_you_should_see: [
            "`org-export` writes a .org file next to the doc -- no network access, no server.",
            "`gh gist create` prints a gist URL you can open right away.",
            "Plain GitHub already reads the .org file close to markdown; the extension's \"View rendered\" button renders the same file exactly as it looked in the canvas."
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
