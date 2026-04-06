/**
 * StreamWeaver Keyboard Shortcuts Registry (sw-keyboard.js)
 *
 * Centralized keyboard shortcut handling with:
 * - "mod" mapping: Meta (Cmd) on Mac, Control elsewhere
 * - Context-aware suppression: shortcuts ignored in text inputs, textareas, etc.
 * - Priority contexts for conflict resolution
 */
(function() {
  'use strict';

  var isMac = /Mac|iPod|iPhone|iPad/.test(navigator.platform || navigator.userAgent);

  // Selectors where shortcuts should be suppressed
  var SUPPRESS_SELECTORS = [
    'input[type="text"]',
    'input[type="search"]',
    'input[type="email"]',
    'input[type="url"]',
    'input[type="number"]',
    'input:not([type])',
    'textarea',
    '[contenteditable="true"]',
    '.sw-mermaid--zoom',
    '.sw-code-scroll'
  ].join(',');

  // Registry: array of { key, context, handler }
  var shortcuts = [];

  /**
   * Normalize a key combo string.
   * "mod+s" -> { key: "s", ctrl: !isMac, meta: isMac, alt: false, shift: false }
   */
  function parseCombo(combo) {
    var parts = combo.toLowerCase().split('+');
    var parsed = { key: null, ctrl: false, meta: false, alt: false, shift: false };

    parts.forEach(function(part) {
      switch (part) {
        case 'mod':
          if (isMac) parsed.meta = true;
          else parsed.ctrl = true;
          break;
        case 'ctrl':
        case 'control':
          parsed.ctrl = true;
          break;
        case 'meta':
        case 'cmd':
        case 'command':
          parsed.meta = true;
          break;
        case 'alt':
        case 'option':
          parsed.alt = true;
          break;
        case 'shift':
          parsed.shift = true;
          break;
        default:
          parsed.key = part;
      }
    });

    return parsed;
  }

  /**
   * Check if the active element should suppress shortcuts.
   */
  function shouldSuppress() {
    var el = document.activeElement;
    if (!el) return false;
    return el.matches(SUPPRESS_SELECTORS);
  }

  /**
   * Check if a keyboard event matches a parsed combo.
   */
  function matchesCombo(event, parsed) {
    var eventKey = event.key.toLowerCase();

    // Special key name normalization
    if (eventKey === ' ') eventKey = 'space';

    if (parsed.key !== eventKey) return false;
    if (parsed.ctrl !== event.ctrlKey) return false;
    if (parsed.meta !== event.metaKey) return false;
    if (parsed.alt !== event.altKey) return false;
    if (parsed.shift !== event.shiftKey) return false;

    return true;
  }

  // Global keyboard handler
  document.addEventListener('keydown', function(event) {
    // Check each registered shortcut
    for (var i = 0; i < shortcuts.length; i++) {
      var entry = shortcuts[i];

      if (matchesCombo(event, entry.parsed)) {
        // Context-aware suppression: skip if focus is in suppressed element
        // (navigation and selection contexts are always suppressed in inputs;
        //  global context shortcuts with modifiers are allowed)
        if (entry.context !== 'global' && shouldSuppress()) continue;
        if (entry.context === 'global' && !entry.parsed.ctrl && !entry.parsed.meta && shouldSuppress()) continue;

        event.preventDefault();
        event.stopPropagation();
        entry.handler(event);
        return;
      }
    }
  });

  // Public API
  window.swKeyboard = {
    /**
     * Register a keyboard shortcut.
     * @param {string} combo - Key combination (e.g. "mod+s", "ArrowRight")
     * @param {string} context - Context name ("global", "navigation", "selection")
     * @param {function} handler - Callback function(event)
     */
    register: function(combo, context, handler) {
      shortcuts.push({
        combo: combo,
        context: context || 'global',
        parsed: parseCombo(combo),
        handler: handler
      });
    },

    /**
     * Remove all shortcuts with a given context.
     * @param {string} context - Context name to remove
     */
    removeContext: function(context) {
      shortcuts = shortcuts.filter(function(s) { return s.context !== context; });
    },

    /**
     * Remove all registered shortcuts.
     */
    clear: function() {
      shortcuts = [];
    },

    /**
     * Check if running on Mac (for UI display of shortcut hints).
     * @returns {boolean}
     */
    isMac: function() {
      return isMac;
    },

    /**
     * Get the platform-appropriate modifier label.
     * @returns {string} "Cmd" on Mac, "Ctrl" elsewhere
     */
    modLabel: function() {
      return isMac ? '\u2318' : 'Ctrl';
    }
  };
})();
