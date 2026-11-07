# frozen_string_literal: true

require_relative "../support/ide_markup"
require_relative "../support/node_js"

RSpec.describe "ide_editor and file_section" do
  include IdeMarkup

  let(:page) do
    render_ide_page do
      ide_editor do
        file_section "readme", label: "README.md" do
          text "Hello"
        end
        file_section "install", label: "docs/INSTALL.md", icon: :package, comment: "INSTALL" do
          text "gem install stream_weaver"
        end
        file_section "faq", label: "FAQ.md", icon: "?", comment: false
      end
    end
  end
  let(:editor) { ide_region(page, "main", "sw-ide-editor") }
  let(:tabs) { find_all(editor, "nav[@class='sw-ide-tabstrip']/a") }
  let(:sections) { find_all(editor, "section") }

  describe "the generated tab strip" do
    it "comes first in the editor, one tab per file section, in order" do
      strip = editor.elements[1]
      expect(strip.name).to eq("nav")
      expect(strip.attributes["aria-label"]).to eq("Open files")
      expect(strip.attributes["data-sw-ide-links"]).to eq("")
      expect(tabs.map { |tab| text_of(first(tab, "span[@class='sw-ide-tab__label']")) })
        .to eq(%w[README.md INSTALL.md FAQ.md])
    end

    it "links each tab to its section by in-page href and spy target" do
      expect(tabs.map { |tab| tab.attributes["href"] }).to eq(%w[#readme #install #faq])
      expect(tabs.map { |tab| tab.attributes["data-sw-ide-target"] }).to eq(%w[readme install faq])
      expect(tabs.map { |tab| tab.attributes["class"] }).to all(eq("sw-ide-tab"))
    end

    it "shows each section's icon on its tab" do
      expect(first(tabs[0], "*[local-name()='svg'][@class='sw-ide-tab__icon']")).not_to be_nil
      expect(text_of(first(tabs[2], "span[@aria-hidden='true']/span[@class='sw-ide-tab__icon']"))).to eq("?")
    end

    it "is absent from an editor with no file sections, which loads no scroll spy" do
      plain = render_ide_page { ide_editor { text "Just text" } }
      expect(find_all(ide_region(plain, "main", "sw-ide-editor"), ".//nav")).to be_empty
      expect(plain).not_to include("swInitSidebarToc")
    end
  end

  describe "the file sections" do
    it "are anchors named by their name, carrying their file path" do
      expect(sections.map { |s| s.attributes["id"] }).to eq(%w[readme install faq])
      expect(sections.map { |s| s.attributes["data-file"] }).to eq(%w[README.md docs/INSTALL.md FAQ.md])
      expect(sections.map { |s| s.attributes["class"] }).to all(eq("sw-ide-file-section"))
    end

    it "open with a comment line, defaulting to the label, unless comment: false" do
      comments = sections.map { |s| first(s, "p[@class='sw-ide-file-section__comment']") }
      expect(comments[0..1].map { |c| text_of(c) }).to eq(["<!-- README.md -->", "<!-- INSTALL -->"])
      expect(comments[2]).to be_nil
    end

    it "render their block as the section body" do
      expect(text_of(sections[1])).to include("gem install stream_weaver")
    end
  end

  it "ships the shared scroll spy once, with the ide editor wired into it" do
    expect(page.scan("window.swInitSidebarToc = init").size).to eq(1)
    expect(page).to include("document.querySelector('.sw-ide-editor')")
  end

  # The scroll spy itself, run in node against a stub DOM: a shell whose
  # editor holds two sections, with a tab strip and a second link list (a
  # right-rail file tree) pointing at the same sections.
  describe "scroll spy wiring" do
    include NodeJS

    let(:spy_js) { File.read(File.expand_path("../../lib/stream_weaver/assets/js/sw-sidebar-toc.js", __dir__)) }

    let(:shim) do
      <<~JS
        globalThis.window = globalThis;
        const log = { observers: [], observed: [], scrolls: [], strips: [], listeners: {} };

        function box(top, bottom, left, right) { return { top, bottom, left, right }; }
        function makeLink(target, list) {
          const attrs = { "data-sw-ide-target": target };
          const classes = new Set();
          const handlers = {};
          return {
            target, list, attrs, classes,
            getAttribute: (name) => (name in attrs ? attrs[name] : null),
            setAttribute: (name, value) => { attrs[name] = value; },
            removeAttribute: (name) => { delete attrs[name]; },
            classList: { add: (c) => classes.add(c), remove: (c) => classes.delete(c) },
            addEventListener: (type, fn) => { handlers[type] = fn; },
            click: () => handlers.click({ preventDefault() {} }),
            closest: (sel) => (sel === "[data-sw-ide-links]" ? list : null),
            getBoundingClientRect: () => link_boxes[target + ":" + list.name] || box(0, 10, 0, 10)
          };
        }
        const link_boxes = {};
        const tabstrip = { name: "tabs", getBoundingClientRect: () => box(0, 36, 0, 300),
                           scrollBy: (opts) => log.strips.push(["tabs", opts]) };
        const filetree = { name: "tree", getBoundingClientRect: () => box(100, 300, 900, 1200),
                           scrollBy: (opts) => log.strips.push(["tree", opts]) };
        const links = [makeLink("readme", tabstrip), makeLink("install", tabstrip),
                       makeLink("readme", filetree), makeLink("install", filetree)];
        const shell = { querySelectorAll: (sel) => (sel === "[data-sw-ide-target]" ? links : []) };
        const editor = {
          scrollTop: 0, clientHeight: 700, scrollHeight: 2000,
          closest: (sel) => (sel === ".sw-ide-shell" ? shell : null),
          addEventListener: (type, fn) => { log.listeners[type] = fn; }
        };
        const sections = {};
        ["readme", "install"].forEach((id) => {
          sections[id] = { id, scrollIntoView: (opts) => log.scrolls.push([id, opts]) };
        });

        let observerCallback = null;
        globalThis.IntersectionObserver = function (callback, options) {
          observerCallback = callback;
          log.observers.push({ rootIsEditor: options.root === editor, rootMargin: options.rootMargin });
          return { observe: (el) => log.observed.push(el.id) };
        };
        globalThis.document = {
          readyState: "complete",
          querySelector: (sel) => (sel === ".sw-ide-editor" ? editor : null),
          getElementById: (id) => sections[id] || null,
          addEventListener() {}
        };
        const intersect = (states) =>
          observerCallback(Object.entries(states).map(([id, on]) => ({ target: sections[id], isIntersecting: on })));
        const active = () => links.filter((l) => l.classes.has("sw-is-active")).map((l) => l.target + ":" + l.list.name);
        const current = () => links.filter((l) => l.attrs["aria-current"]).map((l) => l.target + ":" + l.list.name);
      JS
    end

    def run_spy(driver)
      run_node_json(shim, spy_js, driver)
    end

    it "observes each section once, inside the editor, below the tab strip" do
      result = run_spy("console.log(JSON.stringify(log));")
      expect(result["observers"]).to eq([{ "rootIsEditor" => true, "rootMargin" => "-48px 0px -60% 0px" }])
      expect(result["observed"]).to eq(%w[readme install])
    end

    it "starts on the first section, marking every link to it, without scrolling any list" do
      result = run_spy("console.log(JSON.stringify({ active: active(), current: current(), strips: log.strips }));")
      expect(result["active"]).to eq(%w[readme:tabs readme:tree])
      expect(result["current"]).to eq(%w[readme:tabs readme:tree])
      expect(result["strips"]).to be_empty
    end

    it "moves the shared active section to the first section in the band as the editor scrolls" do
      result = run_spy(<<~JS)
        intersect({ readme: true, install: true });
        const both = active();
        intersect({ readme: false });
        console.log(JSON.stringify({ both, after: active(), current: current() }));
      JS
      expect(result["both"]).to eq(%w[readme:tabs readme:tree])
      expect(result["after"]).to eq(%w[install:tabs install:tree])
      expect(result["current"]).to eq(%w[install:tabs install:tree])
    end

    it "marks the last section once the editor is scrolled to its end, even with the first still in the band" do
      result = run_spy(<<~JS)
        log.listeners.scroll();
        const midway = active();
        editor.scrollTop = 1300;
        log.listeners.scroll();
        const byScroll = active();
        intersect({ readme: true });
        console.log(JSON.stringify({ midway, byScroll, byObserver: active() }));
      JS
      expect(result["midway"]).to eq(%w[readme:tabs readme:tree])
      expect(result["byScroll"]).to eq(%w[install:tabs install:tree])
      expect(result["byObserver"]).to eq(%w[install:tabs install:tree])
    end

    it "scrolls the active link into view within its own list only" do
      result = run_spy(<<~JS)
        link_boxes["install:tabs"] = box(0, 36, 280, 380);    // past the strip's right edge
        link_boxes["install:tree"] = box(150, 170, 900, 1200); // already visible
        intersect({ install: true });
        console.log(JSON.stringify({ strips: log.strips }));
      JS
      expect(result["strips"]).to eq([["tabs", { "left" => 80, "top" => 0, "behavior" => "smooth" }]])
    end

    it "scrolls a clicked tab's section into view and holds it active until the scroll ends" do
      result = run_spy(<<~JS)
        links[1].click();
        const clicked = active();
        intersect({ readme: true, install: false });   // passing sections mid-scroll
        const during = active();
        log.listeners.scrollend();
        intersect({ readme: true, install: false });
        console.log(JSON.stringify({ scrolls: log.scrolls, clicked, during, after: active() }));
      JS
      expect(result["scrolls"]).to eq([["install", { "behavior" => "smooth", "block" => "start" }]])
      expect(result["clicked"]).to eq(%w[install:tabs install:tree])
      expect(result["during"]).to eq(%w[install:tabs install:tree])
      expect(result["after"]).to eq(%w[readme:tabs readme:tree])
    end

    it "wires a kept editor node once across re-inits and restores its active section" do
      result = run_spy(<<~JS)
        intersect({ install: true });
        links.forEach((l) => l.classes.clear());   // a morphdom patch strips the class
        window.swInitSidebarToc();
        window.swInitSidebarToc();
        console.log(JSON.stringify({ observers: log.observers.length, active: active() }));
      JS
      expect(result["observers"]).to eq(1)
      expect(result["active"]).to eq(%w[install:tabs install:tree])
    end
  end
end
