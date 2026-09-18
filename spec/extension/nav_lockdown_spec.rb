# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require_relative '../support/node_js'

# Navigation lockdown for the sandboxed doc-render frame.
#
# extension-csp-hardening closed sub-resource egress (fetch/XHR/form) with
# default-src/connect-src/form-action 'none'. What CSP does not govern is
# *navigation*, and doc-author Ruby can drive one two ways through Opal's %x{}
# interop: window.open() and window.location =. disc-191 settled both live in
# real Chrome: a declarativeNetRequest session rule scoped to the viewer's tab
# blocks the frame's self-navigation (a sub_frame request in that tab) and
# structurally cannot block a popup (whose new tab has a new id no tab-scoped
# rule matches). So popups are removed as a capability, self-navigation is
# blocked by the rule, and legitimate doc links are handed to the privileged
# half of the viewer to open.
#
# viewer.js and sandbox.js ship as-is with no build step, so this runs the real
# files in node against a DOM/chrome shim rather than pattern-matching their
# source -- the approach spec/extension/viewer_sandbox_frame_spec.rb
# established. That shim models frame identity; this one models the chrome.*
# APIs and the ordering between installing the rule and rendering, which is the
# part under test here. What a shim cannot show is whether Chrome really
# refuses the popup and really blocks the navigation -- that stays a browser
# check (see the story's UAT handoff note).
RSpec.describe 'the viewer navigation lockdown' do
  let(:manifest) do
    JSON.parse(File.read(File.expand_path('../../extension/manifest.json', __dir__)))
  end
  let(:viewer_html) { File.read(File.expand_path('../../extension/viewer.html', __dir__)) }

  describe 'the capabilities the sandbox is granted' do
    it 'grants the sandboxed page no popup capability in the manifest CSP' do
      policy = manifest.fetch('content_security_policy').fetch('sandbox')

      expect(policy).to include('sandbox allow-scripts;')
      expect(policy).not_to include('allow-popups')
    end

    it 'grants the iframe no popup capability either' do
      # Both layers matter: the manifest CSP governs sandbox.html as a
      # document, the attribute governs the browsing context it lives in.
      # Matched inside the whole tag rather than as "id then sandbox" so
      # reordering the attributes cannot fail this for the wrong reason.
      iframe_tag = viewer_html[/<iframe[^>]*id="frame"[^>]*>/m]

      expect(iframe_tag[/sandbox="([^"]*)"/, 1]).to eq('allow-scripts')
    end

    it "pins the sandbox's base URL with base-uri 'none'" do
      # base-uri has no default-src fallback, so the already-landed
      # default-src 'none' does not cover it. Without this a doc could inject
      # <base href="http://attacker.example/"> and every relative link in the
      # doc would resolve there -- and the privileged link handler below would
      # then open it as a perfectly valid http URL.
      expect(manifest.fetch('content_security_policy').fetch('sandbox')).to include("base-uri 'none'")
    end

    it 'declares the declarativeNetRequest permission the guard needs' do
      # declarativeNetRequest, not declarativeNetRequestWithHostAccess: the
      # rule blocks *arbitrary* origins, and the WithHostAccess variant only
      # acts on URLs the extension already has host permissions for (here,
      # raw.githubusercontent.com only).
      expect(manifest.fetch('permissions')).to include('declarativeNetRequest')
    end
  end

  describe 'the running viewer' do
    include NodeJS

    let(:viewer_source) { File.read(File.expand_path('../../extension/viewer.js', __dir__)) }

    # Models what viewer.js touches: element lookup by id, listener dispatch,
    # frame identity, and the chrome.* APIs the lockdown uses. Every
    # security-relevant side effect (installing the rule, posting a doc to the
    # sandbox, opening a tab) appends to one ordered `events` log, because the
    # ordering between them is itself the control: a doc posted before the rule
    # is installed is a doc that ran unprotected.
    def viewer_shim(chrome_stub: 'const chrome = undefined;')
      <<~JS
        const events = [];
        const warnings = [];
        const messageHandlers = [];
        const frames = [];

        class Elem {
          constructor(id) {
            this.id = id;
            this.listeners = {};
            this.hidden = false;
            this.textContent = "";
            this.className = "";
            this.classList = { add() {}, remove() {} };
          }
          addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
          dispatch(type) { (this.listeners[type] || []).forEach((fn) => fn({ preventDefault() {} })); }
          // Only reached via resetSandboxFrame(), i.e. a second doc in one
          // tab. Present so that path cannot crash a run rather than because
          // this file asserts on frame replacement -- that is
          // viewer_sandbox_frame_spec.rb's subject.
          replaceWith() { this.removed = true; }
        }

        class Frame extends Elem {
          constructor(id) {
            super(id);
            this.serial = frames.length + 1;
            const self = this;
            this.contentWindow = {
              postMessage: (msg) => events.push({ kind: "render-post", frame: self.serial, msg: msg })
            };
            frames.push(this);
          }
          cloneNode() { return new Frame(this.id); }
        }

        const elements = {
          "frame": new Frame("frame"),
          "status": new Elem("status"),
          "source-link": new Elem("source-link"),
          "drop-zone": new Elem("drop-zone"),
          "drop-zone-warning": new Elem("drop-zone-warning"),
          "drop-zone-error": new Elem("drop-zone-error"),
          "file-input": new Elem("file-input"),
          "doc-name": new Elem("doc-name")
        };
        elements["frame"].hidden = true;

        const document = { title: "", getElementById: (id) => elements[id] || null };
        const window = {
          addEventListener: (type, fn) => { if (type === "message") messageHandlers.push(fn); },
          open: (url) => events.push({ kind: "window-open", url: url })
        };
        // No ?key, so viewer.js takes its drop-zone branch in every example
        // here -- the same in-extension entry point a browser gate drives.
        const location = { search: "" };
        console.warn = (...args) => warnings.push(args.map(String).join(" "));

        #{chrome_stub}

        const currentFrame = () => frames[frames.length - 1];
        const deliver = (frameEl, data) =>
          messageHandlers.forEach((fn) => fn({ source: frameEl.contentWindow, data: data }));
        // Enough turns for the deepest promise chain viewer.js has on these
        // paths to finish: the nav-lockdown install awaits chrome.tabs
        // .getCurrent, then getSessionRules, then updateSessionRules, then
        // re-drives sendWhenReady, and handleFile awaits file.text() -- six
        // is slack over that, not a tuned number. Anything whose timing is
        // actually under test is released explicitly instead (see the
        // deferred-install example).
        const settle = async () => { for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0)); };
        const drop = (name, source) => {
          const input = elements["file-input"];
          input.files = [{ name: name, text: async () => source }];
          input.dispatch("change");
        };
        const report = (extra) => console.log(JSON.stringify(Object.assign({
          events: events,
          warnings: warnings,
          status: { text: elements["status"].textContent, hidden: elements["status"].hidden },
          frameHidden: currentFrame().hidden,
          warningHidden: elements["drop-zone-warning"].hidden
        }, extra || {})));
      JS
    end

    # The chrome.* surface viewer.js actually uses, with the four pieces an
    # example may want to break: how updateSessionRules behaves, what
    # getSessionRules reports already installed (the id-allocation lookup
    # reads this before ever calling updateSessionRules), what
    # chrome.tabs.getCurrent answers, and whether declarativeNetRequest exists
    # at all.
    def chrome_stub(dnr: 'async (arg) => { events.push({ kind: "dnr", arg: arg }); }', tab: '{ id: 7 }',
                    declarative: true, session_rules: '[]')
      <<~JS
        const chrome = {
          runtime: { getURL: (p) => "chrome-extension://testextid/" + p },
          storage: { session: { get: async () => ({}), remove: async () => {} } },
          tabs: {
            getCurrent: async () => (#{tab}),
            create: (opts) => events.push({ kind: "tab-create", url: opts.url })
          }#{declarative ? ",\n  declarativeNetRequest: { updateSessionRules: #{dnr}, getSessionRules: async () => (#{session_rules}) }" : ''}
        };
      JS
    end

    def run_viewer(shim, script)
      run_node_json(shim, viewer_source, script)
    end

    # The updateSessionRules() call's argument -- addRules/removeRuleIds --
    # pulled out of the event log every example in this describe wants to
    # assert on. Named dnr_call rather than dnr_arg so it doesn't collide
    # with the identically-named `let` a shadowing method of the same name
    # would silently override.
    def dnr_call(result)
      result['events'].find { |event| event['kind'] == 'dnr' }['arg']
    end

    # Renders one doc the ordinary way: drop it in, let the fresh frame report
    # itself ready, wait for everything async to settle.
    def render_one(shim, trailer: '')
      run_viewer(shim, <<~JS)
        (async () => {
          drop("doc.org", "DOC SOURCE");
          await settle();
          deliver(currentFrame(), { type: "sw:sandbox-ready" });
          await settle();
          #{trailer}
          report();
        })();
      JS
    end

    describe 'installing the tab-scoped guard before anything renders' do
      let(:result) { render_one(viewer_shim(chrome_stub: chrome_stub)) }
      let(:dnr_arg) { dnr_call(result) }
      let(:rules) { dnr_arg.fetch('addRules') }

      it 'installs the rule before the doc is ever sent to the sandbox' do
        expect(result['events'].map { |event| event['kind'] }).to eq(%w[dnr render-post])
      end

      it 'hides the drop-zone trust warning, since this is the installed-extension context where the hardening applies' do
        expect(result['warningHidden']).to be true
      end

      it 'blocks sub-frame navigation scoped to this tab only' do
        block = rules.find { |rule| rule.dig('action', 'type') == 'block' }

        expect(block['condition']).to include(
          'urlFilter' => '*',
          'tabIds' => [7],
          'resourceTypes' => ['sub_frame']
        )
      end

      it "excludes main_frame, so the user's own navigation of the tab still works" do
        # DNR blocks user-initiated navigation too -- a main_frame rule would
        # stop the user typing a URL or hitting Back in the viewer tab. The
        # sandbox cannot navigate the top frame anyway: that needs
        # allow-top-navigation, which its sandbox attribute does not grant.
        expect(rules.flat_map { |rule| rule.dig('condition', 'resourceTypes') }).to all(eq('sub_frame'))
      end

      it "lets the extension's own pages through at a higher priority" do
        # The block rule must never be able to shoot the extension itself --
        # sandbox.html is a sub_frame load in this very tab.
        allow_rule = rules.find { |rule| rule.dig('action', 'type') == 'allow' }
        block = rules.find { |rule| rule.dig('action', 'type') == 'block' }

        expect(allow_rule.dig('condition', 'urlFilter')).to eq('|chrome-extension://testextid/')
        expect(allow_rule.dig('condition', 'tabIds')).to eq([7])
        expect(allow_rule['priority']).to be > block['priority']
      end

      it 'replaces its own rules rather than stacking them on a reload' do
        expect(dnr_arg.fetch('removeRuleIds')).to eq(rules.map { |rule| rule.fetch('id') })
        expect(rules.map { |rule| rule.fetch('id') }.uniq.length).to eq(2)
      end
    end

    describe 'allocating rule ids for a large, realistic tab id' do
      # disc-uat-nav-lockdown: a Playwright-launched Chromium tab id
      # (1473826186, well under the int32 max declarativeNetRequest's rule id
      # field requires) produced a blockId of 2947652373 under the old
      # `tabId * 2 + 1` scheme -- past int32 max -- and
      # updateSessionRules() threw "expected integer, found number" on the
      # very first install. Regression coverage for the id-allocation
      # rewrite: real, already-observed-in-the-wild tab ids must not
      # overflow.
      let(:big_tab_id) { 1_473_826_186 }
      let(:result) do
        render_one(viewer_shim(chrome_stub: chrome_stub(tab: "{ id: #{big_tab_id} }")))
      end
      let(:dnr_arg) { dnr_call(result) }
      let(:rules) { dnr_arg.fetch('addRules') }

      it 'installs without throwing and renders the doc' do
        expect(result['events'].map { |event| event['kind'] }).to eq(%w[dnr render-post])
      end

      it 'allocates the deterministic lowest-free pair rather than deriving ids from the tab id' do
        # No other tab owns anything yet, so the allocator's contract is
        # exact: the lowest two ids, not merely "some in-range pair".
        expect(rules.map { |rule| rule.fetch('id') }).to eq([1, 2])
      end

      it 'still scopes both rules to the real (large) tab id' do
        expect(rules.map { |rule| rule.dig('condition', 'tabIds') }).to all(eq([big_tab_id]))
      end
    end

    describe "reusing this tab's own ids on a later install" do
      def installed_rule(id:, type:, url_filter:)
        <<~JS
          { id: #{id}, priority: #{type == 'block' ? 1 : 2}, action: { type: #{type.to_json} },
            condition: { urlFilter: #{url_filter.to_json}, tabIds: [7], resourceTypes: ["sub_frame"] } }
        JS
      end

      it "reuses its previous pair instead of allocating a new one" do
        # Same tab, installed twice (e.g. the guard re-running without the
        # page navigating away). The lookup should find its own previous
        # pair via getSessionRules and reuse them -- not hand out a fresh
        # pair and orphan the old one.
        previously_installed = "[#{installed_rule(id: 3, type: 'block', url_filter: '*')}," \
                                "#{installed_rule(id: 4, type: 'allow', url_filter: '|chrome-extension://testextid/')}]"

        result = render_one(viewer_shim(chrome_stub: chrome_stub(session_rules: previously_installed)))

        expect(dnr_call(result).fetch('addRules').map { |rule| rule.fetch('id') }).to eq([3, 4])
        expect(dnr_call(result).fetch('removeRuleIds')).to eq([3, 4])
      end

      it 'tops up rather than colliding when it owns only one previous id' do
        # The bug this regresses: a prior install that left only one rule
        # behind (a partial install, or one rule removed out from under it).
        # Reusing that single id and then allocating a second "lowest free"
        # id without first accounting for the reused one would hand out the
        # same id twice -- Chrome rejects a duplicate id in one addRules
        # call, so this tab's guard would fail to install on every future
        # reload.
        one_previous_rule = "[#{installed_rule(id: 3, type: 'block', url_filter: '*')}]"

        result = render_one(viewer_shim(chrome_stub: chrome_stub(session_rules: one_previous_rule)))
        ids = dnr_call(result).fetch('addRules').map { |rule| rule.fetch('id') }

        expect(ids).to eq([3, 1])
        expect(ids.uniq.length).to eq(2)
        expect(result['events'].map { |event| event['kind'] }).to eq(%w[dnr render-post])
      end
    end

    describe "not colliding with another tab's already-installed ids" do
      it 'skips ids a different tab already owns' do
        other_tabs_rules = <<~JS
          [
            { id: 1, priority: 1, action: { type: "block" },
              condition: { urlFilter: "*", tabIds: [99], resourceTypes: ["sub_frame"] } },
            { id: 2, priority: 2, action: { type: "allow" },
              condition: { urlFilter: "|chrome-extension://testextid/", tabIds: [99], resourceTypes: ["sub_frame"] } }
          ]
        JS

        result = render_one(viewer_shim(chrome_stub: chrome_stub(session_rules: other_tabs_rules)))
        dnr_arg = dnr_call(result)
        ids = dnr_arg.fetch('addRules').map { |rule| rule.fetch('id') }

        # The allocator's exact contract given tab 99 already holds 1 and 2:
        # the next lowest free pair, not merely "avoids 1 and 2 somehow".
        expect(ids).to eq([3, 4])
        # The security property this whole scheme exists for: this tab's
        # install must never be able to remove a rule that belongs to
        # another tab's still-open, still-relying-on-it guard.
        expect(dnr_arg.fetch('removeRuleIds')).not_to include(1, 2)
      end
    end

    describe 'failing closed' do
      it 'refuses to render when the rule cannot be installed' do
        failing = chrome_stub(dnr: 'async () => { throw new Error("no rules for you"); }')
        result = render_one(viewer_shim(chrome_stub: failing))

        expect(result['events'].map { |event| event['kind'] }).not_to include('render-post')
        expect(result['status']['text']).to include('no rules for you')
        expect(result['frameHidden']).to be true
      end

      it 'refuses to render when the declarativeNetRequest API is missing' do
        # The permission could be dropped from the manifest, or the browser
        # could be too old for it. Either way the doc must not run.
        result = render_one(viewer_shim(chrome_stub: chrome_stub(declarative: false)))

        expect(result['events'].map { |event| event['kind'] }).not_to include('render-post')
        expect(result['status']['text']).to include('declarativeNetRequest')
      end

      it "refuses to render when the tab's own id cannot be determined" do
        result = render_one(viewer_shim(chrome_stub: chrome_stub(tab: 'null')))

        expect(result['events'].map { |event| event['kind'] }).not_to include('render-post')
        expect(result['status']['text']).not_to be_empty
      end

      it 'still renders on the bare-file entry point, which has no chrome APIs at all' do
        # viewer.html opened as a plain file:// page (extension/README.md,
        # "Local-file entry point (S2)"): there is no chrome.* to install a
        # rule with, and the manifest's sandbox CSP does not apply there
        # either, so that path is unprotected by construction rather than
        # protected-and-failing. Failing closed there would only break local
        # preview; its trust warning is extension-misc-hardening's job.
        result = render_one(viewer_shim)

        expect(result['events'].map { |event| event['kind'] }).to eq(['render-post'])
      end
    end

    describe 'a doc that arrives while the guard is still installing' do
      # The window that makes the gate a gate rather than a race. Every other
      # example here answers updateSessionRules immediately, so the guard is
      # already settled by the time a doc lands; this one holds the install
      # open, lets a whole doc arrive and report ready, and only then releases
      # it. Without the re-drive from the install's own handler, the doc would
      # sit there unrendered forever.
      let(:result) do
        deferred = <<~JS.strip
          (arg) => { events.push({ kind: "dnr", arg: arg }); return new Promise((resolve) => { releaseDnr = resolve; }); }
        JS

        run_viewer("let releaseDnr;\n#{viewer_shim(chrome_stub: chrome_stub(dnr: deferred))}", <<~JS)
          (async () => {
            drop("doc.org", "DOC SOURCE");
            await settle();
            deliver(currentFrame(), { type: "sw:sandbox-ready" });
            await settle();
            const whilePending = events.slice();

            releaseDnr();
            await settle();
            report({ whilePending: whilePending });
          })();
        JS
      end

      it 'holds the doc back until the rule is in place' do
        expect(result['whilePending'].map { |event| event['kind'] }).to eq(['dnr'])
      end

      it 'renders it exactly once, as soon as the rule lands' do
        expect(result['events'].map { |event| event['kind'] }).to eq(%w[dnr render-post])
        expect(result['events'].last['msg']).to include('source' => 'DOC SOURCE')
      end

      it 'keeps the pristine frame when a second doc arrives before the first renders' do
        # Nothing ran in the frame while the guard was pending, so the second
        # doc wins the same frame rather than paying for a replacement and a
        # second sandbox.html load. This is what frameHasRendered means -- a
        # frame is dirty once a doc was *posted* to it, not once a file was
        # picked.
        deferred = <<~JS.strip
          (arg) => { events.push({ kind: "dnr", arg: arg }); return new Promise((resolve) => { releaseDnr = resolve; }); }
        JS

        result = run_viewer("let releaseDnr;\n#{viewer_shim(chrome_stub: chrome_stub(dnr: deferred))}", <<~JS)
          (async () => {
            drop("doc-a.org", "DOC A SOURCE");
            await settle();
            deliver(currentFrame(), { type: "sw:sandbox-ready" });
            await settle();
            drop("doc-b.org", "DOC B SOURCE");
            await settle();

            releaseDnr();
            await settle();
            report({ frameCount: frames.length });
          })();
        JS

        expect(result['frameCount']).to eq(1)
        posts = result['events'].select { |event| event['kind'] == 'render-post' }
        expect(posts.length).to eq(1)
        expect(posts.first).to include('frame' => 1)
        expect(posts.first['msg']).to include('source' => 'DOC B SOURCE')
      end
    end

    describe 'the readiness signal' do
      it 'is consumed exactly once per doc, so a replay cannot re-render' do
        # sandbox.js posts this once, but doc code shares that window and can
        # post it again itself. A replay that re-drove the render would run the
        # doc a second time in a frame it has already dirtied -- the same shape
        # of bug extension-sandbox-per-doc found with a stale readiness message
        # from a discarded frame.
        result = render_one(viewer_shim(chrome_stub: chrome_stub), trailer: <<~JS)
          deliver(currentFrame(), { type: "sw:sandbox-ready" });
          deliver(currentFrame(), { type: "sw:sandbox-ready" });
          await settle();
        JS

        expect(result['events'].count { |event| event['kind'] == 'render-post' }).to eq(1)
      end
    end

    describe 'opening a link the doc asked for' do
      def open_link(href)
        render_one(viewer_shim(chrome_stub: chrome_stub), trailer: <<~JS)
          deliver(currentFrame(), { type: "sw:open-external", href: #{href.to_json} });
          await settle();
        JS
      end

      it 'opens an http(s) link in a real tab' do
        result = open_link('https://example.com/docs?a=1#frag')

        expect(result['events']).to include(
          'kind' => 'tab-create', 'url' => 'https://example.com/docs?a=1#frag'
        )
      end

      %w[
        javascript:fetch('https://attacker.example')
        data:text/html,<script>1</script>
        file:///etc/passwd
        chrome-extension://testextid/viewer.html
        blob:https://example.com/abc
        about:blank
      ].each do |href|
        it "refuses a #{href.split(':').first}: link" do
          result = open_link(href)

          expect(result['events'].map { |event| event['kind'] }).not_to include('tab-create')
          expect(result['warnings'].join("\n")).to include('StreamWeaver')
        end
      end

      it 'refuses an unparseable href instead of throwing' do
        result = open_link('not a url')

        expect(result['events'].map { |event| event['kind'] }).not_to include('tab-create')
        expect(result['warnings']).not_to be_empty
      end

      it 'ignores a link request from anything but the current sandbox frame' do
        # The event.source pin is the reason this privileged handler can live
        # on the viewer page at all. viewer_sandbox_frame_spec.rb pins it for
        # readiness messages; this pins it for the one message that has a real
        # capability behind it.
        result = render_one(viewer_shim(chrome_stub: chrome_stub), trailer: <<~JS)
          const impostor = { postMessage: () => {} };
          messageHandlers.forEach((fn) => fn({
            source: impostor,
            data: { type: "sw:open-external", href: "https://attacker.example/steal" }
          }));
          await settle();
        JS

        expect(result['events'].map { |event| event['kind'] }).not_to include('tab-create')
      end
    end
  end

  describe 'the sandbox link handler' do
    include NodeJS

    let(:sandbox_source) { File.read(File.expand_path('../../extension/sandbox.js', __dir__)) }

    # sandbox.js only needs enough DOM to install its delegated click handler
    # and to post to its parent. Nothing here compiles Ruby: the click routing
    # is the behavior under test, and it is pure DOM/postMessage work.
    def run_sandbox(script)
      shim = <<~JS
        const posts = [];
        const scrolled = [];
        const clickHandlers = [];
        const elements = {
          "app-container": { innerHTML: "" },
          "sw-error": { style: {}, textContent: "" },
          "sec-2": { scrollIntoView: (opts) => scrolled.push(opts) }
        };
        const document = {
          head: { appendChild() {} },
          baseURI: "chrome-extension://testextid/sandbox.html",
          getElementById: (id) => elements[id] || null,
          addEventListener: (type, fn) => { if (type === "click") clickHandlers.push(fn); },
          createElement: () => ({})
        };
        const window = { addEventListener() {} };
        const parent = { postMessage: (msg) => posts.push(msg) };
        const self = {};

        const XLINK = "http://www.w3.org/1999/xlink";

        const anchor = (href) => ({
          getAttribute: () => href,
          getAttributeNS: () => null,
          href: href
        });
        // What mermaid's `click A "url"` nodes produce inside the rendered
        // SVG: an SVGAElement, whose .href is an SVGAnimatedString and which
        // has no .hash at all. The URL may live on href or on xlink:href
        // depending on the renderer, so both shapes are modelled.
        const svgAnchor = (href, ns) => ({
          getAttribute: () => (ns ? null : href),
          getAttributeNS: (namespace, attr) => (ns && namespace === XLINK && attr === "href" ? href : null),
          href: { baseVal: href, animVal: href }
        });
        const click = (target, isTrusted) => {
          let prevented = false;
          clickHandlers.forEach((fn) => fn({
            target: target,
            isTrusted: isTrusted !== false,
            preventDefault: () => { prevented = true; }
          }));
          return prevented;
        };
        // These two model `closest` as selector-AWARE, which matters: an
        // xlink-only anchor is routed at all only because the handler's
        // selector uses the namespace wildcard. A shim that handed the anchor
        // back regardless of selector would keep passing if that wildcard were
        // reverted, while every such link in a real doc went silently dead.
        // Substring checks rather than a regex: this shim is interpolated
        // through a Ruby heredoc, which drops the backslashes a JS regex needs
        // and would turn /a\[href\]/ into a character class that matches
        // nothing here.
        const matchesAnyNamespace = (selector) => selector.includes("[*|href]");
        const matchesPlainHref = (selector) => selector.includes("[href]") || matchesAnyNamespace(selector);

        const clickLink = (href) =>
          click({ closest: (selector) => (matchesPlainHref(selector) ? anchor(href) : null) });
        const clickSvgLink = (href, ns) =>
          click({
            closest: (selector) => {
              const matched = ns ? matchesAnyNamespace(selector) : matchesPlainHref(selector);
              return matched ? svgAnchor(href, ns) : null;
            }
          });
        // What doc code can manufacture: anchor.click() produces an identical
        // event except that isTrusted is false.
        const syntheticClickLink = (href) => click({ closest: () => anchor(href) }, false);
        const clickNothing = () => click({ closest: () => null });
        const reportSelector = () => {
          let seen = null;
          click({ closest: (selector) => { seen = selector; return null; } });
          return seen;
        };
      JS

      run_node_json(shim, sandbox_source, script)
    end

    it 'asks the privileged half to open an outbound link instead of navigating itself' do
      result = run_sandbox(<<~JS)
        const prevented = clickLink("https://example.com/a");
        console.log(JSON.stringify({ prevented, posts, scrolled }));
      JS

      expect(result['prevented']).to be true
      expect(result['posts']).to include(
        'type' => 'sw:open-external', 'href' => 'https://example.com/a'
      )
    end

    it 'sends an absolute URL, not the raw attribute' do
      # The privileged half validates a scheme, so it has to be given one. A
      # relative href resolves against the sandbox page, which is also how a
      # doc's relative link ends up refused there rather than opened.
      result = run_sandbox(<<~JS)
        clickLink("docs/elsewhere");
        console.log(JSON.stringify({ posts }));
      JS

      expect(result['posts']).to include(
        'type' => 'sw:open-external', 'href' => 'chrome-extension://testextid/docs/elsewhere'
      )
    end

    it 'selects anchors by namespace-wildcard href, not by plain href' do
      # The one part of this routing no assertion below can reach: what the
      # handler asks the DOM for. An xlink-only anchor is routed at all only
      # because of the wildcard, and the shim cannot parse CSS.
      result = run_sandbox(<<~JS)
        console.log(JSON.stringify({ selector: reportSelector() }));
      JS

      expect(result['selector']).to include('*|href')
    end

    it "routes an SVG anchor, whose .href is not a string at all" do
      # Mermaid at securityLevel 'loose' turns a diagram's `click A "url"`
      # into a real <a> inside the SVG. In a browser, posting its .href (an
      # SVGAnimatedString) throws DataCloneError after preventDefault -- a
      # dead click with nothing but a console exception to show for it. This
      # shim's postMessage does not structured-clone, so what it can show is
      # the wrong payload going over rather than the throw itself.
      result = run_sandbox(<<~JS)
        const prevented = clickSvgLink("https://example.com/diagram-node");
        console.log(JSON.stringify({ prevented, posts }));
      JS

      expect(result['prevented']).to be true
      expect(result['posts']).to include(
        'type' => 'sw:open-external', 'href' => 'https://example.com/diagram-node'
      )
    end

    it 'routes an SVG anchor that carries only xlink:href' do
      # Which attribute mermaid writes depends on its renderer; an xlink-only
      # anchor that missed the selector would be a silently dead link now that
      # the browser refuses to navigate this frame.
      result = run_sandbox(<<~JS)
        clickSvgLink("https://example.com/xlink-node", true);
        console.log(JSON.stringify({ posts }));
      JS

      expect(result['posts']).to include(
        'type' => 'sw:open-external', 'href' => 'https://example.com/xlink-node'
      )
    end

    it 'ignores a click the doc synthesized rather than one the user made' do
      # Otherwise doc code could build an anchor, call .click() on it, and have
      # the privileged half open an arbitrary URL with no user action at all --
      # the popup capability back in through the side door. Not preventing the
      # default matters too: the browser's own refusals (no allow-popups, plus
      # the DNR rule) are what should handle a synthetic click, and they only
      # apply if the default action is left alone.
      result = run_sandbox(<<~JS)
        const prevented = syntheticClickLink("https://attacker.example/steal");
        console.log(JSON.stringify({ prevented, posts }));
      JS

      expect(result['posts'].map { |post| post['type'] }).to eq(['sw:sandbox-ready'])
      expect(result['prevented']).to be false
    end

    it 'still scrolls same-page fragment links without leaving the doc' do
      # sidebar_toc's links, and any hand-written [text](#anchor).
      result = run_sandbox(<<~JS)
        const prevented = clickLink("#sec-2");
        console.log(JSON.stringify({ prevented, posts, scrolled }));
      JS

      expect(result['prevented']).to be true
      expect(result['scrolled']).to eq([{ 'behavior' => 'smooth' }])
      expect(result['posts'].map { |post| post['type'] }).not_to include('sw:open-external')
    end

    it 'leaves a click that is not on a link alone' do
      result = run_sandbox(<<~JS)
        const prevented = clickNothing();
        console.log(JSON.stringify({ prevented, posts }));
      JS

      expect(result['prevented']).to be false
      expect(result['posts'].map { |post| post['type'] }).to eq(['sw:sandbox-ready'])
    end
  end
end
