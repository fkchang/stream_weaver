// Opens the viewer tab.
//
// A content script cannot navigate to a chrome-extension:// page directly
// without exposing that page as a web-accessible resource, which would let any
// site open it. Routing through the service worker keeps the viewer private to
// the extension.

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type !== "sw:open-viewer") return;

  const url = chrome.runtime.getURL(
    `viewer.html?key=${encodeURIComponent(message.key)}&name=${encodeURIComponent(message.name || "")}`
  );
  chrome.tabs.create({ url });
});
