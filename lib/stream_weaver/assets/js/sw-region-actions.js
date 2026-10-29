// Delegated buttons for bridge-owned regions (data-sw-region). Delegation means
// a region swap never needs rewiring. Posts to this page's own path, so no
// session name is interpolated anywhere.
document.addEventListener('click', function (ev) {
  var el = ev.target.closest && ev.target.closest('[data-sw-region] [data-sw-action]');
  if (!el || el.disabled) return;
  var action = el.getAttribute('data-sw-action');
  var base = location.pathname.replace(/\/$/, '');
  if (action === 'send' || action === 'send-end') {
    fetch(base + '/send', { method: 'POST', headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ end: action === 'send-end' }) });
  } else if (action === 'copy' && navigator.clipboard) {
    navigator.clipboard.writeText(el.textContent.trim());
  }
});
