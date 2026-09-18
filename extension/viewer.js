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

  // Whether this page has the extension's own APIs at all. Declared up here
  // because both the navigation lockdown and the outbound-link opener need it
  // during load, not only the entry-point check at the bottom of this file --
  // which is where the reasoning for the test itself lives.
  const hasExtensionContext =
    typeof chrome !== "undefined" && !!chrome.storage && !!chrome.storage.session && !!chrome.runtime;

  // Reassigned per doc by resetSandboxFrame(); every read below, including the
  // event.source identity check, is meant to be the *current* frame.
  let frame = document.getElementById("frame");
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
  // What separates a still-pristine frame from one that must be replaced. Set
  // when a doc is actually posted, not when a file is picked: a frame nothing
  // ran in is still clean.
  let frameHasRendered = false;
  // The navigation guard's answer, once it has one. Written only by the
  // handlers at installNavLockdown()'s call site, which re-drive
  // sendWhenReady() so a doc that arrived while the guard was still pending
  // gets posted (or refused) as soon as the answer lands.
  let navLocked = false;
  let navFailure = null;

  // Hands the doc to the sandbox, once every precondition holds: the frame has
  // reported itself ready, there is a doc to send, this frame has not already
  // had one, and the tab's navigation guard is installed. That last one is why
  // this can be reached and decline to act -- rendering before the rule exists
  // means running doc code unprotected, so the guard gates the post rather
  // than racing it, and installNavLockdown's own handlers below call back here
  // once the answer is known.
  //
  // Everything it does is synchronous on purpose. An earlier version awaited
  // the guard here and needed a pre-emptive claim, captured locals and a
  // frame-identity re-check to survive the frame being replaced mid-await;
  // settling the guard into plain state instead means the post happens in the
  // same turn as the claim, so that hazard cannot arise. `frame` can never
  // change under this function: the only thing that replaces it is
  // startRender() -> resetSandboxFrame(), which runs only when
  // frameHasRendered is already true.
  function sendWhenReady() {
    if (!sandboxReady || !record || frameHasRendered) return;
    if (navFailure) {
      return showError(
        `StreamWeaver did not render this doc: the tab's navigation guard could not be installed.\n\n${
          navFailure.message || navFailure
        }`
      );
    }
    if (!navLocked) return;

    frame.contentWindow.postMessage(
      { type: "sw:render", source: record.source, name: record.name || name },
      "*"
    );
    frameHasRendered = true;
  }

  // Throws the sandbox frame away and puts a fresh one in its place.
  //
  // A sandbox frame is single-use. Rendering a doc runs its compiled Ruby
  // inside that frame's window, which installs state there that nothing can
  // take back out: window.SWRuntime and its click delegation, morphdom's
  // bookkeeping, and every interval/timeout or listener the doc's own
  // `every`/`after`/handlers registered (each `render_html` pass installs a
  // fresh timer with no cleanup of the prior one). There is no "unload the
  // doc" API -- discarding the whole browsing context is the only reliable
  // reset, so doc B never inherits doc A's live timers firing against what is
  // now doc B's DOM.
  //
  // Cloning the live element rather than building an iframe from scratch keeps
  // the security attributes in one place: whatever `sandbox`/`src` viewer.html
  // declares is what the replacement gets, with no second copy here to drift
  // out of sync when that attribute is tightened.
  function resetSandboxFrame() {
    const fresh = frame.cloneNode(false);
    // cloneNode copies attributes, and the first render removed the `hidden`
    // attribute; re-hide so the replacement goes through the same
    // hidden-until-"sw:sandbox-ready" sequence the shipped frame did, for the
    // reason that handler explains.
    fresh.hidden = true;
    frame.replaceWith(fresh);
    frame = fresh;
    sandboxReady = false;
    frameHasRendered = false;
  }

  window.addEventListener("message", (event) => {
    // The frame has a null origin, so origin cannot be checked. It is the only
    // thing that can post here, though: this page is never web-accessible, so
    // no site can open it or reach into it.
    if (event.source !== frame.contentWindow) return;
    const msg = event.data || {};

    if (msg.type === "sw:sandbox-ready") {
      // Consumed exactly once per frame. sandbox.js posts it once, but doc
      // code runs in that same window and can post it again itself, and a
      // replay that re-drove sendWhenReady() would render the doc a second
      // time into a frame its own code has already dirtied.
      // extension-sandbox-per-doc found the stale-message half of this bug
      // (a discarded frame's late readiness re-posting "sw:render"); this
      // closes the replay half, which the event.source check cannot see
      // because the replay really does come from the current frame.
      if (sandboxReady) return;
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
    } else if (msg.type === "sw:open-external") {
      openExternal(msg.href);
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

  // ---- Navigation lockdown ----
  //
  // What is left to close: extension-csp-hardening's default-src/connect-src/
  // form-action 'none' stops the sandbox fetching, XHR-ing or form-posting to
  // a remote origin, and the iframe no longer has allow-popups, so doc code
  // cannot open a tab. Navigation of the frame itself (window.location = ...)
  // is neither -- CSP does not govern it and no sandbox token removes it --
  // and it is exactly what a tab-scoped declarativeNetRequest rule does
  // block, because it is a sub_frame request in this tab (disc-191 verified
  // both halves live in Chrome: the rule blocks the self-navigation, and the
  // same rule cannot touch a popup, whose new tab has an id no tab-scoped
  // rule matches -- hence removing popups outright instead).
  function navLockdownRules(tabId) {
    // Ids are derived from the tab so every viewer tab owns its own pair and
    // two open viewers never overwrite each other's rules (session rule ids
    // are extension-global). Offset by one because a rule id must be >= 1.
    const blockId = tabId * 2 + 1;
    return [
      {
        id: blockId,
        priority: 1,
        action: { type: "block" },
        condition: {
          urlFilter: "*",
          tabIds: [tabId],
          // sub_frame only, deliberately. main_frame would also block the
          // *user's* own navigation of this tab -- typing a URL, hitting
          // Back -- and the sandbox cannot navigate the top frame at all
          // without allow-top-navigation, which its sandbox attribute does
          // not grant. Sub-resource types (xmlhttprequest, image, font,
          // media) are already closed by the sandbox CSP, so repeating them
          // here would add risk -- the extension's own data:/blob: assets --
          // without adding coverage.
          resourceTypes: ["sub_frame"]
        }
      },
      {
        // The block rule must never be able to shoot the extension itself:
        // sandbox.html loads as a sub_frame in this very tab, and so would
        // any replacement frame. An explicit higher-priority allow for the
        // extension's own URL prefix makes that safe regardless of whether
        // chrome-extension: requests are matchable by DNR at all.
        id: blockId + 1,
        priority: 2,
        action: { type: "allow" },
        condition: {
          urlFilter: `|${chrome.runtime.getURL("")}`,
          tabIds: [tabId],
          resourceTypes: ["sub_frame"]
        }
      }
    ];
  }

  async function installNavLockdown() {
    if (!hasExtensionContext) {
      // viewer.html opened as a bare file:// page -- the documented
      // local-file entry point (extension/README.md, "Local-file entry point
      // (S2)"). There are no chrome.* APIs to install a rule with, and
      // manifest.json's sandbox CSP does not apply to that page either, so
      // this path is unprotected by construction rather than
      // protected-and-failing; failing closed here would only break local
      // preview without closing anything. Its trust warning belongs with the
      // rest of that path's caveats, not here.
      return;
    }

    if (!chrome.declarativeNetRequest) {
      throw new Error(
        'chrome.declarativeNetRequest is unavailable -- the "declarativeNetRequest" permission is missing'
      );
    }

    const tab = await chrome.tabs.getCurrent();
    if (!tab || typeof tab.id !== "number") {
      throw new Error("this tab's own id could not be determined, so the rule cannot be scoped to it");
    }

    const rules = navLockdownRules(tab.id);
    await chrome.declarativeNetRequest.updateSessionRules({
      // Idempotent: a reloaded viewer in a recycled tab id replaces its own
      // rules instead of failing on a duplicate id.
      removeRuleIds: rules.map((rule) => rule.id),
      addRules: rules
    });
  }

  // Start the guard now, at load, so it is usually settled before any doc
  // arrives -- and record its answer where sendWhenReady() can read it
  // synchronously. Either handler re-drives sendWhenReady(), which is what
  // covers a doc that arrived while the install was still in flight: it
  // declined to post then, and this is what tells it to try again. Both
  // outcomes are handled here, so a failed install is never also an unhandled
  // promise rejection.
  installNavLockdown().then(
    () => {
      navLocked = true;
      sendWhenReady();
    },
    (e) => {
      navFailure = e;
      sendWhenReady();
    }
  );

  // ---- Outbound links ----
  //
  // A rendered doc's links cannot open themselves any more, so the sandbox
  // asks instead: it posts the resolved href and this side -- the privileged
  // half, the one with chrome.* -- decides whether to honor it. That is the
  // VS Code webview shape: the untrusted content holds no capability, only a
  // narrow message it can ask through, and the privileged side validates
  // before acting.
  //
  // Handled here rather than in background.js on purpose. The service
  // worker's chrome.runtime.onMessage is reachable from every content script
  // this extension injects into github.com, so an "open this URL" handler
  // there would be callable by any page it runs on. This page is never a
  // web-accessible resource, and its message listener already pins
  // event.source to the current sandbox frame, so nothing on the web can
  // reach this one.
  const OPENABLE_PROTOCOLS = ["http:", "https:"];

  function openExternal(href) {
    let url;
    try {
      url = new URL(String(href));
    } catch (e) {
      console.warn("[StreamWeaver] ignored a link that is not a URL:", href);
      return;
    }

    // An allowlist, not a blocklist: javascript:, data:, blob:, file: and
    // chrome-extension: are each a navigation a doc must not be able to hand
    // the user, and so is whatever else is not named above.
    if (!OPENABLE_PROTOCOLS.includes(url.protocol)) {
      console.warn(`[StreamWeaver] refused to open a ${url.protocol} link:`, url.href);
      return;
    }

    if (hasExtensionContext) {
      chrome.tabs.create({ url: url.href });
      return;
    }

    // Bare file:// entry point again: no chrome.tabs to open a tab with. This
    // is the outer page, not the sandbox, so its own window.open is a
    // validated navigation performed by the viewer -- not doc code driving
    // one.
    window.open(url.href, "_blank", "noopener,noreferrer");
  }

  // ---- Local-file entry point (S2) ----
  //
  // viewer.html has two ways to receive a doc: the GitHub-button path above
  // (extension context, a chrome.storage.session key in the URL) and this one
  // -- a drop zone / file picker for any .org or .rb file on disk. Both end up
  // calling the same sendWhenReady()/postMessage("sw:render") that talks to
  // the sandbox iframe; this section only ever decides *what* record to hand
  // it, never how it gets there. Which one serves a given page load is decided
  // at the bottom of this file, where the reasoning for that test lives.
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
  // calls after load(). frame.hidden is not touched here -- each frame is
  // unhidden once by the "sw:sandbox-ready" handler above, and this path gets
  // a brand-new frame (and so a brand-new ready message) per doc.
  function startRender(source, fileName) {
    // Only this path can render twice in one tab, and only from the second doc
    // on: reusing the pristine frame viewer.html shipped saves loading
    // sandbox.html (and its vendored runtime) a second time for nothing. The
    // GitHub/Gist path never reaches here -- background.js opens a fresh tab
    // per click, so its frame renders exactly once.
    if (frameHasRendered) resetSandboxFrame();
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

  // Which of the two entry points this page is serving is decided by two
  // independent checks, because they catch two different situations:
  //
  //   - No chrome.runtime/chrome.storage at all (hasExtensionContext, declared
  //     at the top of this file): this page was opened completely outside the
  //     extension -- a bare `file://` open, or this repo's own
  //     browser-verification tooling, which cannot load a packaged extension
  //     to get real chrome.* APIs. There is no session storage to read
  //     regardless of what's in the URL, so this alone is enough to pick the
  //     drop zone. This is also *why* the drop zone had to be inline on
  //     viewer.html rather than a separate page: re-testing this feature needs
  //     to work by opening a bare file, and a second page would still need
  //     this same no-chrome-APIs fallback to be reachable that way.
  //   - chrome APIs exist but no "key" query param: inside the extension, but
  //     opened without a doc handed to it (e.g. bookmarked, or opened fresh
  //     from chrome://extensions). Today's only supplier (content.js) always
  //     sets a key, but nothing enforces that, so this page should degrade to
  //     something useful instead of the old dead-end "No document key" error.
  //
  // A key that *is* present but fails to resolve (expired/already-consumed
  // session entry, load()'s "no longer available" branch) stays a hard error
  // rather than falling back to the drop zone -- that case means a doc was
  // specified and is now gone, worth surfacing distinctly from "nothing was
  // ever specified."
  if (!hasExtensionContext || !key) {
    initDropZone();
  } else {
    load();
  }
})();
