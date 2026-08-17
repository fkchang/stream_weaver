// Adds a "View rendered" button to StreamWeaver docs on GitHub.
//
// The whole file is already in the page: GitHub's blob view embeds it as a
// rawLines array in a JSON <script> block, so recognizing a doc costs no
// network request. That JSON is GitHub's internal shape and will change
// eventually, so a Raw-link fetch stands behind it.
//
// Detection is by content, not filename. `DocStore` stamps every saved .rb
// doc with a marker comment, which travels with the file regardless of path
// or extension -- so this works on forks and files someone moved (NOT
// gists: those live on gist.github.com, a different origin manifest.json's
// content_scripts doesn't match -- the marker itself would travel there
// fine, the extension just never runs on that page today).
// .org docs carry their own equivalent marker instead (org-doc-format-design.md's
// '#+STREAMWEAVER_DSL: 1', a real org header keyword, not a StreamWeaver
// invention) -- checked the same content-not-filename way, so a renamed or
// extensionless .org doc still gets recognized.

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

function makeButton(onClick) {
  const button = document.createElement("button");
  button.id = BUTTON_ID;
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

async function handleClick(source, name) {
  // Docs run to tens of kilobytes, which is far past what a query string
  // should carry, so the source goes through session storage and only a
  // lookup key travels in the URL.
  const key = `sw-doc-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  await chrome.storage.session.set({ [key]: { source, name, url: location.href } });
  chrome.runtime.sendMessage({ type: "sw:open-viewer", key, name });
}

async function scan() {
  if (!isBlobPage()) return;
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
  mountButton(makeButton(() => handleClick(source, filePath())));
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
