# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/node_js'

# The extension's live-runtime wiring, exercised against the real shipped code.
#
# Behavior here is driven, not grepped for -- the one exception below is an
# invariant about code that must NOT exist, which no run can demonstrate. The
# program below loads the real compiled bundle (extension/vendor/sw-runtime.js,
# i.e. the same Opal build the extension ships) and the real, unbuilt
# extension/sandbox.js, and drives them through the same postMessage the viewer
# sends. What is shimmed is only the browser: a DOM registry, morphdom, and the
# three decoration hooks, each recording what the runtime asked of it.
#
# The split is deliberate. Whether the runtime aims its patch at the extension's
# own container, emits region wrappers, re-runs the decoration hooks after every
# patch, and registers a sort callback for one table form but not the other are
# all decisions made in Ruby and observable here. Whether a real morphdom pass
# against a real layout keeps Prism/Mermaid/sidebar-toc alive is not -- that is
# the browser gate recorded on the story, not something this file claims.
RSpec.describe 'extension live runtime wiring' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:sandbox_source) { File.read(File.join(root, 'extension', 'sandbox.js')) }

  # --- source-level invariants (no node needed) ---------------------------

  # The one invariant no behavioral test below can express, because it is about
  # code that must NOT exist. extension-region-wrapper-css fixed the :doc CSS so
  # the sw-region-N wrappers are safe to keep; stripping them again would turn
  # every region-scoped patch into a silent no-op, since patch_regions resolves
  # each region by document.getElementById("sw-region-N") -- state changes, the
  # DOM does not, and nothing errors.
  #
  # Comments are stripped before matching: this codebase's house style is long
  # explanatory comments, and the next person documenting why the wrappers
  # matter -- inside sandbox.js, which is where such a comment belongs --
  # should not fail a test about stripping wrappers by writing prose.
  describe 'the region wrappers sandbox.js renders' do
    # Line comments only where they start a line, so a "https://" inside a
    # string literal survives.
    let(:sandbox_code) do
      sandbox_source.gsub(%r{/\*.*?\*/}m, '').gsub(%r{^\s*//.*$}, '')
    end

    it 'are never stripped or reached for by id' do
      expect(sandbox_code).not_to match(/unwrap/i)
      expect(sandbox_code).not_to include('sw-region')
    end
  end

  # --- which table forms actually get a sort callback --------------------

  describe 'Table#register_callbacks (the sortable-table split)' do
    def registry_for(table)
      {}.tap { |registry| table.register_callbacks(registry) }
    end

    it 'registers one sort callback per column for a Symbol-state-bound table' do
      table = StreamWeaver::Components::Table.new(:my_data, sortable: true,
                                                            headers: %w[name qty])
      expect(registry_for(table).keys).to eq(%w[my_data_sort_0 my_data_sort_1])
    end

    it 'registers them for a state-bound table whose headers arrive in the state value' do
      # `table(:my_data, sortable: true)` -- the form the story's own example
      # uses, and the one an author writing a state-bound table reaches for.
      # There is no `headers:` kwarg and no column DSL here, so counting only
      # those registered nothing and the sort buttons were rendered inert.
      table = StreamWeaver::Components::Table.new(:my_data, sortable: true)
      table.resolve!(nil, { my_data: { headers: %w[name qty], rows: [%w[beta 2]] } })

      expect(registry_for(table).keys).to eq(%w[my_data_sort_0 my_data_sort_1])
    end

    # Pre-existing constraint, verified rather than assumed: this form renders
    # a sort button and registers nothing behind it. Documented on the story
    # and in the epic wiki as a separate, not-yet-scoped follow-on -- the live
    # runtime does not change it either way.
    it 'registers nothing for a literal headers:/rows: table' do
      table = StreamWeaver::Components::Table.new(headers: %w[name qty],
                                                  rows: [%w[beta 2], %w[alpha 1]],
                                                  sortable: true)
      expect(registry_for(table)).to be_empty
    end
  end

  # --- what made the FIRST interaction disappear --------------------------

  describe 'App#initialize with no usable caller location' do
    # Caught only in a real browser: under Opal, caller_locations comes back
    # empty for a compiled frame entered from a setTimeout callback -- which is
    # exactly how the live runtime schedules its async re-render. The resulting
    # NoMethodError landed mid-render, and OpalRuntime#render_html clears its
    # callback registry before rebuilding, so the registry stayed empty and the
    # user's next click found nothing to invoke. Every symptom was "clicking the
    # sort header does nothing", one click behind reality.
    it 'still builds a usable app when caller_locations yields nothing' do
      allow_any_instance_of(StreamWeaver::App).to receive(:caller_locations).and_return([])

      app = StreamWeaver::App.new("probe") { text "ok" }
      app.rebuild_with_state({})

      # Not `not_to raise_error`: that would pass with a garbage @script_dir.
      # The bug's real symptom was a half-constructed app, so assert the app
      # actually builds its component tree.
      expect(app.components.length).to eq(1)
    end
  end

  describe 'Mermaid#diagram_id' do
    def diagram(code, **options)
      StreamWeaver::Components::Mermaid.new(code, **options)
    end

    # morphdom pairs nodes by id. An id derived from object_id changed on every
    # rebuild, so each patch removed the diagram container and inserted a fresh
    # one -- throwing away the rendered SVG, the zoom/expand wiring and the
    # guards that keep that wiring from being stacked (measured in real Chrome:
    # six sets of wheel/mousedown/mousemove/mouseup listeners after six
    # renders, down to one after this fix).
    it 'is the same for two rebuilds of the same diagram' do
      expect(diagram("graph TD; A-->B;").diagram_id)
        .to eq(diagram("graph TD; A-->B;").diagram_id)
    end

    it 'differs when the diagram source differs' do
      expect(diagram("graph TD; A-->B;").diagram_id)
        .not_to eq(diagram("graph TD; A-->C;").diagram_id)
    end

    # Not just the source. The id decides whether a patch reuses this container,
    # and morph_options then leaves a rendered container's subtree alone, so an
    # input the id ignores can never change on screen again -- `mermaid(src,
    # zoom: state[:zoom])` would render its first value forever.
    it 'differs when an option that reaches the container differs' do
      base = diagram("graph TD; A-->B;")

      expect([diagram("graph TD; A-->B;", zoom: true),
              diagram("graph TD; A-->B;", compact: true),
              diagram("graph TD; A-->B;", layout: :elk),
              diagram("graph TD; A-->B;", theme_vars: { primaryColor: "#fff" })].map(&:diagram_id))
        .to all(satisfy { |id| id != base.diagram_id })
    end

    # Which is what keeps the "skip already-decorated subtrees" morph guard
    # honest: an edited diagram gets a new id, so morphdom never pairs it with
    # the old node and the skip cannot pin stale output on screen.
    it 'is an explicit id when one is given, for two identical diagrams in one doc' do
      expect(diagram("graph TD; A-->B;", id: "first").diagram_id).to eq("first")
    end
  end

  # --- the real bundle, driven in node ------------------------------------

  describe 'the live runtime, running' do
    include NodeJS

    before(:all) do
      bundle = File.expand_path('../../extension/vendor/sw-runtime.js', __dir__)
      skip "#{bundle} is missing -- run bin/build_extension" unless File.exist?(bundle)
    end

    # The browser, reduced to what the runtime and sandbox.js actually reach
    # for, with every call recorded.
    #
    # getElementById invents an element for any sw-region-N id asked for: the
    # region-scoped patch path resolves its targets that way, and a shim that
    # returned null for them would make every such patch look like a no-op for
    # a reason the runtime is not responsible for.
    let(:shim) do
      <<~JS
      const fs = require("fs");
      const vm = require("vm");

      // A browser logs an exception thrown out of a setTimeout and carries on;
      // node exits non-zero and takes the driver's output with it. The runtime
      // schedules a re-render through setTimeout (start hooks, async
      // re-renders), so a doc that raises while rendering throws again from a
      // timer after the synchronous failure has already been handled.
      const asyncErrors = [];
      process.on("uncaughtException", (e) => { asyncErrors.push(e.message || String(e)); });

      const morphs = [];
      const posts = [];
      const headStyles = [];
      const docListeners = {};
      const winListeners = {};
      const hooks = { prism: 0, toc: 0, mermaid: 0 };

      const makeEl = (id) => ({
        id: id, style: {}, textContent: "", innerHTML: "",
        dataset: {}, setAttribute() {}, getAttribute() { return null; },
        appendChild() {}, scrollIntoView() {}
      });

      const elements = {
        "app-container": makeEl("app-container"),
        "sw-error": makeEl("sw-error")
      };

      globalThis.window = globalThis;
      globalThis.self = globalThis;

      globalThis.document = {
        head: { appendChild: (el) => headStyles.push(el.id) },
        baseURI: "chrome-extension://testextid/sandbox.html",
        readyState: "complete",
        getElementById: (id) => {
          if (elements[id]) return elements[id];
          if (/^sw-region-\\d+$/.test(id)) { elements[id] = makeEl(id); return elements[id]; }
          return null;
        },
        createElement: () => makeEl(null),
        addEventListener: (type, fn) => { (docListeners[type] = docListeners[type] || []).push(fn); },
        dispatchEvent: (evt) => {
          (docListeners[evt.type] || []).forEach((fn) => fn(evt));
          return true;
        },
        querySelector: () => null,
        querySelectorAll: () => []
      };

      globalThis.addEventListener = (type, fn) => {
        (winListeners[type] = winListeners[type] || []).push(fn);
      };

      globalThis.parent = { postMessage: (msg) => posts.push(msg) };

      // A recorder, not morphdom: what this file can prove is which element the
      // runtime aimed at and what markup it aimed there. Whether a real morph
      // preserves nodes is the browser gate's job.
      globalThis.morphdom = (fromEl, to, opts) => {
        morphs.push({ id: fromEl && fromEl.id, html: (to && to.__html) || String(to) });
        globalThis.lastMorphOptions = opts;
      };

      // patch_regions parses the full render and picks regions out of it.
      globalThis.DOMParser = function () {
        return {
          parseFromString: (html) => ({
            __html: html,
            getElementById: (id) =>
              html.indexOf('id="' + id + '"') >= 0 ? { id: id, __html: html } : null
          })
        };
      };

      globalThis.Prism = { highlightAll: () => { hooks.prism++; } };
      globalThis.swInitSidebarToc = () => { hooks.toc++; };
      globalThis.swMermaidInit = () => { hooks.mermaid++; };
      globalThis.requestAnimationFrame = (fn) => fn();
      globalThis.marked = { parse: (text) => text };
      globalThis.CustomEvent = globalThis.CustomEvent || function (type) { return { type: type }; };

      const ROOT = #{File.expand_path('../..', __dir__).to_json};
      const load = (rel) =>
        vm.runInThisContext(fs.readFileSync(ROOT + "/" + rel, "utf8"), { filename: rel });

      // The real rewriter, taken through its CommonJS export -- the browser
      // branch of its dual export writes to `window`, which a vm-global load
      // in node does not reach.
      globalThis.swRewriteHeredocs =
        require(ROOT + "/extension/vendor/sw-heredoc-rewrite.js").rewriteHeredocs;

      load("extension/vendor/sw-runtime.js");
      load("extension/sandbox.js");

      // What viewer.js sends. The real listener, the real render path.
      //
      // `source: globalThis.parent` on the outer envelope is event.source, not
      // the doc-source parameter of the same name below -- extension-misc-hardening
      // added an event.source === parent check to sandbox.js's listener, so this
      // shim now has to look like a real postMessage from the parent frame, the
      // same way a real browser sets event.source automatically.
      const deliver = (source, name) => {
        (winListeners["message"] || []).forEach((fn) =>
          fn({ source: globalThis.parent, data: { type: "sw:render", source: source, name: name || "Test Doc" } }));
      };

      // extension-misc-hardening: same envelope as deliver(), but from an
      // arbitrary sender rather than the real parent frame -- proves the
      // event.source === parent guard sandbox.js's listener added.
      const deliverFrom = (spoofedSource, source, name) => {
        (winListeners["message"] || []).forEach((fn) =>
          fn({ source: spoofedSource, data: { type: "sw:render", source: source, name: name || "Test Doc" } }));
      };

      const fire = (type, target) => {
        (docListeners[type] || []).forEach((fn) => fn({
          type: type, target: target, isTrusted: true, preventDefault() {}
        }));
      };

      const clickInvoke = (domId) =>
        fire("click", { closest: (sel) => (sel.indexOf("data-sw-invoke") >= 0 ? { dataset: { swInvoke: domId } } : null) });

      const typeInto = (key, value) =>
        fire("input", { dataset: { swUpdate: key }, value: value });

      const toggle = (key, checked) =>
        fire("change", { dataset: { swToggle: key }, checked: checked });

      const listenerCounts = () => ({
        click: (docListeners["click"] || []).length,
        input: (docListeners["input"] || []).length,
        change: (docListeners["change"] || []).length
      });

      const lastMorph = () => morphs[morphs.length - 1];
      const rowOrder = (html) =>
        (html.match(/<td[^>]*>([^<]*)<\\/td>/g) || []).map((cell) => cell.replace(/<[^>]*>/g, ""));
      JS
    end

    def run_live(driver)
      run_node_json(shim, driver)
    end

    let(:text_doc) do
      <<~RUBY
      state[:q] ||= ""
      text_field :q, label: "Query"
      text "q=" + state[:q].to_s
      RUBY
    end

    let(:state_table_doc) do
      <<~RUBY
      state[:my_data] ||= { headers: ["name", "qty"], rows: [["beta", "2"], ["alpha", "1"]] }
      table(:my_data, sortable: true)
      RUBY
    end

    let(:literal_table_doc) do
      <<~RUBY
      table(headers: ["name", "qty"], rows: [["beta", "2"], ["alpha", "1"]], sortable: true)
      RUBY
    end

    describe "sandbox.js's sw:render message listener (extension-misc-hardening)" do
      it 'ignores a render message whose source is not the parent frame' do
        result = run_live(<<~JS)
          deliverFrom({ postMessage: () => {} }, #{text_doc.to_json});
          console.log(JSON.stringify({ count: morphs.length, posts: posts }));
        JS

        # Never reached render() at all -- no morph, and no post beyond the
        # load-time "sw:sandbox-ready" every run gets regardless.
        expect(result['count']).to eq(0)
        expect(result['posts']).to eq([{ 'type' => 'sw:sandbox-ready' }])
      end

      it 'still renders a message that genuinely comes from the parent frame' do
        result = run_live(<<~JS)
          deliver(#{text_doc.to_json});
          console.log(JSON.stringify({ count: morphs.length, posts: posts }));
        JS

        expect(result['count']).to be >= 1
        expect(result['posts']).to include(hash_including('type' => 'sw:rendered'))
      end
    end

    it 'patches the extension container, not a hardcoded sw-app' do
      result = run_live(<<~JS)
        deliver(#{text_doc.to_json});
        console.log(JSON.stringify({ first: morphs[0], count: morphs.length, posts: posts }));
      JS

      expect(result['count']).to be >= 1
      expect(result.dig('first', 'id')).to eq('app-container')
      expect(result.dig('first', 'html')).to start_with('<div id="app-container">')
      expect(result['posts']).to include(hash_including('type' => 'sw:rendered'))
    end

    it 'renders through the wrapper-emitting path so region patches have targets' do
      result = run_live(<<~JS)
        deliver(#{text_doc.to_json});
        console.log(JSON.stringify({ html: morphs[0].html }));
      JS

      expect(result['html']).to include('id="sw-region-0"')
      expect(result['html']).to include('id="sw-region-1"')
    end

    it 'lets the adapter place component CSS in <head> with no host help' do
      # sandbox.js no longer collects SWRender.css() itself. The adapter's
      # inject_component_css writes one keyed <style> per component instead,
      # which is idempotent across re-renders where a host-placed blob was not.
      doc = <<~RUBY
        sidebar_toc sections: [{ id: "one", label: "One" }]
        doc_section_header 1, "One", id: "one"
      RUBY

      result = run_live(<<~JS)
        deliver(#{doc.to_json});
        console.log(JSON.stringify({ styles: headStyles }));
      JS

      expect(result['styles']).to include('sw-css-sidebar_toc')
    end

    it 're-runs Prism, sidebar-toc and mermaid after every patch, not just the first' do
      # The bug this replaces: the hooks ran once, inline, after the initial
      # static render. morphdom replaces nodes and takes their decoration with
      # them, so every later patch left un-highlighted code and blank diagrams.
      result = run_live(<<~JS)
        deliver(#{text_doc.to_json});
        const afterFirst = JSON.parse(JSON.stringify(hooks));
        typeInto("q", "a");
        typeInto("q", "ab");
        typeInto("q", "abc");
        console.log(JSON.stringify({ afterFirst: afterFirst, afterThree: hooks, morphs: morphs.length }));
      JS

      expect(result['afterFirst']).to eq('prism' => 1, 'toc' => 1, 'mermaid' => 1)
      expect(result['afterThree']).to eq('prism' => 4, 'toc' => 4, 'mermaid' => 4)
    end

    it 'patches only the regions that read the changed key' do
      result = run_live(<<~JS)
        deliver(#{text_doc.to_json});
        typeInto("q", "a");
        console.log(JSON.stringify({ ids: morphs.map((m) => m.id) }));
      JS

      expect(result['ids'].first).to eq('app-container')
      expect(result['ids'][1..]).to all(match(/\Asw-region-\d+\z/))
    end

    it 'updates state from a checkbox change as well as a text input' do
      doc = <<~RUBY
        state[:on] ||= false
        checkbox :on, "On"
        text "on=" + state[:on].to_s
      RUBY

      result = run_live(<<~JS)
        deliver(#{doc.to_json});
        toggle("on", true);
        console.log(JSON.stringify({ html: lastMorph().html }));
      JS

      expect(result['html']).to include('on=true')
    end

    it 'installs its delegated listeners once per page, however often start() is called' do
      # Two starts in one frame would otherwise stack a second set of
      # click/input/change handlers, each closed over a different runtime --
      # a sort click firing twice reads as "sorting is broken", not as a
      # duplicate listener.
      result = run_live(<<~JS)
        deliver(#{text_doc.to_json});
        const afterFirst = listenerCounts();
        window.SWRuntime.start("app-container");
        window.SWRuntime.start("app-container");
        console.log(JSON.stringify({ afterFirst: afterFirst, afterThree: listenerCounts() }));
      JS

      expect(result['afterFirst']).to eq(result['afterThree'])
    end

    it 'sorts a Symbol-state-bound sortable table when a header button is clicked' do
      result = run_live(<<~JS)
        deliver(#{state_table_doc.to_json});
        const before = rowOrder(morphs[0].html);
        clickInvoke("my_data_sort_0");
        console.log(JSON.stringify({ before: before, after: rowOrder(lastMorph().html) }));
      JS

      expect(result['before']).to eq(%w[beta 2 alpha 1])
      expect(result['after']).to eq(%w[alpha 1 beta 2])
    end

    it 'leaves a literal headers:/rows: table unsorted, button and all' do
      result = run_live(<<~JS)
        deliver(#{literal_table_doc.to_json});
        const before = rowOrder(morphs[0].html);
        const hasButton = morphs[0].html.indexOf('data-sw-invoke="_sort_0"') >= 0;
        clickInvoke("_sort_0");
        console.log(JSON.stringify({
          before: before, after: rowOrder(lastMorph().html), hasButton: hasButton
        }));
      JS

      expect(result['hasButton']).to be true
      expect(result['before']).to eq(%w[beta 2 alpha 1])
      expect(result['after']).to eq(%w[beta 2 alpha 1])
    end

    it 'still surfaces a compile error in the error box' do
      result = run_live(<<~JS)
        deliver("def (");
        console.log(JSON.stringify({
          display: elements["sw-error"].style.display,
          text: elements["sw-error"].textContent,
          posts: posts,
          morphs: morphs.length
        }));
      JS

      expect(result['display']).to eq('block')
      expect(result['text']).to include('Compiling Ruby')
      expect(result['posts']).to include(hash_including('type' => 'sw:render-failed'))
      expect(result['morphs']).to eq(0)
    end

    it 'surfaces a render-time error in the error box too' do
      # New failure surface: the static path raised inside SWRender.staticHtml(),
      # the live path raises inside SWRuntime.start(). Both have to land in the
      # same box rather than an unhandled exception in a message handler.
      result = run_live(<<~JS)
        deliver("raise 'boom'");
        console.log(JSON.stringify({
          display: elements["sw-error"].style.display,
          text: elements["sw-error"].textContent
        }));
      JS

      expect(result['display']).to eq('block')
      expect(result['text']).to include('boom')
    end

    it 'tells morphdom to leave already-decorated subtrees alone' do
      # Found in real Chrome, not here: the DSL emits an EMPTY mermaid diagram
      # container and sw-mermaid-zoom.js renders the SVG into it afterwards, so
      # morphing that subtree from freshly rendered markup deletes the diagram
      # on every patch. With patches arriving faster than mermaid renders, the
      # diagram never came back at all.
      result = run_live(<<~JS)
        deliver(#{text_doc.to_json});
        const guard = lastMorphOptions && lastMorphOptions.onBeforeElUpdated;
        const decorated = { hasAttribute: (name) => name === "data-sw-mermaid-done" };
        const plain = { hasAttribute: () => false };
        console.log(JSON.stringify({
          present: typeof guard,
          skipsDecorated: guard ? guard(decorated, {}) : null,
          allowsPlain: guard ? guard(plain, {}) : null
        }));
      JS

      expect(result['present']).to eq('function')
      expect(result['skipsDecorated']).to be false
      expect(result['allowsPlain']).to be true
    end

    it 'fails loudly when pointed at a mount id that is not in the page' do
      # Silence here would be the worst outcome: a typo'd mount id with a
      # working-looking render and no patches ever landing.
      result = run_live(<<~JS)
        deliver(#{text_doc.to_json});
        let message = null;
        try { window.SWRuntime.start("not-in-this-page"); }
        catch (e) { message = e.message || String(e); }
        console.log(JSON.stringify({ message: message }));
      JS

      expect(result['message']).to include('not-in-this-page')
    end
  end

  # --- the re-init guards, under a morphdom-style attribute strip ----------

  describe 'sidebar-toc double-initialization guard' do
    include NodeJS

    let(:toc_js) { File.join(root, 'lib', 'stream_weaver', 'assets', 'js', 'sw-sidebar-toc.js') }

    # One nav node, one set of links, counters on everything the init attaches.
    # The script self-inits on load (readyState is not "loading"), so the first
    # wiring has already happened by the time the driver runs.
    let(:toc_shim) do
      <<~JS
      const listenerAdds = [];
      let observers = 0;

      const activations = [];
      const link = {
        dataset: {},
        getAttribute: () => "one",
        addEventListener: (type) => listenerAdds.push(type),
        classList: { add: (cls) => activations.push(cls), remove() {} },
        closest: () => null
      };
      const links = [link];
      const nav = { dataset: {}, querySelectorAll: () => links, scrollWidth: 0, clientWidth: 0 };

      globalThis.window = globalThis;
      globalThis.IntersectionObserver = function () {
        observers++;
        return { observe() {} };
      };
      globalThis.document = {
        readyState: "complete",
        querySelector: (sel) => (sel === ".sw-sidebar-toc__nav" ? nav : null),
        querySelectorAll: () => [],
        getElementById: () => ({ id: "one", scrollIntoView() {} }),
        addEventListener() {}
      };
      const wiring = () => ({ listenerAdds: listenerAdds.length, observers: observers });
      JS
    end

    it 're-asserts the active link on every init, since a patch strips the class' do
      # The other half of moving the guard off the attribute. morphdom syncs
      # classes from freshly rendered markup, which has no active link, and the
      # IntersectionObserver only fires on an actual intersection change -- so
      # a guard that skipped the whole init left the highlight gone until the
      # reader scrolled. Caught by the browser gate (links=4, active=0).
      driver = <<~JS
        activations.length = 0;
        window.swInitSidebarToc();
        console.log(JSON.stringify({ activations: activations, wiring: wiring() }));
      JS

      result = run_node_json(toc_shim, File.read(toc_js), driver)

      expect(result['activations']).to eq(['sw-is-active'])
      expect(result['wiring']).to eq('listenerAdds' => 1, 'observers' => 1)
    end

    it 'does not re-wire the same nav node on repeated inits' do
      # This is what a re-render does: init runs again against a nav node that
      # morphdom kept, whose links still have their listeners, with any
      # attribute flag synced away from the freshly rendered markup. An
      # attribute-only guard therefore stacks a click handler per link and
      # leaks an IntersectionObserver every render; the guard has to key on
      # node identity instead, which is what this pins.
      driver = <<~JS
        const first = wiring();
        window.swInitSidebarToc();
        window.swInitSidebarToc();
        window.swInitSidebarToc();
        console.log(JSON.stringify({ first: first, after: wiring() }));
      JS

      result = run_node_json(toc_shim, File.read(toc_js), driver)

      expect(result['first']).to eq('listenerAdds' => 1, 'observers' => 1)
      expect(result['after']).to eq(result['first'])
    end
  end

  describe 'mermaid zoom/expand wiring guards' do
    let(:mermaid_js) do
      File.read(File.join(root, 'lib', 'stream_weaver', 'assets', 'js', 'sw-mermaid-zoom.js'))
    end

    # Same failure mode as sidebar-toc's, on nodes this file cannot reach
    # without a real mermaid render: initZoomPan/initExpand run again after a
    # patch that caught the container mid-render, and an attribute guard is
    # exactly what that patch has just removed.
    #
    # Negative only, deliberately. Asserting some positive token (a WeakSet,
    # say) would pass on any appearance of it anywhere and fail on an equally
    # correct rewrite, while still not distinguishing "both guards keyed on
    # identity" from "one reverted" -- which is the failure worth catching. The
    # listener count itself lives on the browser gate.
    it 'does not reintroduce the strippable attribute guards' do
      expect(mermaid_js).not_to include("setAttribute('data-sw-zoom-wired'")
      expect(mermaid_js).not_to include("setAttribute('data-sw-expand-wired'")
    end

    # Deliberately still an attribute: morphdom strips data-sw-mermaid-done at
    # exactly the moment it also strips the rendered SVG out of the diagram
    # element, which is when a fresh render IS the correct response.
    it 'leaves the render-completion flag as an attribute on purpose' do
      expect(mermaid_js).to include("setAttribute('data-sw-mermaid-done'")
    end
  end
end
