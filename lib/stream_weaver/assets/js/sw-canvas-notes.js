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
    'aside[data-sw-region=side]{display:none;position:fixed;z-index:40;top:0;right:0;width:320px;height:100vh;box-sizing:border-box;overflow:hidden;padding:0;border-left:1px solid #c9c9c9;background:#fff;color:#1a1a1a;font:14px system-ui,sans-serif}' +
    '@media (prefers-color-scheme:dark){:root:not([data-theme=light]) aside[data-sw-region=side]{background:#1f2227;color:#eee;border-color:#444}}' +
    ':root[data-theme=dark] aside[data-sw-region=side]{background:#1f2227;color:#eee;border-color:#444}' +
    'body.sw-annotate-on aside[data-sw-region=side]{display:block}' +
    'body.sw-annotate-on{padding-right:352px}' +
    '@media (max-width:859px){aside[data-sw-region=side]{top:auto;bottom:0;width:auto;left:0;height:40vh;border-left:0;border-top:1px solid #c9c9c9}body.sw-annotate-on{padding-right:0;padding-bottom:calc(40vh + 32px)}}' +
    '.sw-notes-panel{display:flex;flex-direction:column;height:100%}.sw-notes-head{flex:none;padding:.6rem .75rem;border-bottom:1px solid #c9c9c9}' +
    '.sw-notes-body{flex:1 1 auto;min-height:0;overflow:auto;padding:.5rem .75rem}.sw-notes-body p{margin:.25rem 0}' +
    '.sw-notes-foot{flex:none;padding:.5rem .75rem;border-top:1px solid #c9c9c9}.sw-notes-actions{display:flex;gap:.5rem}.sw-notes-actions button{flex:1;padding:.4rem .5rem;border:1px solid #c9c9c9;border-radius:6px;background:transparent;color:inherit;cursor:pointer}.sw-notes-actions button:disabled{opacity:.5;cursor:default}.sw-notes-hint{margin:.4rem 0 0;font-size:12px;opacity:.7}' +
    '.sw-notes-head{display:flex;justify-content:space-between;align-items:center;gap:.5rem}.sw-notes-title{margin:0;font-size:16px}' +
    '.sw-annotate-toggle{padding:.25rem .6rem;border-radius:999px;border:1px solid #c9c9c9;background:transparent;color:inherit;cursor:pointer}.sw-annotate-toggle[aria-pressed=true]{background:#2563eb;color:#fff;border-color:#2563eb}' +
    '.sw-note-composer{position:fixed;z-index:70;width:min(320px,calc(100vw - 16px));padding:.5rem;border:1px solid var(--n-bd);border-radius:8px;background:var(--n-bg);color:var(--n-fg);box-shadow:0 6px 24px rgba(0,0,0,.25)}' +
    '.sw-note-composer textarea{width:100%;box-sizing:border-box;min-height:4.5em;background:transparent;color:inherit;border:1px solid var(--n-bd);border-radius:4px;font:inherit}' +
    '.sw-hl{outline:2px dashed #2563eb!important;outline-offset:1px}.sw-hl-sel{outline:3px solid #2563eb!important;outline-offset:1px}' +
    '.sw-note-title{font-weight:600;margin-bottom:.25rem}' +
    '.sw-notes-list{list-style:none;margin:.5rem 0;padding:0}.sw-card{margin:.4rem 0;padding:.45rem .6rem;border:1px solid #c9c9c9;border-radius:8px;overflow-wrap:anywhere;word-break:break-word}' +
    '.sw-card:focus-visible{outline:2px solid #2563eb}.sw-card.sw-card-pre{background:rgba(37,99,235,.06)}.sw-card.sw-card-on{border-left:4px solid #2563eb;background:rgba(37,99,235,.12)}' +
    '.sw-hl-comp{outline:3px solid #2563eb!important;outline-offset:1px}.sw-card-top{display:flex;gap:.4rem;align-items:center;font-size:11px;opacity:.75}' +
    '.sw-card-n{min-width:1.3em;height:1.3em;border-radius:999px;background:#2563eb;color:#fff;text-align:center;line-height:1.3em;font-weight:600}' +
    '.sw-notes-text{cursor:pointer;margin:.2rem 0;white-space:pre-wrap}.sw-notes-ctx{font-size:11px;opacity:.65}.sw-notes-gone{font-style:italic}.sw-card.sw-gone{opacity:.65}' +
    '.sw-card-actions{display:flex;gap:.6rem;margin-top:.25rem;white-space:nowrap}' +
    '.sw-edit-row{display:flex;gap:.4rem;margin-top:.25rem}.sw-edit-row button{padding:.2rem .6rem;border:1px solid #c9c9c9;border-radius:6px;background:transparent;color:inherit;cursor:pointer}' +
    '.sw-notes-input{display:block;width:100%;box-sizing:border-box;min-height:3.5em;font:inherit;color:inherit;background:transparent;border:1px solid #c9c9c9;border-radius:4px;resize:vertical}' +
    '.sw-notes-h{margin:.6rem 0 .2rem;font-size:11px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;opacity:.7}.sw-notes-h-n{font-weight:400}' +
    'details.sw-notes-done>summary.sw-notes-h{cursor:pointer;list-style:revert}details.sw-notes-round{margin:.3rem 0 .3rem .5rem}details.sw-notes-round>summary{cursor:pointer;font-size:12px}.sw-round-name{font-weight:600}.sw-round-n{opacity:.7}' +
    '.sw-card.sw-compact{padding:.3rem .5rem;font-size:13px}.sw-card.sw-pulse{animation:sw-pulse 1.2s ease-out 1}@keyframes sw-pulse{0%{background:rgba(37,99,235,.35)}100%{background:transparent}}' +
    '.sw-hl-card{outline:2px dashed #2563eb!important;outline-offset:1px}' +
    '#sw-badges{display:none}body.sw-annotate-on #sw-badges{display:block}#sw-badges .sw-badge{position:fixed;z-index:30;min-width:18px;height:18px;padding:0 4px;box-sizing:border-box;border-radius:999px;background:#2563eb;color:#fff;font:600 11px/18px system-ui,sans-serif;text-align:center;box-shadow:0 1px 4px rgba(0,0,0,.35);cursor:pointer!important}' +
    'aside[data-sw-region] button::after{content:none!important;display:none!important}' +
    'body.sw-annotate-on .sw-save-doc-btn{right:calc(320px + 1.5rem)}' +
    '@media (max-width:859px){body.sw-annotate-on .sw-save-doc-btn{right:1rem;bottom:calc(40vh + 1rem)}}' +
    '.sw-notes-edit,.sw-notes-remove{padding:0;font-size:12px;border:0;background:transparent;color:inherit;text-decoration:underline;cursor:pointer}' +
    '.sw-note-hint{font-size:12px;opacity:.7;margin-top:.25rem}.sw-note-err{color:#dc2626;opacity:1}' +
    '.sw-note-toast{position:fixed;bottom:3.5rem;left:1rem;z-index:80;padding:.4rem .8rem;border-radius:6px;background:var(--n-ac);color:#fff}' +
    // Last, and two classes deep: selected and composer outlines always beat the hover previews.
    '.sw-hl.sw-hl-sel,.sw-hl-card.sw-hl-sel,.sw-hl.sw-hl-comp,.sw-hl-card.sw-hl-comp{outline:3px solid #2563eb!important;outline-offset:1px}';
  document.head.appendChild(css);

  var root = document.createElement('div');
  root.id = 'sw-notes-root';
  var btn = document.createElement('button');
  btn.id = 'sw-notes-btn';
  btn.type = 'button';
  btn.title = 'Comment on an element (or Alt-click, long-press on touch)';
  root.appendChild(btn);
  var layer = document.createElement('div');
  layer.id = 'sw-badges';
  root.appendChild(layer);
  document.body.appendChild(root);

  // Apply the state locally (poll and toggle both land here); no network.
  function setMode(on) {
    mode = !!on;
    document.body.classList.toggle('sw-annotate-on', mode);
    btn.textContent = 'comment';
    if (window.swRefreshBadges) window.swRefreshBadges();
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
  function breadcrumbFor(el) {
    var heads = document.querySelectorAll('#app-container h1,#app-container h2,#app-container h3,#app-container h4,#app-container h5,#app-container h6');
    var stack = [];
    for (var i = 0; i < heads.length; i++) {
      var h = heads[i];
      if (h !== el && !(h.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING) && !h.contains(el)) continue;
      var lvl = +h.tagName[1];
      while (stack.length && stack[stack.length - 1].lvl >= lvl) stack.pop();
      stack.push({ lvl: lvl, text: h.textContent.trim().slice(0, 80) });
    }
    return stack.map(function (s) { return s.text; }).join(' > ');
  }

  function snapshot(el) {
    var kindEl = el.closest('table,button,a,pre,ul,ol,img,h1,h2,h3,h4,h5,h6,p,li,input,select,textarea') || el;
    var rect = el.getBoundingClientRect();
    return {
      selected_text: String(window.getSelection()).slice(0, 500),
      element_text: (el.innerText || el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 120),
      breadcrumb: breadcrumbFor(el),
      kind: kindEl.tagName.toLowerCase(),
      tag: el.tagName.toLowerCase(),
      el: el,
      rect: rect
    };
  }

  // The composer names the element that is actually outlined (a td, not its table).
  function titleFor(el) { return 'Annotate <' + el.tagName.toLowerCase() + '>'; }

  // What a key does in the inline comment editor: 'save', 'cancel' or null.
  function editKeyAction(key, value, shift) {
    if (key === 'Escape') return 'cancel';
    if (key === 'Enter' && !shift) return value.trim() ? 'save' : null;
    return null;
  }

  // Which comment is active (a note id string or null) after an event. ONE at a
  // time; ending an edit leaves it active; only another comment, Esc with no
  // editor open, a click on the empty page, Send or removal clears it.
  function activeAfter(active, ev) {
    switch (ev.type) {
      case 'activate': return ev.id;
      case 'escape': return ev.editing ? active : null;
      case 'pageClick': case 'send': return null;
      case 'remove': return ev.id === active ? null : active;
      case 'present': return ev.ids.indexOf(active) >= 0 ? active : null;
      default: return active;
    }
  }

  // A badge shows only when its anchor sits in the visible document area:
  // inside the viewport and clear of the right panel or the bottom sheet.
  function badgeVisible(x, y, bounds) {
    return x >= 0 && y >= 0 && x + 18 <= bounds.right && y + 18 <= bounds.bottom;
  }

  // The commented element a click landed in: the innermost one when several
  // commented elements contain the click. `contains(a, b)` is true when a's box
  // holds b. Pure, so it is specced without a DOM.
  function innermost(items, contains) {
    for (var i = 0; i < items.length; i++) {
      var inner = true;
      for (var j = 0; j < items.length; j++) {
        if (i !== j && contains(items[i], items[j])) { inner = false; break; }
      }
      if (inner) return items[i];
    }
    return null;
  }

  // The selected element never carries a hover preview class.
  function dropHover(el) {
    el.classList.remove('sw-hl');
    el.classList.remove('sw-hl-card');
  }

  // Badge rule: comments Ready to send or With the agent always show one; a Done
  // comment only while the Done row and its round are open, or when selected.
  function badgeShown(state, doneOpen, roundOpen, selected) {
    return state !== 'done' || selected || (doneOpen && roundOpen);
  }

  // Ids on the page now that were not there before (a new comment).
  function newIds(before, now) {
    return now.filter(function (id) { return before.indexOf(id) < 0; });
  }

  // Remembered open state: saved is {key: true}; anything unsaved is closed.
  function openFor(saved, key) { return !!(saved && saved[key]); }

  function closeComposer() {
    if (composer) { composer.remove(); composer = null; }
    clearMarks('sw-hl-comp');
  }

  function clearMarks(cls) {
    var m = document.querySelectorAll('.' + cls);
    for (var i = 0; i < m.length; i++) m[i].classList.remove(cls);
  }

  function openComposer(el, x, y) {
    closeComposer();
    var ctx = snapshot(el);
    composer = document.createElement('div');
    composer.className = 'sw-note-composer';
    composer.style.left = Math.max(8, Math.min(x, window.innerWidth - 336)) + 'px';
    composer.style.top = Math.max(8, Math.min(ctx.rect.bottom + 6, window.innerHeight - 160)) + 'px';
    el.classList.add('sw-hl-comp');
    var title = document.createElement('div');
    title.className = 'sw-note-title';
    title.textContent = titleFor(el);
    composer.appendChild(title);
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
    var payload = { text: text, selected_text: ctx.selected_text, element_text: ctx.element_text, breadcrumb: ctx.breadcrumb, kind: ctx.kind, tag: ctx.tag };
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

  // Hover highlight while annotate mode is on.
  document.addEventListener('mouseover', function (e) {
    clearMarks('sw-hl');
    if (!mode || inOverlay(e.target) || !e.target.classList) return;
    if (e.target.id !== 'app-container' && e.target !== activeEl) e.target.classList.add('sw-hl');
  });

  // Find the element a comment was left on in the CURRENT doc: the deepest
  // element whose text equals the stored text, preferring the same breadcrumb.
  function locate(li) {
    var text = li.getAttribute('data-sw-element-text');
    if (!text) return null;
    var crumb = li.getAttribute('data-sw-breadcrumb') || '';
    var all = document.querySelectorAll('#app-container *'), hits = [];
    for (var i = 0; i < all.length; i++) {
      var t = (all[i].innerText || all[i].textContent || '').trim().replace(/\s+/g, ' ').slice(0, 120);
      if (t === text) hits.push(all[i]);
    }
    hits = hits.filter(function (h) { return !hits.some(function (o) { return o !== h && h.contains(o); }); });
    return hits.filter(function (h) { return breadcrumbFor(h) === crumb; })[0] || hits[0] || null;
  }

  // Numbered badges at the corner of each commented element, in a fixed layer
  // outside #app-container (no layout effect, never in the doc HTML that
  // canvas-read, export and save-doc use). A comment whose element is gone
  // keeps its card with "(element changed)" and gets no badge. A badge is
  // hidden while its anchor is off-screen or under the panel / bottom sheet.
  var entries = [];
  var activeId = null, activeEl = null;

  function visibleBounds() {
    var b = { right: window.innerWidth, bottom: window.innerHeight };
    var aside = document.querySelector('aside[data-sw-region="side"]');
    if (mode && aside) {
      var r = aside.getBoundingClientRect();
      if (r.width && r.width < window.innerWidth - 40) b.right = r.left;
      else if (r.height) b.bottom = r.top;
    }
    return b;
  }

  function place() {
    var bounds = visibleBounds();
    entries.forEach(function (en) {
      var r = en.el.getBoundingClientRect();
      var x = r.left - 6 + en.n * 20, y = r.top - 9;
      en.b.style.left = x + 'px';
      en.b.style.top = y + 'px';
      en.b.style.display = badgeVisible(x, y, bounds) ? '' : 'none';
    });
  }

  function setActive(ev) {
    activeId = activeAfter(activeId, ev);
    applyActive();
  }

  // Re-draw the one active comment: solid outline on its element, emphasis on
  // its card. Runs after every region swap and doc push, which replace both.
  function closedAncestor(node) {
    for (var d = node.closest('details'); d; d = d.parentNode && d.parentNode.closest ? d.parentNode.closest('details') : null) {
      if (!d.open) return true;
    }
    return false;
  }

  function applyActive() {
    clearMarks('sw-hl-sel');
    clearMarks('sw-card-on');
    activeEl = null;
    if (activeId === null) return;
    var li = document.querySelector('[data-sw-region] li[data-sw-note="' + activeId + '"]');
    if (!li) { activeId = null; return; }
    // The card is hidden inside a closed Done row or round: nothing to select.
    if (closedAncestor(li)) { activeId = null; return; }
    li.classList.add('sw-card-on');
    var el = locate(li);
    if (el) { dropHover(el); el.classList.add('sw-hl-sel'); activeEl = el; }
  }

  function refresh() {
    var lis = document.querySelectorAll('[data-sw-region] li[data-sw-note]');
    layer.textContent = '';
    entries = [];
    var stacked = [];
    for (var i = 0; i < lis.length; i++) {
      var el = locate(lis[i]);
      var gone = !!lis[i].getAttribute('data-sw-element-text') && !el;
      lis[i].classList.toggle('sw-gone', gone);
      var tag = lis[i].querySelector('.sw-notes-gone');
      if (tag) tag.hidden = !gone;
      if (!el || !mode) continue;
      var det = lis[i].closest('details[data-sw-round]'), grp = lis[i].closest('details[data-sw-group="done"]');
      if (!badgeShown(lis[i].getAttribute('data-sw-state'), !grp || grp.open, !det || det.open, lis[i].getAttribute('data-sw-note') === activeId)) continue;
      var n = stacked.filter(function (x) { return x === el; }).length;
      stacked.push(el);
      var b = document.createElement('div');
      b.className = 'sw-badge';
      b.textContent = lis[i].querySelector('.sw-card-n').textContent;
      b.setAttribute('data-sw-for', lis[i].getAttribute('data-sw-note'));
      layer.appendChild(b);
      entries.push({ b: b, el: el, n: n });
    }
    var ids = [].map.call(lis, function (l) { return l.getAttribute('data-sw-note'); });
    activeId = activeAfter(activeId, { type: 'present', ids: ids });
    applyActive();
    place();
  }
  var markTimer = null, placeFrame = null;
  function scheduleMark() { clearTimeout(markTimer); markTimer = setTimeout(refresh, 150); }
  function schedulePlace() {
    if (placeFrame) return;
    placeFrame = requestAnimationFrame(function () { placeFrame = null; place(); });
  }
  window.swRefreshBadges = scheduleMark;
  var app = document.getElementById('app-container'), side = document.querySelector('[data-sw-region="side"]');
  if (window.MutationObserver) {
    var mo = new MutationObserver(scheduleMark);
    if (app) mo.observe(app, { childList: true, subtree: true });
    if (side) mo.observe(side, { childList: true, subtree: true });
  }
  window.addEventListener('resize', scheduleMark);
  window.addEventListener('load', scheduleMark);
  window.addEventListener('scroll', schedulePlace, { passive: true, capture: true });
  scheduleMark();

  // The entry whose element contains node t (its badge counts), innermost first.
  function entryAt(t) {
    var hit = entries.filter(function (en) { return en.el === t || en.el.contains(t); });
    return innermost(hit, function (a, b) { return a.el !== b.el && a.el.contains(b.el); });
  }

  function cardFor(en) {
    return en && document.querySelector('[data-sw-region] li[data-sw-note="' + en.b.getAttribute('data-sw-for') + '"]');
  }

  // Done row and round open/closed state, kept per canvas in the browser.
  var OPEN_KEY = 'sw-notes-open:' + BASE;
  function savedOpen() {
    try { return JSON.parse(localStorage.getItem(OPEN_KEY) || '{}') || {}; } catch (e) { return {}; }
  }
  function detailsKey(d) {
    return d.getAttribute('data-sw-group') === 'done' ? 'done' : 'r' + d.getAttribute('data-sw-round');
  }
  function restoreOpen() {
    var saved = savedOpen();
    [].forEach.call(document.querySelectorAll('[data-sw-region] details[data-sw-group], [data-sw-region] details[data-sw-round]'), function (d) {
      d.open = openFor(saved, detailsKey(d));
    });
  }
  function cardIds() {
    return [].map.call(document.querySelectorAll('[data-sw-region] li[data-sw-note]'), function (l) { return l.getAttribute('data-sw-note'); });
  }
  var knownIds = null;
  // The poll script calls these around a region swap, in the same task.
  window.swRegionBefore = function (name) {
    var body = document.querySelector('[data-sw-region="' + name + '"] .sw-notes-body');
    return { top: body ? body.scrollTop : 0, ids: cardIds() };
  };
  window.swRegionSwapped = function (name, kept) {
    restoreOpen();
    var body = document.querySelector('[data-sw-region="' + name + '"] .sw-notes-body');
    if (body && kept) body.scrollTop = kept.top;
    var fresh = kept ? newIds(kept.ids, cardIds()) : [];
    if (fresh.length && body) {
      var card = document.querySelector('[data-sw-region] li[data-sw-note="' + fresh[fresh.length - 1] + '"]');
      if (card && !closedAncestor(card)) { card.scrollIntoView({ block: 'nearest' }); card.classList.add('sw-pulse'); }
    }
    applyActive();
    scheduleMark();
  };
  restoreOpen();
  // toggle does not bubble: listen in the capture phase.
  document.addEventListener('toggle', function (e) {
    var d = e.target;
    if (!d.matches || !d.matches('[data-sw-region] details[data-sw-group], [data-sw-region] details[data-sw-round]')) return;
    var saved = savedOpen();
    saved[detailsKey(d)] = d.open;
    try { localStorage.setItem(OPEN_KEY, JSON.stringify(saved)); } catch (err) { /* private mode */ }
    scheduleMark();
  }, true);

  // Make a comment the one active comment (solid outline, emphasized card).
  function activate(li, scroll) {
    setActive({ type: 'activate', id: li.getAttribute('data-sw-note') });
    var el = locate(li);
    if (el && scroll) el.scrollIntoView({ block: 'center', behavior: 'smooth' });
  }

  function cardOf(t) { return t.closest && t.closest('[data-sw-region] li[data-sw-note]'); }

  // Hover is only a dashed preview, and never on the active card's element.
  document.addEventListener('mouseover', function (e) {
    clearMarks('sw-hl-card');
    clearMarks('sw-card-pre');
    if (mode && !inOverlay(e.target)) {
      var pre = cardFor(entryAt(e.target));
      if (pre) pre.classList.add('sw-card-pre');
    }
    var li = cardOf(e.target), el = li && locate(li);
    if (el && el !== activeEl && li.getAttribute('data-sw-note') !== activeId) el.classList.add('sw-hl-card');
  });
  document.addEventListener('focusin', function (e) {
    var li = cardOf(e.target);
    if (li && e.target === li) activate(li, true);
  });

  // Card actions (delegated, so a region swap never needs rewiring).
  document.addEventListener('click', function (e) {
    var send = e.target.closest && e.target.closest('[data-sw-region] [data-sw-action="send"], [data-sw-region] [data-sw-action="send-end"]');
    if (send) { setActive({ type: 'send' }); return; }
    var badge = e.target.closest && e.target.closest('#sw-badges .sw-badge');
    if (badge) {
      var target = document.querySelector('[data-sw-region] li[data-sw-note="' + badge.getAttribute('data-sw-for') + '"]');
      if (target) { target.scrollIntoView({ block: 'nearest', behavior: 'smooth' }); activate(target, false); }
      return;
    }
    var li = cardOf(e.target);
    if (!li) return;
    var a = e.target.closest('[data-sw-action]'), id = li.getAttribute('data-sw-note');
    var act = a && a.getAttribute('data-sw-action');
    if (e.target.closest('.sw-edit-row') || e.target.closest('.sw-notes-input')) return;
    if (act === 'remove') {
      setActive({ type: 'remove', id: id });
      fetch(BASE + '/note/' + encodeURIComponent(id), { method: 'DELETE' });
    } else if (act === 'edit') {
      startEdit(li, id);
    } else {
      activate(li, true);
    }
  });

  // Inline editor: textarea with the text selected, Save and Cancel buttons;
  // Enter saves, Esc cancels. Keys never reach the page's Esc handler.
  function startEdit(li, id) {
    var span = li.querySelector('.sw-notes-text');
    if (!span || li.querySelector('.sw-notes-input')) return;
    activate(li, true);
    var cur = span.textContent;
    var input = document.createElement('textarea');
    input.className = 'sw-notes-input';
    input.value = cur;
    input.setAttribute('aria-label', 'Edit comment');
    var row = document.createElement('div');
    row.className = 'sw-edit-row';
    var save = document.createElement('button'), cancel = document.createElement('button');
    save.type = cancel.type = 'button';
    save.textContent = 'Save';
    cancel.textContent = 'Cancel';
    row.appendChild(save);
    row.appendChild(cancel);
    span.hidden = true;
    span.parentNode.insertBefore(input, span.nextSibling);
    input.parentNode.insertBefore(row, input.nextSibling);
    input.focus();
    input.select();
    function close() { input.remove(); row.remove(); span.hidden = false; }
    function commit() {
      var text = input.value.trim();
      if (!text) return;
      close();
      if (text !== cur) {
        fetch(BASE + '/note/' + encodeURIComponent(id), { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text: text }) });
      }
    }
    save.addEventListener('click', commit);
    cancel.addEventListener('click', close);
    input.addEventListener('keydown', function (ev) {
      ev.stopPropagation();
      var what = editKeyAction(ev.key, input.value, ev.shiftKey);
      if (what === 'cancel') close();
      else if (what === 'save') { ev.preventDefault(); commit(); }
    });
  }

  // Capture phase: runs before Alpine's @click handlers on the controls.
  document.addEventListener('click', function (e) {
    if (inOverlay(e.target)) return;
    setActive({ type: 'pageClick' });
    if (swallowClick || e.altKey || mode) {
      var fromPress = swallowClick;
      swallowClick = false;
      e.stopPropagation();
      e.preventDefault();
      if (!fromPress) {
        // Select the commented element the click landed in (after the clear
        // above), then still open the composer so another comment can be added.
        var sel = cardFor(entryAt(e.target));
        if (sel) { setActive({ type: 'activate', id: sel.getAttribute('data-sw-note') }); sel.scrollIntoView({ block: 'nearest' }); }
        openComposer(e.target, e.clientX, e.clientY);
      }
    }
  }, true);

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape' || composer) return;
    if (activeId !== null) setActive({ type: 'escape', editing: false });
    else if (mode) setAnnotate(false);
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
