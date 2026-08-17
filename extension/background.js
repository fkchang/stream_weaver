// Opens the viewer tab.
//
// A content script cannot navigate to a chrome-extension:// page directly
// without exposing that page as a web-accessible resource, which would let any
// site open it. Routing through the service worker keeps the viewer private to
// the extension.

// chrome.storage.session defaults to TRUSTED_CONTEXTS only (extension pages,
// the service worker) -- a content script injected into a web page is an
// untrusted context and gets "Access to storage is not allowed from this
// context" on every read/write until this runs. Only the service worker can
// call setAccessLevel; content.js can't opt itself in. Set once at worker
// startup -- content.js's chrome.storage.session.set() in handleClick is
// what actually needs this.
chrome.storage.session.setAccessLevel({ accessLevel: "TRUSTED_AND_UNTRUSTED_CONTEXTS" });

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type !== "sw:open-viewer") return;

  const url = chrome.runtime.getURL(
    `viewer.html?key=${encodeURIComponent(message.key)}&name=${encodeURIComponent(message.name || "")}`
  );
  chrome.tabs.create({ url });
});
