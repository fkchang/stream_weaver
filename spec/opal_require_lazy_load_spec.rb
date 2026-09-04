# frozen_string_literal: true

require 'spec_helper'

# opal (~> 1.8 in the Gemfile) is the heavyweight browser-compile toolchain
# behind `streamweaver opal-build` -- deliberately NOT a stream_weaver.gemspec
# runtime dependency, because a doc-shelf-only `gem install stream_weaver`
# must never be forced to pull it in. A clean-gemset install test caught a
# top-level `require "opal"` in lib/stream_weaver/opal/builder.rb, reached
# unconditionally via cli.rb -> stream_weaver.rb at load time, which crashed
# every invocation (including `streamweaver --help`) when opal wasn't
# installed.
#
# Textual and therefore approximate (same accepted limit as
# spec/browser_open_call_site_sweep_spec.rb): it would miss a require built
# by metaprogramming, or count one hidden inside a string. The alternative --
# no ledger at all -- is what let the eager one through.
RSpec.describe 'opal require lazy-load sweep' do
  OPAL_SWEEP_LIB_DIR = File.expand_path('../lib', __dir__)

  # Any `require "opal"` / `require 'opal'` line found at column 0 (i.e. not
  # indented inside a method body) would run the moment the file loads.
  def self.top_level_opal_requires
    Dir.glob(File.join(OPAL_SWEEP_LIB_DIR, '**', '*.rb')).each_with_object({}) do |path, found|
      lines = File.readlines(path).each_with_index.select do |line, _idx|
        line =~ /^require\s+['"]opal['"]/
      end
      relative = path.sub("#{OPAL_SWEEP_LIB_DIR}/", '')
      found[relative] = lines.map { |_line, idx| idx + 1 } unless lines.empty?
    end
  end

  it 'has no top-level (unconditional, file-load-time) require of "opal"' do
    actual = self.class.top_level_opal_requires
    expect(actual).to eq({}),
      "Found a top-level `require \"opal\"` -- this runs at file-load time, " \
      "before any opal feature is actually invoked, forcing every " \
      "stream_weaver load path (including `streamweaver --help`) to have " \
      "the opal gem installed. Move it inside the method that actually " \
      "needs it (see StreamWeaver::Opal::OpalBuilder.require_opal!).\n" \
      "Found: #{actual.inspect}"
  end

  it 'still lazily loads opal from OpalBuilder.require_opal! when the feature is actually used' do
    source = File.read(File.join(OPAL_SWEEP_LIB_DIR, 'stream_weaver/opal/builder.rb'))
    expect(source).to match(/def self\.require_opal!.*require\s+['"]opal['"]/m),
      'expected StreamWeaver::Opal::OpalBuilder.require_opal! to require "opal" -- sweep is stale'
  end
end
