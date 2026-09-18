# frozen_string_literal: true

require 'spec_helper'
require 'json'

# Egress guard for the sandboxed doc-render page.
#
# The sandbox compiles and evals arbitrary doc-author Ruby, and Opal's backtick
# / %x{} interop means that Ruby can call any JS function it likes. The only
# thing standing between a hostile doc and an arbitrary origin is this CSP, so
# the directives below are a security control, not a style preference.
#
# Kept in its own file rather than folded into slim_graph_r_runtime_spec.rb:
# that suite's before(:all) runs bin/build_extension (needs node and the
# slim_graph_r gem), and this guard has to keep running even when that build
# path is unavailable.
RSpec.describe 'the shipped extension sandbox CSP' do
  let(:policy) do
    manifest = JSON.parse(File.read(File.expand_path('../../extension/manifest.json', __dir__)))
    manifest.fetch('content_security_policy').fetch('sandbox')
  end

  it "blocks outbound fetch/XHR/WebSocket with connect-src 'none'" do
    expect(policy).to include("connect-src 'none'")
  end

  it "denies every unlisted fetch directive with default-src 'none'" do
    expect(policy).to include("default-src 'none'")
  end

  it "blocks form submission exfiltration with form-action 'none' (no default-src fallback)" do
    expect(policy).to include("form-action 'none'")
  end

  it 'still allows the local resources the sandbox itself needs' do
    expect(policy).to include("script-src 'self' 'unsafe-eval'")
    expect(policy).to include("style-src 'self' 'unsafe-inline'")
    expect(policy).to include('img-src \'self\' data: blob:')
    expect(policy).to include("font-src 'self' data:")
    expect(policy).to include("child-src 'self'")
  end

  it 'never allows a remote origin in any directive' do
    expect(policy).not_to match(%r{(?:https?:)?//})
  end
end
