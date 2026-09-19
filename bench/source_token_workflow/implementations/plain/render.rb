# frozen_string_literal: true

require "erb"
require "fileutils"
root = File.expand_path("../..", __dir__)
output = File.join(root, "tmp", "rendered")
template = ERB.new(File.read(File.join(__dir__, "dashboard.erb"), encoding: "UTF-8"), trim_mode: "-")
FileUtils.mkdir_p(output)

variant = ARGV.fetch(0)
raise ArgumentError, "variant must be initial or revised" unless %w[initial revised].include?(variant)

require_relative variant
html = template.result_with_hash(SourceTokenWorkflow::PlainDashboard.locals)
File.write(File.join(output, "plain-#{variant}.html"), html)
