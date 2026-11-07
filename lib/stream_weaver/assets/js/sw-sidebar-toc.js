/**
 * StreamWeaver scroll spy: sidebar_toc and ide_editor
 *
 * Uses IntersectionObserver to highlight the link of the section the reader
 * is on, and scrolls a section into view when its link is clicked. Two
 * components use it, each as one "spy":
 *
 * - sidebar_toc: links in .sw-sidebar-toc__nav, sections scrolled by the
 *   page itself. Works with both the desktop sticky sidebar and the mobile
 *   horizontal bar.
 * - ide_editor: sections scrolled inside .sw-ide-editor. Every
 *   [data-sw-ide-target] link in the shell (the editor's tab strip, a right
 *   rail file tree) shares the one active section, and each scrolls its
 *   active link into view within its own strip or list.
 */
(function() {
  'use strict';

  // Within this many pixels of the bottom, a scrolling root counts as
  // scrolled to its end.
  var END_TOLERANCE_PX = 2;
  // A clicked section stays active until its scroll ends; this releases it
  // when no scrollend event comes (nothing scrolled, or no browser support).
  var UNPIN_AFTER_MS = 1000;

  // Each spy's state, keyed by its root node's identity.
  //
  // Node identity, not a data attribute: a host patching with morphdom (the
  // browser extension's sandbox, via SWRuntime) syncs attributes from freshly
  // rendered markup that never carries a guard flag, so it strips the flag
  // while keeping the very node whose links already have listeners. An
  // attribute guard therefore holds only until the first re-render and then
  // stacks a click listener per link and leaks an IntersectionObserver
  // watching the previous one's targets, on every render after that.
  //
  // A real htmx swap replaces the node outright, so a fresh node is correctly
  // absent from this map and gets wired -- the behavior the attribute flag
  // was there for is unchanged.
  var spiesByRoot = new WeakMap();

  // The section the reader is currently on, per spy, remembered across
  // re-renders.
  var activeSectionIds = {};

  function scrollBehavior() {
    var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    return reduce ? 'auto' : 'smooth';
  }

  function initSidebarToc() {
    var navEl = document.querySelector('.sw-sidebar-toc__nav');
    if (!navEl) return;

    initSpy(navEl, {
      key: 'toc',
      scope: navEl,
      linkSelector: '.sw-sidebar-toc__link',
      attr: 'data-sw-toc-target',
      root: null,
      rootMargin: '-80px 0px -60% 0px',
      reveal: revealTocLink
    });
  }

  function initIdeEditor() {
    var editor = document.querySelector('.sw-ide-editor');
    if (!editor) return;

    var strip = editor.querySelector('.sw-ide-tabstrip');
    initSpy(editor, {
      key: 'ide',
      scope: editor.closest('.sw-ide-shell') || document,
      linkSelector: '[data-sw-ide-target]',
      attr: 'data-sw-ide-target',
      root: editor,
      // The band is the top of the editor, starting below the sticky tab
      // strip (whose height the stylesheet also gives sections as their
      // scroll margin).
      rootMargin: '-' + (strip ? strip.offsetHeight : 0) + 'px 0px -60% 0px',
      ariaCurrent: true,
      focusTarget: true,
      reveal: revealIdeLinks
    });
  }

  function init() {
    initSidebarToc();
    initIdeEditor();
  }

  // Wires a spy once per root node; every later call (a re-render) picks up
  // links and sections added since, and restores the active link.
  function initSpy(node, config) {
    var spy = spiesByRoot.get(node);
    if (!spy) {
      spy = createSpy(config);
      spiesByRoot.set(node, spy);
    }
    spy.refresh();
    if (spy.sectionIds.length === 0) return;

    // Re-asserted on every call. A morphdom patch syncs classes from freshly
    // rendered markup, which has no active link, and the
    // IntersectionObserver below only fires when an intersection actually
    // changes -- so without this the highlight disappears on the first
    // re-render and does not come back until the reader scrolls.
    // reveal: false -- nothing about the reader's position changed here, and
    // the reveal scrolls a link strip. Doing it on every patch would scroll
    // the strip on every keystroke in an interactive doc.
    var remembered = activeSectionIds[spy.key];
    var restore = spy.sectionIds.indexOf(remembered) >= 0 ? remembered : spy.sectionIds[0];
    setActiveLink(spy, restore, false);
  }

  function createSpy(config) {
    var spy = config;
    var root = config.root;
    var visibleSections = {};
    var observedSections = new WeakSet();
    // A clicked section stays active while its scroll passes the sections in
    // between.
    var pinned = null;
    var unpinTimer = null;

    spy.sectionIds = [];
    spy.links = function() {
      return config.scope.querySelectorAll(config.linkSelector);
    };

    function lastId() {
      return spy.sectionIds[spy.sectionIds.length - 1];
    }

    function unpin() {
      pinned = null;
      clearTimeout(unpinTimer);
    }

    // Short sections at the end never reach the band, so a reader who has
    // scrolled an overflowing root all the way down is on the last one.
    function scrolledToEnd() {
      return !!root && root.scrollHeight > root.clientHeight &&
        root.scrollTop + root.clientHeight >= root.scrollHeight - END_TOLERANCE_PX;
    }

    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        visibleSections[entry.target.id] = entry.isIntersecting;
      });
      if (pinned) return;

      // The first visible section, in DOM order
      var activeId = scrolledToEnd() ? lastId() : null;
      for (var i = 0; !activeId && i < spy.sectionIds.length; i++) {
        if (visibleSections[spy.sectionIds[i]]) activeId = spy.sectionIds[i];
      }
      if (activeId) setActiveLink(spy, activeId);
    }, {
      root: root,
      rootMargin: config.rootMargin,
      threshold: 0
    });

    // Link ids in order, each once (several links may point at one
    // section), and an observer on every section not yet observed.
    spy.refresh = function() {
      var sectionIds = [];
      Array.prototype.forEach.call(spy.links(), function(link) {
        var id = link.getAttribute(config.attr);
        if (id && sectionIds.indexOf(id) < 0) sectionIds.push(id);
      });
      spy.sectionIds = sectionIds;
      sectionIds.forEach(function(id) {
        var el = document.getElementById(id);
        if (el && !observedSections.has(el)) {
          observedSections.add(el);
          observer.observe(el);
        }
      });
    };

    if (root) {
      root.addEventListener('scrollend', unpin);
      // Reaching the end need not change any intersection, so the observer
      // may not fire there.
      root.addEventListener('scroll', function() {
        if (!pinned && activeSectionIds[spy.key] !== lastId() && scrolledToEnd()) {
          setActiveLink(spy, lastId());
        }
      });
    }

    // One delegated listener, so links rendered after wiring work too.
    config.scope.addEventListener('click', function(e) {
      var link = e.target.closest && e.target.closest(config.linkSelector);
      if (!link) return;
      var targetId = link.getAttribute(config.attr);
      var target = document.getElementById(targetId);
      if (!target) return;

      e.preventDefault();
      if (root) {
        pinned = targetId;
        clearTimeout(unpinTimer);
        unpinTimer = setTimeout(unpin, UNPIN_AFTER_MS);
      }
      target.scrollIntoView({ behavior: scrollBehavior(), block: 'start' });
      // The default action would have moved focus to the target; keep that.
      if (config.focusTarget) target.focus({ preventScroll: true });
      setActiveLink(spy, targetId);
    });

    return spy;
  }

  // reveal defaults to true: the two callers that pass nothing (a click, the
  // scroll-spy observer) both mean "the reader moved", which is when a link
  // strip should follow along.
  function setActiveLink(spy, activeId, reveal) {
    activeSectionIds[spy.key] = activeId;
    var activeLinks = [];
    Array.prototype.forEach.call(spy.links(), function(link) {
      var isActive = link.getAttribute(spy.attr) === activeId;
      if (isActive) {
        link.classList.add('sw-is-active');
        activeLinks.push(link);
      } else {
        link.classList.remove('sw-is-active');
      }
      if (spy.ariaCurrent) {
        if (isActive) {
          link.setAttribute('aria-current', 'location');
        } else {
          link.removeAttribute('aria-current');
        }
      }
    });

    if (reveal === false) return;
    spy.reveal(activeLinks);
  }

  // On mobile, scroll the active link into view in the horizontal bar
  function revealTocLink(links) {
    var activeLink = links[0];
    if (!activeLink) return;
    var nav = activeLink.closest('.sw-sidebar-toc__nav');
    if (nav && nav.scrollWidth > nav.clientWidth) {
      activeLink.scrollIntoView({ behavior: scrollBehavior(), block: 'nearest', inline: 'center' });
    }
  }

  // Scrolls only the strip or list that holds each link, never the editor:
  // scrollIntoView would also move the editor and cut short the scroll a
  // click just started.
  function revealIdeLinks(links) {
    links.forEach(function(link) {
      var list = link.closest('[data-sw-ide-links]');
      if (!list) return;

      var listBox = list.getBoundingClientRect();
      var linkBox = link.getBoundingClientRect();
      var dx = 0;
      var dy = 0;
      if (linkBox.left < listBox.left) dx = linkBox.left - listBox.left;
      if (linkBox.right > listBox.right) dx = linkBox.right - listBox.right;
      if (linkBox.top < listBox.top) dy = linkBox.top - listBox.top;
      if (linkBox.bottom > listBox.bottom) dy = linkBox.bottom - listBox.bottom;
      if (dx || dy) list.scrollBy({ left: dx, top: dy, behavior: scrollBehavior() });
    });
  }

  // Hosts with no htmx at all (the browser extension's sandbox, a one-shot
  // static render) call this directly instead of relying on the htmx
  // listener below -- a named, greppable hook rather than that host faking
  // an htmx event it never actually loads.
  window.swInitSidebarToc = init;

  // Initialize on DOMContentLoaded and after HTMX swaps
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  document.addEventListener('htmx:afterSwap', init);
})();
