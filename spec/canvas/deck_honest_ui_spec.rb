# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'
require_relative '../support/node_js'

# disc-096: swDeckSelect painted .sw-deck-option--selected and aria-checked="true"
# onto the clicked card and *then* fired a fetch it never looked at, at a route
# only the standalone server mounts. Two halves to the fix: confirmation gated
# on the response (with failures reported), and a read-only deck wherever
# AlpineJS#deck_read_only? says nothing serves /deck/*.
RSpec.describe 'honest deck UI (disc-096)' do
  let(:tmpdir) { Dir.mktmpdir('deck_honest_ui') }

  after { FileUtils.rm_rf(tmpdir) }

  def render(adapter, state = {}, &block)
    app = StreamWeaver::App.new('deck honest ui spec', &block)
    app.rebuild_with_state(state)
    StreamWeaver::ComponentRenderer.render_html(adapter, app.components, state)
  end

  def deck_app
    proc do
      design_deck 'Design' do
        slide 'arch', 'Architecture' do
          option('Monolith') { text 'Simple' }
          option('Microservices') { text 'Complex' }
        end
      end
    end
  end

  def render_deck(adapter, state = {})
    render(adapter, state, &deck_app)
  end

  def render_model_selector(adapter)
    render(adapter) do
      model_selector(models: [
                       { id: 'opus', name: 'Opus', provider: 'Anthropic' },
                       { id: 'gpt', name: 'GPT', provider: 'OpenAI' }
                     ])
    end
  end

  let(:standalone) { StreamWeaver::Adapter::AlpineJS.new }
  let(:bridge)     { StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/abc', mode: :websocket) }
  let(:reader)     { StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/abc', mode: :websocket, inert: true) }
  let(:export)     { StreamWeaver::Adapter::AlpineJS.new(deck_server: false) }

  # =========================================================================
  # Which render targets can serve /deck/*
  # =========================================================================

  describe StreamWeaver::Adapter::AlpineJS do
    describe '#deck_read_only?' do
      it 'is false for the standalone server, the one place /deck/* is mounted' do
        expect(described_class.new.send(:deck_read_only?)).to be false
      end

      it 'is true on the canvas bridge, which serves none of those routes' do
        expect(described_class.new(mode: :websocket).send(:deck_read_only?)).to be true
      end

      it 'is true for the reader' do
        expect(described_class.new(mode: :websocket, inert: true).send(:deck_read_only?)).to be true
      end

      it 'is true wherever the caller says there is no deck server' do
        expect(described_class.new(deck_server: false).send(:deck_read_only?)).to be true
      end
    end

    # Standalone and export both render :http with an empty prefix, so the only
    # thing that can tell them apart is the flag each caller sets.
    describe 'what each caller declares' do
      it 'produces a read-only deck in a real exported file' do
        app = StreamWeaver::App.new('deck export spec', &deck_app)
        app.rebuild_with_state({})
        path = File.join(tmpdir, 'deck.html')
        StreamWeaver::Export::HtmlExporter.new(app).export(path: path)

        exported = File.read(path)
        expect(exported).to include('aria-disabled="true"')
        expect(exported).not_to include('/deck/select')
      end

      # Counted rather than matched per-construction: a regex for one call would
      # miss a multiline `AlpineJS.new(\n  url_prefix: ...\n)`, which is how the
      # canvas sites are already written -- and failing open is the one way this
      # guard could matter and not fire.
      it 'has every service-mode, export and live-push adapter declare no deck server' do
        %w[service.rb cli.rb export/html_exporter.rb].each do |name|
          source = File.read(File.expand_path("../../lib/stream_weaver/#{name}", __dir__))

          expect(source.scan('Adapter::AlpineJS.new').length).to be > 0
          expect(source.scan('deck_server: false').length).to eq(source.scan('Adapter::AlpineJS.new').length)
        end
      end
    end
  end

  # =========================================================================
  # The emitted JS, run for real
  # =========================================================================

  describe 'the emitted deck JS' do
    include NodeJS

    # Every <script> the deck emits that defines a swDeck* function -- the real
    # shipped source, not a restatement of it.
    def deck_js(html)
      scripts = html.scan(%r{<script>(.*?)</script>}m).flatten.select { |s| s.include?('swDeck') }
      raise 'the deck emitted no swDeck* script' if scripts.empty?

      scripts.join("\n")
    end

    # Runs the emitted source against a DOM shim and a fetch stub, so what the
    # user would see after a click is observed rather than asserted about the
    # source text. `responses` maps a path to { ok:, status: } or the string
    # 'reject' (fetch itself fails, as it does from a file:// export).
    def run(action, responses, html: render_deck(standalone))
      program = <<~JS
        const log = { fetches: [], errors: [], reloaded: false, refreshed: false };
        console.error = function() { log.errors.push(Array.prototype.join.call(arguments, ' ')); };

        const RESPONSES = #{JSON.generate(responses)};
        function fetch(url, opts) {
          const path = url.split('?')[0];
          log.fetches.push({ path: path, body: opts && opts.body ? JSON.parse(opts.body) : null });
          if (path === '/deck/refresh') log.refreshed = true;
          const spec = RESPONSES[path];
          if (spec === undefined) return Promise.reject(new Error('no stub for ' + path));
          if (spec === 'reject') return Promise.reject(new Error('network down'));
          return Promise.resolve({
            ok: spec.ok, status: spec.status, text: function() { return Promise.resolve('<div></div>'); }
          });
        }

        function makeOption(label) {
          const o = { dataset: { slideId: 'arch', optionLabel: label }, classes: ['sw-deck-option'], attrs: { 'aria-checked': 'false' } };
          o.classList = {
            add: function(c) { if (o.classes.indexOf(c) === -1) o.classes.push(c); },
            remove: function(c) { o.classes = o.classes.filter(function(x) { return x !== c; }); },
            contains: function(c) { return o.classes.indexOf(c) !== -1; }
          };
          o.setAttribute = function(n, v) { o.attrs[n] = v; };
          o.removeAttribute = function(n) { delete o.attrs[n]; };
          o.closest = function() { return grid; };
          return o;
        }
        const options = ['Monolith', 'Microservices'].map(makeOption);
        const grid = { querySelectorAll: function() { return options; } };
        const textarea = { dataset: { slideId: 'arch', optionLabel: 'Monolith' }, value: 'a note' };
        const scope = { selectedModel: 'opus' };

        const document = {
          activeElement: null,
          addEventListener: function() {},
          querySelector: function() { return null; },
          getElementById: function() { return null; }
        };
        const window = { location: { reload: function() { log.reloaded = true; } } };

        #{deck_js(html)}

        #{action}

        setTimeout(function() {
          log.options = options.map(function(o) {
            const out = {
              label: o.dataset.optionLabel,
              selected: o.classList.contains('sw-deck-option--selected'),
              ariaChecked: o.attrs['aria-checked']
            };
            if ('aria-busy' in o.attrs) out.ariaBusy = o.attrs['aria-busy'];
            return out;
          });
          log.scope = scope;
          console.log(JSON.stringify(log));
        }, 25);
      JS

      output, status = Open3.capture2e('node', '-e', program)
      raise "node could not run the deck JS: #{output}" unless status.success?

      JSON.parse(output)
    end

    describe 'swDeckSelect' do
      it 'confirms the option once the server has recorded the selection' do
        log = run('swDeckSelect(options[0]);', {'/deck/select' => { ok: true, status: 200 }, '/deck/refresh' => { ok: true, status: 200 }})

        expect(log['options'][0]).to include('selected' => true, 'ariaChecked' => 'true')
        expect(log['errors']).to be_empty
        expect(log['refreshed']).to be true
      end

      it 'posts the slide and option before touching the card' do
        log = run('swDeckSelect(options[1]);', {'/deck/select' => { ok: true, status: 200 }, '/deck/refresh' => { ok: true, status: 200 }})

        expect(log['fetches'].first).to eq(
          'path' => '/deck/select', 'body' => { 'slide_id' => 'arch', 'option_label' => 'Microservices' }
        )
      end

      it 'leaves the card unchecked when /deck/select 404s' do
        log = run('swDeckSelect(options[0]);', {'/deck/select' => { ok: false, status: 404 }})

        expect(log['options'][0]).to include('selected' => false, 'ariaChecked' => 'false')
        expect(log['refreshed']).to be false
      end

      it 'reports the 404 instead of swallowing it' do
        log = run('swDeckSelect(options[0]);', {'/deck/select' => { ok: false, status: 404 }})

        expect(log['errors'].join).to include('/deck/select').and include('404')
      end

      it 'leaves the card unchecked and reports when the fetch itself fails' do
        log = run('swDeckSelect(options[0]);', {'/deck/select' => 'reject'})

        expect(log['options'][0]).to include('selected' => false, 'ariaChecked' => 'false')
        expect(log['errors'].join).to include('/deck/select')
      end

      it 'does not steal a sibling\'s checkmark on a failed selection' do
        log = run("options[1].classList.add('sw-deck-option--selected'); options[1].setAttribute('aria-checked', 'true'); swDeckSelect(options[0]);", {'/deck/select' => { ok: false, status: 404 }})

        expect(log['options'][1]).to include('selected' => true, 'ariaChecked' => 'true')
      end
    end

    describe 'swDeckSaveNote' do
      it 'refreshes once the note is stored' do
        log = run('swDeckSaveNote(textarea);', {'/deck/note' => { ok: true, status: 200 }, '/deck/refresh' => { ok: true, status: 200 }})

        expect(log['refreshed']).to be true
        expect(log['errors']).to be_empty
      end

      it 'reports a note that never reached a server' do
        log = run('swDeckSaveNote(textarea);', {'/deck/note' => { ok: false, status: 404 }})

        expect(log['errors'].join).to include('/deck/note').and include('404')
        expect(log['refreshed']).to be false
      end
    end

    describe 'swDeckSubmit' do
      it 'reloads only on a successful submit' do
        log = run('swDeckSubmit();', {'/deck/submit' => { ok: true, status: 200 }})

        expect(log['reloaded']).to be true
      end

      it 'reports a failed submit rather than doing nothing visible' do
        log = run('swDeckSubmit();', {'/deck/submit' => { ok: false, status: 404 }})

        expect(log['reloaded']).to be false
        expect(log['errors'].join).to include('/deck/submit').and include('404')
      end
    end

    describe 'swDeckSaveFinalNotes' do
      it 'reports final notes that never reached a server' do
        log = run('swDeckSaveFinalNotes(textarea);', {'/deck/final_notes' => { ok: false, status: 404 }})

        expect(log['errors'].join).to include('/deck/final_notes')
        expect(log['refreshed']).to be false
      end
    end

    describe 'swDeckSetModel' do
      let(:model_html) { render_model_selector(standalone) }

      it 'moves the highlight once the server has the model' do
        log = run("swDeckSetModel(scope, 'gpt');", { '/deck/set_model' => { ok: true, status: 200 } }, html: model_html)

        expect(log['scope']).to eq('selectedModel' => 'gpt')
        expect(log['errors']).to be_empty
      end

      it 'leaves the highlight alone and reports when /deck/set_model 404s' do
        log = run("swDeckSetModel(scope, 'gpt');", { '/deck/set_model' => { ok: false, status: 404 } }, html: model_html)

        expect(log['scope']).to eq('selectedModel' => 'opus')
        expect(log['errors'].join).to include('/deck/set_model')
      end
    end

    describe 'swDeckRefresh' do
      it 'reports a refresh that 404s rather than swallowing the response' do
        log = run('swDeckRefresh();', {'/deck/refresh' => { ok: false, status: 404 }})

        expect(log['errors'].join).to include('/deck/refresh').and include('404')
      end
    end

    # These two already logged before the fix, but with a message that named
    # neither the route nor the reason. Routing them through swDeckPost is what
    # makes "every deck call reports where and why" true rather than nearly true.
    describe 'the generate-more calls' do
      let(:generate_html) do
        deck_state = StreamWeaver::Components::Deck::DeckState.new('honest-ui', state_dir: tmpdir)
        render_deck(standalone, { _deck_state: deck_state })
      end

      it 'reports a failed generate, naming the route and status' do
        log = run("swGenerate('arch');", { '/deck/generate' => { ok: false, status: 404 } }, html: generate_html)

        expect(log['errors'].join).to include('/deck/generate').and include('404')
      end

      it 'reports a failed cancel, naming the route and status' do
        log = run('swCancelGenerate();', { '/deck/cancel_generate' => { ok: false, status: 404 } }, html: generate_html)

        expect(log['errors'].join).to include('/deck/cancel_generate').and include('404')
      end
    end

    # The click used to be acknowledged instantly and dishonestly. Gating on the
    # response removes the lie but would otherwise replace it with silence.
    describe 'the in-flight card' do
      it 'marks the card busy for the round trip and clears it either way' do
        log = run("swDeckSelect(options[0]); log.busyDuringFlight = options[0].attrs['aria-busy'];",
                  { '/deck/select' => { ok: false, status: 404 } })

        expect(log['busyDuringFlight']).to eq('true')
        expect(log['options'][0]).not_to have_key('ariaBusy')
      end
    end
  end

  # =========================================================================
  # Read-only where the mode proves there is no backend
  # =========================================================================

  describe 'a deck rendered where no backend serves /deck/*' do
    # The bridge and the reader are known from the mode; an export is known
    # only because HtmlExporter says so. All three must degrade the same way.
    %i[bridge reader export].each do |target|
      context "in the #{target}" do
        let(:adapter) { send(target) }
        let(:html) { render_deck(adapter) }
        let(:option_card) { html[/<div class="sw-deck-option"[^>]*>/] }

        it 'offers no /deck/* call at all' do
          expect(html).not_to include('/deck/')
        end

        it 'wires no selection handler to the option card' do
          expect(option_card).not_to include('@click')
          expect(html).not_to include('swDeckSelect')
        end

        it 'marks the option cards non-interactive, with a reason' do
          expect(option_card).to include('aria-disabled="true"')
          expect(option_card).to include('title="Read-only: deck selections need the standalone deck server"')
        end

        it 'takes the option cards out of the tab order' do
          expect(option_card).not_to include('tabindex')
        end

        it 'disables the notes textarea rather than accepting notes it cannot save' do
          textarea = html[/<textarea class="sw-deck-option__notes-input"[^>]*>/]

          expect(textarea).to include('disabled')
          expect(textarea).not_to include('@blur')
        end

        it 'registers no number-key quick-select, which would post the same dead call' do
          expect(html).not_to include('swDeckSelect(target)')
        end

        it 'disables the summary submit and final notes' do
          expect(html).not_to include('swDeckSubmit')
          expect(html).not_to include('swDeckSaveFinalNotes')

          submit = html[/<button[^>]*class="sw-deck-summary__submit[^>]*>/]
          expect(submit).to include('disabled')
        end

        it 'still shows the selection the deck state recorded' do
          deck_state = StreamWeaver::Components::Deck::DeckState.new('honest-ui', state_dir: tmpdir)
          deck_state.select('arch', 'Microservices')
          rendered = render_deck(adapter, { _deck_state: deck_state })

          expect(rendered.scan('aria-checked="true"').length).to eq(1)
          expect(rendered).to include('data-option-label="Microservices"')
        end
      end
    end

    it 'disables the generate-more controls' do
      # The controls only render when the deck has state to generate into.
      deck_state = StreamWeaver::Components::Deck::DeckState.new('honest-ui', state_dir: tmpdir)
      html = render_deck(bridge, { _deck_state: deck_state })

      expect(html).not_to include('swGenerate')
      expect(html).not_to include('/deck/generate')
      expect(html[/<button[^>]*sw-generate-more__btn--generate[^>]*>/]).to include('disabled')
      expect(html[/<input[^>]*sw-generate-more__prompt[^>]*>/]).to include('disabled')
    end

    it 'stops the model selector from claiming a model the server never got' do
      html = render_model_selector(bridge)

      expect(html).not_to include('/deck/set_model')
      expect(html[/<div class="sw-model-selector__item"[^>]*>/]).to include('aria-disabled="true"')
    end

    it 'keeps the model selector provider pills, which never needed a server' do
      html = render_model_selector(bridge)

      expect(html).to include(%(@click="provider = 'All'"))
    end
  end

  # =========================================================================
  # Standalone is unchanged
  # =========================================================================

  describe 'the standalone deck' do
    let(:html) { render_deck(standalone) }

    it 'wires the option card exactly as before' do
      expect(html).to include(
        '<div class="sw-deck-option" role="radio" aria-checked="false" tabindex="0" ' \
        'data-slide-id="arch" data-option-label="Monolith" data-option-index="0" @click="swDeckSelect($el)">'
      )
    end

    it 'wires the notes textarea exactly as before' do
      expect(html).to include(
        '<textarea class="sw-deck-option__notes-input" placeholder="Add notes..." rows="2" ' \
        'data-slide-id="arch" data-option-label="Monolith" @blur="swDeckSaveNote($el)">'
      )
    end

    it 'keeps every deck control live' do
      expect(html[/<div class="sw-deck-option"[^>]*>/]).not_to include('aria-disabled')
      expect(html).not_to include(StreamWeaver::Adapter::AlpineJS::DECK_READ_ONLY_TITLE)
      expect(html).to include('swDeckSubmit()')
      expect(html).to include('swDeckSaveFinalNotes($el)')
    end

    it 'still binds the number-key quick-select' do
      expect(html).to include("addEventListener('keydown'")
      expect(html).to include('swDeckSelect(target)')
    end

    it 'differs from the read-only rendering' do
      expect(html).not_to eq(render_deck(bridge))
    end

    it 'wires the model selector items to the server, JSON-quoting the model id' do
      expect(render_model_selector(standalone)).to include('@click="swDeckSetModel($data, &quot;gpt&quot;)"')
    end
  end
end
