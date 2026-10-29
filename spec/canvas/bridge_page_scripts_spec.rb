# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'tmpdir'
require 'open3'
require 'stream_weaver/canvas/bridge_server'

# Every inline <script> in the live canvas page must parse. The page is built
# in an interpolating heredoc, where a backslash sequence in JS (e.g. /\/$/)
# is silently rewritten by Ruby and can turn into a `//` comment: the script
# then fails to parse and its listeners never register, with no spec noticing.
RSpec.describe 'canvas page inline scripts', type: :request do
  include Rack::Test::Methods

  def app = StreamWeaver::Canvas::BridgeServer

  around do |ex|
    prev = app.bridge
    app.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      app.bridge = prev
    end
  end

  let(:page) do
    app.bridge.create_session('plan').add_note(text: 'a comment')
    get '/canvas/plan'
    last_response.body
  end

  let(:inline_scripts) do
    page.gsub(/<!--.*?-->/m, "").scan(%r{<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>}m).flatten.reject { |s| s.strip.empty? }
  end

  it 'finds the inline scripts, including the region-button script' do
    expect(inline_scripts.size).to be >= 4
    expect(inline_scripts.grep(/data-sw-region\] \[data-sw-action\]/)).not_to be_empty
  end

  it 'serves the region-button script with its trailing-slash regex intact' do
    script = inline_scripts.find { |s| s.include?('[data-sw-region] [data-sw-action]') }
    expect(script).to include("replace(/\\/$/, '')")
    expect(script).not_to include('replace(//$')
  end

  it 'parses every inline script (node --check)' do
    skip 'node is not on PATH; cannot syntax-check inline scripts' unless system('which node > /dev/null 2>&1')

    Dir.mktmpdir do |dir|
      inline_scripts.each_with_index do |script, i|
        file = File.join(dir, "inline#{i}.js")
        File.write(file, script)
        _, err, status = Open3.capture3('node', '--check', file)
        expect(status.success?).to be(true), "inline script #{i} does not parse: #{err.lines.first(4).join}\n#{script[0, 120]}"
      end
    end
  end
end
