#!/usr/bin/env ruby
require 'opal'

# Add the lib directory so require_relative chains resolve properly
Opal.append_path File.expand_path('../lib', __dir__)

puts "Opal version: #{Opal::VERSION}"
puts "Ruby version: #{RUBY_VERSION}"
puts ""
puts "=" * 60
puts "PASS 1: Strict mode (documents missing requires)"
puts "=" * 60

# Helper: build a file using its logical Opal require path (relative to lib/)
def opal_build(logical_path, severity: :error)
  builder = Opal::Builder.new(missing_require_severity: severity)
  builder.build(logical_path)
  puts "OK: #{logical_path}"
rescue Opal::Builder::MissingRequire => e
  # Extract just the "can't find file" part
  msg = e.message.split("\n").first(2).join(" | ")
  puts "MISSING_REQUIRE: #{logical_path}"
  puts "  #{msg}"
rescue Opal::SyntaxError => e
  puts "FAIL(syntax): #{logical_path}"
  puts "  #{e.message[0..300]}"
rescue => e
  puts "FAIL: #{logical_path}"
  puts "  #{e.class}: #{e.message[0..300]}"
end

files = [
  'stream_weaver/version',
  'stream_weaver/utils',
  'stream_weaver/theme',
  'stream_weaver/display_dsl',
  'stream_weaver/app',
  'stream_weaver/components',
  'stream_weaver/adapter/base',
]

files.each { |f| opal_build(f) }

puts ""
puts "=" * 60
puts "PASS 2: Ignore missing requires (syntax-only check)"
puts "=" * 60

files.each { |f| opal_build(f, severity: :ignore) }

puts ""
puts "=" * 60
puts "PASS 3: kramdown Opal compatibility"
puts "=" * 60

begin
  builder = Opal::Builder.new(missing_require_severity: :ignore)
  builder.build('kramdown')
  puts "OK: kramdown"
rescue => e
  puts "FAIL: kramdown"
  puts "  #{e.class}: #{e.message.split("\n").first(2).join(' | ')}"
end
