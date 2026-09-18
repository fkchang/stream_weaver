// Compiles a StreamWeaver doc's Ruby and renders it.
//
// Runs sandboxed so the compiler's output can be evaluated -- see the comment
// in sandbox.html. Receives source over postMessage because a sandboxed page
// has no extension APIs of its own.

(function () {
  "use strict";

  const app = document.getElementById("app-container");
  const errorBox = document.getElementById("sw-error");

  function fail(stage, err) {
    const detail = (err && (err.message || err.toString())) || String(err);
    errorBox.textContent = `StreamWeaver could not render this doc.\n\n${stage}: ${detail}`;
    errorBox.style.display = "block";
    parent.postMessage({ type: "sw:render-failed", stage, detail }, "*");
  }

  // '#+STREAMWEAVER_DSL: 1' is the org format's own version marker, first
  // line always (org-doc-format-design.md) -- same check content.js uses to
  // decide whether to offer the button in the first place, repeated here
  // since the sandbox only receives raw source, not the extension of the
  // file it came from.
  const ORG_MARKER_RE = /^#\+STREAMWEAVER_DSL:\s*\d+/m;

  // Org::Reader is bundled into sw-runtime.js (build_extension) alongside
  // the rest of the StreamWeaver runtime -- Reader only, not Writer, since
  // Writer needs `ripper` (MRI-only) and the extension only ever reads
  // .org, never writes it. Already-compiled, so this is a direct Opal JS
  // call (Opal's $-prefixed method convention), not a second Opal.eval --
  // no need to re-parse a call expression through the self-hosted parser.
  function orgToDsl(source) {
    return Opal.StreamWeaver.Org.Reader.$to_dsl(source);
  }

  // Ruby's heredocs are how doc bodies carry prose, and Opal's self-hosted
  // parser cannot lex any form of them -- unlike the MRI-hosted compiler,
  // which handles them fine. Rewriting them to quoted strings first is what
  // makes in-browser compilation work on real documents.
  function toCompilableRuby(source, name) {
    if (ORG_MARKER_RE.test(source)) source = orgToDsl(source);

    const rewrite = self.swRewriteHeredocs;
    if (typeof rewrite !== "function") throw new Error("heredoc rewriter not loaded");

    const title = JSON.stringify(name || "StreamWeaver Doc");
    return `app(${title}) do\n${rewrite(source)}\nend\n`;
  }

  // The live runtime, not the one-pass static render this used to call.
  //
  // A doc's interactive controls -- a sortable table's column header, a
  // text_field, a checkbox -- are inert without it: SWRuntime.start() is what
  // installs the delegated event listeners and the morphdom patch loop, and
  // it renders through the region-wrapping path those patches target.
  // Both SWRuntime and SWRender are installed by every compiled doc's `app()`
  // call regardless (opal_entry.rb), so this is a change of which one is
  // asked to render, not new capability.
  //
  // start() is handed this page's own container id. The runtime defaults to
  // "sw-app"; sandbox.html explains why this page cannot be renamed to match.
  //
  // Component CSS needs no handling here any more: rendering through the live
  // runtime routes it through the adapter's inject_component_css, which writes
  // one keyed <style> into <head> per component and is therefore idempotent
  // across the re-renders this page now does.
  function render(source, name) {
    let ruby;
    try {
      ruby = toCompilableRuby(source, name);
    } catch (e) {
      return fail("Preparing source", e);
    }

    try {
      Opal.eval(ruby);
    } catch (e) {
      return fail("Compiling Ruby", e);
    }

    try {
      window.SWRuntime.start("app-container");
    } catch (e) {
      return fail("Rendering document", e);
    }

    parent.postMessage({ type: "sw:rendered", bytes: app.innerHTML.length }, "*");
  }

  // Every link in a rendered doc is routed by this one delegated handler --
  // at the cause, not per component, so a link works the same whether the
  // component that emitted it ships its own JS or not (stream_weaver-v3ni).
  //
  // Same-page fragment links (sidebar_toc's, or a hand-written
  // [text](#anchor) inside an md block) scroll in place. They have no
  // business opening a new tab, and sandbox.html's <base target="_blank">
  // applies to every link on the page, not just outbound ones, so without
  // this they inherit it and try to pop themselves open -- reproduced live as
  // a genuine navigation error, not hypothetical.
  //
  // Everything else is outbound, and this frame can no longer open one
  // itself: viewer.html's iframe grants only allow-scripts now (no popups),
  // and a tab-scoped declarativeNetRequest rule blocks this frame navigating
  // itself. So the click is handed to the privileged half instead -- viewer.js
  // validates the URL and opens it with chrome.tabs.create. Doc code can ask
  // for a navigation; it cannot perform one.
  //
  // The href is read as an attribute and resolved here rather than taken from
  // `link.href`, because not every anchor in a rendered doc is an HTML one.
  // Mermaid runs at `securityLevel: 'loose'` (vendor/sw-mermaid-zoom.js),
  // which is exactly the level that turns a diagram's `click A "https://..."`
  // into a real <a> inside the generated SVG -- and an SVGAElement's `.href`
  // is an SVGAnimatedString, not a string. Posting that would throw
  // DataCloneError *after* preventDefault, i.e. a silently dead click; it has
  // no `.hash` either, so the fragment branch below would throw on one too.
  // Some mermaid renderers also write the URL to `xlink:href` rather than
  // `href`, which is why both namespaces are read here and why the selector
  // is the namespace wildcard `[*|href]` -- that form matches an href in any
  // namespace *including none*, so it subsumes plain `a[href]` rather than
  // needing to be paired with it. Downstream this is always a plain absolute
  // string, which is what the far side needs anyway since it validates a
  // scheme.
  const XLINK_NS = "http://www.w3.org/1999/xlink";

  function linkHref(link) {
    return link.getAttribute("href") ?? link.getAttributeNS(XLINK_NS, "href");
  }

  document.addEventListener("click", (event) => {
    const link = event.target.closest("a[*|href]");
    if (!link) return;

    // Falsy, not just null: the wildcard selector also matches an anchor
    // whose href lives in some third namespace, where both getters come back
    // empty, and an href of "" is nothing worth handing across the boundary
    // either.
    const href = linkHref(link);
    if (!href) return;

    if (href.startsWith("#")) {
      event.preventDefault();
      document.getElementById(href.slice(1))?.scrollIntoView({ behavior: "smooth" });
      return;
    }

    // Only a real user click asks for a tab. Doc code can build an anchor and
    // call .click() on it, and that synthetic event is indistinguishable from
    // a user's by everything except isTrusted -- without this check it would
    // be a way to make the privileged half open an arbitrary URL with no user
    // action at all, which is the popup capability coming back in through the
    // side door. Untrusted clicks are left to the browser's own refusals
    // instead (a synthetic click still tries to navigate or pop open, and
    // both of those are now blocked), which is why this branch does not
    // preventDefault before bailing out.
    if (!event.isTrusted) return;

    event.preventDefault();

    let resolved;
    try {
      resolved = new URL(href, document.baseURI).href;
    } catch (e) {
      // A malformed href resolves to nothing usable. Hand it over as-is
      // rather than throwing inside a click handler: the privileged side
      // already refuses anything it cannot parse.
      resolved = href;
    }

    parent.postMessage({ type: "sw:open-external", href: resolved }, "*");
  });

  // Prism, sidebar-toc and Mermaid decorate markup rather than produce it, so
  // they run after the HTML is in the DOM. Failures here are cosmetic -- the
  // document is already readable -- so they are logged rather than surfaced.
  //
  // All three self-initialize at DOMContentLoaded, which fires before any doc
  // content exists in #app-container. Every other host re-triggers them with a
  // real htmx:afterSwap event; this page has no htmx, so it calls their
  // exported hooks itself.
  function enhance() {
    try {
      if (typeof Prism !== "undefined") Prism.highlightAll();
    } catch (e) {
      console.error("[StreamWeaver] highlighting failed:", e);
    }

    try {
      self.swInitSidebarToc?.();
    } catch (e) {
      console.error("[StreamWeaver] sidebar toc failed:", e);
    }

    runMermaidWhenPainted();
  }

  // Once per patch, not once per document.
  //
  // morphdom replaces nodes and takes their decoration with them, so a doc
  // that re-renders (which is the whole point of starting the live runtime)
  // would otherwise lose its highlighting and diagrams on the first
  // interaction and never get them back. OpalRuntime#announce_render fires
  // this event at the end of every patch, full-container or per-region alike.
  //
  // Registered at load, before any render(): the first patch happens inside
  // SWRuntime.start(), so a listener attached afterwards would miss it.
  //
  // Each hook is responsible for its own idempotency, and each one's guard has
  // to key on node identity rather than on a DOM attribute -- morphdom syncs
  // attributes from freshly rendered markup that never carries the guard flag,
  // so it strips the flag while keeping the very node whose listeners are
  // already attached (see sw-sidebar-toc.js and sw-mermaid-zoom.js).
  document.addEventListener("sw:render", enhance);

  // viewer.js unhides this iframe before sending "sw:render" specifically so
  // mermaid has real layout to measure (a hidden ancestor makes getBBox etc.
  // return NaN -- see viewer.js's comment on why frame.hidden flips there,
  // not here). That fixes the steady-state case, but postMessage delivery
  // between the extension's separate frames has enough IPC latency variance
  // that the unhide and this handler running aren't strictly ordered by wall
  // clock alone -- reproduced in production (not locally: a same-process
  // localhost postMessage round-trip is fast and consistent enough to never
  // hit this) as the exact same NaN transform error even with the frame
  // already unhidden by the time it was inspected after the fact. Waiting
  // for two animation frames is a wall-clock-independent guarantee instead
  // of a race: it always means "the browser has completed at least one real
  // layout+paint pass since now," regardless of how postMessage IPC timing
  // varies between a local test and a real extension.
  //
  // sw-mermaid-zoom.js (vendor, stream_weaver-mermaid-extension) is the same
  // engine canvas/reader use -- it owns mermaid.initialize(), diagram
  // rendering, and the zoom/pan/expand controls Adapter::Static now emits
  // markup for. It self-inits on DOMContentLoaded, which fires before this
  // render() has put any doc content into #app-container, so it has to be
  // invoked directly here too, same as swInitSidebarToc above; the paint
  // guard this function existed for stays wrapped around that call.
  function runMermaidWhenPainted() {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        try {
          self.swMermaidInit?.();
        } catch (e) {
          console.error("[StreamWeaver] mermaid failed:", e);
        }
      });
    });
  }

  window.addEventListener("message", (event) => {
    const msg = event.data;
    if (!msg || msg.type !== "sw:render") return;
    render(msg.source, msg.name);
  });

  parent.postMessage({ type: "sw:sandbox-ready" }, "*");
})();
