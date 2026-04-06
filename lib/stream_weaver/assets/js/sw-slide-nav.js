/**
 * StreamWeaver Slide Navigation (sw-slide-nav.js)
 *
 * Alpine.js data component for slide container navigation.
 * Handles both :swap and :scroll_snap modes.
 *
 * Usage: x-data="swSlideNav(totalSlides, mode)"
 *
 * Registers keyboard shortcuts via swKeyboard (if available).
 */
(function() {
  'use strict';

  /**
   * Alpine.js data factory for slide navigation.
   * @param {number} total - Total number of slides
   * @param {string} mode - 'swap' or 'scroll_snap'
   * @param {boolean} keyboardNav - Whether to register keyboard shortcuts
   * @returns {object} Alpine.js data object
   */
  window.swSlideNav = function(total, mode, keyboardNav, initialSlide) {
    return {
      current: initialSlide || 0,
      total: total,
      mode: mode || 'swap',

      init: function() {
        if (keyboardNav !== false && typeof swKeyboard !== 'undefined') {
          var self = this;

          swKeyboard.register('arrowright', 'navigation', function() {
            self.next();
          });
          swKeyboard.register('arrowleft', 'navigation', function() {
            self.prev();
          });
          swKeyboard.register('arrowdown', 'navigation', function() {
            self.next();
          });
          swKeyboard.register('arrowup', 'navigation', function() {
            self.prev();
          });
          swKeyboard.register(' ', 'navigation', function() {
            self.next();
          });
        }
      },

      next: function() {
        if (this.current < this.total - 1) {
          this.current++;
          this._onNavigate();
        }
      },

      prev: function() {
        if (this.current > 0) {
          this.current--;
          this._onNavigate();
        }
      },

      goTo: function(index) {
        if (index >= 0 && index < this.total) {
          this.current = index;
          this._onNavigate();
        }
      },

      /** Progress as a percentage (0-100) */
      progress: function() {
        if (this.total <= 1) return 100;
        return Math.round((this.current / (this.total - 1)) * 100);
      },

      /** Whether the Back button should be enabled */
      canPrev: function() {
        return this.current > 0;
      },

      /** Whether the Next button should be enabled */
      canNext: function() {
        return this.current < this.total - 1;
      },

      /** Handle post-navigation actions (scroll-snap scroll, scroll-to-top for swap) */
      _onNavigate: function() {
        if (this.mode === 'scroll_snap') {
          var slideEl = document.getElementById('sw-slide-' + this.current);
          if (slideEl) {
            slideEl.scrollIntoView({ behavior: 'smooth' });
          }
        } else if (this.mode === 'swap') {
          // Scroll the slide container into view so the new slide is visible
          var container = this.$el;
          if (container) {
            container.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        }
      }
    };
  };
})();
