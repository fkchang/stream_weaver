/**
 * StreamWeaver scroll spy: sidebar_toc and ide_editor
 *
 * Uses IntersectionObserver to highlight the link of the section the reader
 * is on, and smooth-scrolls a section into view when its link is clicked.
 * Two pages use it, each as one "spy":
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

  // Which spy roots are already wired, by identity.
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
  // absent from this set and gets wired -- the behavior the attribute flag
  // was there for is unchanged.
  var wiredNavs = new WeakSet();

  // The section the reader is currently on, per spy, remembered across
  // re-renders.
  var activeSectionIds = {};

  function initSidebarToc() {
    var navEl = document.querySelector('.sw-sidebar-toc__nav');
    if (!navEl) return;

    initSpy({
      key: 'toc',
      node: navEl,
      links: navEl.querySelectorAll('.sw-sidebar-toc__link'),
      attr: 'data-sw-toc-target',
      root: null,
      rootMargin: '-80px 0px -60% 0px',
      reveal: revealTocLink
    });
  }

  function initIdeEditor() {
    var editor = document.querySelector('.sw-ide-editor');
    if (!editor) return;

    var shell = editor.closest('.sw-ide-shell') || document;
    initSpy({
      key: 'ide',
      node: editor,
      links: shell.querySelectorAll('[data-sw-ide-target]'),
      attr: 'data-sw-ide-target',
      root: editor,
      // The band is the top of the editor, below the sticky tab strip.
      rootMargin: '-48px 0px -60% 0px',
      ariaCurrent: true,
      reveal: revealIdeLinks
    });
  }

  function init() {
    initSidebarToc();
    initIdeEditor();
  }

  function initSpy(spy) {
    if (spy.links.length === 0) return;

    // Section ids in link order, each once (a file tree folder row may
    // point at the same section as its first file).
    var sectionIds = [];
    spy.links.forEach(function(link) {
      var id = link.getAttribute(spy.attr);
      if (id && sectionIds.indexOf(id) < 0) sectionIds.push(id);
    });
    if (sectionIds.length === 0) return;
    spy.sectionIds = sectionIds;

    if (!wiredNavs.has(spy.node)) {
      wiredNavs.add(spy.node);
      wireSpy(spy);
    }

    // Re-asserted on every call, wired or not. A morphdom patch syncs classes
    // from freshly rendered markup, which has no active link, and the
    // IntersectionObserver below only fires when an intersection actually
    // changes -- so without this the highlight disappears on the first
    // re-render and does not come back until the reader scrolls.
    // reveal: false -- nothing about the reader's position changed here, and
    // the reveal is a smooth scroll of a link strip. Doing it on every patch
    // would scroll the strip on every keystroke in an interactive doc.
    var remembered = activeSectionIds[spy.key];
    var restore = sectionIds.indexOf(remembered) >= 0 ? remembered : sectionIds[0];
    setActiveLink(spy, restore, false);
  }

  function wireSpy(spy) {
    var sectionIds = spy.sectionIds;
    // Track which sections are intersecting
    var visibleSections = {};
    // A clicked section stays active while its smooth scroll passes the
    // sections in between.
    var pinned = null;
    var unpinTimer = null;

    var root = spy.root;
    var lastId = sectionIds[sectionIds.length - 1];

    function unpin() {
      pinned = null;
      clearTimeout(unpinTimer);
    }

    // Short sections at the end never reach the band, so a reader who has
    // scrolled a scrolling root all the way down is on the last one.
    function scrolledToEnd() {
      return !!root && root.scrollTop + root.clientHeight >= root.scrollHeight - 2;
    }

    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        visibleSections[entry.target.id] = entry.isIntersecting;
      });
      if (pinned) return;

      // Find the first visible section (in DOM order)
      var activeId = scrolledToEnd() ? lastId : null;
      for (var i = 0; !activeId && i < sectionIds.length; i++) {
        if (visibleSections[sectionIds[i]]) {
          activeId = sectionIds[i];
        }
      }

      if (activeId) {
        setActiveLink(spy, activeId);
      }
    }, {
      root: spy.root,
      rootMargin: spy.rootMargin,
      threshold: 0
    });

    // Observe each section target
    sectionIds.forEach(function(id) {
      var el = document.getElementById(id);
      if (el) observer.observe(el);
    });

    if (root) {
      root.addEventListener('scrollend', unpin);
      // Reaching the end need not change any intersection, so the observer
      // may not fire there.
      root.addEventListener('scroll', function() {
        if (!pinned && activeSectionIds[spy.key] !== lastId && scrolledToEnd()) {
          setActiveLink(spy, lastId);
        }
      });
    }

    // Smooth-scroll click handler
    spy.links.forEach(function(link) {
      link.addEventListener('click', function(e) {
        e.preventDefault();
        var targetId = link.getAttribute(spy.attr);
        var target = document.getElementById(targetId);
        if (target) {
          if (spy.root) {
            pinned = targetId;
            clearTimeout(unpinTimer);
            // scrollend never fires when nothing scrolls, or in browsers
            // without it.
            unpinTimer = setTimeout(unpin, 1000);
          }
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          setActiveLink(spy, targetId);
        }
      });
    });
  }

  // reveal defaults to true: the two callers that pass nothing (a click, the
  // scroll-spy observer) both mean "the reader moved", which is when a link
  // strip should follow along.
  function setActiveLink(spy, activeId, reveal) {
    activeSectionIds[spy.key] = activeId;
    var activeLinks = [];
    spy.links.forEach(function(link) {
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
  function revealTocLink() {
    var activeLink = document.querySelector('.sw-sidebar-toc__link.sw-is-active');
    if (activeLink) {
      var nav = activeLink.closest('.sw-sidebar-toc__nav');
      if (nav && nav.scrollWidth > nav.clientWidth) {
        activeLink.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
      }
    }
  }

  // Scrolls only the strip or list that holds each link, never the editor:
  // scrollIntoView would also move the editor and cut short the smooth
  // scroll a click just started.
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
      if (dx || dy) list.scrollBy({ left: dx, top: dy, behavior: 'smooth' });
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
