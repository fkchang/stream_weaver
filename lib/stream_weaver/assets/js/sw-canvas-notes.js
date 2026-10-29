// Canvas comment overlay: leave a note on any element of a live canvas page.
// Alt-click (long-press on touch) or the floating "comment" button turns on
// annotate mode (held on the session, so a reload or second tab agrees); while it is
// on, a click opens a composer instead of pressing the control. Alt-click opens one.
// While off, the only thing added to the page is the small "comment" pill.
// Mounted outside #app-container so the 500 ms poll swap cannot destroy it.
(function () {
  if (window.__swCanvasNotes) return;
  window.__swCanvasNotes = true;

  var URL_ = location.pathname.replace(/\/$/, '') + '/note';
  var BASE = location.pathname.replace(/\/$/, '');
  var mode = document.body.classList.contains('sw-annotate-on'), composer = null, pressTimer = null, swallowClick = false;

  var css = document.createElement('style');
  css.textContent =
    '#sw-notes-root{--n-bg:#fff;--n-fg:#1a1a1a;--n-bd:#c9c9c9;--n-ac:#2563eb;font:14px system-ui,sans-serif}' +
    '@media (prefers-color-scheme:dark){:root:not([data-theme=light]) #sw-notes-root{--n-bg:#1f2227;--n-fg:#eee;--n-bd:#444}}' +
    ':root[data-theme=dark] #sw-notes-root{--n-bg:#1f2227;--n-fg:#eee;--n-bd:#444}' +
    '#sw-notes-btn{position:fixed;bottom:1rem;left:1rem;z-index:50;padding:.4rem .8rem;border-radius:999px;border:1px solid var(--n-bd);background:var(--n-bg);color:var(--n-fg);cursor:pointer}' +
    'body.sw-annotate-on #sw-notes-btn{display:none}' +
    'body.sw-annotate-on,body.sw-annotate-on *{cursor:crosshair!important}' +
    'body.sw-annotate-on aside[data-sw-region],body.sw-annotate-on aside[data-sw-region] *{cursor:auto!important}' +
    'aside[data-sw-region=side]{display:none;position:fixed;z-index:40;top:0;right:0;width:320px;height:100vh;box-sizing:border-box;overflow:auto;padding:.75rem;border-left:1px solid #c9c9c9;background:#fff;color:#1a1a1a;font:14px system-ui,sans-serif}' +
    '@media (prefers-color-scheme:dark){:root:not([data-theme=light]) aside[data-sw-region=side]{background:#1f2227;color:#eee;border-color:#444}}' +
    ':root[data-theme=dark] aside[data-sw-region=side]{background:#1f2227;color:#eee;border-color:#444}' +
    'body.sw-annotate-on aside[data-sw-region=side]{display:block}' +
    'body.sw-annotate-on{padding-right:352px}' +
    '@media (max-width:859px){aside[data-sw-region=side]{top:auto;bottom:0;width:auto;left:0;height:40vh;border-left:0;border-top:1px solid #c9c9c9}body.sw-annotate-on{padding-right:0;padding-bottom:calc(40vh + 32px)}}' +
    '.sw-notes-head{display:flex;justify-content:space-between;align-items:center;gap:.5rem}.sw-notes-title{margin:0;font-size:16px}' +
    '.sw-annotate-toggle{padding:.25rem .6rem;border-radius:999px;border:1px solid #c9c9c9;background:transparent;color:inherit;cursor:pointer}.sw-annotate-toggle[aria-pressed=true]{background:#2563eb;color:#fff;border-color:#2563eb}' +
    '.sw-note-composer{position:fixed;z-index:70;width:min(320px,calc(100vw - 16px));padding:.5rem;border:1px solid var(--n-bd);border-radius:8px;background:var(--n-bg);color:var(--n-fg);box-shadow:0 6px 24px rgba(0,0,0,.25)}' +
    '.sw-note-composer textarea{width:100%;box-sizing:border-box;min-height:4.5em;background:transparent;color:inherit;border:1px solid var(--n-bd);border-radius:4px;font:inherit}' +
    '.sw-note-hint{font-size:12px;opacity:.7;margin-top:.25rem}.sw-note-err{color:#dc2626;opacity:1}' +
    '.sw-note-toast{position:fixed;bottom:3.5rem;left:1rem;z-index:80;padding:.4rem .8rem;border-radius:6px;background:var(--n-ac);color:#fff}';
  document.head.appendChild(css);

  var root = document.createElement('div');
  root.id = 'sw-notes-root';
  var btn = document.createElement('button');
  btn.id = 'sw-notes-btn';
  btn.type = 'button';
  btn.title = 'Comment on an element (or Alt-click, long-press on touch)';
  root.appendChild(btn);
  document.body.appendChild(root);

  // Apply the state locally (poll and toggle both land here); no network.
  function setMode(on) {
    mode = !!on;
    document.body.classList.toggle('sw-annotate-on', mode);
    btn.textContent = 'comment';
  }
  window.swSetAnnotate = function (on) { if (!!on !== mode) { if (!on) closeComposer(); setMode(on); } };
  // Set it and tell the session, so a reload or a second tab agrees.
  function setAnnotate(on) {
    if (!on) closeComposer();
    setMode(on);
    fetch(BASE + '/annotate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ on: !!on }) });
  }
  setMode(mode);
  btn.addEventListener('click', function () { setAnnotate(true); });
  document.addEventListener('click', function (e) {
    var t = e.target.closest && e.target.closest('[data-sw-action="annotate-toggle"]');
    if (t) setAnnotate(!mode);
  });

  function toast(msg) {
    var t = document.createElement('div');
    t.className = 'sw-note-toast';
    t.textContent = msg;
    root.appendChild(t);
    setTimeout(function () { t.remove(); }, 1500);
  }

  // Snapshot everything at click time; the DOM node may be swapped by the next poll.
  function snapshot(el) {
    var heads = document.querySelectorAll('#app-container h1,#app-container h2,#app-container h3,#app-container h4,#app-container h5,#app-container h6');
    var stack = [];
    for (var i = 0; i < heads.length; i++) {
      var h = heads[i];
      if (h !== el && !(h.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING) && !h.contains(el)) continue;
      var lvl = +h.tagName[1];
      while (stack.length && stack[stack.length - 1].lvl >= lvl) stack.pop();
      stack.push({ lvl: lvl, text: h.textContent.trim().slice(0, 80) });
    }
    var kindEl = el.closest('table,button,a,pre,ul,ol,img,h1,h2,h3,h4,h5,h6,p,li,input,select,textarea') || el;
    var rect = el.getBoundingClientRect();
    return {
      selected_text: String(window.getSelection()).slice(0, 500),
      element_text: (el.innerText || el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 120),
      breadcrumb: stack.map(function (s) { return s.text; }).join(' > '),
      kind: kindEl.tagName.toLowerCase(),
      rect: rect
    };
  }

  function closeComposer() { if (composer) { composer.remove(); composer = null; } }

  function openComposer(el, x, y) {
    closeComposer();
    var ctx = snapshot(el);
    composer = document.createElement('div');
    composer.className = 'sw-note-composer';
    composer.style.left = Math.max(8, Math.min(x, window.innerWidth - 336)) + 'px';
    composer.style.top = Math.max(8, Math.min(ctx.rect.bottom + 6, window.innerHeight - 160)) + 'px';
    var ta = document.createElement('textarea');
    ta.placeholder = 'Comment on this...';
    var hint = document.createElement('div');
    hint.className = 'sw-note-hint';
    hint.textContent = 'Enter to post, Shift-Enter newline, Esc to cancel';
    composer.appendChild(ta);
    composer.appendChild(hint);
    root.appendChild(composer);
    ta.focus();
    ta.addEventListener('keydown', function (e) {
      e.stopPropagation();
      if (e.key === 'Escape') { closeComposer(); }
      else if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); post(ta, hint, ctx); }
    });
  }

  function post(ta, hint, ctx) {
    var text = ta.value.trim();
    if (!text) return;
    var payload = { text: text, selected_text: ctx.selected_text, element_text: ctx.element_text, breadcrumb: ctx.breadcrumb, kind: ctx.kind };
    fetch(URL_, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        closeComposer();
        toast('noted');
      })
      .catch(function (err) {
        hint.textContent = 'Not saved (' + err.message + '). Your draft is kept; Enter to retry.';
        hint.className = 'sw-note-hint sw-note-err';
      });
  }

  function inOverlay(t) { return root.contains(t) || !!(t.closest && t.closest('[data-sw-region]')); }

  // Capture phase: runs before Alpine's @click handlers on the controls.
  document.addEventListener('click', function (e) {
    if (inOverlay(e.target)) return;
    if (swallowClick || e.altKey || mode) {
      var fromPress = swallowClick;
      swallowClick = false;
      e.stopPropagation();
      e.preventDefault();
      if (!fromPress) openComposer(e.target, e.clientX, e.clientY);
    }
  }, true);

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && mode && !composer) setAnnotate(false);
  });

  // Long-press (~500 ms, little movement) opens the composer on touch screens.
  document.addEventListener('touchstart', function (e) {
    if (inOverlay(e.target) || e.touches.length !== 1) return;
    var t = e.target, p = e.touches[0];
    clearTimeout(pressTimer);
    pressTimer = setTimeout(function () {
      swallowClick = true;
      openComposer(t, p.clientX, p.clientY);
      setTimeout(function () { swallowClick = false; }, 800);
    }, 500);
  }, { passive: true, capture: true });
  ['touchend', 'touchmove', 'touchcancel'].forEach(function (n) {
    document.addEventListener(n, function () { clearTimeout(pressTimer); }, { passive: true, capture: true });
  });
})();
