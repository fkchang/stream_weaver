// Adds a "View rendered" button to StreamWeaver docs on GitHub.
//
// The whole file is already in the page: GitHub's blob view embeds it as a
// rawLines array in a JSON <script> block, so recognizing a doc costs no
// network request. That JSON is GitHub's internal shape and will change
// eventually, so a Raw-link fetch stands behind it.
//
// Detection is by content, not filename. `DocStore` stamps every saved .rb
// doc with a marker comment, which travels with the file regardless of path
// or extension -- so this works on forks and files someone moved, and on
// gists too (gist.github.com is a second origin `manifest.json`'s
// content_scripts matches, alongside github.com).
// .org docs carry their own equivalent marker instead (org-doc-format-design.md's
// '#+STREAMWEAVER_DSL: 1', a real org header keyword, not a StreamWeaver
// invention) -- checked the same content-not-filename way, so a renamed or
// extensionless .org doc still gets recognized.
//
// Gist pages don't embed file content in page JSON the way a repo blob page
// does -- confirmed by inspecting a real gist page's DOM, not assumed: an
// .org file's raw text isn't even in the DOM (GitHub renders it into
// formatted prose, keyword lines and all, dropping the raw source), and a
// gist can hold multiple files, each in its own `.file` block with its own
// Raw link. So every gist file is read the same way regardless of format:
// fetch its Raw link (`gist.github.com/.../raw/<sha>/<name>`, which
// redirects to `gist.githubusercontent.com`) and scan the fetched text.

const STAMP_RE = /^#\s*streamweaver-doc:\s*v(\d+)\s*$/;
const ORG_MARKER_RE = /^#\+STREAMWEAVER_DSL:\s*\d+/;
const STAMP_SCAN_LINES = 10;
const BUTTON_ID = "sw-view-rendered";

function isStreamWeaverDoc(lines) {
  return lines.slice(0, STAMP_SCAN_LINES).some((l) => STAMP_RE.test(l) || ORG_MARKER_RE.test(l));
}

// Pulls the file's lines out of GitHub's embedded payload.
//
// The payload nests most routes but stores this one under a literal dotted
// key ("codeViewBlobLayoutRoute.StyledBlob"), so the lookup checks both
// spellings rather than assuming either survives.
function rawLinesFromPage() {
  const blocks = document.querySelectorAll('script[type="application/json"]');
  for (const block of blocks) {
    let data;
    try {
      data = JSON.parse(block.textContent);
    } catch {
      continue;
    }
    const payload = data && data.payload;
    if (!payload) continue;

    const blob =
      payload["codeViewBlobLayoutRoute.StyledBlob"] ||
      (payload.codeViewBlobLayoutRoute && payload.codeViewBlobLayoutRoute.StyledBlob);

    if (blob && Array.isArray(blob.rawLines)) return blob.rawLines;
  }
  return null;
}

// The Raw link GitHub renders, used when the embedded payload is unreadable.
// Preferred over rebuilding the URL from the path, because "/blob/<ref>/<path>"
// is ambiguous when a branch name contains a slash.
function rawUrlFromPage() {
  const link =
    document.querySelector('a[data-testid="raw-button"]') ||
    document.querySelector('a[href*="raw.githubusercontent.com"]') ||
    document.querySelector('a#raw-url');
  if (!link) return null;
  return new URL(link.getAttribute("href"), location.origin).href;
}

function filePath() {
  const m = location.pathname.match(/^\/[^/]+\/[^/]+\/blob\/[^/]+\/(.+)$/);
  return m ? decodeURIComponent(m[1]) : location.pathname;
}

function isBlobPage() {
  return /^\/[^/]+\/[^/]+\/blob\//.test(location.pathname);
}

// A gist URL is "/<user>/<gist-id>" (or, for an anonymous gist, just
// "/<gist-id>") -- nothing like a repo blob's "/<owner>/<repo>/blob/...".
// The id itself is the reliable anchor: a hex string GitHub assigns, never
// a real username segment.
function isGistPage() {
  return location.hostname === "gist.github.com" && /\/[0-9a-f]{20,}$/i.test(location.pathname);
}

// `id` is omitted for gist buttons -- a gist page can hold several files, so
// several buttons can coexist, and a duplicate DOM id would be invalid HTML.
// Blob pages pass BUTTON_ID, keeping their existing single-button dedup
// (`document.getElementById(BUTTON_ID)` in scan()) unchanged.
function makeButton(onClick, id) {
  const button = document.createElement("button");
  if (id) button.id = id;
  button.type = "button";
  button.className = "sw-view-rendered-btn";
  button.textContent = "View rendered";
  button.title = "Render this StreamWeaver doc";
  button.addEventListener("click", onClick);
  return button;
}

// GitHub rewrites this toolbar often, so several anchors are tried and the
// last resort is a floating button -- a misplaced button beats none.
function mountButton(button) {
  const host =
    document.querySelector('[data-testid="blob-actions-menu"]')?.parentElement ||
    document.querySelector("#repos-sticky-header .react-blob-header-edit-and-raw-actions") ||
    document.querySelector(".react-blob-header-edit-and-raw-actions") ||
    document.querySelector('[data-testid="latest-commit-details"]')?.parentElement;

  if (host) {
    host.prepend(button);
  } else {
    button.classList.add("sw-view-rendered-btn--floating");
    document.body.appendChild(button);
  }
}

// Each file on a gist page lives in its own `.file` block, with its own Raw
// link inside `.file-actions` -- confirmed against a real multi-file gist,
// not assumed: a single-file gist has exactly one `.file` block, so this
// same code path covers both without a separate "only file" case. Filenames
// come from `.file-info a`'s text (falls back to the Raw URL's last segment,
// in case that selector ever changes) since a gist's file-content pages
// don't expose a query-string equivalent of a blob page's `filePath()`.
function gistFileBlocks() {
  return Array.from(document.querySelectorAll(".file"))
    .map((file) => {
      const rawLink = file.querySelector('a[href*="/raw/"]');
      if (!rawLink) return null;
      const rawUrl = new URL(rawLink.getAttribute("href"), location.origin).href;
      const nameEl = file.querySelector(".file-info a");
      const name = nameEl ? nameEl.textContent.trim() : decodeURIComponent(rawUrl.split("/").pop());
      return { file, actions: file.querySelector(".file-actions"), name, rawUrl };
    })
    .filter(Boolean);
}

// Mirrors `mountButton`'s toolbar-anchor-with-floating-fallback shape, but
// scoped per file block rather than once per page, since a gist can carry
// more than one StreamWeaver doc.
function mountFileButton(button, actions) {
  if (actions) {
    actions.prepend(button);
  } else {
    button.classList.add("sw-view-rendered-btn--floating");
    document.body.appendChild(button);
  }
}

async function handleClick(source, name) {
  // Docs run to tens of kilobytes, which is far past what a query string
  // should carry, so the source goes through session storage and only a
  // lookup key travels in the URL.
  const key = `sw-doc-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  await chrome.storage.session.set({ [key]: { source, name, url: location.href } });
  chrome.runtime.sendMessage({ type: "sw:open-viewer", key, name });
}

// Marks a `.file` block once it's been fetched-and-checked, so repeated
// scans (the mutation observer below re-triggers on every DOM change) don't
// re-fetch the same Raw URL -- fetch is async, so without this a burst of
// mutations during the async gap could fire several fetches for one file.
const GIST_SCANNED_ATTR = "data-sw-scanned";

async function scanGistPage() {
  for (const { file, actions, name, rawUrl } of gistFileBlocks()) {
    if (file.hasAttribute(GIST_SCANNED_ATTR)) continue;
    file.setAttribute(GIST_SCANNED_ATTR, "1");

    let lines;
    try {
      const text = await (await fetch(rawUrl)).text();
      lines = text.split("\n");
    } catch {
      continue;
    }

    if (!isStreamWeaverDoc(lines)) continue;

    const source = lines.join("\n");
    mountFileButton(makeButton(() => handleClick(source, name)), actions);
  }
}

async function scanBlobPage() {
  if (document.getElementById(BUTTON_ID)) return;

  let lines = rawLinesFromPage();

  if (!lines) {
    // Embedded payload unreadable -- fall back to the Raw URL.
    const rawUrl = rawUrlFromPage();
    if (!rawUrl) return;
    try {
      const text = await (await fetch(rawUrl)).text();
      lines = text.split("\n");
    } catch {
      return;
    }
  }

  if (!isStreamWeaverDoc(lines)) return;

  const source = lines.join("\n");
  mountButton(makeButton(() => handleClick(source, filePath()), BUTTON_ID));
}

async function scan() {
  if (isGistPage()) {
    await scanGistPage();
  } else if (isBlobPage()) {
    await scanBlobPage();
  }
}

// GitHub navigates without full page loads, so the button has to be re-added
// after soft navigation. Observing the DOM covers every navigation mechanism
// GitHub has used without depending on which one is current; the debounce
// keeps the scan off the critical path during its render churn.
let pending;
function scheduleScan() {
  clearTimeout(pending);
  pending = setTimeout(() => scan().catch(() => {}), 300);
}

scheduleScan();
new MutationObserver(scheduleScan).observe(document.body, { childList: true, subtree: true });
