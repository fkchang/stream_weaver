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
        .catch(reject);
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
  // =========================================================
  function initZoomPan(container, diagramEl) {
    var state = { scale: 1, panX: 0, panY: 0, dragging: false, startX: 0, startY: 0 };

    function applyTransform() {
      diagramEl.style.transform =
        'translate(' + state.panX + 'px, ' + state.panY + 'px) scale(' + state.scale + ')';
      diagramEl.style.transformOrigin = '0 0';
    }

    // Ctrl+Scroll zoom
    container.addEventListener('wheel', function (e) {
      if (!e.ctrlKey && !e.metaKey) return;
      e.preventDefault();

      var delta = e.deltaY > 0 ? -ZOOM_STEP : ZOOM_STEP;
      var newScale = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, state.scale + delta));

      // Zoom toward cursor position
      var rect = container.getBoundingClientRect();
      var cursorX = e.clientX - rect.left;
      var cursorY = e.clientY - rect.top;

      var scaleRatio = newScale / state.scale;
      state.panX = cursorX - (cursorX - state.panX) * scaleRatio;
      state.panY = cursorY - (cursorY - state.panY) * scaleRatio;
      state.scale = newScale;
      applyTransform();
    }, { passive: false });

    // Click-drag pan
    container.addEventListener('mousedown', function (e) {
      if (e.button !== 0) return;
      state.dragging = true;
      state.startX = e.clientX - state.panX;
      state.startY = e.clientY - state.panY;
      container.style.cursor = 'grabbing';
      e.preventDefault();
    });

    document.addEventListener('mousemove', function (e) {
      if (!state.dragging) return;
      state.panX = e.clientX - state.startX;
      state.panY = e.clientY - state.startY;
      applyTransform();
    });

    document.addEventListener('mouseup', function () {
      if (state.dragging) {
        state.dragging = false;
        container.style.cursor = 'grab';
      }
    });

    container.style.cursor = 'grab';

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
    }
  }

  // =========================================================
  // Theme change observer: re-render on theme switch
  // =========================================================
  function observeThemeChanges() {
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
