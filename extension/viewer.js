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
  const dropZone = document.getElementById("drop-zone");
  const dropZoneError = document.getElementById("drop-zone-error");
  const fileInput = document.getElementById("file-input");

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

  // ---- Local-file entry point (S2) ----
  //
  // viewer.html has two ways to receive a doc now: the GitHub-button path
  // above (extension context, a chrome.storage.session key in the URL) and
  // this one -- a drop zone / file picker for any .org or .rb file on disk.
  // Both end up calling the same sendWhenReady()/postMessage("sw:render")
  // that talks to the sandbox iframe; this section only ever decides *what*
  // record to hand it, never how it gets there.
  //
  // Which mode to start in is decided by two independent checks, because
  // they catch two different situations:
  //
  //   - No chrome.runtime/chrome.storage at all: this page was opened
  //     completely outside the extension -- a bare `file://` open, or this
  //     repo's own browser-verification tooling, which cannot load a packaged
  //     extension to get real chrome.* APIs. There is no session storage to
  //     read regardless of what's in the URL, so this alone is enough to pick
  //     the drop zone. This is also *why* the drop zone had to be inline on
  //     viewer.html rather than a separate page: re-testing this feature
  //     needs to work by opening a bare file, and a second page would still
  //     need this same no-chrome-APIs fallback to be reachable that way.
  //   - chrome APIs exist but no "key" query param: inside the extension,
  //     but opened without a doc handed to it (e.g. bookmarked, or opened
  //     fresh from chrome://extensions). Today's only supplier (content.js)
  //     always sets a key, but nothing enforces that, so this page should
  //     degrade to something useful instead of the old dead-end "No document
  //     key" error.
  //
  // A key that *is* present but fails to resolve (expired/already-consumed
  // session entry, load()'s "no longer available" branch) stays a hard
  // error rather than falling back to the drop zone -- that case means a doc
  // was specified and is now gone, worth surfacing distinctly from "nothing
  // was ever specified."
  const hasExtensionContext =
    typeof chrome !== "undefined" && !!chrome.storage && !!chrome.storage.session && !!chrome.runtime;

  const SUPPORTED_FILE_RE = /\.(org|rb)$/i;

  function showDropZone() {
    status.hidden = true;
    frame.hidden = true;
    sourceLink.hidden = true; // no GitHub URL until a file is actually picked
    dropZone.hidden = false;
  }

  function showDropZoneError(text) {
    dropZoneError.textContent = text;
    dropZoneError.hidden = false;
  }

  function clearDropZoneError() {
    dropZoneError.hidden = true;
    dropZoneError.textContent = "";
  }

  // Shared by both entry points from here down: sets the record the render
  // pipeline reads and reuses the exact same sendWhenReady() the GitHub path
  // calls after load(). frame.hidden is not touched here -- it is only ever
  // flipped false once, by the "sw:sandbox-ready" handler above, and stays
  // that way for every render after the first (a second file dropped in
  // doesn't need the frame re-revealed, only re-rendered).
  function startRender(source, fileName) {
    dropZone.hidden = true;
    document.getElementById("doc-name").textContent = fileName;
    document.title = fileName;
    sourceLink.hidden = true; // no GitHub URL for a local file
    status.textContent = "Rendering…";
    status.className = "";
    status.hidden = false;
    record = { source, name: fileName };
    sendWhenReady();
  }

  async function handleFile(file) {
    if (!file) return;
    if (!SUPPORTED_FILE_RE.test(file.name)) {
      showDropZoneError(`Unsupported file: ${file.name}\n\nOnly .org and .rb StreamWeaver docs are supported.`);
      return;
    }

    let text;
    try {
      text = await file.text();
    } catch (e) {
      showDropZoneError(`Could not read file: ${e.message}`);
      return;
    }

    startRender(text, file.name);
  }

  function initDropZone() {
    // Clicking anywhere in the zone opens the picker; the visible
    // #file-picker-btn inside it is what gives this keyboard/screen-reader
    // access (Tab reaches it, Enter/Space activates it natively) without
    // needing a second, redundant keydown handler on the div itself.
    dropZone.addEventListener("click", () => fileInput.click());

    fileInput.addEventListener("change", () => {
      clearDropZoneError();
      handleFile(fileInput.files[0]);
      fileInput.value = ""; // allow re-picking the same file later
    });

    ["dragenter", "dragover"].forEach((evt) =>
      dropZone.addEventListener(evt, (e) => {
        e.preventDefault();
        dropZone.classList.add("drag-over");
      })
    );
    ["dragleave", "dragend"].forEach((evt) =>
      dropZone.addEventListener(evt, () => dropZone.classList.remove("drag-over"))
    );
    dropZone.addEventListener("drop", (e) => {
      e.preventDefault();
      dropZone.classList.remove("drag-over");
      clearDropZoneError();
      handleFile(e.dataTransfer.files[0]);
    });

    showDropZone();
  }

  if (!hasExtensionContext || !key) {
    initDropZone();
  } else {
    load();
  }
})();
