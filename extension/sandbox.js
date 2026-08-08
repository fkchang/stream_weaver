// Compiles a StreamWeaver doc's Ruby and renders it.
//
// Runs sandboxed so the compiler's output can be evaluated -- see the comment
// in sandbox.html. Receives source over postMessage because a sandboxed page
// has no extension APIs of its own.

(function () {
  "use strict";

  const app = document.getElementById("sw-app");
  const errorBox = document.getElementById("sw-error");

  function fail(stage, err) {
    const detail = (err && (err.message || err.toString())) || String(err);
    errorBox.textContent = `StreamWeaver could not render this doc.\n\n${stage}: ${detail}`;
    errorBox.style.display = "block";
    parent.postMessage({ type: "sw:render-failed", stage, detail }, "*");
  }

  // Ruby's heredocs are how doc bodies carry prose, and Opal's self-hosted
  // parser cannot lex any form of them -- unlike the MRI-hosted compiler,
  // which handles them fine. Rewriting them to quoted strings first is what
  // makes in-browser compilation work on real documents.
  function toCompilableRuby(source, name) {
    const rewrite = self.swRewriteHeredocs;
    if (typeof rewrite !== "function") throw new Error("heredoc rewriter not loaded");

    const title = JSON.stringify(name || "StreamWeaver Doc");
    return `app(${title}) do\n${rewrite(source)}\nend\n`;
  }

  // Static markup rather than a live runtime: this is a document viewer, so
  // there is nothing to interact with, and skipping SWRuntime.start() avoids
  // installing event delegation and a re-render loop that would never fire.
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

    let html, css;
    try {
      html = SWRender.html();
      css = SWRender.css();
    } catch (e) {
      return fail("Rendering document", e);
    }

    if (css) {
      const style = document.createElement("style");
      style.textContent = css;
      document.head.appendChild(style);
    }
    app.innerHTML = html;

    enhance();
    parent.postMessage({ type: "sw:rendered", bytes: html.length }, "*");
  }

  // Prism and Mermaid decorate markup rather than produce it, so they run
  // after the HTML is in the DOM. Failures here are cosmetic -- the document
  // is already readable -- so they are logged rather than surfaced.
  function enhance() {
    try {
      if (typeof Prism !== "undefined") Prism.highlightAll();
    } catch (e) {
      console.error("[StreamWeaver] highlighting failed:", e);
    }

    try {
      if (typeof mermaid === "undefined") return;
      mermaid.initialize({ startOnLoad: false, theme: "default" });
      const nodes = document.querySelectorAll(".sw-mermaid:not([data-processed])");
      if (nodes.length) {
        mermaid.run({ nodes }).catch((e) => console.error("[StreamWeaver] mermaid failed:", e));
      }
    } catch (e) {
      console.error("[StreamWeaver] mermaid failed:", e);
    }
  }

  window.addEventListener("message", (event) => {
    const msg = event.data;
    if (!msg || msg.type !== "sw:render") return;
    render(msg.source, msg.name);
  });

  parent.postMessage({ type: "sw:sandbox-ready" }, "*");
})();
