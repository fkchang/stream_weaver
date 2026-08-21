/**
 * StreamWeaver Route Tabs (sw-route-tabs.js)
 *
 * Keeps a `tabs(..., url: true)` group's active index in the query string, so
 * the tab a reader is looking at can be bookmarked, shared, and reached with
 * the back button. Switching stays entirely client-side -- no request is made.
 */
(function() {
  'use strict';

  window.swRouteTabs = {
    /**
     * The active index this group's URL parameter asks for.
     *
     * The URL is the only thing read here. Falling back to the index the
     * server rendered would resurrect a stale tab whenever an unrelated POST
     * morphs the container from older session state.
     *
     * @param {string} key - The tabs group's state key
     * @param {number} count - How many tabs the group has
     * @returns {number} A valid index, or 0 when the parameter is absent,
     *   malformed, or past the last tab
     */
    read: function(key, count) {
      var raw = new URLSearchParams(window.location.search).get(key);
      if (!/^\d+$/.test(raw)) return 0;

      var index = parseInt(raw, 10);
      return index < count ? index : 0;
    },

    /**
     * Record a tab switch in the URL.
     *
     * Merges into the query string as it stands at click time, so parameters
     * this group knows nothing about -- another route tabs group's key, a
     * filter some link put there -- survive the switch.
     *
     * @param {string} key - The tabs group's state key
     * @param {number} index - The newly active index
     */
    push: function(key, index) {
      var params = new URLSearchParams(window.location.search);
      // Re-clicking the tab already showing would otherwise stack a duplicate
      // entry, and the next Back press would look broken -- popstate would
      // re-derive the same index and nothing on the page would move.
      if (params.get(key) === String(index)) return;

      params.set(key, index);
      window.history.pushState({}, '', window.location.pathname + '?' + params.toString() + window.location.hash);
    }
  };
})();
