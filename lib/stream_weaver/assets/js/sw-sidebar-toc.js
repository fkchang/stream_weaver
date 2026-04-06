/**
 * StreamWeaver SidebarToc Scroll Spy
 *
 * Uses IntersectionObserver to highlight the active section in the
 * sidebar table-of-contents. Works with both desktop (sticky sidebar)
 * and mobile (horizontal scrollable bar) layouts.
 */
(function() {
  'use strict';

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

    // Activate the first link by default
    if (links.length > 0 && sectionIds.length > 0) {
      setActiveLink(sectionIds[0], links);
    }
  }

  function setActiveLink(activeId, links) {
    links.forEach(function(link) {
      var isActive = link.getAttribute('data-sw-toc-target') === activeId;
      if (isActive) {
        link.classList.add('sw-is-active');
      } else {
        link.classList.remove('sw-is-active');
      }
    });

    // On mobile, scroll the active link into view in the horizontal bar
    var activeLink = document.querySelector('.sw-sidebar-toc__link.sw-is-active');
    if (activeLink) {
      var nav = activeLink.closest('.sw-sidebar-toc__nav');
      if (nav && nav.scrollWidth > nav.clientWidth) {
        activeLink.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
      }
    }
  }

  // Initialize on DOMContentLoaded and after HTMX swaps
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSidebarToc);
  } else {
    initSidebarToc();
  }
  document.addEventListener('htmx:afterSwap', initSidebarToc);
})();
