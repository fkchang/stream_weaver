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

      # start(mountId) -- mountId names the element every patch morphs into,
      # and is optional: a host with no argument to pass keeps the runtime's
      # default (see OpalRuntime::DEFAULT_MOUNT_ID). The browser extension
      # passes its own container id, which is why this is a parameter rather
      # than a constant.
      #
      # The delegated listeners install at most once per page, no matter how
      # often start() is called, and reach the runtime through a mutable handle
      # rather than closing over one. Every `app()` call replaces
      # window.SWRuntime with a fresh runtime's, so a second start() in the same
      # page -- which the extension's sandbox frame can receive, one sw:render
      # per doc -- would otherwise leave the first runtime's handlers attached
      # alongside the second's: one user click invoking the same callback twice,
      # which for a sort toggle reads as "sorting does not work" rather than as
      # a duplicate listener.
      #
      # The handle is claimed after the render succeeds, not when this bridge is
      # installed. A doc that compiles and then raises while rendering leaves
      # the previous doc still on screen, and its clicks have to keep reaching
      # the runtime that actually drew it rather than the broken one.
      def install
        # :nocov:
        return unless Env.dom?
        runtime = @runtime
        %x{
          window.SWRuntime = {
            start: function(mountId) {
              #{runtime.start(`mountId`)};

              window.__swActiveRuntime = {
                invoke: function(domId) { #{runtime.invoke_and_patch(`domId`)}; },
                update: function(key, value) { #{runtime.update_and_patch(`key`, `value`)}; }
              };

              if (window.__swDelegationInstalled) return;
              window.__swDelegationInstalled = true;

              document.addEventListener('click', function(e) {
                var el = e.target.closest('[data-sw-invoke]');
                if (el) window.__swActiveRuntime.invoke(el.dataset.swInvoke);
              });
              document.addEventListener('click', function(e) {
                var el = e.target.closest('[data-sw-action]');
                if (el && el.dataset.swAction === 'toggle-theme') {
                  if (typeof swToggleTheme === 'function') swToggleTheme();
                }
              });
              document.addEventListener('input', function(e) {
                var key = e.target.dataset && e.target.dataset.swUpdate;
                if (key) window.__swActiveRuntime.update(key, e.target.value);
              });
              document.addEventListener('change', function(e) {
                var key = e.target.dataset && e.target.dataset.swToggle;
                if (key) window.__swActiveRuntime.update(key, e.target.checked);
              });
            }
          };
        }
        # :nocov:
      end
    end
  end
end
