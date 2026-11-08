# frozen_string_literal: true

require_relative "../support/node_js"

# The shared scroll spy (assets/js/sw-sidebar-toc.js), run in node against a
# stub DOM. Two spies use it: sidebar_toc's, over the page, and ide_editor's,
# over the scrolling editor, whose tab strip and right-rail file tree share
# one active section.
RSpec.describe "scroll spy (sw-sidebar-toc.js)" do
  include NodeJS

  let(:spy_js) { File.read(File.expand_path("../../lib/stream_weaver/assets/js/sw-sidebar-toc.js", __dir__)) }

  let(:dom) do
    <<~JS
      globalThis.window = globalThis;
      const log = { observers: [], observed: [], scrolls: [], focus: [], strips: [], attrs: [], listeners: [] };
      let reduceMotion = false;
      window.matchMedia = (query) => ({ matches: reduceMotion && query.includes("reduce") });

      function box(top, bottom, left, right) { return { top, bottom, left, right }; }
      function el(name, props) {
        const handlers = {};
        const classes = new Set();
        const attrs = (props && props.attrs) || {};
        const ancestors = {};
        const node = Object.assign({
          name, classes, attrs, ancestors,
          getAttribute: (n) => (n in attrs ? attrs[n] : null),
          setAttribute: (n, v) => { attrs[n] = v; log.attrs.push([name, n]); },
          removeAttribute: (n) => { delete attrs[n]; },
          classList: { add: (c) => classes.add(c), remove: (c) => classes.delete(c) },
          addEventListener: (type, fn) => { log.listeners.push([name, type]); (handlers[type] = handlers[type] || []).push(fn); },
          fire: (type, event) => (handlers[type] || []).forEach((fn) => fn(event)),
          closest: (sel) => ancestors[sel] || null,
          getBoundingClientRect: () => box(0, 10, 0, 10),
          scrollIntoView: (opts) => log.scrolls.push([name, opts]),
          scrollBy: (opts) => log.strips.push([name, opts]),
          focus: (opts) => log.focus.push([name, opts]),
          querySelector: () => null,
          querySelectorAll: () => []
        }, props);
        return node;
      }
      function click(scope, link) {
        const event = { target: link, prevented: false, preventDefault() { this.prevented = true; } };
        scope.fire("click", event);
        return event;
      }

      const byId = {};
      function section(id) { return (byId[id] = el(id, { id })); }

      // ide: a shell holding an editor (with a 37px tab strip) and a file tree
      function ideDom() {
        const links = [];
        const shell = el("shell", { querySelectorAll: (sel) => (sel === "[data-sw-ide-target]" ? links.slice() : []) });
        const strip = el("tabs", { offsetHeight: 37, getBoundingClientRect: () => box(0, 37, 0, 300) });
        const tree = el("tree", { getBoundingClientRect: () => box(100, 300, 900, 1200) });
        const editor = el("editor", {
          scrollTop: 0, clientHeight: 700, scrollHeight: 2000,
          querySelector: (sel) => (sel === ".sw-ide-tabstrip" ? strip : null)
        });
        editor.ancestors[".sw-ide-shell"] = shell;
        const addLink = (target, list) => {
          const link = el(target + ":" + list.name, { attrs: { "data-sw-ide-target": target } });
          link.ancestors["[data-sw-ide-target]"] = link;
          link.ancestors["[data-sw-ide-links]"] = list;
          link.getBoundingClientRect = () => (list === tree ? box(150, 170, 900, 1200) : box(0, 37, 0, 100));
          links.push(link);
          return link;
        };
        ["readme", "install"].forEach((id) => { section(id); addLink(id, strip); addLink(id, tree); });
        const active = () => links.filter((l) => l.classes.has("sw-is-active")).map((l) => l.name);
        const current = () => links.filter((l) => l.attrs["aria-current"]).map((l) => l.name);
        return { shell, strip, tree, editor, links, addLink, active, current };
      }

      // toc: a nav of links over sections the page itself scrolls
      function tocDom() {
        const links = [];
        const nav = el("nav", { scrollWidth: 200, clientWidth: 200,
                                querySelectorAll: (sel) => (sel === ".sw-sidebar-toc__link" ? links.slice() : []) });
        ["summary", "risks"].forEach((id) => {
          section(id);
          const link = el("toc:" + id, { attrs: { "data-sw-toc-target": id } });
          link.ancestors[".sw-sidebar-toc__link"] = link;
          link.ancestors[".sw-sidebar-toc__nav"] = nav;
          links.push(link);
        });
        const active = () => links.filter((l) => l.classes.has("sw-is-active")).map((l) => l.name);
        return { nav, links, active };
      }

      const ide = WANT.ide ? ideDom() : null;
      const toc = WANT.toc ? tocDom() : null;

      const observerCallbacks = {};
      globalThis.IntersectionObserver = function (callback, options) {
        const rootName = options.root ? options.root.name : "page";
        observerCallbacks[rootName] = callback;
        log.observers.push({ root: rootName, rootMargin: options.rootMargin });
        return { observe: (node) => log.observed.push(rootName + ":" + node.name) };
      };
      const intersect = (rootName, states) => observerCallbacks[rootName](
        Object.entries(states).map(([id, on]) => ({ target: byId[id], isIntersecting: on }))
      );
      globalThis.document = {
        readyState: "complete",
        querySelector: (sel) => (sel === ".sw-ide-editor" && ide ? ide.editor : sel === ".sw-sidebar-toc__nav" && toc ? toc.nav : null),
        getElementById: (id) => byId[id] || null,
        addEventListener() {}
      };
    JS
  end

  def run_spy(driver, ide: true, toc: false)
    run_node_json("const WANT = #{JSON.generate(ide: ide, toc: toc)};", dom, spy_js, driver)
  end

  describe "the ide_editor spy" do
    it "observes each section once, inside the editor, with the band starting below the tab strip" do
      result = run_spy("console.log(JSON.stringify(log));")
      expect(result["observers"]).to eq([{ "root" => "editor", "rootMargin" => "-37px 0px -60% 0px" }])
      expect(result["observed"]).to eq(%w[editor:readme editor:install])
    end

    it "starts on the first section, marking every link to it, without scrolling any list" do
      result = run_spy("console.log(JSON.stringify({ active: ide.active(), current: ide.current(), strips: log.strips }));")
      expect(result["active"]).to eq(%w[readme:tabs readme:tree])
      expect(result["current"]).to eq(%w[readme:tabs readme:tree])
      expect(result["strips"]).to be_empty
    end

    it "moves the shared active section to the first section in the band as the editor scrolls" do
      result = run_spy(<<~JS)
        intersect("editor", { readme: true, install: true });
        const both = ide.active();
        intersect("editor", { readme: false });
        console.log(JSON.stringify({ both, after: ide.active(), current: ide.current() }));
      JS
      expect(result["both"]).to eq(%w[readme:tabs readme:tree])
      expect(result["after"]).to eq(%w[install:tabs install:tree])
      expect(result["current"]).to eq(%w[install:tabs install:tree])
    end

    it "marks the last section once an overflowing editor is scrolled to its end" do
      result = run_spy(<<~JS)
        ide.editor.fire("scroll");
        const midway = ide.active();
        ide.editor.scrollTop = 1300;
        ide.editor.fire("scroll");
        const byScroll = ide.active();
        intersect("editor", { readme: true });
        console.log(JSON.stringify({ midway, byScroll, byObserver: ide.active() }));
      JS
      expect(result["midway"]).to eq(%w[readme:tabs readme:tree])
      expect(result["byScroll"]).to eq(%w[install:tabs install:tree])
      expect(result["byObserver"]).to eq(%w[install:tabs install:tree])
    end

    it "does not treat an editor with nothing to scroll as scrolled to its end" do
      result = run_spy(<<~JS)
        ide.editor.scrollHeight = 700;
        ide.editor.fire("scroll");
        intersect("editor", { readme: true, install: true });
        console.log(JSON.stringify({ active: ide.active() }));
      JS
      expect(result["active"]).to eq(%w[readme:tabs readme:tree])
    end

    it "scrolls the active link into view within its own list only" do
      result = run_spy(<<~JS)
        ide.links[2].getBoundingClientRect = () => box(0, 37, 280, 380);    // install tab, past the strip's edge
        ide.links[3].getBoundingClientRect = () => box(150, 170, 900, 1200); // install row, visible
        intersect("editor", { install: true });
        console.log(JSON.stringify({ strips: log.strips }));
      JS
      expect(result["strips"]).to eq([["tabs", { "left" => 80, "top" => 0, "behavior" => "smooth" }]])
    end

    it "scrolls a clicked link's section into view, focuses it, and holds it active until the scroll ends" do
      result = run_spy(<<~JS)
        const event = click(ide.shell, ide.links[3]);
        const clicked = ide.active();
        intersect("editor", { readme: true, install: false });   // passing sections mid-scroll
        const during = ide.active();
        ide.editor.fire("scrollend");
        intersect("editor", { readme: true, install: false });
        console.log(JSON.stringify({ prevented: event.prevented, scrolls: log.scrolls, focus: log.focus,
                                     clicked, during, after: ide.active() }));
      JS
      expect(result["prevented"]).to be(true)
      expect(result["scrolls"]).to eq([["install", { "behavior" => "smooth", "block" => "start" }]])
      expect(result["focus"]).to eq([["install", { "preventScroll" => true }]])
      expect(result["clicked"]).to eq(%w[install:tabs install:tree])
      expect(result["during"]).to eq(%w[install:tabs install:tree])
      expect(result["after"]).to eq(%w[readme:tabs readme:tree])
    end

    it "scrolls without animation when the reader prefers reduced motion" do
      result = run_spy(<<~JS)
        reduceMotion = true;
        ide.links[2].getBoundingClientRect = () => box(0, 37, 280, 380);
        click(ide.shell, ide.links[2]);
        console.log(JSON.stringify({ scrolls: log.scrolls, strips: log.strips }));
      JS
      expect(result["scrolls"]).to eq([["install", { "behavior" => "auto", "block" => "start" }]])
      expect(result["strips"]).to eq([["tabs", { "left" => 80, "top" => 0, "behavior" => "auto" }]])
    end

    it "handles clicks with one listener on the shell, ignoring clicks outside its links" do
      result = run_spy(<<~JS)
        const event = click(ide.shell, el("elsewhere"));
        console.log(JSON.stringify({ listeners: log.listeners, prevented: event.prevented, scrolls: log.scrolls }));
      JS
      expect(result["listeners"].select { |_, type| type == "click" }).to eq([%w[shell click]])
      expect(result["prevented"]).to be(false)
      expect(result["scrolls"]).to be_empty
    end

    it "picks up a section and links rendered after it was wired, on the next init" do
      result = run_spy(<<~JS)
        section("faq");
        const tab = ide.addLink("faq", ide.strip);
        ide.addLink("faq", ide.tree);
        window.swInitSidebarToc();
        intersect("editor", { readme: false, install: false, faq: true });
        const byScroll = ide.active();
        intersect("editor", { readme: true, faq: false });
        click(ide.shell, tab);
        console.log(JSON.stringify({ observers: log.observers.length, observed: log.observed,
                                     byScroll, byClick: ide.active(), scrolls: log.scrolls }));
      JS
      expect(result["observers"]).to eq(1)
      expect(result["observed"]).to eq(%w[editor:readme editor:install editor:faq])
      expect(result["byScroll"]).to eq(%w[faq:tabs faq:tree])
      expect(result["byClick"]).to eq(%w[faq:tabs faq:tree])
      expect(result["scrolls"]).to eq([["faq", { "behavior" => "smooth", "block" => "start" }]])
    end

    it "wires a kept editor node once across re-inits and restores its active section" do
      result = run_spy(<<~JS)
        intersect("editor", { install: true });
        ide.links.forEach((l) => l.classes.clear());   // a morphdom patch strips the class
        window.swInitSidebarToc();
        window.swInitSidebarToc();
        console.log(JSON.stringify({ observers: log.observers.length, listeners: log.listeners.length, active: ide.active() }));
      JS
      expect(result["observers"]).to eq(1)
      expect(result["listeners"]).to eq(3) # shell click, editor scrollend and scroll
      expect(result["active"]).to eq(%w[install:tabs install:tree])
    end
  end

  describe "the sidebar_toc spy" do
    it "observes its sections on the page itself, with the band below an 80px header" do
      result = run_spy("console.log(JSON.stringify(log));", ide: false, toc: true)
      expect(result["observers"]).to eq([{ "root" => "page", "rootMargin" => "-80px 0px -60% 0px" }])
      expect(result["observed"]).to eq(%w[page:summary page:risks])
    end

    it "marks the first section in the band and never sets aria-current" do
      result = run_spy(<<~JS, ide: false, toc: true)
        const start = toc.active();
        intersect("page", { summary: false, risks: true });
        console.log(JSON.stringify({ start, after: toc.active(), attrs: log.attrs }));
      JS
      expect(result["start"]).to eq(%w[toc:summary])
      expect(result["after"]).to eq(%w[toc:risks])
      expect(result["attrs"]).to be_empty
    end

    it "scrolls a clicked section into view without pinning it or moving focus" do
      result = run_spy(<<~JS, ide: false, toc: true)
        click(toc.nav, toc.links[1]);
        const clicked = toc.active();
        intersect("page", { summary: true, risks: false });
        console.log(JSON.stringify({ clicked, after: toc.active(), scrolls: log.scrolls, focus: log.focus }));
      JS
      expect(result["clicked"]).to eq(%w[toc:risks])
      expect(result["after"]).to eq(%w[toc:summary])
      expect(result["scrolls"]).to eq([["risks", { "behavior" => "smooth", "block" => "start" }]])
      expect(result["focus"]).to be_empty
    end

    it "reveals the active link only when the bar overflows" do
      result = run_spy(<<~JS, ide: false, toc: true)
        intersect("page", { summary: false, risks: true });
        const fits = log.scrolls.length;
        toc.nav.scrollWidth = 400;
        intersect("page", { summary: true });
        console.log(JSON.stringify({ fits, scrolls: log.scrolls }));
      JS
      expect(result["fits"]).to eq(0)
      expect(result["scrolls"]).to eq([["toc:summary", { "behavior" => "smooth", "block" => "nearest", "inline" => "center" }]])
    end
  end

  it "keeps the two spies apart when a page has both" do
    result = run_spy(<<~JS, ide: true, toc: true)
      intersect("editor", { readme: false, install: true });
      const afterEditor = { ide: ide.active(), toc: toc.active() };
      intersect("page", { summary: false, risks: true });
      console.log(JSON.stringify({ observers: log.observers, afterEditor,
                                   afterPage: { ide: ide.active(), toc: toc.active() } }));
    JS
    expect(result["observers"].map { |o| o["root"] }).to contain_exactly("page", "editor")
    expect(result["afterEditor"]).to eq("ide" => %w[install:tabs install:tree], "toc" => %w[toc:summary])
    expect(result["afterPage"]).to eq("ide" => %w[install:tabs install:tree], "toc" => %w[toc:risks])
  end
end
