# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/university/course'
require 'stream_weaver/university/runner'

RSpec.describe StreamWeaver::University::Course do
  # Prompts are heredocs whose line wrapping is free to change; what
  # actually reaches the worker session is Runner.one_line's collapsed
  # single line. Every content assertion below runs against that, so
  # re-flowing a paragraph can never break a check -- and what the spec
  # pins is what the agent is really told.
  def prompt(number)
    step = described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == number }
    StreamWeaver::University::Runner.one_line(step[:prompt])
  end

  def step(number)
    described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == number }
  end

  describe 'GETTING_STARTED_STEPS' do
    it 'has exactly five steps, numbered 1 through 5 in order' do
      numbers = described_class::GETTING_STARTED_STEPS.map { |s| s[:number] }
      expect(numbers).to eq([1, 2, 3, 4, 5])
    end

    it 'gives every step a title, payoff, why_it_matters, prompt, and what_you_should_see' do
      described_class::GETTING_STARTED_STEPS.each do |step|
        expect(step[:title].to_s.strip).not_to be_empty
        expect(step[:payoff].to_s.strip).not_to be_empty
        expect(step[:why_it_matters].to_s.strip).not_to be_empty
        expect(step[:prompt].to_s.strip).not_to be_empty
        expect(step[:what_you_should_see]).to be_an(Array)
        expect(step[:what_you_should_see]).not_to be_empty
        step[:what_you_should_see].each { |line| expect(line.to_s.strip).not_to be_empty }
      end
    end

    # Course content law (features/university-getting-started.context.md):
    # every step earns its minute with something a TUI cannot do. These are
    # the presence checks for each step's capability delta -- the live
    # behaviour itself is UAT.
    it 'has step 1 open the pane and run the canned dashboard demo' do
      expect(prompt(1)).to include('streamweaver panel dashboard')
      expect(prompt(1)).to include('ruby "$(streamweaver university-demo dashboard)" dashboard')
      # Three pushes: the first, then two that mutate the numbers live.
      expect(prompt(1)).to include('dashboard 2')
      expect(prompt(1)).to include('dashboard 3')
      # What the demo carries is narrated, not authored.
      expect(prompt(1)).to match(/KPI tiles/i)
      expect(prompt(1)).to match(/bar chart/i)
      expect(prompt(1)).to include('mermaid')
    end

    it 'has step 2 run the canned counter demo standalone (no canvas push)' do
      expect(prompt(2)).to include('ruby "$(streamweaver university-demo counter)"')
      expect(prompt(2)).not_to include('canvas-push')
    end

    # The governing round-5 change: canned artifacts, narrating agent. A
    # worker that composes its own demo costs minutes of dead air, and one
    # real session went looking for a source checkout to do it -- which a
    # `gem install` user does not have.
    it 'reaches every demo through `streamweaver university-demo`, never a path' do
      (1..5).each do |n|
        next if n == 5 # step 5 consumes step 4's saved doc, it runs no demo of its own

        expect(prompt(n)).to include('streamweaver university-demo'),
                             "step #{n} does not run a canned demo"
      end
    end

    it 'never sends the worker to a source checkout for a demo' do
      (1..5).each do |n|
        expect(prompt(n)).not_to match(%r{/Users/|~/\w|lib/stream_weaver/university/demos})
      end
      [1, 2, 3].each do |n|
        expect(prompt(n)).to match(/do not (?:go looking for|look for) a source checkout/i),
                             "step #{n} never rules out hunting for the repo"
      end
    end

    # Round 5 measured ~5 minutes to first paint. Housekeeping in front of
    # the demo was part of it, and none of it is what the user came to see.
    it 'backgrounds the previous-step cleanup instead of serializing it' do
      (1..4).each do |n|
        expect(prompt(n)).to include('>/dev/null 2>&1 &'),
                             "step #{n}'s cleanup is not backgrounded"
        expect(prompt(n)).to match(/waited on by nothing/i)
      end
    end

    it 'runs the demo before explaining it, on every step that has one' do
      [1, 2, 3, 4].each do |n|
        expect(prompt(n)).to match(/before (?:you )?explain(?:ing)? anything/i),
                             "step #{n} does not put the demo before the narration"
      end
    end

    # Mined from the two real worker sessions
    # (docs/university/worker-session-mining.md): both verified with curl and
    # the action log before touching a browser, and one wasted a tool call
    # reflexively reaching for a browser MCP its own config forbids.
    it 'carries the same verification preamble on every step' do
      (1..5).each do |n|
        expect(prompt(n)).to include(
          StreamWeaver::University::Runner.one_line(described_class::VERIFY_RULE)
        )
      end
    end

    # Round 5's biggest content failure was not a bug: step 2 was
    # curl-verified and then never shown to the user at all, and step 3 made
    # the user find and open a page themselves. Verifying and presenting are
    # two different jobs, so they are two different rules.
    it 'carries the present rule alongside the verify rule on every step' do
      (1..5).each do |n|
        expect(prompt(n)).to include(
          StreamWeaver::University::Runner.one_line(described_class::PRESENT_RULE)
        )
      end
    end

    it 'tells every step to prove it with curl and logs, silently' do
      (1..5).each do |n|
        expect(prompt(n)).to include('`curl`')
        expect(prompt(n)).to match(/never fetch or install a new browser tool/i)
        expect(prompt(n)).to match(/opens nothing and shows me nothing/i)
      end
    end

    # Env portability (worker-session-mining.md, "Round-5 latency +
    # portability pass"): a real session shelled a personal skill path to
    # show the user a page, and baked a discovered bridge port into commands
    # it printed. Neither survives a coworker's machine.
    it 'presents through the user own default browser, never browser automation' do
      (1..5).each do |n|
        expect(prompt(n)).to include('`open <url>`')
        expect(prompt(n)).to match(/never use browser automation to show me/i)
        expect(prompt(n)).to match(/never set SW_NO_OPEN/i)
        expect(prompt(n)).to match(/never hand me a command with a discovered port/i)
      end
    end

    it 'has step 2 name the background task and kill it at the end' do
      expect(prompt(2)).to include('BACKGROUND task')
      expect(prompt(2)).to match(/kill it and confirm it is gone/i)
      expect(step(2)[:what_you_should_see].join(' ')).to match(/background task/i)
    end

    # Live UAT (round-7): the worker took ages finding the app's port and
    # booted a SECOND instance to find it -- an orphaned duplicate server
    # and a terrible first impression. The fix is prompt-level: read the
    # port from your own captured stdout; never launch a second process.
    it 'tells step 2 to read the port from its own stdout, never boot a second instance' do
      expect(prompt(2)).to match(/read the `http:\/\/127\.0\.0\.1:<port>` line/i)
      expect(prompt(2)).to match(/NEVER run a second `ruby \.\.\.` to "find" the port/)
      expect(prompt(2)).to match(/duplicate, orphaned app/i)
    end

    # Two independent worker sessions hit two different startup failures on
    # this one step -- one omitted `require 'stream_weaver'`, the other
    # omitted `.run!`. The "6-line app" framing hides exactly those two
    # lines, so the prompt now names both and recounts honestly.
    it 'has step 2 name both bookend lines the six-line framing hides' do
      expect(prompt(2)).to include("`require 'stream_weaver'`")
      expect(prompt(2)).to include('`.run!`')
      expect(prompt(2)).to include('eight-line file')
      expect(prompt(2)).to include("NoMethodError: undefined method 'app'")
    end

    # Round-6 UAT: the app used to pop up with no explanation of itself. A
    # `callout` is now the ninth line of the file, deliberately outside the
    # six-line mechanism -- the prompt has to say so, not let the worker
    # fold it into "the eight lines" it just finished naming.
    it 'has step 2 name the ninth-line callout as separate from the six-line mechanism' do
      expect(prompt(2)).to match(/ninth line/i)
      expect(prompt(2)).to match(/not part of the mechanism/i)
      expect(prompt(2)).to include('`callout`')
    end

    it 'points step 2 at `streamweaver llm` instead of a search agent' do
      expect(prompt(2)).to include('`streamweaver llm`')
      expect(prompt(2)).to match(/do not dispatch a search agent/i)
    end

    # Round-5 UAT: step 3's standalone half was "puny", and the user had to
    # open the page themselves and then tell the agent they were done. Part
    # one is now a founding loop -- run_once! finds the port, opens the
    # browser, blocks, and hands back JSON with no human bookkeeping.
    it 'opens step 3 with a blocking standalone run the user never has to service' do
      expect(prompt(3)).to include('PART ONE')
      expect(prompt(3)).to match(/founding loop/i)
      expect(prompt(3)).to include('`run_once!`')
      expect(prompt(3)).to match(/OPENS my browser itself/i)
      expect(prompt(3)).to match(/do not ask me to open anything/i)
      expect(prompt(3)).to match(/do not ask me to tell you when I am done/i)
      expect(prompt(3)).to include('JSON')
    end

    it 'has step 3 push the SAME file to the canvas and say so' do
      expect(prompt(3)).to include('PART TWO')
      expect(prompt(3)).to include('streamweaver panel decision')
      expect(prompt(3)).to include('canvas decision')
      expect(prompt(3)).to match(/not a second form, the same one/i)
      expect(prompt(3)).to include('canvas-wait decision')
      expect(prompt(3)).to match(/no `canvas-wait` behind it/)
    end

    # Round-7 UAT: a worker-initiated push (unlike a Run submit) raises
    # nothing on its own, so the canvas variant sat unseen after PART ONE's
    # blocking form pulled attention to its own browser tab.
    it 'raises the canvas pane right after pushing it, before waiting' do
      push_at = prompt(3).index('canvas decision')
      raise_at = prompt(3).index('canvas-raise decision')
      wait_at = prompt(3).index('canvas-wait decision')

      expect(raise_at).not_to be_nil
      expect(push_at).to be < raise_at
      expect(raise_at).to be < wait_at
    end

    # Mined 2026-09-03 (worker-session-mining.md, "Round-5 latency +
    # portability pass"): a foreground `canvas-wait` blew past the harness's
    # 120s foreground ceiling, got demoted to a background task anyway, and
    # cost ~3.5 min of polling lag. Waiting on a human is a background job.
    it 'tells both waiting steps to background the blocking wait, as a named pattern' do
      [3, 4].each do |n|
        expect(prompt(n)).to match(/AS A BACKGROUND TASK/),
                             "step #{n} may foreground-block on a human"
      end
      expect(prompt(3)).to match(/foreground-block ceiling/i)
      expect(prompt(3)).to match(/how an agent should wait on a person/i)
    end

    it 'keeps the step 3 form to radio_group/select/text_field only (disc-098, disc-105)' do
      expect(prompt(3)).to include('`radio_group`')
      expect(prompt(3)).to include('`text_field`')
      expect(prompt(3)).not_to match(/checkbox_group|chip_group/)
    end

    it 'has step 4 run the growing-doc demo through the CLI, not a path' do
      expect(prompt(4)).to include('ruby "$(streamweaver university-demo doc)" doc-demo')
      expect(prompt(4)).to include('streamweaver panel doc-demo --theme=doc')
      expect(prompt(4)).not_to match(%r{/Users/|~/\w})
    end

    # Round-5 UAT: "save must be script-driven, not user homework." The
    # script saves under a deterministic name and reads the path back; the
    # floating button becomes a bonus lap the user is invited to try.
    it 'has step 4 save the doc itself, announce the path, then offer the manual save' do
      expect(prompt(4)).to include('university-doc')
      expect(prompt(4)).to match(/saves the document itself/i)
      expect(prompt(4)).to match(/read that path back to me verbatim/i)
      expect(prompt(4)).to match(/THEN, and only then, invite me to do it by hand/i)
      expect(prompt(4)).to include('Save as doc')
      expect(prompt(4)).to include('docs/streamweaver_canvas/<name>.rb')
      expect(prompt(4)).to include('Save as Org')
    end

    it 'has step 4 name the doc features that grow' do
      %w[two-column code callout mermaid table].each do |feature|
        expect(prompt(4)).to include(feature)
      end
    end

    # The co-edit loop (Forrest, 2026-09-03): step 4 ends open-ended, and
    # reuses step 3's blocking form deliberately -- the pedagogy is that
    # canvas-wait belongs in a real workflow, not just in a demo about
    # canvas-wait.
    it 'has step 4 offer an open tweak loop through the same blocking form as step 3' do
      expect(prompt(4)).to match(/TWEAK LOOP/i)
      expect(prompt(4)).to include('--picker')
      expect(prompt(4)).to include('--extend=')
      expect(prompt(4)).to match(/same blocking form from step 3/i)
      expect(prompt(4)).to match(/co-edit a document/i)
      expect(prompt(4)).to match(/until I choose "done"/i)
    end

    # A free-text request is authored live, so the prompt has to name the
    # org-export-safe component set or the section the agent writes silently
    # falls out of step 5's gist as a placeholder.
    it 'constrains step 4 free-text sections to org-export-safe components' do
      %w[doc_section_header md comparison code_block callout mermaid].each do |component|
        expect(prompt(4)).to include(component)
      end
      expect(prompt(4)).to include('table headers:/rows:')
      expect(prompt(4)).to match(/unrecognized placeholder/i)
    end

    # disc-094: `streamweaver export` drops Chart.js for the chart
    # shorthands, so anything that will be saved, org-exported and reopened
    # (step 4's doc, which step 5 carries out to a gist) must never name
    # one. Step 1's dashboard is live-canvas-only, and is told to use the
    # explicit `chart type:` form regardless -- asserted above.
    it 'keeps step 4 and 5 doc content free of chart shorthands (disc-094)' do
      %w[bar_chart hbar_chart line_chart area_chart pie_chart doughnut_chart
         stacked_bar_chart sparkline].each do |shorthand|
        [4, 5].each { |n| expect(prompt(n)).not_to include(shorthand) }
      end
    end

    it 'has step 5 check gh before exporting the step 4 doc and pushing it to a gist' do
      expect(prompt(5)).to start_with('Before anything else, run `gh auth status`')
      expect(prompt(5)).to include('org-export')
      expect(prompt(5)).to include('gh gist create --public')
      expect(prompt(5)).to include('StreamWeaver Doc Viewer')
    end

    # Env portability: `gh` present but short the gist scope is its own
    # failure, and it is the one that fails late and confusingly.
    it 'has step 5 hand a missing gh back with the exact command to fix it' do
      expect(prompt(5)).to include('`gist` scope')
      expect(prompt(5)).to include('brew install gh')
      expect(prompt(5)).to include('gh auth login')
      expect(prompt(5)).to include('gh auth refresh -s gist')
      expect(prompt(5)).to match(/do not fake the gist half/i)
    end

    # Round-5 UAT: the step-5 doc was too short for the nav to appear, and
    # the diagram popout went unmentioned. Both are payoffs the user walks
    # past unless they are pointed at.
    it 'has step 5 point out the sidebar nav and the mermaid popout' do
      expect(prompt(5)).to match(/outline/i)
      expect(prompt(5)).to match(/moves that nav to the top/i)
      expect(prompt(5)).to match(/popout/i)
    end

    # The real session discovered this live and improvised it well: name the
    # constraint, hand the click back, wait. No automated browser can install
    # a Web Store extension or reach the user's logged-in Chrome, so the
    # prompt owns the boundary instead of letting each agent rediscover it.
    it 'hands the extension moment back to the user instead of attempting it' do
      expect(prompt(5)).to match(/no\s+automated or headless browser/i)
      expect(prompt(5)).to match(/logged-in Chrome/i)
      expect(prompt(5)).to match(/do not attempt it and do not skip it silently/i)
      expect(prompt(5)).to match(/wait for me/i)
      expect(step(5)[:what_you_should_see].join(' ')).to match(/hands the extension step back to you/i)
    end

    # Both real sessions' step-5 assumption broke: the Save-as-doc dialog
    # writes relative to the canvas bridge's cwd, not the shell's.
    # Step 4 now saves under a deterministic name and prints the path, so
    # step 5 uses that path -- the fallback hunt stays only for a resumed
    # session that no longer has it, and it never asks the user to name it.
    it 'has step 5 use the deterministic doc, with a fallback that never asks the user' do
      expect(prompt(5)).to include('`university-doc`')
      expect(prompt(5)).to include('docs/streamweaver_canvas/')
      expect(prompt(5)).to include('~/.streamweaver/canvas/')
      expect(prompt(5)).to match(/do not make me name it/i)
    end

    it 'has step 5 close every demo session and leave only the controller' do
      expect(prompt(5)).to include('streamweaver canvas-list')
      expect(prompt(5)).to match(/only `university`/)
      %w[dashboard decision doc-demo].each do |session|
        expect(prompt(5)).to include(session)
      end
    end

    # No step inherits the previous step's clutter, and the controller
    # canvas is never a casualty of the cleanup.
    it 'opens every step after the first by closing the previous step\'s demo' do
      (2..5).each do |n|
        expect(prompt(n)).to match(/canvas-close/i),
                             "step #{n} does not clean up the previous step"
      end
    end

    it 'tells step 1 to clear leftovers from a prior run without closing the controller' do
      expect(prompt(1)).to include('streamweaver canvas-close dashboard')
      expect(prompt(1)).to include('streamweaver canvas-close decision')
      expect(prompt(1)).to include('streamweaver canvas-close doc-demo')
      expect(prompt(1)).to include('Never close `university`')
    end

    it 'never tells the agent to close the university controller session' do
      (1..5).each { |n| expect(prompt(n)).not_to include('canvas-close university') }
    end

    it 'has every step announce what is about to happen before it happens' do
      (1..5).each do |n|
        expect(prompt(n)).to match(/tell me|say (?:this|out loud)|explain/i),
                             "step #{n} never narrates before acting"
      end
    end

    # Round-6 UAT: with no fixed sign-off, a worker either kept talking past
    # a finished demo or went quiet with the user unsure the step was done.
    # Every prompt now ends on the same two lines -- the closing ritual --
    # so "done" always reads the same and always names the one next action.
    describe 'the closing ritual' do
      it 'ends steps 1-4 with the standard sign-off, naming the next step' do
        (1..4).each do |n|
          expect(prompt(n)).to match(/Step #{n} demo complete -- play with it as long as you like/),
                               "step #{n} is missing the closing ritual's first line"
          expect(prompt(n)).to match(/click Mark done -- that advances you to step #{n + 1}/),
                               "step #{n} does not name step #{n + 1} as next"
          expect(prompt(n)).to match(/then click Run on it/)
        end
      end

      it 'ends step 5 with the same sign-off, pointing at the recap instead of a next step' do
        expect(prompt(5)).to match(/Step 5 demo complete -- play with it as long as you like/)
        expect(prompt(5)).to match(/click Mark done -- that closes out the course/)
        expect(prompt(5)).to match(/recap/i)
        expect(prompt(5)).not_to match(/advances you to step 6/)
      end

      it 'ends every prompt with the ritual, after the verify/present rules' do
        (1..5).each do |n|
          expect(prompt(n).index('demo complete')).to be > prompt(n).index('PRESENT (for me)'),
                                                        "step #{n}'s ritual is not the last thing in the prompt"
        end
      end
    end

    # Round-6 UAT: step 1 ended on the third mutation with no signal that it
    # was the last one, and the mermaid diagram (a picture of the very push
    # that drew it) went unremarked once the narration moved on to numbers.
    it 'has step 1 announce the final push and invite reading the mermaid as the mechanism' do
      expect(prompt(1)).to match(/that was the final push/i)
      expect(prompt(1)).to match(/the dashboard is done/i)
      expect(prompt(1)).to match(/mermaid diagram is not decoration/i)
    end

    # Round-6 UAT: step 4 narrated in one summary after the whole 20-second
    # run finished instead of relaying each push as it happened. The script
    # now announces its own progress to stdout; the prompt has to point the
    # worker at that stream and forbid the after-the-fact summary.
    it 'has step 4 relay the script\'s own stage narration between pushes, not summarize after' do
      expect(prompt(4)).to match(/stage n\/7 pushing/i)
      expect(prompt(4)).to match(/stage n\/7 pushed/i)
      expect(prompt(4)).to match(/do not wait for the whole run to finish/i)
    end

    # Round-6 UAT bug: the picker's radio choice was a human label, --extend
    # expected the bare key, and a worker that guessed wrong got a silent
    # "Saved: <path>" with nothing actually added. The fix touches the
    # prompt too -- it must not let the worker claim success without
    # checking.
    it 'has step 4 verify a --extend actually landed before telling the user' do
      expect(prompt(4)).to match(/OK <key> → section/i)
      expect(prompt(4)).to match(/`FAILED` for one it did not/i)
      expect(prompt(4)).to match(/exits? non-zero/i)
      expect(prompt(4)).to match(/curl the `doc-demo` session/i)
      expect(prompt(4)).to match(/grep for that exact header text/i)
      expect(prompt(4)).to match(/only then say it is there/i)
    end

    # Round-7 UAT: the user picked "cheatsheet" and could not find a
    # matching header -- the rendered title never said which key it came
    # from. Every extension's header now begins with its own key.
    it 'tells the worker every extension header begins with its own key' do
      expect(prompt(4)).to match(/every rendered header begins with its own key/i)
    end

    # Round-7 UAT: a worker re-ran --picker without re-passing --extend and
    # clobbered the doc -- the rebuild had no memory of an earlier
    # invocation's picks.
    it 'tells the worker repeated invocations remember prior --extend picks on their own' do
      expect(prompt(4)).to match(/repeat invocations, on their own/i)
      expect(prompt(4)).to match(/never loses one/i)
    end

    it 'has step 4 use the radio choice as the --extend key verbatim, with no parsing' do
      expect(prompt(4)).to match(/the visible choice is the exact `--extend` key/i)
      expect(prompt(4)).to match(/do not paraphrase or shorten it/i)
    end

    # Save-format callout (round-6): step 4 explains what .rb and .org are
    # each FOR, not just what they're named -- full fidelity vs. portable,
    # human-readable text.
    it 'has step 4 explain why .rb and .org both exist -- fidelity vs portability' do
      expect(prompt(4)).to match(/full fidelity/i)
      expect(prompt(4)).to match(/re-render and extend it again later/i)
      expect(prompt(4)).to match(/nothing to install/i)
    end
  end

  describe 'FUTURE_COURSES' do
    it 'lists exactly the three dormant courses named in the design spec' do
      names = described_class::FUTURE_COURSES.map { |c| c[:name] }
      expect(names).to eq(['Docs deep dive', 'Canvas modes', 'Skills and panels'])
    end

    it 'gives every future course a one-line blurb' do
      described_class::FUTURE_COURSES.each do |course|
        expect(course[:blurb].to_s.strip).not_to be_empty
      end
    end
  end
end
