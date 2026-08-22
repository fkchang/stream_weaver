# frozen_string_literal: true

require 'securerandom'
require 'rack/utils'

module StreamWeaver
  # Development-only "content missing" analog (dev-loud-failure-overlay,
  # streamweaver-way epic). Hotwire treats a missing/stale Turbo Frame
  # target as its single best debugging aid; StreamWeaver's fallback path
  # (server.rb's `rescue StaleActionDefinition`) instead self-heals with a
  # silent full-container swap so production users never see broken wiring.
  # That silence is deliberate in production (see docs/for_llms.md, "Dev
  # loud, prod self-heal") but costs the author a debugging signal in dev --
  # this module renders the loud version for RACK_ENV=development only.
  #
  # Framework-emitted only: app code stays zero-JS. The dismiss control is a
  # pure CSS checkbox/label pattern (see CSS.dev_fallback_css) -- no inline
  # `onclick`, no script tag.
  module DevFallbackOverlay
    CAUSES = {
      definition_changed: "action token stale — the app's registered actions changed since this " \
                           "token was issued (code reload). Interaction fell back to a full re-render.",
      generation_changed: "action token stale — the server session's action generation changed " \
                           "(restart or session reset) since this token was issued. Interaction " \
                           "fell back to a full re-render."
    }.freeze

    DEFAULT_CAUSE = "action token stale after code reload — interaction fell back to a full re-render."

    class << self
      # @param action [Symbol, String, nil] the named action the stale token was minted for
      # @param fragment [String, nil] the scoped fragment id the token declared as its swap target
      # @param cause [Symbol, nil] :definition_changed or :generation_changed
      # @return [String] HTML for the `.sw-dev-fallback` overlay, meant to be prepended to the
      #   fallback response body so it lands inside the retargeted #app-container swap
      def render(action: nil, fragment: nil, cause: nil)
        dismiss_id = "sw-dev-fallback-dismiss-#{SecureRandom.hex(4)}"
        target_label = fragment ? "##{fragment}" : (action ? "action #{action}" : "#app-container")

        <<~HTML
          <div class="sw-dev-fallback" role="alert">
            <input type="checkbox" id="#{dismiss_id}" class="sw-dev-fallback__dismiss" hidden>
            <div class="sw-dev-fallback__panel">
              <label for="#{dismiss_id}" class="sw-dev-fallback__close" aria-label="Dismiss">&times;</label>
              <p class="sw-dev-fallback__title">StreamWeaver dev warning — full re-render fallback</p>
              <p class="sw-dev-fallback__target">Target: <code>#{escape(target_label)}</code> (swapped as <code>#app-container</code> instead)</p>
              <p class="sw-dev-fallback__cause">#{escape(CAUSES.fetch(cause, DEFAULT_CAUSE))}</p>
              <p class="sw-dev-fallback__note">Dev-only — production silently self-heals the same way. See docs/for_llms.md, "Dev loud, prod self-heal".</p>
            </div>
          </div>
        HTML
      end

      private

      def escape(str)
        Rack::Utils.escape_html(str.to_s)
      end
    end
  end
end
