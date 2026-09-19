#!/usr/bin/env ruby
# frozen_string_literal: true

# Run: SW_NO_OPEN=1 ruby examples/components/code_preview_demo_app.rb
# Open: http://localhost:4567 (or whatever port the banner prints)

require_relative "../../lib/stream_weaver"

DEMO_DSL_PATH = File.join(__dir__, "code_preview_demo.rb")

CodePreviewDemo = app "Code Preview Demo", layout: :wide do
  instance_eval(File.read(DEMO_DSL_PATH), DEMO_DSL_PATH)
end

CodePreviewDemo.run! if __FILE__ == $0
