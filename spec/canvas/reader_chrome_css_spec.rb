# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'rack/test'
require 'stream_weaver/canvas/reader'

# The reader's own chrome CSS needs BOTH cascade layering and selector
# scoping -- neither alone is sufficient (stream_weaver-csf):
#
#   * Scoping alone fails: PageShell::CANVAS_CSS and master_theme_css both
#     style bare h1..h6/p/a, which would hit the rail's own headings and links
#     if the chrome CSS weren't in a later layer.
#   * Layering alone fails: an unscoped `body { font-family: ... }` in the
#     later layer would beat every theme font rule for the WHOLE page, not
#     just the rail.
#
# This spec is the guard on the scoping half. The one sanctioned exception is
# the `html { padding-left }` rail offset, which by design has no framework
# equivalent to lose to.
RSpec.describe StreamWeaver::Canvas::Reader, 'chrome CSS scoping' do
  include Rack::Test::Methods
  def app = described_class

  before(:all) do
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, 'doc1.rb'), "header1 'Doc One'")
    described_class.configure_files!(
      described_class::FileList.build([@dir])
    )
  end

  after(:all) { FileUtils.rm_rf(@dir) }

  let(:chrome_css) do
    get '/?file=0'
    css = last_response.body[/<style id="sw-reader-chrome-css">([\s\S]*?)<\/style>/, 1]
    expect(css).not_to be_nil, 'reader chrome CSS block not found'
    css
  end

  # Selector lists are everything preceding a `{` that isn't an at-rule.
  def selectors_in(css)
    css.gsub(%r{/\*[\s\S]*?\*/}, '')
       .scan(/([^{}]+)\{/)
       .flatten
       .flat_map { |s| s.split(',') }
       .map(&:strip)
       .reject(&:empty?)
       .reject { |s| s.start_with?('@') }
  end

  it 'wraps the whole block in the sw-reader-chrome layer' do
    expect(chrome_css).to start_with('@layer sw-reader-chrome {')
  end

  it 'roots every selector at html or #sw-reader-' do
    offenders = selectors_in(chrome_css).reject { |s| s.match?(/\A(html|#sw-reader-)/) }
    expect(offenders).to be_empty,
      "unscoped reader chrome selector(s) would bleed into doc content: #{offenders.inspect}"
  end

  it 'offsets for the rail on html, never on body' do
    expect(chrome_css).to match(/html\s*\{[^}]*padding-left/)
    expect(selectors_in(chrome_css)).not_to include(a_string_matching(/\bbody\b/))
  end

  it 'collapses the rail with left, not transform (fixed descendants must stay viewport-fixed)' do
    rail_rules = chrome_css.scan(/#sw-reader-chrome\s*\{[^}]*\}/)
    expect(rail_rules).not_to be_empty
    expect(rail_rules.join).not_to match(/transform\s*:/)
  end

  it 'collapses the rail below 1100px' do
    expect(chrome_css).to match(/@media \(max-width: 1100px\)/)
  end

  it 'pins the chrome layer after the framework layer' do
    get '/?file=0'
    expect(last_response.body).to include('<style>@layer stream-weaver, sw-reader-chrome;</style>')
  end
end
