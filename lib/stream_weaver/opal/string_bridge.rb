# frozen_string_literal: true
# backtick_javascript: true

require_relative "env"

module StreamWeaver
  module Opal
    # Publishes the DOM-free render path to JavaScript as globalThis.SWRender.
    #
    # OpalBridge hands a browser tab window.SWRuntime -- start(), event
    # delegation, morphdom patching. None of that exists in a Node process, and
    # neither does `window`, so the string path gets its own handle on
    # globalThis, which both hosts have. Installing is unconditional: the
    # methods behind it never touch a DOM, so a browser page can use them too
    # (e.g. to serialize what it is showing) without a second code path.
    #
    #   globalThis.SWRender.html()        -> body markup, same as the browser paints
    #   globalThis.SWRender.css()         -> component CSS collected by that render
    #   globalThis.SWRender.document(t)   -> standalone HTML page, CSS inlined
    #
    # html() must run before css() has anything to report -- CSS is collected as
    # components render -- so document() does both in the right order and is the
    # call a file-writing CLI wants.
    class StringBridge
      def initialize(runtime, title: nil)
        @runtime = runtime
        @title   = title || "StreamWeaver Document"
      end

      def install
        return unless RUBY_ENGINE == "opal"

        runtime       = @runtime
        default_title = @title
        # :nocov:
        %x{
          globalThis.SWRender = {
            html: function() { return #{runtime.render_body_html}; },
            css: function() { return #{runtime.collected_css}; },
            document: function(title) {
              return #{runtime.render_document(title: `title == null ? default_title : title`)};
            }
          };
        }
        # :nocov:
        nil
      end
    end
  end
end
