# frozen_string_literal: true

module StreamWeaver
  module University
    # Curriculum data: what `streamweaver get-started` teaches, and what's
    # coming next. Plain data only -- no rendering, no ledger knowledge. The
    # `prompt:` on each Getting Started step is exactly what a later story
    # (`driver-worker-runner`) will send to a worker session, so it stays a
    # plain string here rather than markup or DSL.
    module Course
      GETTING_STARTED_STEPS = [
        {
          number: 1,
          title: "A card in your pane",
          payoff: "Push a card to the canvas beside your terminal without writing any HTML.",
          prompt: <<~PROMPT.strip
            Using stream_weaver, write a tiny script that pushes one card to a
            canvas session -- a header and a line of text, nothing else.
            Run it with `streamweaver canvas-push <name> < your_file.rb` and
            confirm the card shows up in the canvas pane beside this terminal.
          PROMPT
        },
        {
          number: 2,
          title: "Six lines of Ruby",
          payoff: "Run a real app and watch the block re-run on every click.",
          prompt: <<~PROMPT.strip
            Using stream_weaver, write a small app with a button that
            increments a counter held in state each time it's clicked.

            Run it and click the button a few times, watching the canvas
            re-render with the new count after every click.
          PROMPT
        },
        {
          number: 3,
          title: "One form, two modes",
          payoff: "The same form stays live, or blocks and waits for one answer.",
          prompt: <<~PROMPT.strip
            Using stream_weaver, write a small app with a radio_group and a button
            that stores the choice in state and keeps rendering after each click.
            Run it and click through it.

            Then show me the same form driven by `canvas-wait`, so the script blocks
            until I answer and prints my answer as JSON in the terminal.
          PROMPT
        },
        {
          number: 4,
          title: "A doc that writes itself",
          payoff: "Watch a script append sections, then save the result as a document.",
          prompt: <<~PROMPT.strip
            Using stream_weaver, write a script that pushes to one canvas
            session three times in a row -- a header, then the header plus a
            new section, then that plus one more section -- pausing a couple
            of seconds between each push so I can watch the doc grow.

            Finish by using the canvas's "Save canvas as doc" control to save
            what you built.
          PROMPT
        },
        {
          number: 5,
          title: "Take the doc with you",
          payoff: "Export to org, drop it in a gist, read it anywhere.",
          prompt: <<~PROMPT.strip
            Using stream_weaver, take the doc you saved in the previous step
            and run `streamweaver export` on it to produce a standalone HTML
            file that needs no server.

            Then confirm you can reopen the same source with
            `streamweaver canvas-read` and it renders the same content
            outside of any canvas session.
          PROMPT
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
