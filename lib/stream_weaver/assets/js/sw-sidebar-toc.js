/**
 * StreamWeaver SidebarToc Scroll Spy
 *
 * Uses IntersectionObserver to highlight the active section in the
 * sidebar table-of-contents. Works with both desktop (sticky sidebar)
 * and mobile (horizontal scrollable bar) layouts.
 */
(function() {
  'use strict';

  // Which nav nodes are already wired, by identity.
  //
  // Node identity, not a data attribute: a host patching with morphdom (the
  // browser extension's sandbox, via SWRuntime) syncs attributes from freshly
  // rendered markup that never carries a guard flag, so it strips the flag
  // while keeping the very nav node whose links already have listeners. An
  // attribute guard therefore holds only until the first re-render and then
  // stacks a click listener per link and leaks an IntersectionObserver
  // watching the previous one's targets, on every render after that.
  //
  // A real htmx swap replaces navEl outright, so a fresh node is correctly
  // absent from this set and gets wired -- the behavior the attribute flag
  // was there for is unchanged.
  var wiredNavs = new WeakSet();

  // The section the reader is currently on, remembered across re-renders.
  var activeSectionId = null;

  function initSidebarToc() {
    var navEl = document.querySelector('.sw-sidebar-toc__nav');
    if (!navEl) return;

    var links = navEl.querySelectorAll('.sw-sidebar-toc__link');
    if (links.length === 0) return;

    // Collect target section IDs
    var sectionIds = [];
    links.forEach(function(link) {
      var id = link.getAttribute('data-sw-toc-target');
      if (id) sectionIds.push(id);
    });
    if (sectionIds.length === 0) return;

    if (!wiredNavs.has(navEl)) {
      wiredNavs.add(navEl);
      wireNav(links, sectionIds);
    }

    // Re-asserted on every call, wired or not. A morphdom patch syncs classes
    // from freshly rendered markup, which has no active link, and the
    // IntersectionObserver below only fires when an intersection actually
    // changes -- so without this the highlight disappears on the first
    // re-render and does not come back until the reader scrolls.
    // reveal: false -- nothing about the reader's position changed here, and
    // the reveal is a smooth scroll of the mobile TOC bar. Doing it on every
    // patch would scroll the bar on every keystroke in an interactive doc.
    var restore = sectionIds.indexOf(activeSectionId) >= 0 ? activeSectionId : sectionIds[0];
    setActiveLink(restore, links, false);
  }

  function wireNav(links, sectionIds) {
    // Track which sections are intersecting
    var visibleSections = {};

    // Create IntersectionObserver
    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        visibleSections[entry.target.id] = entry.isIntersecting;
      });

      // Find the first visible section (in DOM order)
      var activeId = null;
      for (var i = 0; i < sectionIds.length; i++) {
        if (visibleSections[sectionIds[i]]) {
          activeId = sectionIds[i];
          break;
        }
      }

      if (activeId) {
        setActiveLink(activeId, links);
      }
    }, {
      rootMargin: '-80px 0px -60% 0px',
      threshold: 0
    });

    // Observe each section target
    sectionIds.forEach(function(id) {
      var el = document.getElementById(id);
      if (el) observer.observe(el);
    });

    // Smooth-scroll click handler
    links.forEach(function(link) {
      link.addEventListener('click', function(e) {
        e.preventDefault();
        var targetId = link.getAttribute('data-sw-toc-target');
        var target = document.getElementById(targetId);
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          setActiveLink(targetId, links);
        }
      });
    });
  }

  // reveal defaults to true: the two callers that pass nothing (a click, the
  // scroll-spy observer) both mean "the reader moved", which is when the
  // mobile TOC bar should follow along.
  function setActiveLink(activeId, links, reveal) {
    activeSectionId = activeId;
    links.forEach(function(link) {
      var isActive = link.getAttribute('data-sw-toc-target') === activeId;
      if (isActive) {
        link.classList.add('sw-is-active');
      } else {
        link.classList.remove('sw-is-active');
      }
    });

    if (reveal === false) return;

    // On mobile, scroll the active link into view in the horizontal bar
    var activeLink = document.querySelector('.sw-sidebar-toc__link.sw-is-active');
    if (activeLink) {
      var nav = activeLink.closest('.sw-sidebar-toc__nav');
      if (nav && nav.scrollWidth > nav.clientWidth) {
        activeLink.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
      }
    }
  }

  // Hosts with no htmx at all (the browser extension's sandbox, a one-shot
  // static render) call this directly instead of relying on the htmx
  // listener below -- a named, greppable hook rather than that host faking
  // an htmx event it never actually loads.
  window.swInitSidebarToc = initSidebarToc;

  // Initialize on DOMContentLoaded and after HTMX swaps
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSidebarToc);
  } else {
    initSidebarToc();
  }
  document.addEventListener('htmx:afterSwap', initSidebarToc);
})();
