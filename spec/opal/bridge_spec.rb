# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/bridge"

RSpec.describe StreamWeaver::Opal::OpalBridge do
  describe "data-sw-action toggle-theme listener" do
    it "is documented: clicking [data-sw-action=toggle-theme] calls swToggleTheme()" do
      # Browser-only — covered by OpalBridge#install (:nocov:).
      # Manually verified: button rendered by render_theme_toggle triggers swToggleTheme()
      # when dark_mode_script is present in the built index.html.
      pending "browser-only; not testable in MRI"
      fail "Test would pass here when running in a real browser"
    end
  end
end
