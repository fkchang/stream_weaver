# frozen_string_literal: true

require 'spec_helper'

# A spec run popped real browser tabs on the developer's desktop
# (streamweaver get-started's premier path under test, no real iTerm
# session -- ledger: get-started-door-command). Root cause: this codebase
# has FOUR independent places that actually shell out to open a URL
# (`system('open'|'xdg-open'|'start', url)`), documented as duplicated
# rather than consolidated in docs/university/dependency-survey.md -- and
# not every one of them checked SW_NO_OPEN. spec/spec_helper.rb now forces
# SW_NO_OPEN=1 for the whole suite as the blanket guarantee, but that only
# holds if every primitive that can shell out actually honors it. This
# sweep is the ledger that keeps that true.
#
# Textual and therefore approximate (same accepted limit as
# spec/canvas/htmx_call_site_sweep_spec.rb): it would miss a call built by
# metaprogramming, or count a mention inside a comment/string. The
# alternative -- no ledger at all -- is what let the ungated ones through.
RSpec.describe 'browser-open call site sweep' do
  LIB_DIR = File.expand_path('../lib/stream_weaver', __dir__)

  # file (relative to lib/stream_weaver/) => method name(s) whose body
  # contains a raw system('open'|'xdg-open'|'start', ...) call. Each one
  # must also contain an SW_NO_OPEN guard somewhere in its body (checked
  # below) -- adding a 5th raw call site means adding it here deliberately
  # AND guarding it, not adding it here to make this spec pass.
  KNOWN_RAW_OPEN_METHODS = {
    'cli.rb' => %w[open_browser],
    'server.rb' => %w[open_browser],
    'service_client.rb' => %w[open_in_browser],
    'iterm.rb' => %w[split_vertical_with_url]
  }.freeze

  def self.raw_open_methods_by_file
    Dir.glob(File.join(LIB_DIR, '**', '*.rb')).each_with_object({}) do |path, found|
      relative = path.sub("#{LIB_DIR}/", '')
      enclosing = nil
      methods = File.readlines(path).filter_map do |line|
        enclosing = Regexp.last_match(1) if line =~ /^\s*def (?:self\.)?(\w+[?!]?)/
        enclosing if line =~ /system\(\s*['"](?:open|xdg-open|start)['"]/
      end.uniq
      found[relative] = methods unless methods.empty?
    end
  end

  # Textual extraction of one `def ... end` block by name, matching `end`
  # at the same indentation as the `def` line (same approach as the htmx
  # sweep) -- robust against nested if/case/do blocks inside the method,
  # including modifier-form `if`/`unless` which a naive keyword-depth
  # counter would miscount.
  def self.extract_method_source(path, method_name)
    lines = File.readlines(path)
    start_idx = lines.index { |l| l =~ /^(\s*)def (?:self\.)?#{Regexp.escape(method_name)}\b/ }
    return '' unless start_idx

    indent = lines[start_idx][/^\s*/]
    end_idx = ((start_idx + 1)...lines.size).find { |i| lines[i] =~ /^#{indent}end\s*(?:#.*)?$/ }
    lines[start_idx..(end_idx || start_idx)].join
  end

  it 'has exactly the known set of methods that shell out to open a URL' do
    actual = self.class.raw_open_methods_by_file
    expect(actual).to eq(KNOWN_RAW_OPEN_METHODS),
      "A method now shells out to open a URL that isn't declared in KNOWN_RAW_OPEN_METHODS.\n" \
      "Decide whether it needs an SW_NO_OPEN guard (almost certainly yes), add the guard, " \
      "then declare it here.\n" \
      "Found: #{actual.inspect}\n" \
      "Expected: #{KNOWN_RAW_OPEN_METHODS.inspect}"
  end

  KNOWN_RAW_OPEN_METHODS.each do |file, methods|
    methods.each do |method_name|
      it "#{file}##{method_name} is guarded by SW_NO_OPEN somewhere in its body" do
        source = self.class.extract_method_source(File.join(LIB_DIR, file), method_name)

        expect(source).not_to eq(''), "could not locate `def #{method_name}` in #{file} -- sweep is stale"
        expect(source).to match(/SW_NO_OPEN/),
          "#{file}##{method_name} shells out to open a URL but has no SW_NO_OPEN guard anywhere " \
          "in its body:\n#{source}"
      end
    end
  end
end
