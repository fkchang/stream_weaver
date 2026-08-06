/**
 * StreamWeaver Clipboard Copy Helper (sw-copy.js)
 *
 * Copies a fixed text payload (read from the triggering element's
 * data-sw-copy-text attribute) to the clipboard, with a fallback for
 * non-secure origins where navigator.clipboard is unavailable
 * (e.g. a LAN IP served over plain HTTP).
 */
(function() {
  'use strict';

  /**
   * Copy the text stored on el.dataset.swCopyText to the clipboard.
   * @param {Element} el - Element carrying the data-sw-copy-text attribute
   * @returns {Promise} Resolves on success, rejects on failure
   */
  window.swCopy = function(el) {
    var text = el.dataset.swCopyText || '';

    if (window.isSecureContext && navigator.clipboard) {
      return navigator.clipboard.writeText(text);
    }

    return new Promise(function(resolve, reject) {
      var textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.setAttribute('readonly', '');
      textarea.style.position = 'fixed';
      textarea.style.top = '0';
      textarea.style.left = '-9999px';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      textarea.setSelectionRange(0, textarea.value.length);

      try {
        var successful = document.execCommand('copy');
        document.body.removeChild(textarea);
        if (successful) {
          resolve();
        } else {
          reject(new Error('execCommand copy failed'));
        }
      } catch (err) {
        document.body.removeChild(textarea);
        reject(err);
      }
    });
  };
})();
