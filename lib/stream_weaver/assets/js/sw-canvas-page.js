// Wears a pushed canvas page without a reload (disc-127). `page` is the
// poll's page payload (Canvas::BridgeServer#live_page): the body class,
// the head tags keyed by a digest of the tag, and the push CSS. `seen` is
// the Set of keys this page's head already has.
//
// Order is the same as a fresh render of the page (render_canvas_page):
// the page's tags, then the push CSS, last in <head>, after every fixed
// tag (highlight.js, chart CSS), so an unlayered use_stylesheet rule wins
// or loses the same way live and after a reload. Tags are append-only and
// never re-appended; the push CSS is replaced as a group, so a token edit
// never stacks or reorders.
window.swApplyPage = function (page, seen) {
  if (!page) return;
  var body = document.body, head = document.head;
  var annotating = body.classList.contains('sw-annotate-on');
  body.className = page.body_class;
  body.classList.toggle('sw-annotate-on', annotating);
  page.assets.forEach(function (asset) {
    if (seen.has(asset.key)) return;
    seen.add(asset.key);
    head.insertAdjacentHTML('beforeend', asset.html);
  });
  head.querySelectorAll('style[data-sw-push-css]').forEach(function (el) { el.remove(); });
  page.push_css.forEach(function (css) {
    var el = document.createElement('style');
    el.setAttribute('data-sw-push-css', '');
    el.textContent = css;
    head.appendChild(el);
  });
};
