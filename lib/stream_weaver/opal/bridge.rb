# frozen_string_literal: true

require_relative "env"

module StreamWeaver
  module Opal
    # Wires an OpalRuntime to window.SWRuntime in the browser.
    # Registers delegated event listeners so no inline JS is needed in HTML.
    #
    # Every line below needs a DOM -- `window`, `document`, and event
    # delegation -- so installing is a no-op where there is none. That is what
    # lets `app()` stay a single unconditional call site while the same bundle
    # also loads in Node, where the string path (StringBridge) takes over.
    class OpalBridge
      def initialize(runtime)
        @runtime = runtime
      end

      def install
        # :nocov:
        return unless Env.dom?
        runtime = @runtime
        %x{
          window.SWRuntime = {
            start: function() {
              #{runtime.render_and_patch}
              document.addEventListener('click', function(e) {
                var el = e.target.closest('[data-sw-invoke]');
                if (el) #{runtime.invoke_and_patch(`el.dataset.swInvoke`)};
              });
              document.addEventListener('click', function(e) {
                var el = e.target.closest('[data-sw-action]');
                if (el && el.dataset.swAction === 'toggle-theme') {
                  if (typeof swToggleTheme === 'function') swToggleTheme();
                }
              });
              document.addEventListener('input', function(e) {
                var key = e.target.dataset && e.target.dataset.swUpdate;
                if (key) #{runtime.update_and_patch(`key`, `e.target.value`)};
              });
              document.addEventListener('change', function(e) {
                var key = e.target.dataset && e.target.dataset.swToggle;
                if (key) #{runtime.update_and_patch(`key`, `e.target.checked`)};
              });
            }
          };
        }
        # :nocov:
      end
    end
  end
end
