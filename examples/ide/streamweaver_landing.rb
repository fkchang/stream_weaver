#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone entry for the StreamWeaver landing page. The page itself is the
# bare DSL body in streamweaver_landing_body.rb, shared with canvas-push.
#
# Run with: SW_NO_OPEN=1 bundle exec ruby examples/ide/streamweaver_landing.rb
# (drop SW_NO_OPEN to open a browser tab). The theme toggle in the title bar
# flips light and dark; below 1180px the right rail moves behind the menu
# button and below 840px the left rail is hidden.

require_relative "../../lib/stream_weaver"

module StreamWeaverLanding
  BODY_PATH = File.join(__dir__, "streamweaver_landing_body.rb")

  APP = StreamWeaver::App.new("StreamWeaver", chrome: false, theme: :ide) do
    instance_eval(File.read(BODY_PATH), BODY_PATH)
  end
end

StreamWeaverLanding::APP.generate.run! if __FILE__ == $PROGRAM_NAME
