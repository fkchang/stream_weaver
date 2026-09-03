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
    # Rules every step's content obeys (Forrest, after the live UAT rounds
    # of 2026-09-03 -- see features/university-getting-started.context.md,
    # "Course content law"):
    #
    # 1. Never show what a TUI already does, and does faster. Each step has
    #    to earn its minute with a capability delta -- live arbitrary UI,
    #    charts, diagrams, a blocking visual decision, a growing styled doc,
    #    portability. "The agent could have just printed that" means the
    #    step failed.
    # 2. CANNED ARTIFACTS, NARRATING AGENT (round 5). The worker never
    #    concocts demo DSL live and never reads a source checkout: every
    #    demo ships finished inside the gem and is reached through
    #    `streamweaver university-demo <name>`. Round 5 measured ~5 minutes
    #    to first paint with the agent composing; the fix is to run first
    #    and narrate after, so the explanation lands on something the user
    #    can already see.
    # 3. Verifying and presenting are different jobs (VERIFY_RULE vs
    #    PRESENT_RULE). Round 5 curl-verified step 2 and then never showed
    #    it to the user at all.
    # 4. Every prompt opens with previous-step cleanup as ONE backgrounded
    #    command that nothing waits on (`cleanup_line`), so housekeeping
    #    never sits between the user and the demo. The demo sessions are
    #    `dashboard` (step 1), `decision` (step 3) and `doc-demo` (step 4);
    #    `university` is the controller canvas the user drives the course
    #    from and is never closed.
    module Course
      # Mined from the two real worker sessions
      # (docs/university/worker-session-mining.md): both reached for `curl`
      # and the app's own action log before any browser, and one burned a
      # tool call plus a visible reasoning detour reflexively reaching for a
      # browser MCP its own config forbids. Same line on every step so
      # neither is rediscovered per step. Interpolated into each prompt
      # rather than repeated, so the five can never drift.
      VERIFY_RULE = "VERIFY (for you, silently): prove it with `curl` and the app's own " \
                    "logs -- a POST to `.../action/...` returning 200, plus the expected " \
                    "text in the HTML that comes back, is proof the DSL block re-ran " \
                    "server-side. Verification is yours alone: it opens nothing and shows " \
                    "me nothing. Use a headless/automation browser only if this session is " \
                    "already configured with one, and never fetch or install a new browser " \
                    "tool mid-course."

      # Round-5 UAT's biggest content failure was not a bug: step 2 was
      # verified with curl and then never shown to the user at all, and step
      # 3 made the user find and open a page themselves. Verifying and
      # presenting are two different jobs with two different tools, so they
      # are now two different rules and every prompt carries both.
      #
      # The second mining pass (docs/university/worker-session-mining.md,
      # "Round-5 latency + portability pass") added the portability half: a
      # real session shelled a personal skill path to show the user a page,
      # which would not exist on a coworker's machine, and baked a
      # dynamically-discovered bridge port into commands it printed.
      PRESENT_RULE = "PRESENT (for me): when something is meant for my eyes, open it in MY " \
                     "own default browser -- `open <url>` on macOS, `xdg-open <url>` on " \
                     "Linux -- or let `streamweaver panel` open the pane itself. Never use " \
                     "browser automation to show me something; that renders into your " \
                     "session, not mine. Never set SW_NO_OPEN on a run I am meant to " \
                     "interact with. And never hand me a command with a discovered port " \
                     "baked into it -- ports move between runs and machines; give me the " \
                     "URL that was printed, or a command that resolves the port itself."

      # One backgrounded command, at the very start, that nothing waits on.
      # Round-5 UAT measured ~5 minutes to first paint; serialized
      # housekeeping in front of the demo was part of it, and none of it is
      # anything the user came to watch.
      def self.cleanup_line(*sessions)
        closes = sessions.map { |s| "streamweaver canvas-close #{s}" }.join('; ')
        "Housekeeping, backgrounded, first line, waited on by nothing: " \
          "`( #{closes} ) >/dev/null 2>&1 &`. Kill any background app task from an earlier " \
          "step the same way. Never close `university` -- that is the controller canvas I am " \
          "driving this course from. Then go straight to the demo; do not report on the cleanup."
      end

      # Referenced by `closing_ritual` below while GETTING_STARTED_STEPS
      # itself is still being built (its own step hashes call
      # `closing_ritual`, so the array constant does not exist yet at that
      # point) -- mirrors why VERIFY_RULE/PRESENT_RULE/cleanup_line are also
      # plain methods/constants rather than reaching into the array.
      TOTAL_STEPS = 5

      # Round-6 UAT: with no fixed sign-off, a worker either kept talking
      # past a finished demo or went quiet with the user unsure the step was
      # actually done. Every prompt now ends on the exact same two lines, so
      # "done" always looks the same and always names the one next action --
      # click Mark done -- rather than the worker inventing its own closing
      # line. Step 5 has no next step to advance to, so its own variant below
      # points at the course recap instead of "step N+1".
      def self.closing_ritual(number)
        intro = "✅ Step #{number} demo complete -- play with it as long as you like."
        next_hint = if number >= TOTAL_STEPS
                      "When ready: go to the StreamWeaver University window and click Mark done -- " \
                      "that closes out the course and shows you the recap of everything you just ran."
                    else
                      "When ready: go to the StreamWeaver University window and click Mark done -- " \
                      "that advances you to step #{number + 1} (then click Run on it)."
                    end
        "#{intro}\n\n#{next_hint}"
      end

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
            #{cleanup_line('dashboard', 'decision', 'doc-demo')}

            Then run these two commands immediately, before you explain anything. Getting
            something on my screen inside the first minute is the point of this step; the
            explanation is worth more once I can see what you are explaining.

            streamweaver panel dashboard
            ruby "$(streamweaver university-demo dashboard)" dashboard

            The demo is a finished file that ships inside the stream_weaver gem. Do not
            write your own, and do not go looking for a source checkout -- there may not
            be one on this machine.

            NOW narrate what is on my screen: KPI tiles, a Chart.js bar chart and a
            rendered mermaid sequence diagram, all in one push. Point out that the diagram
            is a picture of the command you just ran -- you, the CLI, the bridge, this
            pane. Then read the demo file (`streamweaver university-demo dashboard` prints
            its path) and show me the eight or so lines of DSL that produced all three.

            Then mutate it while I watch, a few seconds apart, saying what changes before
            each one:

            ruby "$(streamweaver university-demo dashboard)" dashboard 2
            ruby "$(streamweaver university-demo dashboard)" dashboard 3

            Same layout, new numbers, in place -- no reload, no flicker, no page I had to
            open.

            That third push was the last one for this step -- say so plainly: "That was
            the final push -- the dashboard is done." Then stop moving the pane for a
            moment and invite me to actually look at it: the mermaid diagram is not
            decoration, it is the mechanism -- it names you, the CLI, the bridge and this
            pane, the exact chain that just drew everything else on screen.

            #{VERIFY_RULE}

            #{PRESENT_RULE}

            #{closing_ritual(1)}
          PROMPT
          what_you_should_see: [
            "Something is on your screen within seconds -- your agent ran the demo first and explained it after, instead of composing one while you waited.",
            "One push, and the pane holds KPI tiles, a chart and a diagram at once -- three things a terminal cannot draw.",
            "The mermaid diagram describes the canvas-push that put it there: agent, CLI, bridge, pane.",
            "Two more pushes a few seconds later change the numbers in place -- no reload, no flicker.",
            "The demo came out of the installed gem, not out of this repo -- your agent ran `streamweaver university-demo dashboard` and never went looking for a checkout."
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
            #{cleanup_line('dashboard')}

            Then start the app immediately, as a BACKGROUND task, before explaining
            anything:

            ruby "$(streamweaver university-demo counter)"

            That is a finished eight-line file inside the stream_weaver gem. Do not write
            your own version and do not go looking for a source checkout. Do NOT set
            SW_NO_OPEN -- this app is meant to open in MY browser, and it opens itself.

            The browser should already be up. If the startup banner did not reach your
            captured output, find the port with `lsof -i :4567-4620 -sTCP:LISTEN` rather
            than sleeping on the log, and open that URL for me the way the PRESENT rule
            below says.

            NOW narrate. Print the file -- nine lines now, `streamweaver university-demo
            counter` prints its path -- and walk me through it:

            - The mechanism itself is still exactly six lines, in an eight-line file: four
              statements wrapped by `app "Counter" do` and `end.run!`. The two hidden
              bookends are `require 'stream_weaver'` on line 1, and `.run!` chained onto
              the block's closing `end`. Without the first you get `NoMethodError:
              undefined method 'app'`; without the second the process builds the app,
              starts no server, and exits silently. Both are in the file, on purpose.
            - The ninth line is new, and it is not part of the mechanism: a `callout` at
              the top of the block that introduces the app to whoever it opens for. Point
              at it on my screen and read it to me instead of paraphrasing it -- I may tab
              over here before your narration reaches me.
            - There is no event handler anywhere in it. Tell me to click `+1` a few times,
              and say what actually happens: the whole block re-executes, `state[:count]`
              is one higher when it does, so the `text` line renders a different number.
              That is the entire mechanism, and everything else in StreamWeaver is this
              loop wearing different clothes.

            Say plainly that the app is running as a background task and that you will
            kill it. When I say I have seen it, kill it and confirm it is gone -- never
            leave a course demo server listening.

            For any DSL syntax question, run `streamweaver llm` FIRST -- one command, the
            canonical reference, and its counter example is exactly this app. Do not
            dispatch a search agent to grep a repo for it.

            #{VERIFY_RULE}

            #{PRESENT_RULE}

            #{closing_ritual(2)}
          PROMPT
          what_you_should_see: [
            "The browser opens on its own within seconds -- no port to guess, no URL to type, and your agent did not quietly verify it with curl and move on without showing you.",
            "Each click updates the count immediately, with no page reload or spinner.",
            "The Ruby block ran again on every click; nothing else touched the page.",
            "Your agent printed all nine lines of the file it actually ran, and named `require 'stream_weaver'` and `end.run!` as the two the \"six-line app\" framing hides -- the two that cost real sessions a debug cycle each.",
            "A callout at the top of the app explains itself the moment it opens -- what it is and what to click -- in case you tab over here before the narration reaches you.",
            "It said plainly that the app runs as a background task, offered to kill it, and did kill it at the end -- no orphaned server left behind."
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
            #{cleanup_line('dashboard', 'decision')}

            PART ONE -- the founding loop. Run this now, as a BACKGROUND task, before
            explaining anything:

            ruby "$(streamweaver university-demo decision-form)"

            That is a finished file inside the stream_weaver gem: a mermaid diagram of two
            candidate architectures, a comparison table, a `radio_group` and a rationale
            `text_field`. Do not write your own and do not look for a source checkout.

            It runs through `run_once!`, which means it finds a free port, OPENS my browser
            itself, and BLOCKS until I submit. So: do not ask me to open anything, do not
            print a URL for me to click, and do not ask me to tell you when I am done. The
            page is already in front of me. Say one line -- "answer that, I am waiting" --
            and then wait for the process to exit.

            The moment it exits it prints my submitted state as JSON on stdout. Print that
            JSON verbatim and REACT to it: name the option I picked, quote the rationale I
            typed, and say what you would actually do differently because of it. That
            round trip -- your process blocked on a human, and resumed with their answer
            in hand -- is the whole step.

            PART TWO -- the same file, a second surface. Say that plainly, because it is
            the lesson: not a second form, the same one.

            streamweaver panel decision
            ruby "$(streamweaver university-demo decision-form)" canvas decision

            Same context, same `radio_group`, same `text_field` -- now on the canvas,
            with a callout saying you are frozen, and an explicit submit button.

            Then wait on it -- and how you wait is itself worth saying out loud. Run
            `streamweaver canvas-wait decision` AS A BACKGROUND TASK from the start, not
            in the foreground. A foreground wait on a human will blow past your harness's
            foreground-block ceiling, get demoted to a background task anyway, and cost
            minutes in polling lag on the way back. A blocking wait on a human is a
            background job with a completion notification, and that is how an agent should
            wait on a person. The moment the notification lands, read the result and react
            to it immediately -- do not sit in a poll loop.

            Close on one beat: the same form left live with no `canvas-wait` behind it
            keeps its state in the pane, and you can read my answer back whenever you need
            it. Blocking is a choice, not a limitation.

            #{VERIFY_RULE}

            #{PRESENT_RULE}

            #{closing_ritual(3)}
          PROMPT
          what_you_should_see: [
            "The browser opened by itself with a real question in it -- you never opened a page, never copied a URL, and never had to tell your agent you were done.",
            "The form carries a rendered diagram of both designs and a comparison table right next to the choice; a terminal prompt can carry neither.",
            "The moment you submitted, your agent printed the JSON verbatim and reacted to it -- naming your choice and quoting the rationale you typed.",
            "Then the same file, unchanged, appeared on the canvas -- your agent said so out loud: one artifact, two surfaces.",
            "It waited on the canvas form as a background task and said why: a blocking wait on a human is a background job with a notification, not a frozen foreground prompt.",
            "The closing beat: the same form left live without `canvas-wait` becomes state the agent can query later."
          ]
        },
        {
          number: 4,
          title: "A doc that writes itself",
          payoff: "Watch a script write a document, save it, then ask you what else it should say.",
          why_it_matters: <<~WHY.strip,
            A canvas isn't limited to one static push -- a script can keep adding to the
            same session over time, and the pane updates each time without you touching
            anything. What grows is a real document: an outline, a two-column section,
            syntax-highlighted code, a callout, a rendered diagram, a table.

            Then the interesting half. The script saves the doc itself and tells you where
            it went -- and your agent asks what else it should say, blocks on your answer,
            adds it, and saves again. That loop is the point: co-editing a document with an
            agent, in a pane, with no file open on either side.
          WHY
          prompt: <<~PROMPT.strip,
            #{cleanup_line('decision')}

            Then start the doc growing immediately, before explaining anything:

            streamweaver panel doc-demo --theme=doc
            ruby "$(streamweaver university-demo doc)" doc-demo

            Narrate it WHILE it runs -- it takes about twenty seconds and the pacing is
            the point. Each push carries everything before it plus one more section, so
            the page grows instead of blinking: a doc header, a two-column comparison, a
            syntax-highlighted code block and a callout, a mermaid diagram, a table of
            what survives an export, and a closing section. Six outline entries, which is
            what makes the sidebar nav in step 5 worth looking at.

            The script narrates its own progress to stdout so you don't have to guess when
            a push landed: a `stage N/7 pushing: <name>` line right before each one, and a
            `stage N/7 pushed: <name>` line right after. Watch that stream and say
            something to me the moment each stage lands -- do not wait for the whole run
            to finish and then summarize it in one breath at the end. That is what "while
            it runs" means here.

            The script saves the document itself, through the same `save-doc` endpoint the
            floating button calls, under the deterministic name `university-doc`, and
            prints the exact path it landed at. Read that path back to me verbatim -- step
            5 uses that file, and you are not to make me transcribe anything.

            THEN, and only then, invite me to do it by hand: there is a floating "Save as
            doc" button at the bottom right of the pane. Tell me to click it, and explain
            the dialog before I do -- typing a name and pressing Save writes a permanent,
            git-tracked `docs/streamweaver_canvas/<name>.rb`; "Save as Org" writes the
            same content as a plain-text `.org` sibling. Say what the two formats are for,
            not just what they're named: `.rb` is full fidelity -- StreamWeaver can
            re-render and extend it again later, exactly as it looked here. `.org` is the
            portable half -- plain text, human-readable anywhere with nothing to install,
            and the StreamWeaver Doc Viewer extension (step 5) makes that same file
            beautiful again without needing StreamWeaver at all. Mine is a bonus lap. Step
            5 uses yours.

            THE TWEAK LOOP. Now tell me the doc is mine to change for as long as I like,
            and offer to extend it -- and say what you are doing as you do it: "I am using
            the same blocking form from step 3 to ask you a real question. This is how an
            agent and a human co-edit a document."

            ruby "$(streamweaver university-demo doc)" doc-demo --picker

            That appends a picker to the bottom of the doc: a `radio_group` of sections
            not yet in it (the visible choice IS the exact `--extend` key -- read a
            legend line above the choices for what each one means), a free-text field,
            and a "done, move on" option. Wait on it with `streamweaver canvas-wait
            doc-demo` AS A BACKGROUND TASK -- same rule as step 3, never a foreground
            block on a human -- and react the moment the notification lands.

            If I pick a canned section, add it and re-save in one command, using the key
            exactly as it appeared on the radio choice -- do not paraphrase or shorten it:

            ruby "$(streamweaver university-demo doc)" doc-demo --extend=<key>

            (Keys accumulate: `--extend=timeline,cheatsheet` for two.) The command tells
            you plainly -- an OK line per key it recognized, a FAILED line per key it did
            not, and it exits non-zero if anything failed. Still VERIFY before telling me
            anything landed: curl the `doc-demo` session (or read the command's own
            OK/FAILED output) and grep for the new section's heading text. Only then say
            it is there -- a push that silently no-op'd once looked identical to a
            successful one. If I typed a description instead, write that section yourself
            -- and keep it to `doc_section_header`, `md`, `table headers:/rows:`,
            `comparison`, `code_block`, `callout` and `mermaid`. Those are exactly the
            components `streamweaver org-export` recognizes; anything else looks right in
            the pane and then leaves as an unrecognized placeholder, silently, which is
            the failure step 5 exists to disprove.

            Then push the picker again and loop, until I choose "done". Say the saved path
            once more at the end.

            #{VERIFY_RULE}

            #{PRESENT_RULE}

            #{closing_ritual(4)}
          PROMPT
          what_you_should_see: [
            "The pane grows a new section every few seconds -- you watch it happen, you don't just see the end state.",
            "What grows is a document, not three cards: a header and outline, a two-column section, a code block, a callout, a rendered diagram and a table.",
            "The outline on the left fills in as each section arrives, and ends up long enough to be worth navigating.",
            "Your agent saved the doc itself and read you the exact path -- no dialog to fill in, nothing to transcribe. The floating \"Save as doc\" button is then offered to you as a bonus lap, with the dialog explained before you click.",
            "Then it asks what else the doc should say, using the same blocking form from step 3, and says so -- adds your pick, re-pushes, re-saves, and asks again until you say you're done. That is co-editing a document with an agent, with no file open on either side."
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
            Before anything else, run `gh auth status`. If the `gh` CLI is missing, not
            logged in, or logged in without the `gist` scope, say exactly which of those
            it is, and hand it back friendly and concrete: `brew install gh`, then `gh auth
            login`, or `gh auth refresh -s gist` if it is only the scope that is missing.
            Then stop and wait for me. Do not fake the gist half of this step, and do not
            press on hoping it works.

            Then, with the doc still open in the `doc-demo` pane, show me what it grew
            into before it leaves. Point at two things I would otherwise walk past:

            - The outline. Six-plus sections is what earns a sidebar; in a pane this
              narrow the doc theme moves that nav to the top instead of the side, and it
              is the same nav either way. Scroll it, or click an entry, so I see it work.
            - The mermaid diagram's popout control -- a rendered diagram in a 750px pane
              is a thumbnail until you open it full size.

            Now take it with you. Step 4's script saved the doc under the deterministic
            name `university-doc` and printed the path; use that path. If you no longer
            have it, look in `docs/streamweaver_canvas/` AND `~/.streamweaver/canvas/`
            (the bridge's working directory is often not this shell's) and tell me where
            it actually is -- but do not make me name it.

            Run `streamweaver org-export <that file>` to write the sibling `.org`, and show
            me the first few lines so I can see it is plain text with no server behind it.
            Then `gh gist create --public <that .org file>` -- public on purpose, because
            this step ends with the file being opened and compared in a browser -- and give
            me the gist URL. Open it in MY browser, not yours.

            The last beat is NOT yours. Stop and hand it to me, and say why in plain words:
            no automated or headless browser can install a Chrome Web Store extension or
            see my logged-in Chrome, so this part is structurally out of your reach no
            matter which browser tool you have. Do not attempt it and do not skip it
            silently. Give me the StreamWeaver Doc Viewer link from this project's README,
            tell me to install it, reload the gist and click "View rendered", and then wait
            for me to tell you what I saw -- the same file, now carrying the outline, the
            two-column section, the code block, the callout and the diagram it had in the
            canvas.

            Finish by cleaning up after the whole course, backgrounded and in one line:
            `( streamweaver canvas-close dashboard; streamweaver canvas-close decision;
            streamweaver canvas-close doc-demo ) >/dev/null 2>&1 &`. Kill any background
            task still running. Then `streamweaver canvas-list` and confirm to me that
            only `university` -- the controller -- is left.

            #{VERIFY_RULE}

            #{PRESENT_RULE}

            #{closing_ritual(5)}
          PROMPT
          what_you_should_see: [
            "Your agent checked `gh auth status` first and told you up front if gh was missing, logged out, or short the gist scope -- with the exact command to fix it -- instead of failing halfway through.",
            "It pointed out the doc's own navigation before exporting it: the outline the six sections earned, moved to the top in a narrow pane, and the mermaid diagram's popout.",
            "It used the doc step 4 saved for you, at the path step 4 printed -- you never had to name a file.",
            "`org-export` writes a .org file next to the doc -- no network access, no server -- and `gh gist create --public` prints a gist URL that opens in your own browser.",
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
