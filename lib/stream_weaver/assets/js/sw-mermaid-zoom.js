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

  function getThemeVariables() {
    var style = getComputedStyle(document.documentElement);
    var isDark = document.documentElement.getAttribute('data-sw-theme') === 'dark';

    return {
      primaryColor: style.getPropertyValue('--sw-node-a').trim() || (isDark ? '#f97316' : '#c2410c'),
      secondaryColor: style.getPropertyValue('--sw-node-b').trim() || (isDark ? '#2dd4bf' : '#0d9488'),
      tertiaryColor: style.getPropertyValue('--sw-node-c').trim() || (isDark ? '#a78bfa' : '#7c3aed'),
      primaryTextColor: style.getPropertyValue('--sw-text').trim() || (isDark ? '#f5f5f5' : '#111111'),
      lineColor: style.getPropertyValue('--sw-border').trim() || (isDark ? 'rgba(255,255,255,0.1)' : '#e0e0e0'),
      background: style.getPropertyValue('--sw-surface').trim() || (isDark ? '#333' : '#ffffff'),
      mainBkg: style.getPropertyValue('--sw-surface').trim() || (isDark ? '#333' : '#ffffff'),
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
    var diagramEl = container.querySelector('.sw-mermaid__diagram');
    if (!diagramEl) return;

    var code = diagramEl.getAttribute('data-sw-mermaid-code');
    if (!code) return;

    var id = container.id || ('sw-mermaid-' + Math.random().toString(36).slice(2, 9));

    var themeVars = getThemeVariables();
    // Merge custom per-block overrides
    if (customVars) {
      Object.keys(customVars).forEach(function (k) {
        themeVars[k] = customVars[k];
      });
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
      // Apply zoom if enabled
      if (container.classList.contains('sw-mermaid--zoom')) {
        initZoomPan(container, diagramEl);
      }
    }).catch(function (err) {
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

  function reRenderAll() {
    if (!mermaidLoaded || !window.__swMermaid) return;
    var containers = document.querySelectorAll('.sw-mermaid');
    containers.forEach(function (container) {
      var customVarsStr = container.getAttribute('data-sw-mermaid-vars');
      var customVars = null;
      if (customVarsStr) {
        try { customVars = JSON.parse(customVarsStr); } catch (e) { /* ignore */ }
      }
      renderDiagram(container, window.__swMermaid, customVars);
    });
  }

  // =========================================================
  // Public API: called by the adapter's inline init script
  // =========================================================
  window.swMermaidInit = function () {
    var containers = document.querySelectorAll('.sw-mermaid');
    if (containers.length === 0) return;

    // Check if any container needs ELK
    var needsElk = false;
    containers.forEach(function (c) {
      if (c.getAttribute('data-sw-mermaid-elk') === 'true') needsElk = true;
    });

    loadMermaid(needsElk).then(function (mermaid) {
      containers.forEach(function (container) {
        var customVarsStr = container.getAttribute('data-sw-mermaid-vars');
        var customVars = null;
        if (customVarsStr) {
          try { customVars = JSON.parse(customVarsStr); } catch (e) { /* ignore */ }
        }
        renderDiagram(container, mermaid, customVars);
      });
      observeThemeChanges();
    });
  };
})();
