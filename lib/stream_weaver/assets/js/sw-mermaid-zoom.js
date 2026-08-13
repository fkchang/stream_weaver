/**
 * StreamWeaver Mermaid Zoom/Pan Engine
 *
 * Provides zoom (Ctrl+scroll, button controls) and pan (click-drag)
 * for Mermaid diagram containers marked with sw-mermaid--zoom.
 *
 * Theme-aware: reads data-sw-theme from <html> to set Mermaid
 * themeVariables dynamically. Listens for theme changes via
 * MutationObserver on data-sw-theme.
 *
 * Usage: loaded lazily by the AlpineJS adapter only when a mermaid
 * component is rendered. Initializes via swMermaidInit().
 */
(function () {
  'use strict';

  // =========================================================
  // Constants
  // =========================================================
  var ZOOM_MIN = 0.25;
  var ZOOM_MAX = 4.0;
  var ZOOM_STEP = 0.15;
  var CDN_BASE = 'https://cdn.jsdelivr.net/npm';
  var MERMAID_VERSION = '11';
  var ELK_VERSION = '0.1';

  // =========================================================
  // Theme mapping: reads data-sw-theme to pick Mermaid theme
  // =========================================================
  function getMermaidTheme() {
    var attr = document.documentElement.getAttribute('data-sw-theme');
    return attr === 'dark' ? 'dark' : 'default';
  }

  // Mermaid's color parser only understands hex/rgb/hsl/named colors, but StreamWeaver's
  // theme tokens use modern CSS color functions (oklch(), color-mix()) that it chokes on
  // (throws synchronously in mermaid.initialize(), aborting the render). Resolve any CSS
  // color value through the browser's own computed style so Mermaid always receives rgb().
  // getComputedStyle no longer downgrades modern color syntax to rgb() in current
  // browsers (it echoes oklch()/lab() back as-is), so resolving through a probe element's
  // computed style doesn't help. Rasterizing to a 1x1 canvas and reading the pixel back
  // always yields true 8-bit sRGB values regardless of the input color space.
  function toRgbColor(value) {
    if (!value) return null;
    if (!toRgbColor._ctx) {
      var canvas = document.createElement('canvas');
      canvas.width = 1;
      canvas.height = 1;
      toRgbColor._ctx = canvas.getContext('2d', { willReadFrequently: true });
    }
    var ctx = toRgbColor._ctx;
    // Canvas2D silently ignores an unparseable fillStyle assignment rather than throwing
    // (per spec) -- detect rejection by checking whether the sentinel value survived.
    var sentinel = '#010203';
    ctx.fillStyle = sentinel;
    ctx.fillStyle = value;
    if (ctx.fillStyle === sentinel) return null;
    ctx.clearRect(0, 0, 1, 1);
    ctx.fillRect(0, 0, 1, 1);
    var data = ctx.getImageData(0, 0, 1, 1).data;
    var alpha = data[3] / 255;
    return alpha < 1
      ? 'rgba(' + data[0] + ',' + data[1] + ',' + data[2] + ',' + alpha.toFixed(3) + ')'
      : 'rgb(' + data[0] + ',' + data[1] + ',' + data[2] + ')';
  }

  function getThemeVariables() {
    var style = getComputedStyle(document.documentElement);
    var isDark = document.documentElement.getAttribute('data-sw-theme') === 'dark';

    return {
      primaryColor: toRgbColor(style.getPropertyValue('--sw-node-a').trim()) || (isDark ? '#f97316' : '#c2410c'),
      secondaryColor: toRgbColor(style.getPropertyValue('--sw-node-b').trim()) || (isDark ? '#2dd4bf' : '#0d9488'),
      tertiaryColor: toRgbColor(style.getPropertyValue('--sw-node-c').trim()) || (isDark ? '#a78bfa' : '#7c3aed'),
      primaryTextColor: toRgbColor(style.getPropertyValue('--sw-text').trim()) || (isDark ? '#f5f5f5' : '#111111'),
      // --sw-border is tuned for subtle card hairlines, not diagram connectors -- at
      // that contrast, arrows/edges are nearly invisible against --sw-surface. Use the
      // muted-text token instead: dark enough to read as a line, still lighter than
      // primary text so it doesn't compete with node labels.
      lineColor: toRgbColor(style.getPropertyValue('--sw-text-dim').trim()) || (isDark ? 'rgba(255,255,255,0.4)' : '#6b6860'),
      background: toRgbColor(style.getPropertyValue('--sw-surface').trim()) || (isDark ? '#333' : '#ffffff'),
      mainBkg: toRgbColor(style.getPropertyValue('--sw-surface').trim()) || (isDark ? '#333' : '#ffffff'),
      fontFamily: style.getPropertyValue('--sw-font-body').trim() || 'system-ui, sans-serif'
    };
  }

  // =========================================================
  // Mermaid CDN Loader (lazy, ESM)
  // =========================================================
  var mermaidLoaded = false;
  var mermaidLoadPromise = null;

  function loadMermaid(needsElk) {
    if (mermaidLoadPromise) return mermaidLoadPromise;

    // An offline export (stream_weaver-dnq) inlines mermaid's classic
    // build as a plain <script>, which sets this global directly -- no
    // CDN request needed (or, on the CSP that flag exists for, possible
    // at all). ELK still isn't covered by that inline (see the exporter's
    // comment on mermaid_offline_script_tag), so an ELK diagram still
    // falls through to the CDN import below either way.
    if (globalThis.mermaid && !needsElk) {
      // Assign synchronously, not inside a .then(): the value is already
      // available, and deferring mermaidLoaded=true to a microtask leaves
      // a window where reRenderAll() (an early theme-change mutation, say)
      // would see mermaidLoaded still false and silently no-op.
      window.__swMermaid = globalThis.mermaid;
      mermaidLoaded = true;
      mermaidLoadPromise = Promise.resolve(globalThis.mermaid);
      return mermaidLoadPromise;
    }

    mermaidLoadPromise = new Promise(function (resolve, reject) {
      // Dynamic ESM import for Mermaid 11
      var mermaidUrl = CDN_BASE + '/mermaid@' + MERMAID_VERSION + '/dist/mermaid.esm.min.mjs';
      var elkUrl = needsElk
        ? CDN_BASE + '/@mermaid-js/layout-elk@' + ELK_VERSION + '/dist/mermaid-layout-elk.esm.min.mjs'
        : null;

      var imports = [import(mermaidUrl)];
      if (elkUrl) imports.push(import(elkUrl));

      Promise.all(imports)
        .then(function (modules) {
          var mermaid = modules[0].default || modules[0];
          if (modules[1]) {
            // Register ELK layout
            var elk = modules[1].default || modules[1];
            if (mermaid.registerLayoutLoaders) {
              mermaid.registerLayoutLoaders(elk);
            }
          }
          window.__swMermaid = mermaid;
          mermaidLoaded = true;
          resolve(mermaid);
        })
        .catch(function (err) {
          // Don't cache a rejected promise forever -- a transient CDN
          // failure (a flaky connection, not the CSP case this file's
          // offline path exists for) would otherwise be unrecoverable for
          // the rest of the page's life, since every future call just
          // returns this same settled promise back at line 94.
          mermaidLoadPromise = null;
          reject(err);
        });
    });

    return mermaidLoadPromise;
  }

  // =========================================================
  // Render a single diagram
  // =========================================================
  function renderDiagram(container, mermaid, customVars) {
    // Guard: skip if already rendered or a render is in progress.
    // swMermaidInit() can be called concurrently (self-init on
    // DOMContentLoaded, htmx:afterSwap, the canvas's live-update poll
    // handler), and mermaid.render() is async — without this guard, two
    // renders race on the same container ID, which corrupts mermaid's
    // internal state.
    if (container.hasAttribute('data-sw-mermaid-done')) return;
    if (container.hasAttribute('data-sw-mermaid-rendering')) return;
    container.setAttribute('data-sw-mermaid-rendering', 'true');

    var diagramEl = container.querySelector('.sw-mermaid__diagram');
    if (!diagramEl) { container.removeAttribute('data-sw-mermaid-rendering'); return; }

    var code = diagramEl.getAttribute('data-sw-mermaid-code');
    if (!code) { container.removeAttribute('data-sw-mermaid-rendering'); return; }

    var id = container.id || ('sw-mermaid-' + Math.random().toString(36).slice(2, 9));

    var themeVars = getThemeVariables();

    // When custom per-block vars are provided, use Mermaid's %%{init}%% directive
    // so each diagram gets its own theme independently of the global initialize() config.
    // theme: 'base' lets themeVariables fully control node colors.
    // Auto-derive mainBkg from primaryColor: in Mermaid's base theme, flowchart node fills
    // use mainBkg, not primaryColor. Users shouldn't need to know this distinction.
    if (customVars) {
      var vars = Object.assign({}, customVars);
      if (vars.primaryColor && !vars.mainBkg) {
        vars.mainBkg = vars.primaryColor;
      }
      var initDirective = '%%{init: ' + JSON.stringify({ theme: 'base', themeVariables: vars }) + '}%%\n';
      code = initDirective + code;
    }

    mermaid.initialize({
      startOnLoad: false,
      theme: getMermaidTheme(),
      themeVariables: themeVars,
      securityLevel: 'loose',
      fontFamily: themeVars.fontFamily
    });

    mermaid.render(id + '-svg', code).then(function (result) {
      diagramEl.innerHTML = result.svg;
      container.removeAttribute('data-sw-mermaid-rendering');
      container.setAttribute('data-sw-mermaid-done', 'true');
      // Apply zoom if enabled
      if (container.classList.contains('sw-mermaid--zoom')) {
        initZoomPan(container, diagramEl);
      }
      // Expand is always wired, regardless of zoom: true (stream_weaver-yjv).
      initExpand(container, diagramEl);
    }).catch(function (err) {
      container.removeAttribute('data-sw-mermaid-rendering');
      diagramEl.innerHTML = '<pre class="sw-mermaid__error" style="color:var(--sw-error,#dc2626);padding:1rem;">'
        + escapeHtml(err.message || String(err)) + '</pre>';
    });
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  // =========================================================
  // Zoom/Pan Engine
  //
  // Shared by the in-place zoom: true container and the fullscreen
  // overlay below -- createZoomPan(hitArea, target) does the actual work;
  // initZoomPan wraps it with the +/-/reset button wiring the in-place
  // container has and the overlay doesn't. `signal`, when passed, ties
  // every listener registered here to one AbortController so a single
  // `.abort()` tears all of them down -- needed by the overlay, which is
  // created and destroyed repeatedly over a page's lifetime; not needed
  // by the in-place container, which lives as long as the diagram does.
  // =========================================================
  function createZoomPan(hitArea, target, signal) {
    var state = { scale: 1, panX: 0, panY: 0, dragging: false, startX: 0, startY: 0 };
    var opts = signal ? { signal: signal } : undefined;

    function applyTransform() {
      target.style.transformOrigin = '0 0';
      target.style.transform =
        'translate(' + state.panX + 'px, ' + state.panY + 'px) scale(' + state.scale + ')';
    }

    // Ctrl+Scroll zoom, toward the cursor
    hitArea.addEventListener('wheel', function (e) {
      if (!e.ctrlKey && !e.metaKey) return; // Plain scroll pans natively otherwise.
      e.preventDefault();

      var delta = e.deltaY > 0 ? -ZOOM_STEP : ZOOM_STEP;
      var newScale = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, state.scale + delta));

      var rect = hitArea.getBoundingClientRect();
      var cursorX = e.clientX - rect.left;
      var cursorY = e.clientY - rect.top;

      var scaleRatio = newScale / state.scale;
      state.panX = cursorX - (cursorX - state.panX) * scaleRatio;
      state.panY = cursorY - (cursorY - state.panY) * scaleRatio;
      state.scale = newScale;
      applyTransform();
    }, Object.assign({ passive: false }, opts));

    // Click-drag pan
    hitArea.addEventListener('mousedown', function (e) {
      if (e.button !== 0) return;
      state.dragging = true;
      state.startX = e.clientX - state.panX;
      state.startY = e.clientY - state.panY;
      hitArea.style.cursor = 'grabbing';
      e.preventDefault();
    }, opts);

    document.addEventListener('mousemove', function (e) {
      if (!state.dragging) return;
      state.panX = e.clientX - state.startX;
      state.panY = e.clientY - state.startY;
      applyTransform();
    }, opts);

    document.addEventListener('mouseup', function () {
      if (state.dragging) {
        state.dragging = false;
        hitArea.style.cursor = 'grab';
      }
    }, opts);

    hitArea.style.cursor = 'grab';
    return { state: state, applyTransform: applyTransform };
  }

  function initZoomPan(container, diagramEl) {
    // reRenderAll() (a theme toggle) clears data-sw-mermaid-done and
    // re-runs renderDiagram against this SAME container without ever
    // recreating it -- without this guard, every toggle stacks another
    // full set of wheel/mousedown/document-mousemove/document-mouseup
    // listeners (the last two unremovable, with no AbortController) plus
    // another click handler per button, each closing over its own
    // independent zoom state. Same pattern as initExpand's
    // data-sw-expand-wired guard just below.
    if (container.hasAttribute('data-sw-zoom-wired')) return;
    container.setAttribute('data-sw-zoom-wired', 'true');

    var engine = createZoomPan(container, diagramEl);
    var state = engine.state;
    var applyTransform = engine.applyTransform;

    // Wire up zoom control buttons
    var controls = container.querySelector('.sw-mermaid__controls');
    if (controls) {
      var zoomInBtn = controls.querySelector('[data-sw-zoom="in"]');
      var zoomOutBtn = controls.querySelector('[data-sw-zoom="out"]');
      var resetBtn = controls.querySelector('[data-sw-zoom="reset"]');

      if (zoomInBtn) {
        zoomInBtn.addEventListener('click', function () {
          state.scale = Math.min(ZOOM_MAX, state.scale + ZOOM_STEP);
          applyTransform();
        });
      }
      if (zoomOutBtn) {
        zoomOutBtn.addEventListener('click', function () {
          state.scale = Math.max(ZOOM_MIN, state.scale - ZOOM_STEP);
          applyTransform();
        });
      }
      if (resetBtn) {
        resetBtn.addEventListener('click', function () {
          state.scale = 1;
          state.panX = 0;
          state.panY = 0;
          applyTransform();
        });
      }
      // The buttons sit inside `container`, which also has its own
      // mousedown-to-pan listener -- without this, clicking a button
      // also starts a drag of the diagram underneath it.
      controls.addEventListener('mousedown', function (e) { e.stopPropagation(); });
    }
  }

  // =========================================================
  // Fullscreen expand (stream_weaver-yjv)
  //
  // A wide diagram's fixed-px labels shrink proportionally to fit
  // whatever doc column width it renders in -- the constraint is the
  // container, not the SVG, so no amount of in-place pan/zoom fixes it.
  // Expand re-hosts the already-rendered SVG (never moved, always cloned,
  // so the in-place diagram and its own zoom/pan state if any are
  // untouched) in a modal <dialog>, which has no width to shrink against.
  //
  // <dialog>.showModal() rather than a hand-rolled overlay div: it gives
  // us the top layer (no z-index arms race with toasts/nav elsewhere in
  // this codebase), Escape-to-close, focus moved in and restored to the
  // expand button on close, and an inert background -- all of which a
  // hand-rolled div would otherwise have to reimplement, badly.
  //
  // Pure client-side, no server route: works identically in the live
  // canvas, the reader, and a static export (including an --offline one,
  // since this file is what's already inlined there -- no new
  // dependency).
  // =========================================================
  var fullscreen = null; // { dialog, abort } -- one at a time.
  var fullscreenSeq = 0;

  function initExpand(container, diagramEl) {
    var btn = container.querySelector('.sw-mermaid__controls [data-sw-zoom="expand"]');
    // reRenderAll() (theme switch) clears data-sw-mermaid-done and re-runs
    // renderDiagram against this SAME button -- it replaces diagramEl's
    // innerHTML but never recreates .sw-mermaid__controls. Without this
    // guard, every theme toggle stacks another click handler on it, and
    // each stacked handler opens (and immediately re-closes) its own
    // overlay + AbortController on a single click.
    if (!btn || btn.hasAttribute('data-sw-expand-wired')) return;
    btn.setAttribute('data-sw-expand-wired', 'true');

    btn.addEventListener('click', function () {
      openFullscreen(diagramEl);
    });
  }

  // Mermaid namespaces every internal id off the root <svg>'s own id --
  // arrowhead markers, gradients, and the selectors inside the SVG's own
  // inlined <style> all reference it via url(#...) or a bare selector. A
  // plain cloneNode(true) reproduces that whole id set while the original
  // is still in the document, and url(#...) resolves to the FIRST element
  // in document order with a given id -- the original's, not the clone's.
  // It renders correctly today, which is the trap: it breaks the moment
  // the original is re-rendered or swapped out from under an open
  // overlay (a theme toggle, a canvas push), silently dropping every
  // arrowhead in the exact "complex diagram" view this feature exists
  // for. Re-namespacing with one string swap (everything is prefixed off
  // the same root id) fixes ids, references, and inline style selectors
  // together in a single pass.
  function cloneSvgWrapper(svg) {
    var markup = svg.outerHTML;
    if (svg.id) markup = markup.split(svg.id).join(svg.id + '-fs' + (++fullscreenSeq));

    var wrapper = document.createElement('div');
    wrapper.className = 'sw-mermaid-fullscreen-overlay__svg-wrapper';
    wrapper.innerHTML = markup;

    var svgEl = wrapper.firstElementChild;
    // Mermaid's root <svg> carries width="100%" (an HTML attribute) plus
    // an inline style="max-width: Npx" -- fine in the original in-place
    // container, a normal block-level div with a concrete width to
    // resolve 100% against. Here it isn't: `content` (this wrapper's
    // parent) is a flex item with no explicit width, so "100%" has
    // nothing solid to resolve against and collapses toward zero --
    // verified live: the dialog rendered the diagram at a few px wide
    // instead of natural size, the opposite of this feature's entire
    // purpose. Fixed by setting concrete pixel dimensions read straight
    // from the SVG's own viewBox -- which IS "natural size" -- so nothing
    // here depends on any ancestor's computed width at all.
    //
    // Set via setAttribute, not svgEl.style.*: an inline-style CSP
    // restriction (style-src-attr) was the first suspected cause of this
    // still going blank on SharePoint after the width="100%" fix below,
    // but that theory didn't hold up -- see the expand button's own icon
    // in adapter/alpinejs.rb for what actually turned out to be wrong
    // (markup sanitization, not CSS at all). That doesn't make this wrong
    // to keep, though: this SVG is inserted by JS at runtime, not present
    // in the page's original markup, so it was never at risk from a
    // sanitizer that only processes uploaded HTML -- but setAttribute is
    // no more complex than .style and has strictly fewer ways to be
    // blocked by *some* CSP variant, so there's no reason to revert it.
    // width=/height= are plain SVG geometry attributes regardless.
    // removeAttribute clears mermaid's own inline max-width, the only
    // thing that attribute contains.
    var viewBox = svgEl.getAttribute('viewBox');
    var dims = viewBox && viewBox.trim().split(/\s+/).map(Number);
    if (dims && dims.length === 4 && dims[2] > 0 && dims[3] > 0) {
      svgEl.setAttribute('width', dims[2]);
      svgEl.setAttribute('height', dims[3]);
    }
    svgEl.removeAttribute('style');
    return wrapper;
  }

  function openFullscreen(diagramEl) {
    var svg = diagramEl.querySelector('svg');
    if (!svg) return; // Not rendered yet, or the render errored -- nothing to show.
    closeFullscreen(); // Only one overlay at a time.

    // One AbortController per open: every listener below is registered
    // against its signal, so closing is a single .abort() call and
    // nothing can be left orphaned on `document` across repeated
    // open/close cycles.
    var abort = new AbortController();
    var signal = abort.signal;

    var dialog = document.createElement('dialog');
    dialog.className = 'sw-mermaid-fullscreen-overlay';
    dialog.setAttribute('aria-label', 'Diagram, expanded');

    var content = document.createElement('div');
    content.className = 'sw-mermaid-fullscreen-overlay__content';
    var wrapper = cloneSvgWrapper(svg);
    content.appendChild(wrapper);

    var closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'sw-mermaid-fullscreen-overlay__close';
    closeBtn.setAttribute('aria-label', 'Close');
    closeBtn.textContent = '✕';

    var hint = document.createElement('div');
    hint.className = 'sw-mermaid-fullscreen-overlay__hint';
    hint.textContent = 'Scroll or drag to pan · Ctrl+scroll to zoom · Esc to close';

    dialog.appendChild(content);
    dialog.appendChild(closeBtn);
    dialog.appendChild(hint);
    document.body.appendChild(dialog);

    // Same engine as zoom: true -- including its cursor-anchored zoom.
    createZoomPan(content, wrapper, signal);

    closeBtn.addEventListener('click', closeFullscreen, { signal: signal });
    // mousedown, not click: a click's target is the nearest common
    // ancestor of its mousedown and mouseup targets, so releasing a pan
    // drag over the backdrop (the common case for a diagram wider than
    // the viewport -- the exact case this feature is for) would report
    // the dialog as the target and close the overlay mid-drag. mousedown
    // fires on the actual element under the cursor, so a drag that
    // begins on `content` can never trigger this.
    dialog.addEventListener('mousedown', function (e) {
      if (e.target === dialog) closeFullscreen();
    }, { signal: signal });
    // showModal()'s native Escape handling calls dialog.close(), which
    // fires 'close' -- route that through the same cleanup so Escape and
    // the close button and the backdrop click all converge on one path.
    dialog.addEventListener('close', closeFullscreen, { signal: signal });

    fullscreen = { dialog: dialog, abort: abort };
    document.documentElement.classList.add('sw-mermaid-fullscreen-open');
    dialog.showModal();
  }

  // Unconditional class removal: if the dialog ever leaves by a route
  // other than this function (a canvas push replacing body content, an
  // htmx swap), the scroll lock must not survive it -- an unscrollable
  // page with no visible overlay to explain it is unrecoverable short of
  // a reload.
  function closeFullscreen() {
    document.documentElement.classList.remove('sw-mermaid-fullscreen-open');
    if (!fullscreen) return;

    var closing = fullscreen;
    fullscreen = null; // Before .close(), so the 'close' listener's re-entry no-ops.
    closing.abort.abort(); // Every listener from this open, gone in one call.
    if (closing.dialog.open) closing.dialog.close();
    closing.dialog.remove();
  }

  // =========================================================
  // Theme change observer: re-render on theme switch
  // =========================================================
  var themeObserverAttached = false;

  function observeThemeChanges() {
    // Called from swMermaidInit()'s loadMermaid().then() -- reached again
    // on DOMContentLoaded, every htmx:afterSwap, and the canvas's
    // live-update poll handler, so without this guard every one of those
    // adds another MutationObserver on <html>, each firing reRenderAll()
    // independently on the next theme toggle.
    if (themeObserverAttached) return;
    themeObserverAttached = true;

    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (m) {
        if (m.attributeName === 'data-sw-theme') {
          reRenderAll();
        }
      });
    });
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-sw-theme'] });
  }

  function getCustomVars(container) {
    var raw = container.getAttribute('data-sw-mermaid-vars');
    if (!raw) return null;
    try { return JSON.parse(raw); } catch (e) { return null; }
  }

  function reRenderAll() {
    if (!mermaidLoaded || !window.__swMermaid) return;
    var containers = document.querySelectorAll('.sw-mermaid');
    containers.forEach(function (container) {
      // renderDiagram() no-ops when data-sw-mermaid-done is set (guards against
      // concurrent initial-load races) — clear it so a theme change can force a fresh render.
      container.removeAttribute('data-sw-mermaid-done');
      renderDiagram(container, window.__swMermaid, getCustomVars(container));
    });
  }

  // =========================================================
  // Public API: called by the adapter's inline init script
  // =========================================================
  window.swMermaidInit = function () {
    // Snapshot un-rendered containers now to check needsElk and decide whether
    // to bother loading the CDN at all. The actual render queries fresh at CDN
    // resolve time so it operates on whatever is currently in the DOM — not stale
    // references to nodes that may have been replaced by a subsequent canvas-push
    // before the async CDN load completed.
    var snapshot = document.querySelectorAll('.sw-mermaid:not([data-sw-mermaid-done])');
    if (snapshot.length === 0) return;

    var needsElk = false;
    snapshot.forEach(function (c) {
      if (c.getAttribute('data-sw-mermaid-elk') === 'true') needsElk = true;
    });

    loadMermaid(needsElk).then(function (mermaid) {
      // Re-query at render time: earlier snapshot nodes may be detached if the
      // canvas was updated while the CDN was loading.
      var containers = document.querySelectorAll('.sw-mermaid:not([data-sw-mermaid-done])');
      containers.forEach(function (container) {
        renderDiagram(container, mermaid, getCustomVars(container));
      });
      observeThemeChanges();
    }).catch(function (err) {
      // needsElk is page-global -- one elk: true diagram forces every
      // diagram on the page down this CDN-import path, including in an
      // --offline export, where the CDN is exactly what's blocked (ELK
      // has no equivalent inlinable build; see the exporter's comment on
      // mermaid_offline_script_tag). Without this, that failure was
      // invisible: renderDiagram()'s own .catch only covers render
      // errors, never a load failure, so every diagram on the page just
      // stayed blank with nothing in the console but an unhandled
      // rejection. Surface it the same way a render error already does.
      document.querySelectorAll('.sw-mermaid__diagram:empty').forEach(function (diagramEl) {
        diagramEl.innerHTML = '<pre class="sw-mermaid__error">'
          + escapeHtml(err.message || String(err)) + '</pre>';
      });
    });
  };

  // Preload the mermaid CDN without rendering anything.
  // Call this on page load so the CDN fetch completes before the first mermaid push arrives.
  window.swMermaidPreload = function () { loadMermaid(false); };

  // Re-trigger init after every HTMX swap so mermaid works in canvas-push sequences
  // where the first push had no mermaid and a later push introduces it for the first time.
  // swMermaidInit is idempotent: data-sw-mermaid-done guards against re-rendering.
  document.addEventListener('htmx:afterSwap', function () {
    if (document.querySelector('.sw-mermaid:not([data-sw-mermaid-done])')) {
      window.swMermaidInit();
    }
  });

  // Self-init once the document is fully parsed, so a page doesn't need
  // Alpine (or any other trigger) to make its diagrams appear -- this file
  // is the single thing a mermaid diagram actually depends on. Deferred to
  // DOMContentLoaded rather than called here directly: this script is
  // inlined at the position of the FIRST mermaid component in the page, so
  // calling swMermaidInit() synchronously at parse time would miss any
  // mermaid containers that appear later in the same document.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', window.swMermaidInit);
  } else {
    window.swMermaidInit();
  }
})();
