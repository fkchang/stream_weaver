// Outer half of the viewer.
//
// Holds the extension APIs the sandboxed frame cannot have: it reads the doc
// source the content script stashed in session storage, then hands it to the
// frame by postMessage. Everything from compilation onward happens in there.

(function () {
  "use strict";

  const params = new URLSearchParams(location.search);
  const key = params.get("key");
  const name = params.get("name") || "StreamWeaver doc";

  const frame = document.getElementById("frame");
  const status = document.getElementById("status");
  const sourceLink = document.getElementById("source-link");

  document.getElementById("doc-name").textContent = name;
  document.title = name;

  function showError(text) {
    status.textContent = text;
    status.className = "error";
    status.hidden = false;
    frame.hidden = true;
  }

  let record = null;
  let sandboxReady = false;

  function sendWhenReady() {
    if (!sandboxReady || !record) return;
    frame.contentWindow.postMessage(
      { type: "sw:render", source: record.source, name: record.name || name },
      "*"
    );
  }

  window.addEventListener("message", (event) => {
    // The frame has a null origin, so origin cannot be checked. It is the only
    // thing that can post here, though: this page is never web-accessible, so
    // no site can open it or reach into it.
    if (event.source !== frame.contentWindow) return;
    const msg = event.data || {};

    if (msg.type === "sw:sandbox-ready") {
      sandboxReady = true;
      // Unhide the frame before, not after, asking it to render -- not just
      // cosmetic. sandbox.js's render() calls mermaid.run() synchronously as
      // part of handling "sw:render", and mermaid measures real DOM layout
      // (getBBox etc.) to position diagram nodes. A hidden iframe (or any
      // hidden ancestor) has no layout box, so those measurements come back
      // NaN and mermaid fails with `<g> transform: "translate(undefined,
      // NaN)"` -- reproduced directly, this exact sequencing is the cause.
      // postMessage delivery to the frame is async, so unhiding here (before
      // sendWhenReady's postMessage even goes out) guarantees the frame has
      // real layout by the time the frame's own message handler -- and
      // therefore render()/mermaid.run() -- executes.
      frame.hidden = false;
      sendWhenReady();
    } else if (msg.type === "sw:rendered") {
      status.hidden = true;
    } else if (msg.type === "sw:render-failed") {
      showError(`StreamWeaver could not render this doc.\n\n${msg.stage}: ${msg.detail}`);
    }
  });

  async function load() {
    if (!key) return showError("No document key. Open a doc from its GitHub page.");

    let stored;
    try {
      stored = await chrome.storage.session.get(key);
    } catch (e) {
      return showError(`Could not read the stashed document: ${e.message}`);
    }

    record = stored[key];
    if (!record || !record.source) {
      return showError("That document is no longer available. Reopen it from GitHub.");
    }

    if (record.url) {
      sourceLink.href = record.url;
    } else {
      sourceLink.hidden = true;
    }

    // One-shot handoff: the source lives in the tab, not in storage, once the
    // viewer has it. Leaving copies of every doc ever opened in session
    // storage serves nothing.
    chrome.storage.session.remove(key).catch(() => {});

    sendWhenReady();
  }

  load();
})();
