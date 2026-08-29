# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

# Story step-4-growing-doc's script: a background boot smoke test, not a
# canvas-integration test (that's UAT -- see the story's consolidated
# handoff note on step-1-canvas-push). Confirms the file requires and
# starts cleanly under SW_NO_OPEN=1 without a Ruby-level crash, then is
# killed by PID rather than waited out to completion -- a live bridge
# would otherwise keep it sleeping between pushes for the full pause.
RSpec.describe 'stream_weaver/university/scripts/growing_doc.rb' do
  let(:script_path) do
    File.expand_path('../../../lib/stream_weaver/university/scripts/growing_doc.rb', __dir__)
  end
  let(:session_name) { "growing-doc-smoke-#{Process.pid}" }

  after do
    require 'stream_weaver/canvas/client'
    StreamWeaver::Canvas::Client.send_message(
      StreamWeaver::Canvas::Protocol::Messages.close(session_name)
    )
  rescue StandardError
    nil # best-effort cleanup; no bridge reachable is fine here
  end

  it 'boots under SW_NO_OPEN=1 without raising, and can be killed by PID' do
    pid = Process.spawn(
      { 'SW_NO_OPEN' => '1', 'STREAMWEAVER_GROWING_DOC_PAUSE' => '5' },
      Gem.ruby, '-I', File.expand_path('../../../lib', __dir__), script_path, session_name,
      out: File::NULL, err: File::NULL
    )

    killed_mid_run = false
    status = begin
      Timeout.timeout(1) { Process.waitpid2(pid).last }
    rescue Timeout::Error
      Process.kill('TERM', pid)
      Process.waitpid2(pid)
      killed_mid_run = true
      nil
    end

    # Either it finished fast (no bridge reachable -- the rescued warning
    # path exits 0) or it was still mid-run against a live bridge and we
    # killed it by PID; both mean the script loaded and ran, not crashed.
    expect(killed_mid_run || status.success?).to be(true)
  end
end
