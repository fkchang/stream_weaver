# frozen_string_literal: true
# backtick_javascript: true

module StreamWeaver
  module Opal
    # Answers "is there a DOM here?" for code that is compiled once and then
    # runs in two very different hosts.
    #
    # The same bundle powers a browser tab (where `document` and `window` exist
    # and the runtime patches live nodes) and a bare Node process (where neither
    # exists and the runtime can only build strings). Rather than making every
    # caller take a "browser or not" argument -- which would change the shape of
    # `app()` and break existing builds -- the browser-only paths ask here and
    # no-op when the answer is no.
    #
    # Under MRI this is always false: MRI is neither host, and short-circuiting
    # before the backtick keeps the JS probe from being evaluated as a shell
    # command.
    module Env
      def self.dom?
        return false unless RUBY_ENGINE == "opal"

        # :nocov:
        `typeof document !== 'undefined' && document !== null && typeof document.createElement === 'function'`
        # :nocov:
      end
    end
  end
end
